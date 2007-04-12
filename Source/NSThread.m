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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSThread class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_NANOSLEEP
#include <time.h>
#endif
#ifdef NeXT_RUNTIME
#include "thr-mach.h"
#endif

#include <errno.h>

#include "Foundation/NSException.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSString.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSNotificationQueue.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSConnection.h"
#include "Foundation/NSInvocation.h"

#include "GSPrivate.h"
#include "GSRunLoopCtxt.h"

@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

typedef struct { @defs(NSThread) } NSThread_ivars;

static Class threadClass = Nil;
static NSNotificationCenter *nc = nil;

/**
 * This class performs a dual function ...
 * <p>
 *   As a class, it is responsible for handling incoming events from
 *   the main runloop on a special inputFd.  This consumes any bytes
 *   written to wake the main runloop.<br />
 *   During initialisation, the default runloop is set up to watch
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
- (void) fire;
@end

/**
 * Sleep until the current date/time is the specified time interval
 * past the reference date/time.<br />
 * Implemented as a function taking an NSTimeInterval argument in order
 * to avoid objc messaging and object allocation/deallocation (NSDate)
 * overheads.<br />
 * Used to implement [NSThread+sleepUntilDate:]
 */
void
GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval when)
{
  extern NSTimeInterval GSTimeNow(void);
  NSTimeInterval delay;

  // delay is always the number of seconds we still need to wait
  delay = when - GSTimeNow();

#ifdef	HAVE_NANOSLEEP
  // Avoid any possibility of overflow by sleeping in chunks.
  while (delay > 32768)
    {
      struct timespec request;

      request.tv_sec = (time_t)32768;
      request.tv_nsec = (long)0;
      nanosleep(&request, 0);
      delay = when - GSTimeNow();
    }
  if (delay > 0)
    {
      struct timespec request;
      struct timespec remainder;

      request.tv_sec = (time_t)delay;
      request.tv_nsec = (long)((delay - request.tv_sec) * 1000000000);
      remainder.tv_sec = 0;
      remainder.tv_nsec = 0;

      /*
       * With nanosleep, we can restart the sleep after a signal by using
       * the remainder information ... so we can be sure to sleep to the
       * desired limit without having to re-generate the delay needed.
       */
      while (nanosleep(&request, &remainder) < 0
	&& (remainder.tv_sec > 0 || remainder.tv_nsec > 0))
	{
	  request.tv_sec = remainder.tv_sec;
	  request.tv_nsec = remainder.tv_nsec;
	  remainder.tv_sec = 0;
	  remainder.tv_nsec = 0;
	}
    }
#else

  /*
   * Avoid integer overflow by breaking up long sleeps.
   */
  while (delay > 30.0*60.0)
    {
      // sleep 30 minutes
#if defined(__MINGW32__)
      Sleep (30*60*1000);
#else
      sleep (30*60);
#endif
      delay = when - GSTimeNow();
    }

  /*
   * sleeping may return early because of signals, so we need to re-calculate
   * the required delay and check to see if we need to sleep again.
   */
  while (delay > 0)
    {
#ifdef	HAVE_USLEEP
      usleep ((int)(delay*1000000));
#else
#if defined(__MINGW32__)
      Sleep (delay*1000);
#else
      sleep ((int)delay);
#endif
#endif
      delay = when - GSTimeNow();
    }
#endif
}

static NSArray *
commonModes(void)
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

inline static void objc_thread_add (void)
{
  objc_mutex_lock(__objc_runtime_mutex);
  __objc_is_multi_threaded = 1;
  __objc_runtime_threads_alive++;
  objc_mutex_unlock(__objc_runtime_mutex);
}

inline static void objc_thread_remove (void)
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
GSCurrentThread(void)
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
	  fprintf(stderr,
"ALERT ... GSCurrentThread() ... objc_thread_get_data() call returned nil!\n"
"Your application MUST call GSRegisterCurrentThread() before attempting to\n"
"use any GNUstep code from a thread other than the main GNUstep thread.\n");
	  fflush(stderr);	// Needed for windoze
	}
    }
  return t;
}

/**
 * Fast access function for thread dictionary of current thread.<br />
 * If there is no dictionary, creates the dictionary.
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
GSCurrentThreadDictionary(void)
{
  return GSDictionaryForThread(nil);
}

/*
 * The special timer which we set up in the run loop of the main thread
 * to perform housekeeping duties.  NSRunLoop needs to call this private
 * function so it knows about the housekeeping timer and won't keep the
 * loop running just to do housekeeping.
 *
 * The NSUserDefaults system registers as an observer of GSHousekeeping
 * notifications in order to synchronise the in-memory cache and the
 * on-disk database.
 */
static NSTimer	*housekeeper = nil;

/**
 * Returns the runloop for the specified thread (or, if t is nil,
 * for the current thread).<br />
 * Creates a new runloop if necessary,
 * as long as the thread dictionary exists.<br />
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
	  if (housekeeper == nil && (t == nil || t == defaultThread))
	    {
	      CREATE_AUTORELEASE_POOL	(arp);
	      NSNotificationCenter	*ctr;
	      NSNotification		*not;
	      NSInvocation		*inv;
	      SEL			sel;

	      ctr = [NSNotificationCenter defaultCenter];
	      not = [NSNotification notificationWithName: @"GSHousekeeping"
						  object: nil
						userInfo: nil];
	      sel = @selector(postNotification:);
	      inv = [NSInvocation invocationWithMethodSignature:
		[ctr methodSignatureForSelector: sel]];
	      [inv setTarget: ctr];
	      [inv setSelector: sel];
	      [inv setArgument: &not atIndex: 2];
	      [inv retainArguments];
		
	      housekeeper = [[NSTimer alloc] initWithFireDate: nil
						     interval: 30.0
						       target: inv
						     selector: NULL
						     userInfo: nil
						      repeats: YES];
	      [r _setHousekeeper: housekeeper];
	      RELEASE(housekeeper);
	      RELEASE(arp);
	    }
        }
    }
  return r;
}

/*
 * Callback function so send notifications on becoming multi-threaded.
 */
static void
gnustep_base_thread_callback(void)
{
  /*
   * Protect this function with locking ... to avoid any possibility
   * of multiple threads registering with the system simultaneously,
   * and so that all NSWillBecomeMultiThreadedNotifications are sent
   * out before any second thread can interfere with anything.
   */
  if (entered_multi_threaded_state == NO)
    {
      [gnustep_global_lock lock];
      if (entered_multi_threaded_state == NO)
	{
	  /*
	   * For apple compatibility ... and to make things easier for
	   * code called indirectly within a will-become-multi-threaded
	   * notification handler, we set the flag to say we are multi
	   * threaded BEFORE sending the notifications.
	   */
	  entered_multi_threaded_state = YES;
	  NS_DURING
	    {
	      [GSPerformHolder class];	// Force initialization

	      /*
	       * Post a notification if this is the first new thread
	       * to be created.
	       * Won't work properly if threads are not all created
	       * by this class, but it's better than nothing.
	       */
	      if (nc == nil)
		{
		  nc = RETAIN([NSNotificationCenter defaultCenter]);
		}
	      [nc postNotificationName: NSWillBecomeMultiThreadedNotification
				object: nil
			      userInfo: nil];
	    }
	  NS_HANDLER
	    {
	      fprintf(stderr,
"ALERT ... exception while becoming multi-threaded ... system may not be\n"
"properly initialised.\n");
	      fflush(stderr);
	    }
	  NS_ENDHANDLER
	}
      [gnustep_global_lock unlock];
    }
}


/**
 * This class encapsulates OpenStep threading.  See [NSLock] and its
 * subclasses for handling synchronisation between threads.<br />
 * Each process begins with a main thread and additional threads can
 * be created using NSThread.  The GNUstep implementation of OpenStep
 * has been carefully designed so that the internals of the base
 * library do not use threading (except for methods which explicitly
 * deal with threads of course) so that you can write applications
 * without threading.  Non-threaded applications are more efficient
 * (no locking is required) and are easier to debug during development.
 */
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
  NSThread	*t = nil;

  if (entered_multi_threaded_state == NO)
    {
      /*
       * The NSThread class has been initialized - so we will have a default
       * thread set up unless the default thread subsequently exited.
       */
      t = defaultThread;
    }
  if (t == nil)
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
 * <p>Create a new thread - use this method rather than alloc-init.  The new
 * thread will begin executing the message given by aSelector, aTarget, and
 * anArgument.  This should have no return value, and must set up an
 * autorelease pool if retain/release memory management is used.  It should
 * free this pool before it finishes execution.</p>
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
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to detach thread (unknown error)"];
    }
}


/**
 * Terminates the current thread.<br />
 * Normally you don't need to call this method explicitly,
 * since exiting the method with which the thread was detached
 * causes this method to be called automatically.
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
	  nc = RETAIN([NSNotificationCenter defaultCenter]);
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
 * Returns a flag to say whether the application is multi-threaded or not.<br />
 * An application is considered to be multi-threaded if any thread other
 * than the main thread has been started, irrespective of whether that
 * thread has since terminated.<br />
 * NB. This method returns YES if called within a handler processing
 * <code>NSWillBecomeMultiThreadedNotification</code>
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
  GSSleepUntilIntervalSinceReferenceDate([date timeIntervalSinceReferenceDate]);
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
  if (_autorelease_vars.pool_cache != 0)
    {
      [NSAutoreleasePool _endThread: self];
    }

  if (_thread_dictionary != nil)
    {
      /*
       * Try again to get rid of thread dictionary.
       */
      DESTROY(_thread_dictionary);
      if (_autorelease_vars.pool_cache != 0)
	{
	  [NSAutoreleasePool _endThread: self];
	}
      if (_thread_dictionary != nil)
	{
	  NSLog(@"Oops - leak - thread dictionary is %@", _thread_dictionary);
	  if (_autorelease_vars.pool_cache != 0)
	    {
	      [NSAutoreleasePool _endThread: self];
	    }
	}
    }
  if (self == defaultThread)
    {
      defaultThread = nil;
    }
  NSDeallocateObject(self);
  GSNOSUPERDEALLOC;
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
      nc = RETAIN([NSNotificationCenter defaultCenter]);
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



@implementation GSPerformHolder

static NSLock *subthreadsLock = nil;
#ifdef __MINGW32__
static HANDLE	event;
#else
static int inputFd = -1;
static int outputFd = -1;
#endif	
static NSMutableArray *perfArray = nil;
static NSDate *theFuture;

+ (void) initialize
{
  NSRunLoop	*loop = GSRunLoopForThread(defaultThread);
  NSArray	*m = commonModes();
  unsigned	count = [m count];
  unsigned	i;

  theFuture = RETAIN([NSDate distantFuture]);
  subthreadsLock = [[NSLock alloc] init];
  perfArray = [[NSMutableArray alloc] initWithCapacity: 10];

#ifndef __MINGW32__
  {
    int	fd[2];

    if (pipe(fd) == 0)
      {
	inputFd = fd[0];
	outputFd = fd[1];
      }
    else
      {
	[NSException raise: NSInternalInconsistencyException
	  format: @"Failed to create pipe to handle perform in main thread"];
      }
    for (i = 0; i < count; i++)
      {
	[loop addEvent: (void*)(intptr_t)inputFd
		  type: ET_RDESC
	       watcher: (id<RunLoopEvents>)self
	       forMode: [m objectAtIndex: i]];
      }
  }
#else
  {
    if ((event = CreateEvent(NULL, TRUE, FALSE, NULL)) == NULL)
      {
	[NSException raise: NSInternalInconsistencyException
	  format: @"Failed to create event to handle perform in main thread"];
      }
    for (i = 0; i < count; i++)
      {
	[loop addEvent: (void*)event
		  type: ET_HANDLE
	       watcher: (id<RunLoopEvents>)self
	       forMode: [m objectAtIndex: i]];
      }
  }
#endif  
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

#if defined(__MINGW32__)
  if (SetEvent(event) == 0)
    {
      NSLog(@"Set event failed - %@", [NSError _last]);
    }
#else
  if (write(outputFd, "0", 1) != 1)
    {
      NSLog(@"Write to pipe failed - %@", [NSError _last]);
    }
#endif

  [subthreadsLock unlock];

  return h;
}

+ (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];
  NSArray	*toDo;
  unsigned int	i;
  unsigned int	c;

  [subthreadsLock lock];

#if defined(__MINGW32__)
  if (ResetEvent(event) == 0)
    {
      NSLog(@"Reset event failed - %@", [NSError _last]);
    }
#else
  if (read(inputFd, &c, 1) != 1)
    {
      NSLog(@"Read pipe failed - %@", [NSError _last]);
    }
#endif

  toDo = [[NSArray alloc] initWithArray: perfArray];
  [perfArray removeAllObjects];
  [subthreadsLock unlock];

  c = [toDo count];
  for (i = 0; i < c; i++)
    {
      GSPerformHolder	*h = [toDo objectAtIndex: i];

      [loop performSelector: @selector(fire)
		     target: h
		   argument: nil
		      order: 0
		      modes: h->modes];
    }
  RELEASE(toDo);
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
  GSNOSUPERDEALLOC;
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
      NSConditionLock	*l = lock;

      [lock lock];
      lock = nil;
      [l unlockWithCondition: 1];
    }
}
@end

/**
 * Extra methods to permit messages to be sent to an object such that they
 * are executed in the <em>main</em> thread.<br />
 * The main thread is the thread in which the GNUstep system is started,
 * and where the GNUstep gui is used, it is the thread in which gui
 * drawing operations <strong>must</strong> be performed.
 */
@implementation	NSObject (NSMainThreadPerformAdditions)

/**
 * <p>This method performs aSelector on the receiver, passing anObject as
 * an argument, but does so in the main thread of the program.  The receiver
 * and anObject are both retained until the method is performed.
 * </p>
 * <p>The selector is performed when the runloop of the main thread next
 * runs in one of the modes specified in anArray.<br />
 * Where this method has been called more than once before the runloop
 * of the main thread runs in the required mode, the order in which the
 * operations in the main thread is done is the same as that in which
 * they were added using this method.
 * </p>
 * <p>If there are no modes in anArray,
 * the method has no effect and simply returns immediately.
 * </p>
 * <p>The argument aFlag specifies whether the method should wait until
 * the selector has been performed before returning.<br />
 * <strong>NB.</strong> This method does <em>not</em> cause the runloop of
 * the main thread to be run ... so if the runloop is not executed by some
 * code in the main thread, the thread waiting for the perform to complete
 * will block forever.
 * </p>
 * <p>As a special case, if aFlag == YES and the current thread is the main
 * thread, the modes array is ignored and the selector is performed immediately.
 * This behavior is necessary to avoid the main thread being blocked by
 * waiting for a perform which will never happen because the runloop is
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
 * using the supplied arguments and an array containing common modes.<br />
 * These modes consist of NSRunLoopMode, NSConnectionreplyMode, and if
 * in an application, the NSApplication modes.
 */
- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
{
  [self performSelectorOnMainThread: aSelector
			 withObject: anObject
		      waitUntilDone: aFlag
			      modes: commonModes()];
}
@end

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
	  nc = RETAIN([NSNotificationCenter defaultCenter]);
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
