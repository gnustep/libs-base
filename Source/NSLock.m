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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include <config.h>
#include <errno.h>
#include <unistd.h>
#include <base/preface.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>

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
        raise: NSLockException 					\
        format: @"Thread attempted to recursively lock"];	\
      /* NOT REACHED */						\
    }								\
}

#define CHECK_RECURSIVE_CONDITION_LOCK(mutex)			\
{								\
  if ((mutex)->owner == objc_thread_id())			\
    {								\
      [NSException						\
        raise: NSConditionLockException 			\
        format: @"Thread attempted to recursively lock"];	\
      /* NOT REACHED */						\
    }								\
}

// NSLock class
// Simplest lock for protecting critical sections of code

@implementation NSLock

// Designated initializer
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      // Allocate the mutex from the runtime
      _mutex = objc_mutex_allocate();
      if (_mutex == 0)
	{
	  RELEASE(self);
	  NSLog(@"Failed to allocate a mutex");
	  return nil;
	}
    }
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) gcFinalize
{
  if (_mutex != 0)
    {
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(_mutex) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed");
	}
    }
}

// Try to acquire the lock
// Does not block
- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_mutex) == -1)
    {
      return NO;
    }
  else
    {
      /*
       * The recursive lock check goes here to support openstep's 
       * implementation.  In openstep you can lock in one thread trylock in the
       *  same thread and have another thread release the lock.
       *  
       *  This is dangerous and broken IMHO.
       */
      CHECK_RECURSIVE_LOCK(_mutex);
      return YES;
    }
}

- (BOOL) lockBeforeDate: (NSDate *)limit
{
  int x;

  while ((x = objc_mutex_trylock(_mutex)) == -1)
    {
      NSDate *current = [NSDate date];
      NSComparisonResult compare;
      
      compare = [current compare: limit];
      if (compare == NSOrderedSame || compare == NSOrderedDescending)
	{
	  return NO;
	}
      /*
       * This should probably be more accurate like usleep(250)
       * but usleep is known to NOT be thread safe under all architectures.
       */
      sleep(1);
    }
  /*
   * The recursive lock check goes here to support openstep's implementation.
   * In openstep you can lock in one thread trylock in the same thread and have
   * another thread release the lock.
   *  
   *  This is dangerous and broken IMHO.
   */
  CHECK_RECURSIVE_LOCK(_mutex);
  return YES;
}

// NSLocking protocol
- (void) lock
{
  CHECK_RECURSIVE_LOCK(_mutex);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_mutex) == -1)
    {
      [NSException raise: NSLockException
        format: @"failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_mutex) == -1)
    {
      [NSException raise: NSLockException
		  format: @"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end


// NSConditionLock
// Allows locking and unlocking to be based upon an integer condition

@implementation NSConditionLock

- (id) init
{
  return [self initWithCondition: 0];
}

// Designated initializer
// Initialize lock with condition
- (id) initWithCondition: (int)value
{
  self = [super init];
  if (self != nil)
    {
      _condition_value = value;

      // Allocate the mutex from the runtime
      _condition = objc_condition_allocate ();
      if (_condition == 0)
	{
	  NSLog(@"Failed to allocate a condition");
	  RELEASE(self);
	  return nil;
	}
      _mutex = objc_mutex_allocate ();
      if (_mutex == 0)
	{
	  NSLog(@"Failed to allocate a mutex");
	  RELEASE(self);
	  return nil;
	}
    }
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) gcFinalize
{
  if (_condition != 0)
    {
      // Ask the runtime to deallocate the condition
      if (objc_condition_deallocate(_condition) == -1)
	{
	  NSWarnMLog(@"objc_condition_deallocate() failed");
	}
    }
  if (_mutex != 0)
    {
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(_mutex) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed");
	}
    }
}

// Return the current condition of the lock
- (int) condition
{
  return _condition_value;
}

// Acquiring and release the lock
- (void) lockWhenCondition: (int)value
{
  CHECK_RECURSIVE_CONDITION_LOCK(_mutex);

  if (objc_mutex_lock(_mutex) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"lockWhenCondition: failed to lock mutex"];
      /* NOT REACHED */
    }

  while (_condition_value != value)
    {
      if (objc_condition_wait(_condition, _mutex) == -1)
        {
          [NSException raise: NSConditionLockException
            format: @"objc_condition_wait failed"];
          /* NOT REACHED */
        }
    }
}

- (void) unlockWithCondition: (int)value
{
  int depth;

  // First check to make sure we have the lock
  depth = objc_mutex_trylock(_mutex);

  // Another thread has the lock so abort
  if (depth == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: Tried to unlock someone else's lock"];
      /* NOT REACHED */
    }

  // If the depth is only 1 then we just acquired
  // the lock above, bogus unlock so abort
  if (depth == 1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: Unlock attempted without lock"];
      /* NOT REACHED */
    }

  // This is a valid unlock so set the condition
  _condition_value = value;

  // wake up blocked threads
  if (objc_condition_broadcast(_condition) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // and unlock twice
  if ((objc_mutex_unlock(_mutex) == -1)
      || (objc_mutex_unlock(_mutex) == -1))
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

- (BOOL) tryLock
{
  CHECK_RECURSIVE_CONDITION_LOCK(_mutex);

  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_mutex) == -1)
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
  if (_condition_value == value)
    return YES;
  else
    {
      // Wrong condition so release the lock
      [self unlock];
      return NO;
    }
}

// Acquiring the lock with a date condition
- (BOOL) lockBeforeDate: (NSDate*)limit
{ 
  CHECK_RECURSIVE_CONDITION_LOCK(_mutex);

  while (objc_mutex_trylock(_mutex) == -1)
    {
      NSDate *current = [NSDate date];
      NSComparisonResult compare;
      
      compare = [current compare: limit];
      if (compare == NSOrderedSame || compare == NSOrderedDescending)
	{
	  return NO;
	}
      /*
       * This should probably be more accurate like usleep(250)
       * but usleep is known to NOT be thread safe under all architectures.
       */
      sleep(1);
    }
  return YES;
}


- (BOOL) lockWhenCondition: (int)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
#ifndef HAVE_OBJC_CONDITION_TIMEDWAIT
  [self notImplemented: _cmd];
  return NO;
#else
  NSTimeInterval atimeinterval;
  struct timespec endtime;
  
  CHECK_RECURSIVE_CONDITION_LOCK(_mutex);
  
  if (-1 == objc_mutex_lock(_mutex))
    [NSException raise: NSConditionLockException 
		 format: @"lockWhenCondition: failed to lock mutex"];
	
  if (_condition_value == condition_to_meet)
    return YES;
  
  atimeinterval = [limitDate timeIntervalSince1970];
  endtime.tv_sec =(unsigned int)atimeinterval; // 941883028;//
  endtime.tv_nsec = (unsigned int)((atimeinterval - (float)endtime.tv_sec)
				   * 1000000000.0);
  
  while (_condition_value != condition_to_meet)
    {
      switch (objc_condition_timedwait(_condition, _mutex, &endtime))
	{
	  case 0: 
	    break;
	  case EINTR: 
	    break;
	  case ETIMEDOUT : 
	    [self unlock];
	    return NO;
	  default: 
	    [NSException raise: NSConditionLockException 
			 format: @"objc_condition_timedwait failed"];
	    [self unlock];
	    return NO;
	}
    }
  return YES;
#endif /* HAVE__OBJC_CONDITION_TIMEDWAIT */
}

// NSLocking protocol
// These methods ignore the condition
- (void) lock
{
  CHECK_RECURSIVE_CONDITION_LOCK(_mutex);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_mutex) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // wake up blocked threads
  if (objc_condition_broadcast(_condition) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_mutex) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlock: failed to unlock mutex"];
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
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      // Allocate the mutex from the runtime
      _mutex = objc_mutex_allocate();
      if (_mutex == 0)
	{
	  NSLog(@"Failed to allocate a mutex");
	  RELEASE(self);
	  return nil;
	}
    }
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) gcFinalize
{
  if (_mutex != 0)
    {
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(_mutex) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed");
	}
    }
}

// Try to acquire the lock
// Does not block
- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_mutex) == -1)
    return NO;
  else
    return YES;
}

- (BOOL) lockBeforeDate: (NSDate *)limit
{
  while (objc_mutex_trylock(_mutex) == -1)
    {
      NSDate *current = [NSDate date];
      NSComparisonResult compare;
      
      compare = [current compare: limit];
      if (compare == NSOrderedSame || compare == NSOrderedDescending)
	{
	  return NO;
	}
      /*
       * This should probably be more accurate like usleep(250)
       * but usleep is known to NOT be thread safe under all architectures.
       */
      sleep(1);
    }
  return YES;
}

// NSLocking protocol
- (void) lock
{
  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_mutex) == -1)
    {
      [NSException raise: NSRecursiveLockException
        format: @"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_mutex) == -1)
    {
      [NSException raise: NSRecursiveLockException
        format: @"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end
