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
#include <sys/types.h>
#include <sys/socket.h>

#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSConnection.h>

@class	GSPerformHolder;

static Class threadClass = Nil;
static NSNotificationCenter *nc = nil;

static NSArray *
commonModes()
{
  static NSArray	*modes = nil;

  if (modes == nil)
    {
      [gnustep_global_lock lock];
      if (modes == nil)
	{
	  Class	c = NSClassFromString(@"NSApplication");
	  SEL	s = @selector(allRunLoopModes);

	  if (c != 0 && [c respondsToSelector: s])
	    {
	      modes = RETAIN([c performSelector: s]);
	    }
	  else
	    {
	      modes = [[NSArray alloc] initWithObjects:
		NSDefaultRunLoopMode, NSConnectionReplyMode, nil];
	    }
	}
      [gnustep_global_lock unlock];
    }
  return modes;
}

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
 * <p>
 *   This function is a GNUstep extension.  It pretty much
 *   duplicates the functionality of [NSThread +currentThread]
 *   but is more efficient and is used internally throughout
 *   GNUstep.
 * </p>
 * <p>
 *   Returns the current thread.  Could perhaps return <code>nil</code>
 *   if executing a thread that was started outside the GNUstep
 *   environment and not registered (this should not happen in a
 *   well-coded application).
 * </p>
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
GSDictionaryForThread(NSThread *t)
{
  if (t == nil)
    {
      t = GSCurrentThread();
    }
  if (t == nil)
    {
      return nil;
    }
  else 
    {
      NSMutableDictionary	*dict = t->_thread_dictionary;

      if (dict == nil)
	{
	  dict = [t threadDictionary];
	}
      return dict; 
    }
}

/**
 * Fast access function for thread dictionary of current thread.
 */
NSMutableDictionary*
GSCurrentThreadDictionary()
{
  return GSDictionaryForThread(nil);
}

/**
 * Returns the run loop for the specified thread (or, if t is nil,
 * for the current thread).  Creates a new run loop if necessary.<br />
 * Returns nil on failure.
 */
NSRunLoop*
GSRunLoopForThread(NSThread *t)
{
  static NSString       *key = @"NSRunLoopThreadKey";
  NSMutableDictionary   *d = GSDictionaryForThread(t);
  NSRunLoop             *r;

  r = [d objectForKey: key];
  if (r == nil)
    {
      if (d != nil)
        {
          r = [NSRunLoop new];
          [d setObject: r forKey: key];
          RELEASE(r);
        }
    }
  return r;
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

      [GSPerformHolder class];	// Force initialization

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

/**
 * <p>
 *   Returns the NSThread object corresponding to the current thread.
 * </p>
 * <p>
 *   NB. In GNUstep the library internals use the GSCurrentThread()
 *   function as a more efficient mechanism for doing this job - so
 *   you cannot use a category to override this method and expect
 *   the library internals to use your implementation.
 * </p>
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

/**
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
      entered_multi_threaded_state = NO;
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to detach thread (unknown error)"];
    }
}

/**
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

/**
 * Returns a flag to say whether the application is multi-threaded or not.
 * An application is considered to be multi-threaded if any thread other
 * than the main thread has been started, irrespective of whether that
 * thread has since terminated.
 */
+ (BOOL) isMultiThreaded
{
  return entered_multi_threaded_state;
}

/**
 * Set the priority of the current thread.  This is a value in the
 * range 0.0 (lowest) to 1.0 (highest) which is mapped to the underlying
 * system priorities.  The current gnu objc runtime supports three
 * priority levels which you can obtain using values of 0.0, 0.5, and 1.0
 */
+ (void) setThreadPriority: (double)pri
{
  int	p;

  if (pri <= 0.3)
    p = OBJC_THREAD_LOW_PRIORITY;
  else if (pri <= 0.6)
    p = OBJC_THREAD_BACKGROUND_PRIORITY;
  else
    p = OBJC_THREAD_INTERACTIVE_PRIORITY;

  objc_thread_set_priority(p);
}

/**
 * Delaying a thread ... pause until the specified date.
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

/**
 * Return the priority of the current thread.
 */
+ (double) threadPriority
{
  int	p = objc_thread_get_priority();

  if (p == OBJC_THREAD_LOW_PRIORITY)
    return 0.0;
  else if (p == OBJC_THREAD_BACKGROUND_PRIORITY)
    return 0.5;
  else if (p == OBJC_THREAD_INTERACTIVE_PRIORITY)
    return 1.0;
  else
    return 0.0;	// Unknown.
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

  [_target performSelector: _selector withObject: _arg];
  [NSThread exit];
}

/**
 * Return the thread dictionary.  This dictionary can be used to store
 * arbitrary thread specific data.<br />
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



/**
 * This class performs a dual function ...
 * <p>
 *   As a class, it is responsible for handling incoming events from
 *   the main run loop on a special inputFd.  This consumes any bytes
 *   written to wake the main run loop.<br />
 *   During initialisation, the default run loop is set up to watch
 *   for data arriving on inputFd.
 * </p>
 * <p>
 *   As instances, each  instance retains perform receiver and argument
 *   values as long as they are needed, and handles locking to support
 *   mthods which want to block until an action has been performed.
 * </p>
 * <p>
 *   The initialize method of this class is called before any new threads
 *   run.
 * </p>
 */
@interface GSPerformHolder : NSObject
{
  id			receiver;
  id			argument;
  SEL			selector;
  NSArray		*modes;
  NSConditionLock	*lock;		// Not retained.
}
+ (BOOL) isValid;
+ (GSPerformHolder*) newForReceiver: (id)r
			   argument: (id)a
			   selector: (SEL)s
			      modes: (NSArray*)m
			       lock: (NSConditionLock*)l;
+ (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode;
+ (NSDate*) timedOutEvent: (void*)data
                     type: (RunLoopEventType)type
                  forMode: (NSString*)mode;
- (void) fire;
@end

@implementation GSPerformHolder

static NSLock *subthreadsLock = nil;
static int inputFd = -1;
static int outputFd = -1;
static NSMutableArray *perfArray = nil;
static NSDate *theFuture;

+ (void) initialize
{
  int		fd[2];
  NSRunLoop	*loop = GSRunLoopForThread(defaultThread);
  NSArray	*m = commonModes();
  unsigned	count = [m count];
  unsigned	i;

  theFuture = RETAIN([NSDate distantFuture]);

  pipe(fd);

  subthreadsLock = [[NSLock alloc] init];

  perfArray = [[NSMutableArray alloc] initWithCapacity: 10];

  inputFd = fd[0];
  outputFd = fd[1];

  for (i = 0; i < count; i++ )
    {
      [loop addEvent: (void*)inputFd
		type: ET_RDESC
	     watcher: (id<RunLoopEvents>)self
	     forMode: [m objectAtIndex: i]];
    }
}

+ (BOOL) isValid
{
  return YES;
}

+ (GSPerformHolder*) newForReceiver: (id)r
			   argument: (id)a
			   selector: (SEL)s
			      modes: (NSArray*)m
			       lock: (NSConditionLock*)l
{
  GSPerformHolder	*h;

  h = (GSPerformHolder*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  h->receiver = RETAIN(r);
  h->argument = RETAIN(a);
  h->selector = s;
  h->modes = RETAIN(m);
  h->lock = l;

  [subthreadsLock lock];
  [perfArray addObject: h];
  write(outputFd, "0", 1);
  [subthreadsLock unlock];

  return h;
}

+ (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];
  unsigned	c;
  char		dummy;

  read(inputFd, &dummy, 1);

  [subthreadsLock lock];

  c = [perfArray count];
  while (c-- > 0)
    {
      GSPerformHolder	*h = [perfArray objectAtIndex: c];

      [loop performSelector: @selector(fire)
		     target: h
		   argument: nil
		      order: 0
		      modes: h->modes];
    }
  [perfArray removeAllObjects];
      
  [subthreadsLock unlock];
}

+ (NSDate*) timedOutEvent: (void*)data
                     type: (RunLoopEventType)type
                  forMode: (NSString*)mode
{
  return theFuture;
}

- (void) dealloc
{
  DESTROY(receiver);
  DESTROY(argument);
  DESTROY(modes);
  if (lock != nil)
    {
      [lock lock];
      [lock unlockWithCondition: 1];
      lock = nil;
    }
  NSDeallocateObject(self);
}

- (void) fire
{
  if (receiver == nil)
    {
      return;	// Already fired!
    }
  [GSRunLoopForThread(defaultThread) cancelPerformSelectorsWithTarget: self];
  [receiver performSelector: selector withObject: argument];
  DESTROY(receiver);
  DESTROY(argument);
  DESTROY(modes);
  if (lock == nil)
    {
      RELEASE(self);
    }
  else
    {
      [lock lock];
      [lock unlockWithCondition: 1];
      lock = nil;
    }
}
@end

@implementation	NSObject (NSMainThreadPerformAdditions)

/**
 * <p>This method performs aSelector on the receiver, passing anObject as
 * an argument, but does so in the main thread of the program.  The receiver
 * and anObject are both retained until the method is performed.
 * </p>
 * <p>The selector is performed when the runloop of the main thread is in
 * one of the modes specified in anArray, or if there are no modes in
 * anArray, the method has no effect and simply returns immediately.
 * </p>
 * <p>The argument aFlag specifies whether the method should wait until
 * the selector has been performed before returning.<br />
 * <strong>NB.</strong> This method does <em>not</em> cause the run loop of
 * the main thread to be run ... so if the run loop is not executed by some
 * code in the main thread, the thread waiting for the perform to complete
 * will block forever.
 * </p>
 * <p>As a special case, if aFlag == YES and the current thread is the main
 * thread, the modes array is ignord and the selector is performed immediately.
 * This behavior is necessary to avoid the main thread being blocked by
 * waiting for a perform which will never happen because the run loop is
 * not executing.
 * </p>
 */
- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
			       modes: (NSArray*)anArray
{
  NSThread	*t;

  if ([anArray count] == 0)
    {
      return;
    }

  t = GSCurrentThread();
  if (t == defaultThread)
    {
      if (aFlag == YES)
	{
	  [self performSelector: aSelector withObject: anObject];
	}
      else
	{
	  [GSRunLoopForThread(t) performSelector: aSelector
					  target: self
					argument: anObject
					   order: 0
					   modes: anArray];
	}
    }
  else
    {
      GSPerformHolder	*h;
      NSConditionLock	*l = nil;

      if (aFlag == YES)
	{
	  l = [[NSConditionLock alloc] init];
	}
      
      h = [GSPerformHolder newForReceiver: self
				 argument: anObject
				 selector: aSelector
				    modes: anArray
				     lock: l];

      if (aFlag == YES)
	{
          [l lockWhenCondition: 1];
	  RELEASE(h);
	  [l unlock];
	  RELEASE(l);
	}
    }
}

/**
 * Invokes -performSelectorOnMainThread:withObject:waitUntilDone:modes:
 * using the supplied arguments and an array containing common modes.
 */
- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
{
  static NSArray	*commonModes = nil;

  if (commonModes == nil)
    {
      commonModes = [[NSArray alloc] initWithObjects:
	NSDefaultRunLoopMode, NSConnectionReplyMode, nil];
    }
  [self performSelectorOnMainThread: aSelector
			 withObject: anObject
		      waitUntilDone: aFlag
			      modes: commonModes];
}
@end
typedef struct { @defs(NSThread) } NSThread_ivars;


/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library register themselves to be used with the
 *   GNUstep system.  All such threads should call this function
 *   before attempting to use any GNUstep objects.
 * </p>
 * <p>
 *   Returns <code>YES</code> if the thread can be registered,
 *   <code>NO</code> if it is already registered.
 * </p>
 * <p>
 *   Sends out a <code>NSWillBecomeMultiThreadedNotification</code>
 *   if the process was not already multithreaded.
 * </p>
 */
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

/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library unregister themselves from the GNUstep threading
 *   system. 
 * </p>
 * <p>
 *   Calling this function causes a
 *   <code>NSThreadWillExitNotification</code>
 *   to be sent out, and destroys the GNUstep NSThread object
 *   associated with the thread.
 * </p>
 */
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
