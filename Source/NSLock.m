/* Mutual exclusion locking classes
   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
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

#include <gnustep/base/preface.h>
#include <Foundation/NSLock.h>

// NSLock class
// Simplest lock for protecting critical sections of code

@implementation NSLock

// Designated initializer
- init
{
  [super init];
  
  // Allocate the mutex from the runtime
  mutex = objc_mutex_allocate();
  NSAssertParameter (mutex);
  return self;
}

- (void) dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block
  objc_mutex_deallocate (mutex);
  [super dealloc];
}

// Try to acquire the lock
// Does not block
- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock (mutex) == -1)
    return NO;
  else
    return YES;
}

// NSLocking protocol
- (void) lock
{
  // Ask the runtime to acquire a lock on the mutex
  // This will block
  objc_mutex_lock (mutex);
}

- (void)unlock
{
  // Ask the runtime to release a lock on the mutex
  objc_mutex_unlock (mutex);
}

@end


// NSConditionLock
// Allows locking and unlocking to be based upon an integer condition

@implementation NSConditionLock

- init
{
  return [self initWithCondition: 0];
}

// Designated initializer
// Initialize lock with condition
- (id)initWithCondition:(int)value
{
  [super init];
  
  condition = value;

  // Allocate the mutex from the runtime
  mutex = objc_mutex_allocate ();
  NSParameterAssert (mutex);
  return self;
}

- (void)dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block
  objc_mutex_deallocate (mutex);
  [super dealloc];
}

// Return the current condition of the lock
- (int)condition
{
  return condition;
}

// Acquiring and release the lock
- (void) lockWhenCondition: (int)value
{
  BOOL done;

  done = NO;
  while (!done)
    {
      // Try to get the lock
      [self lock];

      // Is it in the condition we are looking for?
      if (condition == value)
	done = YES;
      else
	// Release the lock and keep waiting
	[self unlock];
    }
}

- (void) unlockWithCondition: (int)value
{
  int depth;

  // First check to make sure we have the lock
  depth= objc_mutex_trylock (mutex);

  // Another thread has the lock so abort
  if (depth == -1)
    return;

  // If the depth is only 1 then we just acquired
  // the lock above, bogus unlock so abort
  if (depth == 1)
    return;

  // This is a valid unlock so set the condition
  // and unlock twice
  condition = value;
  objc_mutex_unlock (mutex);
  objc_mutex_unlock (mutex);
}

- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(mutex) == -1)
    return NO;
  else
    return YES;
}

- (BOOL) tryLockWhenCondition: (int)value
{
  // First can we even get the lock?
  if (![self tryLock])
    return NO;

  // If we got the lock is it the right condition?
  if (condition == value)
    return YES;
  else
    {
      // Wrong condition so release the lock
      [self unlock];
      return NO;
    }
}

// NSLocking protocol
// These methods ignore the condition
- (void) lock
{
  // Ask the runtime to acquire a lock on the mutex
  // This will block
  objc_mutex_lock (mutex);
}

- (void)unlock
{
  // Ask the runtime to release a lock on the mutex
  objc_mutex_unlock (mutex);
}

@end


// NSRecursiveLock
// Allows the lock to be recursively acquired by the same thread
//
// If the same thread locks the mutex (n) times then that same 
// thread must also unlock it (n) times before another thread 
// can acquire the lock.

@implementation NSRecursiveLock

// Default initializer
- init
{
  [super init];
  // Allocate the mutex from the runtime
  mutex = objc_mutex_allocate();
  NSParameterAssert (mutex);
  return self;
}

- (void) dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block.
  objc_mutex_deallocate(mutex);
  [super dealloc];
}

// Try to acquire the lock
// Does not block
- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock (mutex) == -1)
    return NO;
  else
    return YES;
}

// NSLocking protocol
- (void) lock
{
  // Ask the runtime to acquire a lock on the mutex
  // This will block
  objc_mutex_lock (mutex);
}

- (void) unlock
{
  // Ask the runtime to release a lock onthe mutex
  objc_mutex_unlock (mutex);
}

@end
