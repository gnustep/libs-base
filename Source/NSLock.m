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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSException.h>

// Exceptions

NSString *NSLockException = @"NSLockException";
NSString *NSConditionLockException = @"NSConditionLockException";
NSString *NSRecursiveLockException = @"NSRecursiveLockException";

// Macros

#define CHECK_RECURSIVE_LOCK(mutex)				\
{								\
  if ((mutex)->owner == objc_thread_id())			\
    {								\
      [NSException						\
        raise:NSLockException 					\
        format:@"Thread attempted to recursively lock"];	\
      /* NOT REACHED */						\
    }								\
}

#define CHECK_RECURSIVE_CONDITION_LOCK(mutex)			\
{								\
  if ((mutex)->owner == objc_thread_id())			\
    {								\
      [NSException						\
        raise:NSConditionLockException 				\
        format:@"Thread attempted to recursively lock"];	\
      /* NOT REACHED */						\
    }								\
}

// NSLock class
// Simplest lock for protecting critical sections of code

@implementation NSLock

// Designated initializer
- init
{
  [super init];
  
  // Allocate the mutex from the runtime
  mutex = objc_mutex_allocate();
  if (!mutex)
    {
      NSLog(@"Failed to allocate a mutex");
      return nil;
    }
  return self;
}

- (void) dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block
  if (objc_mutex_deallocate (mutex) == -1)
    {
      [NSException raise:NSLockException
        format:@"invalid mutex"];
      /* NOT REACHED */
    }
  [super dealloc];
}

// Try to acquire the lock
// Does not block
- (BOOL) tryLock
{
  CHECK_RECURSIVE_LOCK (mutex);

  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock (mutex) == -1)
    return NO;
  else
    return YES;
}

// NSLocking protocol
- (void) lock
{
  CHECK_RECURSIVE_LOCK (mutex);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock (mutex) == -1)
    {
      [NSException raise:NSLockException
        format:@"failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void)unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock (mutex) == -1)
    {
      [NSException raise:NSLockException
        format:@"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
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
  
  condition_value = value;

  // Allocate the mutex from the runtime
  condition = objc_condition_allocate ();
  if (!condition)
    {
      NSLog(@"Failed to allocate a condition");
      return nil;
    }
  mutex = objc_mutex_allocate ();
  if (!mutex)
    {
      NSLog(@"Failed to allocate a mutex");
      return nil;
    }
  return self;
}

- (void)dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block
  if (objc_condition_deallocate (condition) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"dealloc: invalid condition"];
      /* NOT REACHED */
    }
  if (objc_mutex_deallocate (mutex) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"dealloc: invalid mutex"];
      /* NOT REACHED */
    }
  [super dealloc];
}

// Return the current condition of the lock
- (int)condition
{
  return condition_value;
}

// Acquiring and release the lock
- (void) lockWhenCondition: (int)value
{
  int result;

  CHECK_RECURSIVE_CONDITION_LOCK (mutex);

  if (objc_mutex_lock (mutex) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"lockWhenCondition: failed to lock mutex"];
      /* NOT REACHED */
    }

  while (condition_value != value)
    {
      if (objc_condition_wait (condition,mutex) == -1)
        {
          [NSException raise:NSConditionLockException
            format:@"objc_condition_wait failed"];
          /* NOT REACHED */
        }
    }
}

- (void) unlockWithCondition: (int)value
{
  int depth;

  // First check to make sure we have the lock
  depth = objc_mutex_trylock (mutex);

  // Another thread has the lock so abort
  if (depth == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"unlockWithCondition: Tried to unlock someone else's lock"];
      /* NOT REACHED */
    }

  // If the depth is only 1 then we just acquired
  // the lock above, bogus unlock so abort
  if (depth == 1)
    {
      [NSException raise:NSConditionLockException
        format:@"unlockWithCondition: Unlock attempted without lock"];
      /* NOT REACHED */
    }

  // This is a valid unlock so set the condition
  condition_value = value;

  // wake up blocked threads
  if (objc_condition_broadcast(condition) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // and unlock twice
  if ((objc_mutex_unlock (mutex) == -1)
      || (objc_mutex_unlock (mutex) == -1))
    {
      [NSException raise:NSConditionLockException
        format:@"unlockWithCondition: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

- (BOOL) tryLock
{
  CHECK_RECURSIVE_CONDITION_LOCK (mutex);

  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(mutex) == -1)
    return NO;
  else
    return YES;
}

- (BOOL) tryLockWhenCondition: (int)value
{
  // tryLock message will check for recursive locks

  // First can we even get the lock?
  if (![self tryLock])
    return NO;

  // If we got the lock is it the right condition?
  if (condition_value == value)
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
  CHECK_RECURSIVE_CONDITION_LOCK (mutex);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock (mutex) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void)unlock
{
  // wake up blocked threads
  if (objc_condition_broadcast(condition) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock (mutex) == -1)
    {
      [NSException raise:NSConditionLockException
        format:@"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end


// NSRecursiveLock
// Allows the lock to be recursively acquired by the same thread
//
// If the same thread locks the mutex (n) times then that same 
// thread must also unlock it (n) times before another thread 
// can acquire the lock.

@implementation NSRecursiveLock

// Designated initializer
- init
{
  [super init];
  
  // Allocate the mutex from the runtime
  mutex = objc_mutex_allocate();
  if (!mutex)
    {
      NSLog(@"Failed to allocate a mutex");
      return nil;
    }
  return self;
}

- (void) dealloc
{
  // Ask the runtime to deallocate the mutex
  // If there are outstanding locks then it will block
  if (objc_mutex_deallocate (mutex) == -1)
    {
      [NSException raise:NSRecursiveLockException
        format:@"dealloc: invalid mutex"];
      /* NOT REACHED */
    }
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
  if (objc_mutex_lock (mutex) == -1)
    {
      [NSException raise:NSRecursiveLockException
        format:@"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void)unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock (mutex) == -1)
    {
      [NSException raise:NSRecursiveLockException
        format:@"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end
