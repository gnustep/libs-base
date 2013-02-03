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
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSThread class reference</title>
   $Date$ $Revision$
*/

#import "common.h"
#define	EXPOSE_NSThread_IVARS	1
#ifdef HAVE_NANOSLEEP
#include <time.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif
#ifdef HAVE_PTHREAD_H
#include <pthread.h>
#endif

#if	defined(HAVE_SYS_FILE_H)
#  include	<sys/file.h>
#endif

#if	defined(HAVE_SYS_FCNTL_H)
#  include <sys/fcntl.h>
#elif	defined(HAVE_FCNTL_H)
#  include <fcntl.h>
#endif

#if defined(__POSIX_SOURCE)\
        || defined(__EXT_POSIX1_198808)\
        || defined(O_NONBLOCK)
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#import "Foundation/NSException.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSConnection.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSGarbageCollector.h"

#import "GSPrivate.h"
#import "GSRunLoopCtxt.h"

#if	GS_WITH_GC
#include	<gc/gc.h>
#endif
#if __OBJC_GC__
#include <objc/objc-auto.h>
#endif

#if defined(__FreeBSD__) || defined(__OpenBSD__)
#  include <pthread_np.h>
#  define IS_MAIN_PTHREAD (pthread_main_np() == 1)
#else
#  define IS_MAIN_PTHREAD (1)
#endif


// Some older BSD systems used a non-standard range of thread priorities.
// Use these if they exist, otherwise define standard ones.
#ifndef PTHREAD_MAX_PRIORITY
#define PTHREAD_MAX_PRIORITY 31
#endif
#ifndef PTHREAD_MIN_PRIORITY
#define PTHREAD_MIN_PRIORITY 0
#endif


@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

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
 *   methods which want to block until an action has been performed.
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
  NSConditionLock	*lock;		// Not retained.
  NSArray		*modes;
  BOOL                  invalidated;
}
+ (GSPerformHolder*) newForReceiver: (id)r
			   argument: (id)a
			   selector: (SEL)s
			      modes: (NSArray*)m
			       lock: (NSConditionLock*)l;
- (void) fire;
- (void) invalidate;
- (BOOL) isInvalidated;
- (NSArray*) modes;
@end

/**
 * Sleep until the current date/time is the specified time interval
 * past the reference date/time.<br />
 * Implemented as a function taking an NSTimeInterval argument in order
 * to avoid objc messaging and object allocation/deallocation (NSDate)
 * overheads.<br />
 * Used to implement [NSThread+sleepUntilDate:]
 * If the date is in the past, this function simply allows other threads
 * (if any) to run.
 */
void
GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval when)
{
  NSTimeInterval delay;

  // delay is always the number of seconds we still need to wait
  delay = when - GSPrivateTimeNow();
  if (delay <= 0.0)
    {
      sched_yield();
      return;
    }

#ifdef	HAVE_NANOSLEEP
  // Avoid any possibility of overflow by sleeping in chunks.
  while (delay > 32768)
    {
      struct timespec request;

      request.tv_sec = (time_t)32768;
      request.tv_nsec = (long)0;
      nanosleep(&request, 0);
      delay = when - GSPrivateTimeNow();
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
#if defined(__MINGW__)
      Sleep (30*60*1000);
#else
      sleep (30*60);
#endif
      delay = when - GSPrivateTimeNow();
    }

  /*
   * sleeping may return early because of signals, so we need to re-calculate
   * the required delay and check to see if we need to sleep again.
   */
  while (delay > 0)
    {
#if	defined(__MINGW__)
#if	defined(HAVE_USLEEP)
      /* On windows usleep() seems to perform a busy wait ... so we only
       * use it for short delays ... otherwise use the less accurate Sleep()
       */
      if (delay > 0.1)
	{
          Sleep ((NSInteger)(delay*1000));
	}
      else
	{
          usleep ((NSInteger)(delay*1000000));
	}
#else
      Sleep ((NSInteger)(delay*1000));
#endif	/* HAVE_USLEEP */
#else
#if	defined(HAVE_USLEEP)
      usleep ((NSInteger)(delay*1000000));
#else
      sleep ((NSInteger)delay);
#endif	/* HAVE_USLEEP */
#endif	/* __MINGW__ */
      delay = when - GSPrivateTimeNow();
    }
#endif	/* HAVE_NANOSLEEP */
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

/*
 * Flag indicating whether the objc runtime ever went multi-threaded.
 */
static BOOL	entered_multi_threaded_state = NO;

static NSThread *defaultThread;

static pthread_key_t thread_object_key;

/**
 * Pthread cleanup call.
 *
 * We should normally not get here ... because threads should exit properly
 * and clean up, so that this function doesn't get called.  However if a
 * thread terminates for some reason without calling the exit method, we
 * can at least log it.
 *
 * We can't do anything more than that since at the point
 * when this function is called, the thread specific data is no longer
 * available, so the currentThread method will always fail and the
 * repercussions of that would well be a crash.
 *
 * As a special case, we ignore the exit of the default thread ... that one
 * will usually terminate without calling the exit method as it ends the
 * whole process by returning from the 'main' function.
 */
static void exitedThread(void *thread)
{
  if (thread != defaultThread)
    {
      fprintf(stderr, "WARNING thread %p terminated without calling +exit!\n",
        thread);
    }
}

/**
 * These functions needed because sending messages to classes is a seriously
 * slow process with gcc and the gnu runtime.
 */
inline NSThread*
GSCurrentThread(void)
{
  NSThread *thr = pthread_getspecific(thread_object_key);
  if (nil == thr)
    {
      GSRegisterCurrentThread();
      thr = pthread_getspecific(thread_object_key);
      if ((nil == defaultThread) && IS_MAIN_PTHREAD)
        {
          defaultThread = [thr retain];
        }
    }
  assert(nil != thr && "No main thread");
  return thr;
}

NSMutableDictionary*
GSDictionaryForThread(NSThread *t)
{
  if (nil == t)
    {
      t = GSCurrentThread();
    }
  return [t threadDictionary];
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
#if	GS_WITH_GC && defined(HAVE_GC_ALLOW_REGISTER_THREADS)
	  /* This function needs to be called before going multi-threaded
	   * so that the garbage collection library knows to support
	   * registration of new threads.
	   */
	  GS_allow_register_threads();
#endif
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
#if	!defined(HAVE_INITIALIZE)
	      if (NO == [[NSUserDefaults standardUserDefaults]
		boolForKey: @"GSSilenceInitializeWarning"])
		{
		  NSLog(@"WARNING your program is becoming multi-threaded, but you are using an ObjectiveC runtime library which does not have a thread-safe implementation of the +initialize method. Please see README.initialize for more information.");
		}
#endif
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


@implementation NSThread

static void
setThreadForCurrentThread(NSThread *t)
{
  [[NSGarbageCollector defaultCollector] disableCollectorForPointer: t];
  pthread_setspecific(thread_object_key, t);
  gnustep_base_thread_callback();
}

static void
unregisterActiveThread(NSThread *thread)
{
  if (thread->_active == YES)
    {
      /*
       * Set the thread to be inactive to avoid any possibility of recursion.
       */
      thread->_active = NO;
      thread->_finished = YES;

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

      [(GSRunLoopThreadInfo*)thread->_runLoopInfo invalidate];
      [thread  release];

      [[NSGarbageCollector defaultCollector] enableCollectorForPointer: thread];
      pthread_setspecific(thread_object_key, nil);
    }
}

+ (NSArray*) callStackReturnAddresses
{
  NSMutableArray        *stack = GSPrivateStackAddresses();

  return stack;
}

+ (BOOL) _createThreadForCurrentPthread
{
  NSThread	*t = pthread_getspecific(thread_object_key);

  if (t == nil)
    {
      t = [self new];
      t->_active = YES;
      [[NSGarbageCollector defaultCollector] disableCollectorForPointer: t];
      pthread_setspecific(thread_object_key, t);
      GS_CONSUMED(t);
      return YES;
    }
  return NO;
}

+ (NSThread*) currentThread
{
  return GSCurrentThread();
}

+ (void) detachNewThreadSelector: (SEL)aSelector
		        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
  NSThread	*thread;

  /*
   * Create the new thread.
   */
  thread = [[NSThread alloc] initWithTarget: aTarget
                                   selector: aSelector
                                     object: anArgument];

  [thread start];
  RELEASE(thread);
}

+ (void) exit
{
  NSThread	*t;

  t = GSCurrentThread();
  if (t->_active == YES)
    {
      unregisterActiveThread (t);

      if (t == defaultThread || defaultThread == nil)
	{
	  /* For the default thread, we exit the process.
	   */
	  exit(0);
	}
      else
	{
          pthread_exit(NULL);
	}
    }
}

/*
 * Class initialization
 */
+ (void) initialize
{
  if (self == [NSThread class])
    {
      if (pthread_key_create(&thread_object_key, exitedThread))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"Unable to create thread key!"];
	}
      /*
       * Ensure that the default thread exists.
       */
      threadClass = self;

      GSCurrentThread();
    }
}

+ (BOOL) isMainThread
{
  return (GSCurrentThread() == defaultThread ? YES : NO);
}

+ (BOOL) isMultiThreaded
{
  return entered_multi_threaded_state;
}

+ (NSThread*) mainThread
{
  return defaultThread;
}

/**
 * Set the priority of the current thread.  This is a value in the
 * range 0.0 (lowest) to 1.0 (highest) which is mapped to the underlying
 * system priorities.
 */
+ (void) setThreadPriority: (double)pri
{
#if defined(_POSIX_THREAD_PRIORITY_SCHEDULING) && (_POSIX_THREAD_PRIORITY_SCHEDULING > 0)
  int	policy;
  struct sched_param param;

  // Clamp pri into the required range.
  if (pri > 1) { pri = 1; }
  if (pri < 0) { pri = 0; }

  // Scale pri based on the range of the host system.
  pri *= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
  pri += PTHREAD_MIN_PRIORITY;

  pthread_getschedparam(pthread_self(), &policy, &param);
  param.sched_priority = pri;
  pthread_setschedparam(pthread_self(), policy, &param);
#endif
}

+ (void) sleepForTimeInterval: (NSTimeInterval)ti
{
  GSSleepUntilIntervalSinceReferenceDate(GSPrivateTimeNow() + ti);
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
  double pri = 0;
#if defined(_POSIX_THREAD_PRIORITY_SCHEDULING) && (_POSIX_THREAD_PRIORITY_SCHEDULING > 0)
  int policy;
  struct sched_param param;

  pthread_getschedparam(pthread_self(), &policy, &param);
  pri = param.sched_priority;
  // Scale pri based on the range of the host system.
  pri -= PTHREAD_MIN_PRIORITY;
  pri /= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);

#else
#warning Your pthread implementation does not support thread priorities
#endif
  return pri;

}



/*
 * Thread instance methods.
 */

- (void) cancel
{
  _cancelled = YES;
}

- (void) dealloc
{
  if (_active == YES)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Deallocating an active thread without [+exit]!"];
    }
  if (_runLoopInfo != 0)
    {
      GSRunLoopThreadInfo       *info = (GSRunLoopThreadInfo*)_runLoopInfo;

      _runLoopInfo = 0;
      [info release];
    }
  DESTROY(_thread_dictionary);
  DESTROY(_target);
  DESTROY(_arg);
  DESTROY(_name);
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
  DESTROY(_gcontext);
  [super dealloc];
}

- (id) init
{
  init_autorelease_thread_vars(&_autorelease_vars);
  return self;
}

- (id) initWithTarget: (id)aTarget
             selector: (SEL)aSelector
               object: (id)anArgument
{
  /* initialize our ivars. */
  _selector = aSelector;
  _target = RETAIN(aTarget);
  _arg = RETAIN(anArgument);
  init_autorelease_thread_vars(&_autorelease_vars);
  return self;
}

- (BOOL) isCancelled
{
  return _cancelled;
}

- (BOOL) isExecuting
{
  return _active;
}

- (BOOL) isFinished
{
  return _finished;
}

- (BOOL) isMainThread
{
  return (self == defaultThread ? YES : NO);
}

- (void) main
{
  if (_active == NO)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"[%@-$@] called on inactive thread",
        NSStringFromClass([self class]),
        NSStringFromSelector(_cmd)];
    }

  [_target performSelector: _selector withObject: _arg];

}

- (NSString*) name
{
  return _name;
}

- (void) setName: (NSString*)aName
{
  ASSIGN(_name, aName);
}

- (void) setStackSize: (NSUInteger)stackSize
{
  _stackSize = stackSize;
}

- (NSUInteger) stackSize
{
  return _stackSize;
}

/**
 * Trampoline function called to launch the thread
 */
static void *nsthreadLauncher(void* thread)
{
    NSThread *t = (NSThread*)thread;
    setThreadForCurrentThread(t);
#if __OBJC_GC__
	objc_registerThreadWithCollector();
#endif
#if	GS_WITH_GC && defined(HAVE_GC_REGISTER_MY_THREAD)
  {
    struct GC_stack_base	base;

    if (GC_get_stack_base(&base) == GC_SUCCESS)
      {
	int	result;

	result = GC_register_my_thread(&base);
	if (result != GC_SUCCESS && result != GC_DUPLICATE)
	  {
	    fprintf(stderr, "Argh ... no thread support in garbage collection library\n");
	  }
      }
    else
      {
	fprintf(stderr, "Unable to determine stack base to register new thread for garbage collection\n");
      }
  }
#endif

  /*
   * Let observers know a new thread is starting.
   */
  if (nc == nil)
    {
      nc = RETAIN([NSNotificationCenter defaultCenter]);
    }
  [nc postNotificationName: NSThreadDidStartNotification
		    object: t
		  userInfo: nil];

  [t main];

  [NSThread exit];
  // Not reached
  return NULL;
}

- (void) start
{
  pthread_attr_t	attr;
  pthread_t		thr;

  if (_active == YES)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"[%@-$@] called on active thread",
        NSStringFromClass([self class]),
        NSStringFromSelector(_cmd)];
    }
  if (_cancelled == YES)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"[%@-$@] called on cancelled thread",
        NSStringFromClass([self class]),
        NSStringFromSelector(_cmd)];
    }
  if (_finished == YES)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"[%@-$@] called on finished thread",
        NSStringFromClass([self class]),
        NSStringFromSelector(_cmd)];
    }

  /* Make sure the notification is posted BEFORE the new thread starts.
   */
  gnustep_base_thread_callback();

  /* The thread must persist until it finishes executing.
   */
  [self retain];

  /* Mark the thread as active whiul it's running.
   */
  _active = YES;

  errno = 0;
  pthread_attr_init(&attr);
  /* Create this thread detached, because we never use the return state from
   * threads.
   */
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
  /* Set the stack size when the thread is created.  Unlike the old setrlimit
   * code, this actually works.
   */
  if (_stackSize > 0)
    {
      pthread_attr_setstacksize(&attr, _stackSize);
    }
  if (pthread_create(&thr, &attr, nsthreadLauncher, self))
    {
      DESTROY(self);
      [NSException raise: NSInternalInconsistencyException
                  format: @"Unable to detach thread (last error %@)",
                  [NSError _last]];
    }
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



@implementation GSRunLoopThreadInfo
- (void) addPerformer: (id)performer
{
  [lock lock];
  [performers addObject: performer];
#if defined(__MINGW__)
  if (SetEvent(event) == 0)
    {
      NSLog(@"Set event failed - %@", [NSError _last]);
    }
#else
  /* The write could concievably fail if the pipe is full.
   * In that case we need to release the lock teporarily to allow the other
   * thread to consume data from the pipe.  It's possible that the thread
   * and its runloop might stop during that ... so we need to check that
   * outputFd is still valid.
   */
  while (outputFd >= 0 && write(outputFd, "0", 1) != 1)
    {
      [lock unlock];
      [lock lock];
    }
#endif
  [lock unlock];
}

- (void) dealloc
{
  [self invalidate];
  DESTROY(performers);
  DESTROY(lock);
  DESTROY(loop);
  [super dealloc];
}

- (id) init
{
#ifdef __MINGW__
  if ((event = CreateEvent(NULL, TRUE, FALSE, NULL)) == INVALID_HANDLE_VALUE)
    {
      DESTROY(self);
      [NSException raise: NSInternalInconsistencyException
        format: @"Failed to create event to handle perform in thread"];
    }
#else
  int	fd[2];

  if (pipe(fd) == 0)
    {
      int	e;

      inputFd = fd[0];
      outputFd = fd[1];
      if ((e = fcntl(inputFd, F_GETFL, 0)) >= 0)
	{
	  e |= NBLK_OPT;
	  if (fcntl(inputFd, F_SETFL, e) < 0)
	    {
	      [NSException raise: NSInternalInconsistencyException
		format: @"Failed to set non block flag for perform in thread"];
	    }
	}
      else
	{
	  [NSException raise: NSInternalInconsistencyException
	    format: @"Failed to get non block flag for perform in thread"];
	}
      if ((e = fcntl(outputFd, F_GETFL, 0)) >= 0)
	{
	  e |= NBLK_OPT;
	  if (fcntl(outputFd, F_SETFL, e) < 0)
	    {
	      [NSException raise: NSInternalInconsistencyException
		format: @"Failed to set non block flag for perform in thread"];
	    }
	}
      else
	{
	  [NSException raise: NSInternalInconsistencyException
	    format: @"Failed to get non block flag for perform in thread"];
	}
    }
  else
    {
      DESTROY(self);
      [NSException raise: NSInternalInconsistencyException
        format: @"Failed to create pipe to handle perform in thread"];
    }
#endif
  lock = [NSLock new];
  performers = [NSMutableArray new];
  return self;
}

- (void) invalidate
{
  [lock lock];
  [performers makeObjectsPerformSelector: @selector(invalidate)];
  [performers removeAllObjects];
#ifdef __MINGW__
  if (event != INVALID_HANDLE_VALUE)
    {
      CloseHandle(event);
      event = INVALID_HANDLE_VALUE;
    }
#else
  if (inputFd >= 0)
    {
      close(inputFd);
      inputFd = -1;
    }
  if (outputFd >= 0)
    {
      close(outputFd);
      outputFd = -1;
    }
#endif
  [lock unlock];
}

- (void) fire
{
  NSArray	*toDo;
  unsigned int	i;
  unsigned int	c;

  [lock lock];
#if defined(__MINGW__)
  if (event != INVALID_HANDLE_VALUE)
    {
      if (ResetEvent(event) == 0)
        {
          NSLog(@"Reset event failed - %@", [NSError _last]);
        }
    }
#else
  if (inputFd >= 0)
    {
      char	buf[BUFSIZ];

      /* We don't care how much we read.  If there have been multiple
       * performers queued then there will be multiple bytes available,
       * but we always handle all available performers, so we can also
       * read all available bytes.
       * The descriptor is non-blocking ... so it's safe to ask for more
       * bytes than are available.
       */
      while (read(inputFd, buf, sizeof(buf)) > 0)
	;
    }
#endif

  c = [performers count];
  if (0 == c)
    {
      /* We deal with all available performers each time we fire, so
       * it's likely that we will fire when we have no performers left.
       * In that case we can skip the copying and emptying of the array.
       */
      [lock unlock];
      return;
    }
  toDo = [NSArray arrayWithArray: performers];
  [performers removeAllObjects];
  [lock unlock];

  for (i = 0; i < c; i++)
    {
      GSPerformHolder	*h = [toDo objectAtIndex: i];

      [loop performSelector: @selector(fire)
		     target: h
		   argument: nil
		      order: 0
		      modes: [h modes]];
    }
}
@end

GSRunLoopThreadInfo *
GSRunLoopInfoForThread(NSThread *aThread)
{
  GSRunLoopThreadInfo   *info;

  if (aThread == nil)
    {
      aThread = GSCurrentThread();
    }
  if (aThread->_runLoopInfo == nil)
    {
      [gnustep_global_lock lock];
      if (aThread->_runLoopInfo == nil)
        {
          aThread->_runLoopInfo = [GSRunLoopThreadInfo new];
	}
      [gnustep_global_lock unlock];
    }
  info = aThread->_runLoopInfo;
  return info;
}

@implementation GSPerformHolder

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

  return h;
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
  GSRunLoopThreadInfo   *threadInfo;

  if (receiver == nil)
    {
      return;	// Already fired!
    }
  threadInfo = GSRunLoopInfoForThread(GSCurrentThread());
  [threadInfo->loop cancelPerformSelectorsWithTarget: self];
  [receiver performSelector: selector withObject: argument];
  DESTROY(receiver);
  DESTROY(argument);
  DESTROY(modes);
  if (lock != nil)
    {
      NSConditionLock	*l = lock;

      [lock lock];
      lock = nil;
      [l unlockWithCondition: 1];
    }
}

- (void) invalidate
{
  if (invalidated == NO)
    {
      invalidated = YES;
      DESTROY(receiver);
      if (lock != nil)
        {
          NSConditionLock	*l = lock;

          [lock lock];
          lock = nil;
          [l unlockWithCondition: 1];
        }
    }
}

- (BOOL) isInvalidated
{
  return invalidated;
}

- (NSArray*) modes
{
  return modes;
}
@end

@implementation	NSObject (NSThreadPerformAdditions)

- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
			       modes: (NSArray*)anArray
{
  /* It's possible that this method could be called before the NSThread
   * class is initialised, so we check and make sure it's initiailised
   * if necessary.
   */
  if (defaultThread == nil)
    {
      [NSThread currentThread];
    }
  [self performSelector: aSelector
               onThread: defaultThread
             withObject: anObject
          waitUntilDone: aFlag
                  modes: anArray];
}

- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
{
  [self performSelectorOnMainThread: aSelector
			 withObject: anObject
		      waitUntilDone: aFlag
			      modes: commonModes()];
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
                   modes: (NSArray*)anArray
{
  GSRunLoopThreadInfo   *info;
  NSThread	        *t;

  if ([anArray count] == 0)
    {
      return;
    }

  t = GSCurrentThread();
  if (aThread == nil)
    {
      aThread = t;
    }
  info = GSRunLoopInfoForThread(aThread);
  if (t == aThread)
    {
      /* Perform in current thread.
       */
      if (aFlag == YES || info->loop == nil)
	{
          /* Wait until done or no run loop.
           */
	  [self performSelector: aSelector withObject: anObject];
	}
      else
	{
          /* Don't wait ... schedule operation in run loop.
           */
	  [info->loop performSelector: aSelector
                               target: self
                             argument: anObject
                                order: 0
                                modes: anArray];
	}
    }
  else
    {
      GSPerformHolder   *h;
      NSConditionLock	*l = nil;

      if ([aThread isFinished] == YES)
        {
          [NSException raise: NSInternalInconsistencyException
                      format: @"perform on finished thread"];
        }
      if (aFlag == YES)
	{
	  l = [[NSConditionLock alloc] init];
	}

      h = [GSPerformHolder newForReceiver: self
				 argument: anObject
				 selector: aSelector
				    modes: anArray
				     lock: l];
      [info addPerformer: h];
      if (l != nil)
	{
          [l lockWhenCondition: 1];
	  [l unlock];
	  RELEASE(l);
          if ([h isInvalidated] == YES)
            {
              [NSException raise: NSInternalInconsistencyException
                          format: @"perform on finished thread"];
              RELEASE(h);
            }
	}
      RELEASE(h);
    }
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
{
  [self performSelector: aSelector
               onThread: aThread
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
  return [NSThread _createThreadForCurrentPthread];
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
 *   associated with the thread (like [NSThread+exit]) but does
 *   not exit the underlying thread.
 * </p>
 */
void
GSUnregisterCurrentThread (void)
{
  unregisterActiveThread(GSCurrentThread());
}
