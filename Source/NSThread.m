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

#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>
#include <gnustep/base/o-map.h>
#include <gnustep/base/Notification.h>

// Notifications
NSString *NSBecomingMultiThreaded = @"NSBecomingMultiThreadedNotification";
NSString *NSThreadExiting = @"NSThreadExitingNotification";

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
    }
}


// Initialization

- init
{
  [super init];

  /* initialize our ivars. */
  _thread_dictionary = [NSMutableDictionary dictionary];
  _thread_autorelease_pool = nil;

  /* Make it easy and fast to get this NSThread object from the thread. */
  objc_thread_set_data (self);

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

+ (void) detachNewThreadSelector:(SEL)aSelector
		        toTarget:(id)aTarget
                      withObject:(id)anArgument
{
  // Have the runtime detach the thread
  objc_thread_detach (aSelector, aTarget, anArgument);

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

- (NSMutableDictionary*) threadDictionary
{
  return _thread_dictionary;
}

// Delaying a thread
+ (void) sleepUntilDate: (NSDate*)date
{
  // xxx Do we need some runtime/OS support for this?
  [self notImplemented: _cmd];
}

// Terminating a thread
// What happens if the thread doesn't call +exit?
+ (void) exit
{
  NSThread *t;

  // the the current NSThread
  t = objc_thread_get_data ();
  assert (t);

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
