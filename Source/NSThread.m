/* Control of executable units within a shared virtual memory space
   Copyright (C) 1996 Free Software Foundation, Inc.

   Original Author:  Scott Christley <scottc@net-community.com>
   Rewritten by: Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1996
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <config.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>
#include <base/o_map.h>
#include <base/NotificationDispatcher.h>

// Class variables

#define USING_THREAD_COLLECTION 0
#if USING_THREAD_COLLECTION
/* For managing the collection of all NSThread objects.  Note, however,
   threads that have not yet called +currentThread will not be in the
   collection.
   xxx Do we really need this collection anyway?  
   How about getting rid of it? */
static NSRecursiveLock *thread_lock;
static o_map_t thread_id_2_nsthread;
#endif

/* Flag indicating whether the objc runtime ever went multi-threaded. */
static BOOL entered_multi_threaded_state;

inline NSThread*
GSCurrentThread()
{
  id t = (id) objc_thread_get_data ();

  /* If an NSThread object for this thread has already been created
     and stashed away, return it.  This depends on the objc runtime
     initializing objc_thread_get_data() to 0 for newly-created
     threads. */
  if (t)
    return t;

  /* We haven't yet created an NSThread object for this thread; create
     it.  (Doing this here instead of in +detachNewThread.. not only
     avoids the race condition, it also nicely provides an NSThread on
     request for the single thread that exists at application
     start-up, and for thread's created by calling
     objc_thread_detach() directly.) */
  t = [[NSThread alloc] init];
  return t;
}

NSMutableDictionary*
GSCurrentThreadDictionary()
{
  NSThread		*thread = GSCurrentThread();
  NSMutableDictionary	*dict = thread->_thread_dictionary;

  if (dict == nil)
    dict = [thread threadDictionary];
  return dict; 
}

void gnustep_base_thread_callback()
{
  /* Post a notification if this is the first new thread to be created.
     Won't work properly if threads are not all created by this class.
     */
  if (!entered_multi_threaded_state)
    {
      entered_multi_threaded_state = YES;
      [NotificationDispatcher
	postNotificationName: NSBecomingMultiThreaded
	object: nil];
    }
}


@implementation NSThread

// Class initialization
+ (void) initialize
{
  if (self == [NSThread class])
    {
#if USING_THREAD_COLLECTION
      thread_id_2_nsthread = o_map_of_non_owned_void_p ();
      thread_lock = [[[NSRecursiveLock alloc] init]
		      autorelease];
#endif
      entered_multi_threaded_state = NO;
      objc_set_thread_callback(gnustep_base_thread_callback);
    }
}


// Initialization

- (void)dealloc
{
  [_thread_dictionary release];
  [super dealloc];
}

- init
{
  [super init];

  /* Make it easy and fast to get this NSThread object from the thread. */
  objc_thread_set_data (self);

  /* initialize our ivars. */
  _thread_dictionary = nil;	// Initialize this later only when needed
  _exception_handler = NULL;
  init_autorelease_thread_vars (&_autorelease_vars);

#if USING_THREAD_COLLECTION
  /* Register ourselves in the maptable of all threads. */
  // Lock the thread list so it doesn't change on us
  [thread_lock lock];
  // Save the thread in our thread map; NOTE: this will not retain it
  o_map_at_key_put_value_known_absent (thread_id_2_nsthread, tid, t);
  [thread_lock unlock];
#endif

  return self;
}


// Creating an NSThread

+ (NSThread*) currentThread
{
  return GSCurrentThread();
}

+ (void) detachNewThreadSelector:(SEL)aSelector
		        toTarget:(id)aTarget
                      withObject:(id)anArgument
{
  // Have the runtime detach the thread
  if (objc_thread_detach (aSelector, aTarget, anArgument) == NULL)
    {
      /* This should probably be an exception */
      NSLog(@"Unable to detach thread (unknown error)");
    }

  /* NOTE we can't create the new NSThread object for this thread here
     because there would be a race condition.  The newly created
     thread might ask for its NSThread object before we got to create
     it. */
}


// Querying a thread

+ (BOOL) isMultiThreaded
{
  return entered_multi_threaded_state;
}

/* Thread dictionary
   NB. This cannot be autoreleased, since we cannot be sure that the
   autorelease pool for the thread will continue to exist for the entire
   life of the thread!
 */
- (NSMutableDictionary*) threadDictionary
{
  if (!_thread_dictionary)
    _thread_dictionary = [NSMutableDictionary new];
  return _thread_dictionary;
}

// Delaying a thread
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
      sleep (30*60);
#endif
      delay = [date timeIntervalSinceNow];
    }

  // usleep may return early because of signals
  while (delay > 0)
    {
#ifdef	HAVE_USLEEP
      usleep ((int)(delay*1000000));
#else
      sleep ((int)delay);
#endif
      delay = [date timeIntervalSinceNow];
    }
}

// Terminating a thread
// What happens if the thread doesn't call +exit?
+ (void) exit
{
  NSThread *t;

  // the current NSThread
  t = [NSThread currentThread];

  // Post the notification
  [NotificationDispatcher
    postNotificationName: NSThreadExiting
    object: t];

#if USING_THREAD_COLLECTION
  { 
    _objc_thread_t tid;
    // Get current thread id from runtime
    tid = objc_thread_id();
    // Lock the thread list so it doesn't change on us
    [thread_lock lock];
    // Remove the thread from the map
    o_map_remove_key (thread_id_2_nsthread, tid);
    // Unlock the thread list
    [thread_lock unlock];
  }
#endif

  // Release the thread object
  [t release];

  // xxx Clean up any outstanding NSAutoreleasePools here.

  // Tell the runtime to exit the thread
  objc_thread_exit ();
}

@end
