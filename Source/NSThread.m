/** Control of executable units within a shared virtual memory space
   Copyright (C) 1996-2000 Free Software Foundation, Inc.

   Original Author:  Scott Christley <scottc@net-community.com>
   Rewritten by: Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1996
   Rewritten by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   to add optimisations features for faster thread access.
   Modified by: Nicola Pero <n.pero@mi.flashnet.it>
   to add GNUstep extensions allowing to interact with threads created 
   by external libraries/code (eg, a Java Virtual Machine).
   
   This file is part of the GNUstep Objective-C Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSThread class reference</title>
   $Date$ $Revision$
*/ 

#include <config.h>
#include <base/preface.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>

static Class threadClass = Nil;
static NSNotificationCenter *nc = nil;

#ifndef NO_GNUSTEP
#if !defined(HAVE_OBJC_THREAD_ADD) && !defined(NeXT_RUNTIME)
/* We need to access these private vars in the objc runtime - because
   the objc runtime's API is not enough powerful for the GNUstep
   extensions we want to add.  */
extern objc_mutex_t __objc_runtime_mutex;
extern int __objc_runtime_threads_alive;
extern int __objc_is_multi_threaded;

inline static void objc_thread_add ()
{
  objc_mutex_lock(__objc_runtime_mutex);
  __objc_is_multi_threaded = 1;
  __objc_runtime_threads_alive++;
  objc_mutex_unlock(__objc_runtime_mutex);  
}

inline static void objc_thread_remove ()
{
  objc_mutex_lock(__objc_runtime_mutex);
  __objc_runtime_threads_alive--;
  objc_mutex_unlock(__objc_runtime_mutex);  
}
#endif /* not HAVE_OBJC_THREAD_ADD */
#endif

@interface	NSThread (Private)
- (id) _initWithSelector: (SEL)s toTarget: (id)t withObject: (id)o;
- (void) _sendThreadMethod;
@end

/*
 * Flag indicating whether the objc runtime ever went multi-threaded.
 */
static BOOL	entered_multi_threaded_state = NO;

/*
 * Default thread.
 */
static NSThread	*defaultThread = nil;

/**
 * Fast access function to get current thread.
 */
inline NSThread*
GSCurrentThread()
{
  NSThread	*t;

  if (entered_multi_threaded_state == NO)
    {
      /*
       * If the NSThread class has been initialized, we will have a default
       * thread set up - otherwise we must make sure the class is initialised.
       */
      if (defaultThread == nil)
	{
	  t = [NSThread currentThread];
	}
      else
	{
	  t = defaultThread;
	}
    }
  else
    {
      t = (NSThread*)objc_thread_get_data();
      if (t == nil)
	{
	  fprintf(stderr, "ALERT ... GSCurrentThread() ... the "
	    "objc_thread_get_data() call returned nil!");
	  fflush(stderr);	// Needed for windoze
	}
    }
  return t;
}

/**
 * Fast access function for thread dictionary of current thread.
 */
NSMutableDictionary*
GSCurrentThreadDictionary()
{
  NSThread		*thread = GSCurrentThread();

  if (thread == nil)
    {
      return nil;
    }
  else 
    {
      NSMutableDictionary	*dict = thread->_thread_dictionary;

      if (dict == nil)
	{
	  dict = [thread threadDictionary];
	}
      return dict; 
    }
}

/*
 * Callback function so send notifications on becoming multi-threaded.
 */
static void
gnustep_base_thread_callback()
{
  /*
   * Post a notification if this is the first new thread to be created.
   * Won't work properly if threads are not all created by this class,
   * but it's better than nothing.
   */
  if (entered_multi_threaded_state == NO)
    {
      entered_multi_threaded_state = YES;
      if (nc == nil)
	{
	  nc = [NSNotificationCenter defaultCenter];
	}
      [nc postNotificationName: NSWillBecomeMultiThreadedNotification
			object: nil
		      userInfo: nil];
    }
}


@implementation NSThread

/*
 * Return the current thread
 */
+ (NSThread*) currentThread
{
  NSThread	*t;
 
  if (entered_multi_threaded_state == NO)
    {
      /*
       * The NSThread class has been initialized - so we will have a default
       * thread set up.
       */
      t = defaultThread;
      if (t == nil)
	{
	  fprintf(stderr, "ALERT ... [NSThread +currentThread] ... the "
	    "default thread is nil!");
	  fflush(stderr);	// Needed for windoze
	}
    }
  else
    {
      t = (NSThread*)objc_thread_get_data();
      if (t == nil)
	{
	  fprintf(stderr, "ALERT ... [NSThread +currentThread] ... the "
	    "objc_thread_get_data() call returned nil!");
	  fflush(stderr);	// Needed for windoze
	}
    }
  return t;
}

/*
 * Create a new thread - use this method rather than alloc-init
 */
+ (void) detachNewThreadSelector: (SEL)aSelector
		        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
  NSThread	*thread;

  /*
   * Make sure the notification is posted BEFORE the new thread starts.
   */
  gnustep_base_thread_callback();

  /*
   * Create the new thread.
   */
  thread = (NSThread*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  thread = [thread _initWithSelector: aSelector
			    toTarget: aTarget
			  withObject: anArgument];

  /*
   * Have the runtime detach the thread
   */
  if (objc_thread_detach(@selector(_sendThreadMethod), thread, nil) == NULL)
    {
      /* This should probably be an exception */
      NSLog(@"Unable to detach thread (unknown error)");
    }
}

/*
 * Terminating a thread
 * What happens if the thread doesn't call +exit - it doesn't terminate!
 */
+ (void) exit
{
  NSThread		*t;

  t = GSCurrentThread();
  if (t->_active == YES)
    {
      /*
       * Set the thread to be inactive to avoid any possibility of recursion.
       */
      t->_active = NO;

      /*
       * Let observers know this thread is exiting.
       */
      if (nc == nil)
	{
	  nc = [NSNotificationCenter defaultCenter];
	}
      [nc postNotificationName: NSThreadWillExitNotification
			object: t
		      userInfo: nil];

      /*
       * destroy the thread object.
       */
      DESTROY(t);

      objc_thread_set_data (NULL);

      /*
       * Tell the runtime to exit the thread
       */
      objc_thread_exit();
    }
}

/*
 * Class initialization
 */
+ (void) initialize
{
  if (self == [NSThread class])
    {
      /*
       * The objc runtime calls this callback AFTER creating a new thread -
       * which is not correct for us, but does at least mean that we can tell
       * if we have become multi-threaded due to a call to the runtime directly
       * rather than via the NSThread class.
       */
      objc_set_thread_callback(gnustep_base_thread_callback);

      /*
       * Ensure that the default thread exists.
       */
      defaultThread
	= (NSThread*)NSAllocateObject(self, 0, NSDefaultMallocZone());
      defaultThread = [defaultThread _initWithSelector: (SEL)0
					      toTarget: nil
					    withObject: nil];
      defaultThread->_active = YES;
      objc_thread_set_data(defaultThread);
      threadClass = self;
    }
}

+ (BOOL) isMultiThreaded
{
  return entered_multi_threaded_state;
}

/*
 * Delaying a thread
 */
+ (void) sleepUntilDate: (NSDate*)date
{
  NSTimeInterval delay;

  // delay is always the number of seconds we still need to wait
  delay = [date timeIntervalSinceNow];

  // Avoid integer overflow by breaking up long sleeps
  // We assume usleep can accept a value at least 31 bits in length
  while (delay > 30.0*60.0)
    {
      // sleep 30 minutes
#ifdef	HAVE_USLEEP
      usleep (30*60*1000000);
#else
#if defined(__MINGW__)
      Sleep (30*60*1000);
#else
      sleep (30*60);
#endif
#endif
      delay = [date timeIntervalSinceNow];
    }

  // usleep may return early because of signals
  while (delay > 0)
    {
#ifdef	HAVE_USLEEP
      usleep ((int)(delay*1000000));
#else
#if defined(__MINGW__)
      Sleep (delay*1000);
#else
      sleep ((int)delay);
#endif
#endif
      delay = [date timeIntervalSinceNow];
    }
}



/*
 * Thread instance methods.
 */

- (void) dealloc
{
  if (_active == YES)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Deallocating an active thread without [+exit]!"];
    }
  DESTROY(_thread_dictionary);
  DESTROY(_target);
  DESTROY(_arg);
  [NSAutoreleasePool _endThread: self];

  if (_thread_dictionary != nil)
    {
      /*
       * Try again to get rid of thread dictionary.
       */
      init_autorelease_thread_vars(&_autorelease_vars);
      DESTROY(_thread_dictionary);
      [NSAutoreleasePool _endThread: self];
      if (_thread_dictionary != nil)
	{
	  init_autorelease_thread_vars(&_autorelease_vars);
	  NSLog(@"Oops - leak - thread dictionary is %@", _thread_dictionary);
	  [NSAutoreleasePool _endThread: self];
	}
    }
  NSDeallocateObject(self);
}

- (id) init
{
  RELEASE(self);
  return [NSThread currentThread];
}

- (id) _initWithSelector: (SEL)s toTarget: (id)t withObject: (id)o
{
  /* initialize our ivars. */
  _selector = s;
  _target = RETAIN(t);
  _arg = RETAIN(o);
  _thread_dictionary = nil;	// Initialize this later only when needed
  _exception_handler = NULL;
  _active = NO;
  init_autorelease_thread_vars(&_autorelease_vars);
  return self;
}

- (void) _sendThreadMethod
{
  /*
   * We are running in the new thread - so we store ourself in the thread
   * dictionary and release ourself - thus, when the thread exits, we will
   * be deallocated cleanly.
   */
  objc_thread_set_data(self);
  _active = YES;

#ifndef NO_GNUSTEP
  /*
   * Let observers know a new thread is starting.
   */
  if (nc == nil)
    {
      nc = [NSNotificationCenter defaultCenter];
    }
  [nc postNotificationName: NSThreadDidStartNotification
		    object: self
		  userInfo: nil];
#endif

  [_target performSelector: _selector withObject: _arg];
  [NSThread exit];
}

/*
 * Thread dictionary
 * NB. This cannot be autoreleased, since we cannot be sure that the
 * autorelease pool for the thread will continue to exist for the entire
 * life of the thread!
 */
- (NSMutableDictionary*) threadDictionary
{
  if (_thread_dictionary == nil)
    {
      _thread_dictionary = [NSMutableDictionary new];
    }
  return _thread_dictionary;
}

@end

typedef struct { @defs(NSThread) } NSThread_ivars;


BOOL
GSRegisterCurrentThread (void)
{
  NSThread *thread;

  /*
   * Do nothing and return NO if the thread is known to us.
   */
  if ((NSThread*)objc_thread_get_data() != nil)
    {
      return NO;
    }

  /*
   * Make sure the Objective-C runtime knows there is an additional thread.
   */
  objc_thread_add ();

  if (threadClass == 0)
    {
      /*
       * If the threadClass has not been set, NSThread has not been
       * initialised, and there is no default thread.  So we must
       * initialise now ... which will make the current thread the default.
       */
      NSCAssert(entered_multi_threaded_state == NO,
	NSInternalInconsistencyException);
      thread = [NSThread currentThread];
    }
  else
    {
      /*
       * Create the new thread object.
       */
      thread = (NSThread*)NSAllocateObject (threadClass, 0, 
					NSDefaultMallocZone ());
      thread = [thread _initWithSelector: NULL  toTarget: nil  withObject: nil];
      objc_thread_set_data (thread);
      ((NSThread_ivars *)thread)->_active = YES;
    }

  /*
   * We post the notification after we register the thread.  
   * NB. Even if we are the default thread, we do this to register the app
   * as being multi-threaded - this is so that, if this thread is unregistered
   * later, it does not leave us with a bad default thread.
   */
  gnustep_base_thread_callback();

  return YES;
}

void
GSUnregisterCurrentThread (void)
{
  NSThread *thread;

  thread = GSCurrentThread();
  
  if (((NSThread_ivars *)thread)->_active == YES)
    {
      /*
       * Set the thread to be inactive to avoid any possibility of recursion.
       */
      ((NSThread_ivars *)thread)->_active = NO;
      
      /*
       * Let observers know this thread is exiting.
       */
      if (nc == nil)
	{
	  nc = [NSNotificationCenter defaultCenter];
	}
      [nc postNotificationName: NSThreadWillExitNotification
			object: thread
		      userInfo: nil]; 

      /*
       * destroy the thread object.
       */
      DESTROY (thread);

      objc_thread_set_data (NULL);

      /*
       * Make sure Objc runtime knows there is a thread less to manage
       */
      objc_thread_remove ();
    }
}
