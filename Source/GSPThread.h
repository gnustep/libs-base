/* GSPThread.h
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 
#ifndef _GSPThread_h_
#define _GSPThread_h_

#if defined(_WIN32)

#include <windows.h>

// SRWLock is the fastest on Windows but non-recursive
typedef SRWLOCK gs_mutex_t;
#define GS_MUTEX_INIT_STATIC SRWLOCK_INIT
#define GS_MUTEX_INIT(x) InitializeSRWLock(&(x))
#define GS_MUTEX_LOCK(x) AcquireSRWLockExclusive(&(x))
#define GS_MUTEX_UNLOCK(x) ReleaseSRWLockExclusive(&(x))
#define GS_MUTEX_DESTROY(x)

// Critical Section Objects are recursive
typedef CRITICAL_SECTION gs_recursive_mutex_t;
#define GS_RECURSIVE_MUTEX_INIT(x) InitializeCriticalSection(&(x))
#define GS_RECURSIVE_MUTEX_LOCK(x) EnterCriticalSection(&(x))
#define GS_RECURSIVE_MUTEX_UNLOCK(x) LeaveCriticalSection(&(x))
#define GS_RECURSIVE_MUTEX_DESTROY(x) DeleteCriticalSection(&(x))

typedef CONDITION_VARIABLE gs_cond_t;
#define GS_COND_SIGNAL(x) WakeConditionVariable(&(x))
#define GS_COND_BROADCAST(x) WakeAllConditionVariable(&(x))

#else /* !_WIN32 */

#include <pthread.h>

typedef pthread_mutex_t gs_mutex_t;
#define GS_MUTEX_INIT_STATIC PTHREAD_MUTEX_INITIALIZER
#define GS_MUTEX_INIT(x) pthread_mutex_init(&(x), NULL)
#define GS_MUTEX_LOCK(x) pthread_mutex_lock(&(x))
#define GS_MUTEX_UNLOCK(x) pthread_mutex_unlock(&(x))
#define GS_MUTEX_DESTROY(x) pthread_mutex_destroy(&(x))

typedef pthread_mutex_t gs_recursive_mutex_t;
/*
 * Macro to initialize recursive mutexes in a portable way. Adopted from
 * libobjc2 (lock.h).
 */
# ifdef PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
#   define GS_RECURSIVE_MUTEX_INIT(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
# elif defined(PTHREAD_RECURSIVE_MUTEX_INITIALIZER)
#   define GS_RECURSIVE_MUTEX_INIT(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER
# else
#   define GS_RECURSIVE_MUTEX_INIT(x) GSPThreadInitRecursiveMutex(&(x))

static inline void GSPThreadInitRecursiveMutex(pthread_mutex_t *x)
{
  pthread_mutexattr_t recursiveAttributes;
  pthread_mutexattr_init(&recursiveAttributes);
  pthread_mutexattr_settype(&recursiveAttributes, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(x, &recursiveAttributes);
  pthread_mutexattr_destroy(&recursiveAttributes);
}
# endif // PTHREAD_RECURSIVE_MUTEX_INITIALIZER(_NP)

#define GS_RECURSIVE_MUTEX_LOCK(x) GS_MUTEX_LOCK(x)
#define GS_RECURSIVE_MUTEX_UNLOCK(x) GS_MUTEX_UNLOCK(x)
#define GS_RECURSIVE_MUTEX_DESTROY(x) GS_MUTEX_DESTROY(x)

typedef CONDITION_VARIABLE pthread_cond_t;
#define GS_COND_SIGNAL(x) pthread_cond_signal(&(x))
#define GS_COND_BROADCAST(x) pthread_cond_broadcast(&(x))

#endif /* _WIN32 */

#import "Foundation/NSLock.h"

@class  GSStackTrace;
@class  NSArray;
@class  NSMapTable;

/* Class to obtain/encapsulate a stack trace for exception reporting and/or
 * lock tracing.
 */
@interface GSStackTrace : NSObject
{
  NSArray	        *symbols;
  NSArray	        *addresses;
@public
  NSUInteger            recursion;      // Recursion count for lock trace
  NSUInteger	        *returns;       // The return addresses on the stack
  int                   numReturns;     // Number of return addresses
}
- (NSArray*) addresses; // Return addresses from last trace
- (NSArray*) symbols;   // Return symbols from last trace
- (void) trace;         // Populate with new stack trace
@end

/* Versions of the lock classes where the locking is never traced
 */
@interface      GSUntracedCondition : NSCondition
@end
@interface      GSUntracedConditionLock : NSConditionLock
@end
@interface      GSUntracedLock : NSLock
@end
@interface      GSUntracedRecursiveLock : NSRecursiveLock
@end

/* Versions of the lock classes where the locking is traced
 */
@interface      GSTracedCondition : NSCondition
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

@interface      GSTracedConditionLock : NSConditionLock
@end

@interface      GSTracedLock : NSLock
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

@interface      GSTracedRecursiveLock : NSRecursiveLock
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

#endif // _GSPThread_h_
