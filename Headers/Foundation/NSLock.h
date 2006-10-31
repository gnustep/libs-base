/* 
   NSLock.h

   Definitions for locking protocol and classes

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/ 

#ifndef __NSLock_h_GNUSTEP_BASE_INCLUDE
#define __NSLock_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/**
 * Protocol defining lock and unlock operations.
 */
@protocol NSLocking

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

@end

/**
 * Simplest lock for protecting critical sections of code.
 */
@interface NSLock : NSObject <NSLocking, GCFinalization>
{
@private
  void *_mutex;
}

/**
 *  Try to acquire lock and return immediately, YES if succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

@end

/**
 *  Lock that allows user to request it only when an internal integer
 *  condition is equal to a particular value.  The condition is set on
 *  initialization and whenever the lock is relinquished.
 */
@interface NSConditionLock : NSObject <NSLocking, GCFinalization>
{
@private
  void *_condition;
  void *_mutex;
  int   _condition_value;
}

/**
 * Initialize lock with given condition.
 */
- (id) initWithCondition: (int)value;

/**
 * Return the current condition of the lock.
 */
- (int) condition;

/*
 * Acquiring and releasing the lock.
 */

/**
 *  Acquire lock when it is available and the internal condition is equal to
 *  value.  Blocks until this occurs.
 */
- (void) lockWhenCondition: (int)value;

/**
 *  Relinquish the lock, setting internal condition to value.
 */
- (void) unlockWithCondition: (int)value;

/**
 *  Try to acquire lock regardless of condition and return immediately, YES if
 *  succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Try to acquire lock if condition is equal to value and return immediately
 *  in any case, YES if succeeded, NO if not.
 */
- (BOOL) tryLockWhenCondition: (int)value;

/*
 * Acquiring the lock with a date condition.
 */

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Try to acquire lock, when internal condition is equal to condition_to_meet,
 *  and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockWhenCondition: (int)condition_to_meet
                beforeDate: (NSDate*)limitDate;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

@end


/**
 * Allows the lock to be recursively acquired by the same thread.
 *
 * If the same thread locks the mutex (n) times then that same 
 * thread must also unlock it (n) times before another thread 
 * can acquire the lock.
 */
@interface NSRecursiveLock : NSObject <NSLocking, GCFinalization>
{
@private
  void *_mutex;
}

/**
 *  Try to acquire lock regardless of condition and return immediately, YES if
 *  succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 * Returns IDENT which will be initialized
 * to an instance of a CLASSNAME in a thread safe manner.  
 * If IDENT has been previously initialized 
 * this macro merely returns IDENT.
 * IDENT is considered uninitialized, if it contains nil.
 * CLASSNAME must be either NSLock, NSRecursiveLock or one
 * of their subclasses.
 * See [NSLock+newLockAt:] for details.
 * This macro is intended for code that cannot insure
 * that a lock can be initialized in thread safe manner otherwise.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 *
 * </example>
 */
#define GS_INITIALIZED_LOCK(IDENT,CLASSNAME) \
           (IDENT != nil ? (id)IDENT : (id)[CLASSNAME newLockAt: &IDENT])

/**
 *  Defines the <code>newLockAt:</code> method.
 */
@interface NSLock (GSCategories)
/**
 * Initializes the id pointed to by location
 * with a new instance of the receiver's class
 * in a thread safe manner, unless
 * it has been previously initialized.
 * Returns the contents pointed to by location.  
 * The location is considered unintialized if it contains nil.
 * <br/>
 * This method is used in the GS_INITIALIZED_LOCK macro
 * to initialize lock variables when it cannot be insured
 * that they can be initialized in a thread safe environment.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 * 
 * </example>
 */
+ (id) newLockAt: (id *)location;
@end

/**
 *  Defines the <code>newLockAt:</code> method.
 */
@interface NSRecursiveLock (GSCategories)
/**
 * Initializes the id pointed to by location
 * with a new instance of the receiver's class
 * in a thread safe manner, unless
 * it has been previously initialized.
 * Returns the contents pointed to by location.  
 * The location is considered unintialized if it contains nil.
 * <br/>
 * This method is used in the GS_INITIALIZED_LOCK macro
 * to initialize lock variables when it cannot be insured
 * that they can be initialized in a thread safe environment.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSRecursiveLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 * 
 * </example>
 */
+ (id) newLockAt: (id *)location;
@end

#endif	/* GS_API_NONE */

#if	defined(__cplusplus)
}
#endif

#endif /* __NSLock_h_GNUSTEP_BASE_INCLUDE */

