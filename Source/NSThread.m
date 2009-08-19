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

#include "config.h"
#include "GNUstepBase/preface.h"
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
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
#ifdef NeXT_RUNTIME
#include "thr-mach.h"
#endif
#ifdef HAVE_SYS_FILE_H
#include <sys/file.h>
#endif
#ifdef HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif

#include <errno.h>

#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#include "Foundation/NSDebug.h"
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

#if	GS_WITH_GC
#include	<gc.h>
#endif

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
      usleep ((NSInteger)(delay*1000000));
#else
#if defined(__MINGW32__)
      Sleep (delay*1000);
#else
      sleep ((NSInteger)delay);
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

typedef struct { @defs(NSThread) } *TInfo;

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
      NSMutableDictionary	*dict = ((TInfo)t)->_thread_dictionary;

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

+ (NSArray*) callStackReturnAddresses
{
  NSMutableArray        *stack = GSPrivateStackAddresses();

  return stack;
}

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

+ (void) detachNewThreadSelector: (SEL)aSelector
		        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
  NSThread	*thread;

  /*
   * Create the new thread.
   */
  thread = (NSThread*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  thread = [thread initWithTarget: aTarget
                         selector: aSelector
                           object: anArgument];

  [thread start];
  RELEASE(thread);
}

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
      t->_finished = YES;

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

      [(GSRunLoopThreadInfo*)t->_runLoopInfo invalidate];

      /*
       * destroy the thread object.
       */
      DESTROY(t);

      objc_thread_set_data (NULL);

#if	GS_WITH_GC && defined(HAVE_GC_REGISTER_MY_THREAD)
      GC_unregister_my_thread();
#endif
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
      defaultThread = [defaultThread init];
      defaultThread->_active = YES;
      objc_thread_set_data(defaultThread);
      threadClass = self;
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

+ (void) sleepForTimeInterval: (NSTimeInterval)ti
{
  if (ti > 0.0)
    {
      GSSleepUntilIntervalSinceReferenceDate(
        [NSDate timeIntervalSinceReferenceDate] + ti);
    }
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

- (void) cancel
{
  _cancelled = YES;
}

- (void) dealloc
{
  if (self == defaultThread)
    {
      [self retain];
      [NSException raise: NSInternalInconsistencyException
		  format: @"Deallocating the default thread is not allowed!"];
    }
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
  NSDeallocateObject(self);
  GSNOSUPERDEALLOC;
}

- (id) init
{
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
  _thread_dictionary = nil;	// Initialize this later only when needed
  _exception_handler = NULL;
  _cancelled = NO;
  _active = NO;
  _finished = NO;
  _name = nil;
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
  if (objc_thread_get_data() != nil)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"[%@-$@] called on running thread",
        NSStringFromClass([self class]),
        NSStringFromSelector(_cmd)];
    }

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

#if     defined(HAVE_SETRLIMIT) && defined(RLIMIT_STACK)
  if (_stackSize > 0)
    {
      struct rlimit     rl;

      rl.rlim_cur = _stackSize;
      rl.rlim_max = _stackSize;
      if (setrlimit(RLIMIT_STACK, &rl) < 0)
        {
          NSDebugMLog(@"Unable to set thread stack size to %u: %@",
            _stackSize, [NSError _last]);
        }
    }
#endif

  /*
   * We are running in the new thread - so we store ourself in the thread
   * dictionary and release ourself - thus, when the thread exits, we will
   * be deallocated cleanly.
   */
  objc_thread_set_data(self);

#if     defined(PTHREAD_JOINABLE)
/* Hack to work around the fact that
 * some versions of the objective-c
 * library fail to create the thread detached.
 * We should really do this only in such cases.
 */
pthread_detach(pthread_self());
#endif

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
#if     !defined(HAVE_SETRLIMIT) || !defined(RLIMIT_STACK)
  GSOnceMLog(@"Warning ... -setStackSize: not implemented on this system");
#endif
}

- (NSUInteger) stackSize
{
  return _stackSize;
}

- (void) start
{
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
  IF_NO_GC(RETAIN(self);)

  /* Mark the thread as active whiul it's running.
   */
  _active = YES;

  errno = 0;
  if (objc_thread_detach(@selector(main), self, nil) == NULL)
    {
      _active = NO;
      RELEASE(self);
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
  [lock unlock];
}

- (void) dealloc
{
  [self invalidate];
  DESTROY(lock);
  DESTROY(loop);
  [super dealloc];
}

- (id) init
{
#ifdef __MINGW32__
  if ((event = CreateEvent(NULL, TRUE, FALSE, NULL)) == INVALID_HANDLE_VALUE)
    {
      RELEASE(self);
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
    }
  else
    {
      RELEASE(self);
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
#ifdef __MINGW32__
  if (event != INVALID_HANDLE_VALUE)
    {
      CloseHandle(event);
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
#if defined(__MINGW32__)
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
      if (read(inputFd, &c, 1) != 1)
        {
          NSLog(@"Read pipe failed - %@", [NSError _last]);
        }
    }
#endif

  toDo = [NSArray arrayWithArray: performers];
  [performers removeAllObjects];
  [lock unlock];

  c = [toDo count];
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
  if (((NSThread_ivars*)aThread)->_runLoopInfo == nil)
    {
      ((NSThread_ivars*)aThread)->_runLoopInfo = [GSRunLoopThreadInfo new];
    }
  info = ((NSThread_ivars*)aThread)->_runLoopInfo;
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

      if ([t isFinished] == YES)
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
      thread = [thread init];
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
