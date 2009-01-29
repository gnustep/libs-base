/** Mutual exclusion locking classes
   Copyright (C) 1996,2003 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Created: 1996
   Author:  Richard Frith-Macdonald <rfm@gnu.org>

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

   <title>NSLock class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include <errno.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include "GNUstepBase/preface.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSException.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSThread.h"
#ifdef NeXT_RUNTIME
#include "thr-mach.h"
#endif

#define _MUTEX     ((objc_mutex_t)_mutex)
#define _CONDITION ((objc_condition_t)_condition)

extern void		GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval);
extern NSTimeInterval	GSTimeNow();

typedef struct {
  NSTimeInterval	end;
  NSTimeInterval	i0;
  NSTimeInterval	i1;
  NSTimeInterval	max;
} GSSleepInfo;

static void GSSleepInit(NSDate *limit, GSSleepInfo *context)
{
  context->end = [limit timeIntervalSinceReferenceDate];
  context->i0 = 0.0;
  context->i1 = 0.0001;		// Initial pause interval.
  context->max = 0.25;		// Maximum pause interval.
}

/**
 * <p>Using a pointer to a context structure initialised using GSSleepInit()
 * we either pause for a while and return YES or, if the limit date
 * has passed, return NO.
 * </p>
 * <p>The pause intervals start off very small, but rapidly increase
 * (following a fibonacci sequence) up to a maximum value.
 * </p>
 * <p>We use the GSSleepUntilIntervalSinceReferenceDate() function to
 * avoid objc runtime messaging overheads and overheads of creating and
 * destroying temporary date objects.
 * </p>
 */
static BOOL GSSleepOrFail(GSSleepInfo *context)
{
  NSTimeInterval	when = GSTimeNow();
  NSTimeInterval	tmp;

  if (when >= context->end)
    {
      return NO;
    }
  tmp = context->i0 + context->i1;
  context->i0 = context->i1;
  context->i1 = tmp;
  if (tmp > context->max)
    {
      tmp = context->max;
    }
  when += tmp;
  if (when > context->end)
    {
      when = context->end;
    }
  GSSleepUntilIntervalSinceReferenceDate(when);
  return YES;		// Paused.
}

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

#define WARN_RECURSIVE_CONDITION_LOCK(mutex)			\
{								\
  if ((mutex)->owner == objc_thread_id())			\
    {								\
      NSLog(@"WARNING: Thread attempted to recursively lock: %@",self);	        \
    }								\
}

// NSLock class
// Simplest lock for protecting critical sections of code

/**
 * An <code>NSLock</code> is used in multi-threaded applications to protect
 * critical pieces of code. While one thread holds a lock within a piece of
 * code, another thread cannot execute that code until the first thread has
 * given up its hold on the lock. The limitation of <code>NSLock</code> is
 * that you can only lock an <code>NSLock</code> once and it must be unlocked
 * before it can be acquired again.<br /> Other lock classes, notably
 * [NSRecursiveLock], have different restrictions.
 */
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
  [self finalize];
  [super dealloc];
}

- (NSString*) description
{
  if (_name == nil)
    return [super description];
  return [NSString stringWithFormat: @"%@ named '%@'",
    [super description], _name];
}

- (void) finalize
{
  if (_mutex != 0)
    {
      objc_mutex_t	tmp = _MUTEX;

      _mutex = 0;
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(tmp) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed for %@", self);
	}
    }
  DESTROY(_name);
}

- (NSString*) name
{
  return _name;
}

- (void) setName: (NSString*)name
{
  ASSIGNCOPY(_name, name);
}

/**
 * Attempts to acquire a lock, but returns immediately if the lock
 * cannot be acquired. It returns YES if the lock is acquired. It returns
 * NO if the lock cannot be acquired or if the current thread already has
 * the lock.
 */
- (BOOL) tryLock
{
  /* Return NO if we're already locked */
  if (_MUTEX->owner == objc_thread_id())
    {	
      return NO;
    }

  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_MUTEX) == -1)
    {
      return NO;
    }
  return YES;
}

/**
 * Attempts to acquire a lock before the date limit passes. It returns YES
 * if it can. It returns NO if it cannot, or if the current thread already
 * has the lock (but it waits until the time limit is up before returning
 * NO).
 */
- (BOOL) lockBeforeDate: (NSDate*)limit
{
  int		x;
  GSSleepInfo	ctxt;

  GSSleepInit(limit, &ctxt);

  /* This is really the behavior of OpenStep, if the current thread has
     the lock, we just block until the time limit is up. Very odd */
  while (_MUTEX->owner == objc_thread_id()
    || (x = objc_mutex_trylock(_MUTEX)) == -1)
    {
      if (GSSleepOrFail(&ctxt) == NO)
	{
	  return NO;
	}
    }
  return YES;
}

/**
 * Attempts to acquire a lock, and waits until it can do so.
 */
- (void) lock
{
  CHECK_RECURSIVE_LOCK(_MUTEX);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_MUTEX) == -1)
    {
      [NSException raise: NSLockException
        format: @"failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_MUTEX) == -1)
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
  [self finalize];
  [super dealloc];
}

- (NSString*) description
{
  if (_name == nil)
    return [super description];
  return [NSString stringWithFormat: @"%@ named '%@'",
    [super description], _name];
}

- (void) finalize
{
  if (_condition != 0)
    {
      objc_condition_t	tmp = _CONDITION;

      _condition = 0;
      // Ask the runtime to deallocate the condition
      if (objc_condition_deallocate(tmp) == -1)
	{
	  NSWarnMLog(@"objc_condition_deallocate() failed for %@", self);
	}
    }
  if (_mutex != 0)
    {
      objc_mutex_t	tmp = _MUTEX;

      _mutex = 0;
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(tmp) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed for %@", self);
	}
    }
  DESTROY(_name);
}

// Return the current condition of the lock
- (int) condition
{
  return _condition_value;
}

// Acquiring and release the lock
- (void) lockWhenCondition: (int)value
{
  CHECK_RECURSIVE_CONDITION_LOCK(_MUTEX);

  if (objc_mutex_lock(_MUTEX) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"lockWhenCondition: failed to lock mutex"];
      /* NOT REACHED */
    }

  while (_condition_value != value)
    {
      if (objc_condition_wait(_CONDITION, _MUTEX) == -1)
        {
          [NSException raise: NSConditionLockException
            format: @"objc_condition_wait failed"];
          /* NOT REACHED */
        }
    }
}

- (NSString*) name
{
  return _name;
}

- (void) setName: (NSString*)name
{
  ASSIGNCOPY(_name, name);
}

- (void) unlockWithCondition: (int)value
{
  int depth;

  // First check to make sure we have the lock
  depth = objc_mutex_trylock(_MUTEX);

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
  if (objc_condition_broadcast(_CONDITION) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // and unlock twice
  if ((objc_mutex_unlock(_MUTEX) == -1)
    || (objc_mutex_unlock(_MUTEX) == -1))
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

- (BOOL) tryLock
{
  WARN_RECURSIVE_CONDITION_LOCK(_MUTEX);

  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_MUTEX) == -1)
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
  GSSleepInfo	ctxt;

  CHECK_RECURSIVE_CONDITION_LOCK(_MUTEX);

  GSSleepInit(limit, &ctxt);

  while (objc_mutex_trylock(_MUTEX) == -1)
    {
      if (GSSleepOrFail(&ctxt) == NO)
	{
	  return NO;
	}
    }
  return YES;
}


- (BOOL) lockWhenCondition: (int)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
#ifndef HAVE_OBJC_CONDITION_TIMEDWAIT
  GSSleepInfo	ctxt;

  CHECK_RECURSIVE_CONDITION_LOCK(_MUTEX);

  GSSleepInit(limitDate, &ctxt);

  do
    {
      if (_condition_value == condition_to_meet)
	{
	  while (objc_mutex_trylock(_MUTEX) == -1)
	    {
	      if (GSSleepOrFail(&ctxt) == NO)
		{
		  return NO;
		}
	    }
	  if (_condition_value == condition_to_meet)
	    {
	      return YES;
	    }
	  if (objc_mutex_unlock(_MUTEX) == -1)
	    {
	      [NSException raise: NSConditionLockException
			   format: @"%s failed to unlock mutex",
			   GSNameFromSelector(_cmd)];
	      /* NOT REACHED */
	    }
	}
    }
  while (GSSleepOrFail(&ctxt) == YES);

  return NO;

#else
  NSTimeInterval atimeinterval;
  struct timespec endtime;

  CHECK_RECURSIVE_CONDITION_LOCK(_MUTEX);

  if (-1 == objc_mutex_lock(_MUTEX))
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
      switch (objc_condition_timedwait(_CONDITION, _MUTEX, &endtime))
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
  CHECK_RECURSIVE_CONDITION_LOCK(_MUTEX);

  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_MUTEX) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // wake up blocked threads
  if (objc_condition_broadcast(_CONDITION) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlockWithCondition: objc_condition_broadcast failed"];
      /* NOT REACHED */
    }

  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_MUTEX) == -1)
    {
      [NSException raise: NSConditionLockException
        format: @"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end



/**
 * See [NSLock] for more information about what a lock is. A recursive
 * lock extends [NSLock] in that you can lock a recursive lock multiple
 * times. Each lock must be balanced by a corresponding unlock, and the
 * lock is not released for another thread to acquire until the last
 * unlock call is made (corresponding to the first lock message).
 */
@implementation NSRecursiveLock

/** <init />
 */
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
  [self finalize];
  [super dealloc];
}

- (NSString*) description
{
  if (_name == nil)
    return [super description];
  return [NSString stringWithFormat: @"%@ named '%@'",
    [super description], _name];
}

- (void) finalize
{
  if (_mutex != 0)
    {
      objc_mutex_t	tmp = _MUTEX;

      _mutex = 0;
      // Ask the runtime to deallocate the mutex
      // If there are outstanding locks then it will block
      if (objc_mutex_deallocate(tmp) == -1)
	{
	  NSWarnMLog(@"objc_mutex_deallocate() failed for %@", self);
	}
    }
  DESTROY(_name);
}

- (NSString*) name
{
  return _name;
}

- (void) setName: (NSString*)name
{
  ASSIGNCOPY(_name, name);
}

/**
 * Attempts to acquire a lock, but returns NO immediately if the lock
 * cannot be acquired. It returns YES if the lock is acquired. Can be
 * called multiple times to make nested locks.
 */
- (BOOL) tryLock
{
  // Ask the runtime to acquire a lock on the mutex
  if (objc_mutex_trylock(_MUTEX) == -1)
    return NO;
  else
    return YES;
}

/**
 * Attempts to acquire a lock before the date limit passes. It returns
 * YES if it can. It returns NO if it cannot
 * (but it waits until the time limit is up before returning NO).
 */
- (BOOL) lockBeforeDate: (NSDate*)limit
{
  GSSleepInfo	ctxt;

  GSSleepInit(limit, &ctxt);
  while (objc_mutex_trylock(_MUTEX) == -1)
    {
      if (GSSleepOrFail(&ctxt) == NO)
	{
	  return NO;
	}
    }
  return YES;
}

// NSLocking protocol
- (void) lock
{
  // Ask the runtime to acquire a lock on the mutex
  // This will block
  if (objc_mutex_lock(_MUTEX) == -1)
    {
      [NSException raise: NSRecursiveLockException
        format: @"lock: failed to lock mutex"];
      /* NOT REACHED */
    }
}

- (void) unlock
{
  // Ask the runtime to release a lock on the mutex
  if (objc_mutex_unlock(_MUTEX) == -1)
    {
      [NSException raise: NSRecursiveLockException
        format: @"unlock: failed to unlock mutex"];
      /* NOT REACHED */
    }
}

@end
