/* 
   NSThread.m

   Control of executable units within a shared virtual memory space

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   
   This file is part of the GNUstep Objective-C Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <Foundation/NSThread.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>

// Notifications
NSString *NSBecomingMultiThreaded;
NSString *NSThreadExiting;

// Class variables
NSRecursiveLock *THREAD_LIST_LOCK;
NSMutableArray *THREAD_LIST;
BOOL ENTERED_MULTI_THREADED_STATE;

@implementation NSThread

// Private methods to set/get thread id
- (_objc_thread_t)threadId
{
  return thread_id;
}

- (void)setThreadId:(_objc_thread_t)threadId
{
  thread_id = threadId;
}

// Class initialization
+ (void)initialize
{
  if (self == [NSThread class])
    {
      // Initial version
      [self setVersion:1];

      // Allocate global/class variables
      NSBecomingMultiThreaded = [NSString
				  stringWithCString:"Entering multi-threaded state"];
      NSThreadExiting = [NSString
			  stringWithCString:"Thread is exiting"];
      THREAD_LIST = [NSArray array];
      THREAD_LIST_LOCK = [[NSRecursiveLock alloc] init];
      [THREAD_LIST_LOCK autorelease];
      ENTERED_MULTI_THREADED_STATE = NO;
    }
}

// Initialization
- init
{
  [super init];

  // Thread specific variables
  thread_dictionary = [NSMutableDictionary dictionary];
  return self;
}

// Creating an NSThread
+ (NSThread *)currentThread
{
  NSThread *t;
  _objc_thread_t tid;
  id e;

  // Get current thread id from runtime
  tid = objc_thread_id();

  // Lock the thread list so it doesn't change on us
  [THREAD_LIST_LOCK lock];

  // Enumerate through thread list to find the current thread
  e = [THREAD_LIST objectEnumerator];
  while ((t = [e nextObject]))
    {
      if ([t threadId] == tid)
	{
	  [THREAD_LIST_LOCK unlock];
	  return t;
	}
    }

  // Something is wrong if we get here
  [THREAD_LIST_LOCK unlock];
  return nil;
}

+ (void)detachNewThreadSelector:(SEL)aSelector
		       toTarget:(id)aTarget
withObject:(id)anArgument
{
  NSThread *t = [[NSThread alloc] init];
  _objc_thread_t tid;

  // Lock the thread list so it doesn't change on us
  [THREAD_LIST_LOCK lock];

  // Have the runtime detach the thread
  tid = objc_thread_detach(aSelector, aTarget, anArgument);
  if (!tid)
    {
      // Couldn't detach!
      [THREAD_LIST_LOCK unlock];
      return;
    }

  // Save the thread in our thread list
  [t setThreadId:tid];
  [THREAD_LIST addObject:t];
  [THREAD_LIST_LOCK unlock];
}

// Querying a thread
+ (BOOL)isMultiThreaded
{
  return ENTERED_MULTI_THREADED_STATE;
}

- (NSMutableDictionary *)threadDictionary
{
  return thread_dictionary;
}

// Delaying a thread
+ (void)sleepUntilDate:(NSDate *)date
{
  // Do we need some runtime/OS support for this?
}

// Terminating a thread
// What happens if the thread doesn't call +exit?
+ (void)exit
{
  NSThread *t;
  _objc_thread_t tid;
  id e;
  BOOL found;

  // Get current thread id from runtime
  tid = objc_thread_id();

  // Lock the thread list so it doesn't change on us
  [THREAD_LIST_LOCK lock];

  // Enumerate through thread list to find the current thread
  e = [THREAD_LIST objectEnumerator];
  found = NO;
  while ((t = [e nextObject]) && (!found))
    {
      if ([t threadId] == tid)
	found = YES;
    }

  // I hope we found it
  if (found)
    {
      // Remove the thread from the list
      [THREAD_LIST removeObject: t];

      // Release the thread object
      [t release];
    }

  // Unlock the thread list
  [THREAD_LIST_LOCK unlock];

  // Tell the runtime to exit the thread
  objc_thread_exit();
}

@end
