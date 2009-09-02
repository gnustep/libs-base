/** Control of executable units within a shared virtual memory space
   Copyright (C) 1996-2000 Free Software Foundation, Inc.

   Original Author:  David Chisnall <csdavec@swan.ac.uk>

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
*/



// This file uses some SUS'98 extensions, so we need to tell glibc not to hide
// them.  Other platforms have more sensible libcs, which just default to being
// standards-compliant.
#define _XOPEN_SOURCE 500
#include "Foundation/NSLock.h"
#include <math.h>
#include <errno.h>
#include "Foundation/NSException.h"

/**
 * Methods shared between NSLock, NSRecursiveLock, and NSCondition
 *
 * Note: These methods currently throw exceptions when locks are incorrectly
 * acquired.  This is compatible with earlier GNUstep behaviour.  In OS X 10.5
 * and later, these will just NSLog a warning instead.  Throwing an exception
 * is probably better behaviour, because it encourages developer to fix their
 * code.  
 */
#define NSLOCKING_METHODS \
- (void)lock\
{\
	int err = pthread_mutex_lock(&_mutex);\
	if (EINVAL == err)\
	{\
		[NSException raise: NSLockException\
					format: @"failed to unlock mutex"];\
	}\
	if (EDEADLK == err)\
	{\
		_NSLockError(self, _cmd);\
	}\
}\
- (void)unlock\
{\
	if (0 != pthread_mutex_unlock(&_mutex))\
	{\
		[NSException raise: NSLockException\
					format: @"failed to unlock mutex"];\
	}\
}\
- (NSString*) description\
{\
	if (_name == nil)\
	{\
		return [super description];\
	}\
	return [NSString stringWithFormat: @"%@ '%@'",\
		[super description], _name];\
}\
- (BOOL) tryLock\
{\
	int err = pthread_mutex_trylock(&_mutex);\
	if (EDEADLK == err)\
	{\
		_NSLockError(self, _cmd);\
		return YES;\
	}\
	return (0 == err);\
}\
- (BOOL) lockBeforeDate: (NSDate*)limit\
{\
	do\
	{\
		int err = pthread_mutex_trylock(&_mutex);\
		if (EDEADLK == err)\
		{\
			_NSLockError(self, _cmd);\
			return YES;\
		}\
		if (0 == err)\
		{\
			return YES;\
		}\
		sched_yield();\
	} while([limit timeIntervalSinceNow] < 0);\
	return NO;\
}\
NAME_METHODS

#define NAME_METHODS \
- (void)setName:(NSString*)newName\
{\
	ASSIGNCOPY(_name, newName);\
}\
- (NSString*)name\
{\
	return _name;\
}

/**
 * OS X 10.5 compatibility function to allow debugging deadlock conditions.
 *
 * On OS X, this really deadlocks.  For now, we just continue, while logging
 * the 'you are a numpty' warning.
 */
void _NSLockError(id obj, SEL _cmd)
{
	NSLog(@"*** -[%@ %@]: deadlock (%@)", [obj class],
			NSStringFromSelector(_cmd), obj);
	NSLog(@"*** Break on _NSLockError() to debug.");
}

/**
 * Init method for an NSLock / NSRecursive lock.  Creates a mutex of the
 * specified type.  Also adds the corresponding -finalize and -dealloc methods.
 */
#define INIT_LOCK_WITH_TYPE(lock_type) \
- (id) init\
{\
	if (nil == (self = [super init])) { return nil; }\
	pthread_mutexattr_t attr;\
	pthread_mutexattr_init(&attr);\
	pthread_mutexattr_settype(&attr, lock_type);\
	if (0 != pthread_mutex_init(&_mutex, &attr))\
	{\
		[self release];\
		return nil;\
	}\
	return self;\
}\
- (void) finalize\
{\
	pthread_mutex_destroy(&_mutex);\
}\
- (void) dealloc\
{\
  [self finalize];\
  [_name release];\
  [super dealloc];\
}

// Exceptions

NSString *NSLockException = @"NSLockException";


@implementation NSLock
// Use an error-checking lock.  This is marginally slower, but lets us throw
// exceptions when incorrect locking occurs.
INIT_LOCK_WITH_TYPE(PTHREAD_MUTEX_ERRORCHECK)
NSLOCKING_METHODS
@end

@implementation NSRecursiveLock
INIT_LOCK_WITH_TYPE(PTHREAD_MUTEX_RECURSIVE);
NSLOCKING_METHODS
@end

@implementation NSCondition
- (id)init
{
	if (nil == (self = [super init])) { return nil; }
	if (0 != pthread_cond_init(&_condition, NULL))
	{
		[self release];
		return nil;
	}
	pthread_mutexattr_t attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK);
	if (0 != pthread_mutex_init(&_mutex, &attr))
	{
		pthread_cond_destroy(&_condition);
		[self release];
		return nil;
	}
	return self;
}
- (void)finalize
{
	pthread_cond_destroy(&_condition);
	pthread_mutex_destroy(&_mutex);
}
- (void)dealloc
{
	[self finalize];
	[_name release];
	[super dealloc];
}
- (void)wait
{
	pthread_cond_wait(&_condition, &_mutex);
}
- (BOOL)waitUntilDate: (NSDate*)limit
{
	NSTimeInterval t = [limit timeIntervalSinceReferenceDate];
	double secs, subsecs;
	struct timespec timeout;
	// Split the float into seconds and fractions of a second
	subsecs = modf(t, &secs);
	timeout.tv_sec = secs;
	// Convert fractions of a second to nanoseconds
	timeout.tv_nsec = subsecs * 1e9;
	return (0 == pthread_cond_timedwait(&_condition, &_mutex, &timeout));
}
- (void)signal
{
	pthread_cond_signal(&_condition);
}
- (void)broadcast;
{
	pthread_cond_broadcast(&_condition);
}
NSLOCKING_METHODS
@end

@implementation NSConditionLock
- (id) init
{
  return [self initWithCondition: 0];
}

- (id) initWithCondition: (NSInteger)value
{
	if (nil == (self = [super init])) { return nil; }
	if (nil == (_condition = [NSCondition new]))
	{
		[self release];
		return nil;
	}
	_condition_value = value;
	return self;
}

- (void) dealloc
{
  [_name release];
  [_condition release];
  [super dealloc];
}

- (NSInteger) condition
{
  return _condition_value;
}

- (void) lockWhenCondition: (NSInteger)value
{
	[_condition lock];
	while (value != _condition_value)
	{
		[_condition wait];
	}
}

- (void) unlockWithCondition: (NSInteger)value
{
	[_condition lock];
	_condition_value = value;
	[_condition broadcast];
	[_condition unlock];
}

- (BOOL) tryLockWhenCondition: (NSInteger)value
{
	return [self lockWhenCondition: value
						beforeDate: [NSDate date]];
}

- (BOOL) lockBeforeDate: (NSDate*)limit
{
	return [_condition lockBeforeDate: limit];
}

- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
	[_condition lock];
	if (condition_to_meet == _condition_value)
	{
		return YES;
	}
	if ([_condition waitUntilDate: limitDate]
		&&
		(condition_to_meet == _condition_value))
	{
		return YES;
	}
	return NO;
}

// NSLocking methods.  These aren't instantiated with the macro as they are
// delegated to the NSCondition.
- (void) lock
{
	[_condition lock];
}

- (void) unlock
{
	[_condition unlock];
}

- (BOOL) tryLock
{
	return [_condition tryLock];
}
NAME_METHODS
@end
