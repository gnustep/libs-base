/* Definition of class NSProgress
   Copyright (C) 2025 Free Software Foundation, Inc.
   
   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: August 2025
   
   This file is part of the GNUstep Library.
   
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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#include "GNUstepBase/GNUstep.h"
#import "GSPThread.h"
#define	GS_NSProgress_IVARS	 \
  NSProgressKind _kind;  \
  NSProgressFileOperationKind _fileOperationKind; \
  NSURL *_fileUrl; \
  NSNumber *_estimatedTimeRemaining; \
  NSNumber *_fileCompletedCount; \
  NSNumber *_fileTotalCount; \
  NSNumber *_throughput; \
  int64_t _totalUnitCount; \
  int64_t _completedUnitCount; \
  int64_t _pendingUnitCountForParent; \
  int64_t _pendingUnitCountForChild; \
  double _fractionCompleted; \
  NSMutableDictionary *_userInfo; \
  _Atomic(BOOL) _cancelled; \
  _Atomic(BOOL) _cancellable; \
  _Atomic(BOOL) _indeterminate; \
  _Atomic(BOOL) _finished; \
  BOOL _allowImplicitChild; \
  GSProgressCancellationHandler _cancellationHandler; \
  GSProgressPausingHandler _pausingHandler; \
  NSProgressPublishingHandler _publishingHandler; \
  NSProgressUnpublishingHandler _unpublishingHandler; \
  GSProgressPendingUnitCountBlock _pendingUnitCountHandler; \
  GSProgressResumingHandler _resumingHandler;              \
  NSString * _localizedDescription; \
  NSString * _localizedAdditionalDescription; \
  NSProgress *_parent; \
  NSMutableSet *_children; \
  gs_mutex_t _lock;

#define	EXPOSE_NSProgress_IVARS

#import "Foundation/NSException.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSString.h"
#import "Foundation/NSSet.h"
#import	"Foundation/NSProgress.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSKeyValueObserving.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GSFastEnumeration.h"

#define	GSInternal NSProgressInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSProgress)

/* The current progress is specific to the current thread. Below are helper
 * functions that manage the TLS entry. Progresses marked current are stored in
 * LIFO order. We use an NSMutableArray to model this behaviour. */
static gs_thread_key_t tls_current_progress_key;
static NSMutableArray * tls_current_progress_create(void)
{
  NSMutableArray *stack = [[NSMutableArray alloc] initWithCapacity: 2];
  GS_THREAD_KEY_SET(tls_current_progress_key, stack);
  return stack;
}
/* The destructor is only invoked when the TLS value is non-NULL */
static void tls_current_progress_destroy(void *value)
{
  NSMutableArray *stack = value;
  RELEASE(stack);
}
static void tls_create_keys(void)
{
  GS_THREAD_KEY_INIT(tls_current_progress_key, tls_current_progress_destroy);
}

/* Returns an unretained pointer of the current progress */
static NSProgress *tls_current_progress_get(void)
{
  NSMutableArray *stack = GS_THREAD_KEY_GET(tls_current_progress_key);
  if (stack != NULL)
  {
    return [stack lastObject];
  }
  else
  {
    return nil;
  }
}
static void tls_current_progress_push(NSProgress *new)
{
  NSMutableArray *stack = GS_THREAD_KEY_GET(tls_current_progress_key);
  if (stack == NULL)
  {
    stack = tls_current_progress_create();
  }
  [stack addObject: new];
}
static void tls_current_progress_pop(void)
{
  NSMutableArray *stack = GS_THREAD_KEY_GET(tls_current_progress_key);
  if (stack != NULL)
  {
    [stack removeLastObject];
  }
}

/**
 * Implementation Note: GNUstep currently, as of August 2025, lacks the ability
 * to create RW locks.  RW locks would make the NSProgress implementation more
 * efficient, as getters (and other readers) could request shared, instead of
 * exclusive access.
 *
 * While not explicitly mentioned in the Apple API documentation, NSProgress
 * relies on a per-object NSLock to synchronize progress update operations.
 * Apple's API documentation is terrible for the NSProgress implementation, as
 * it does not describe important implementation details and side-effects.
 * To give you an example, there is no mention of the usage of a thread-specific
 * stack for current progress.
 *
 * We conducted experiments on macOS 15.5 to match this implementation with the
 * one present in Foundation.
 */

@implementation NSProgress

+ (void) initialize
{
  if (self == [NSProgress class])
    {
      /* +initialize is called in a thread-safe manner and only once */
      tls_create_keys();
    }
}

+ (BOOL) automaticallyNotifiesObserversOfCompletedUnitCount
{
  return NO; // We handle this in an internal method
}

+ (NSSet *)keyPathsForValuesAffectingLocalizedDescription {
    return [NSSet setWithObjects:@"userInfo.NSProgressFileOperationKindKey",
                                 @"userInfo.NSProgressFileTotalCountKey",
                                 @"completedUnitCount",
                                 @"totalUnitCount",
                                 @"fractionCompleted",
                                 @"kind",
                                 nil];
}

+ (NSProgress *) currentProgress
{
  NSProgress *current = tls_current_progress_get();
  return AUTORELEASE(RETAIN(current));
}

- (instancetype) initWithParent: (NSProgress *)parent 
                       userInfo: (NSDictionary *)userInfo
{
  [self initWithParent: parent userInfo: userInfo implicitChild: YES];
}

- (instancetype) initWithParent: (NSProgress *)parent 
                       userInfo: (NSDictionary *)userInfo
                  implicitChild: (BOOL) implicitChild
{
  NSProgress *current = tls_current_progress_get();
  if (parent != nil && ![parent isEqual: current])
  {
    [NSException raise: NSInvalidArgumentException
                format: @"The parent of an NSProgress object must be the currentProgress."];
  }

  self = [super init];
  if (self != nil)
    {
      GS_CREATE_INTERNAL(NSProgress);
      internal->_kind = nil;
      internal->_fileOperationKind = nil;
      internal->_fileUrl = nil;
      internal->_estimatedTimeRemaining = nil;
      internal->_fileCompletedCount = nil;
      internal->_fileTotalCount = nil;
      internal->_throughput = nil;

      internal->_totalUnitCount = 0;
      internal->_completedUnitCount = 0;

      /* This pendingUnitCount is used by a child to track the unitCount that is
       * added to the parent, after completion of the child progress. */
      internal->_pendingUnitCountForParent = 0;

      /* A progress may hold a pendingUnitCount that is transferred to a newly
       * created (implicit) child. You can see the hand-off at the end of this
       * method. */
      internal->_pendingUnitCountForChild = 0;
      internal->_userInfo = [userInfo mutableCopy];
      internal->_cancelled = NO;
      internal->_cancellable = YES;
      internal->_indeterminate = NO;
      internal->_finished = NO;
      internal->_localizedDescription = nil;
      internal->_localizedAdditionalDescription = nil;
      internal->_children = nil; // Lazily initialize this set
      internal->_allowImplicitChild = NO;

      // _parent is a weak reference
      objc_storeWeak(&internal->_parent, parent);
      GS_MUTEX_INIT_RECURSIVE(internal->_lock);

      if (implicitChild && current && current->_allowImplicitChild)
      {
        current->_allowImplicitChild = NO;
        [current addChild: self withPendingUnitCount: current->_pendingUnitCountForChild];
      }
    }
  return self;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      RELEASE(internal->_fileOperationKind);
      RELEASE(internal->_kind);
      RELEASE(internal->_estimatedTimeRemaining);
      RELEASE(internal->_fileCompletedCount);
      RELEASE(internal->_fileTotalCount);
      RELEASE(internal->_throughput);
      RELEASE(internal->_userInfo);
      RELEASE(internal->_cancellationHandler);
      RELEASE(internal->_pausingHandler);
      RELEASE(internal->_resumingHandler);
      RELEASE(internal->_localizedDescription);
      RELEASE(internal->_localizedAdditionalDescription);

      objc_destroyWeak(&internal->_parent);
      GS_MUTEX_DESTROY(internal->_lock);

      GS_DESTROY_INTERNAL(NSProgress);
    }
  DEALLOC
}

+ (NSProgress *) discreteProgressWithTotalUnitCount: (int64_t)unitCount
{
  NSProgress *p = [[NSProgress alloc] initWithParent: nil
    userInfo: nil implicitChild: NO];

  p->_totalUnitCount = unitCount;

  return AUTORELEASE(p);
}

+ (NSProgress *) progressWithTotalUnitCount: (int64_t)unitCount
{
  NSProgress *p = [[NSProgress alloc] initWithParent: nil
    userInfo: nil];

  p->_totalUnitCount = unitCount;

  return AUTORELEASE(p);
}

+ (NSProgress *)progressWithTotalUnitCount: (int64_t)unitCount 
  parent: (NSProgress *)parent 
  pendingUnitCount: (int64_t)portionOfParentTotalUnitCount
{
  NSProgress *p = [[NSProgress alloc] initWithParent: parent
    userInfo: nil];

  p->_totalUnitCount = unitCount;
  [parent addChild: p withPendingUnitCount: portionOfParentTotalUnitCount];

  return AUTORELEASE(p);
}

- (void) _setParent: (NSProgress *)p
{
  objc_storeWeak(&internal->_parent, p);
}

// Logic adapted from WinObjC implementation
- (void)_updateCompletedUnitsBy:(int64_t)deltaCompletedUnit
            fractionCompletedBy:(double)deltaFraction
           unitCountForFraction:(int64_t)unitCountForFraction
{
  NSProgress *parent;
  int64_t newCompletedUnitCount;
  double prevFraction;
  double newFraction;
  double adjustedDeltaFraction;

  // This is one big atomic operation. An exclusive lock is required, as reading
  // from _completedUnitCount and _fractionCompleted might be inconsistent over
  // the update period.
  GS_MUTEX_LOCK(_lock);
  prevFraction = _fractionCompleted;

  // If this function is called from a child, deltaFraction needs to be adjusted
  // according to the pending unit count of the child
  // If this function is called from self, unitCountForFraction is equal to _totalUnitCount.
  // Therefore deltaFractionForSelf = deltaFraction.
  adjustedDeltaFraction = deltaFraction * unitCountForFraction / _totalUnitCount;
  newFraction = prevFraction + adjustedDeltaFraction;
  newCompletedUnitCount = _completedUnitCount + deltaCompletedUnit;

  if (prevFraction != newFraction)
  {
    [self willChangeValueForKey:@"fractionCompleted"];
  }
  if (deltaCompletedUnit != 0)
  {
    [self willChangeValueForKey:@"completedUnitCount"];
  }

  // In macOS the finished check is placed before the didChangeValueForKey: @"completedUnitCount" message
  if (newCompletedUnitCount == _totalUnitCount)
  {
    [self willChangeValueForKey:@"finished"];
    _finished = YES;
    [self didChangeValueForKey: @"finished"];
  }

  if (deltaCompletedUnit != 0)
  {
    _completedUnitCount = newCompletedUnitCount;
    [self didChangeValueForKey:@"completedUnitCount"];
  }

  if (prevFraction != newFraction)
  {
    _fractionCompleted = newFraction;
    [self didChangeValueForKey:@"fractionCompleted"];
  }


  if (_fractionCompleted < 0)
  {
      _fractionCompleted = 0;
  }

  parent = objc_loadWeakRetained(&_parent);
  if (parent) {
    if (_fractionCompleted >= 1)
    {
        [parent _updateCompletedUnitsBy: _pendingUnitCountForParent
                     fractionCompletedBy: (1.0f - prevFraction)
                    unitCountForFraction: _pendingUnitCountForParent];
    } else
    {
        [parent _updateCompletedUnitsBy: 0
                     fractionCompletedBy: adjustedDeltaFraction
                    unitCountForFraction: _pendingUnitCountForParent];
    }

    // Remove child from parent
    if (_finished)
    {
      [parent->_children removeObject: self];
    }
    RELEASE(parent);
  }
  GS_MUTEX_UNLOCK(_lock);
}

- (void) becomeCurrentWithPendingUnitCount: (int64_t)unitCount
{
  if ([self isEqual:[NSProgress currentProgress]])
  {
    [NSException raise:NSInvalidArgumentException
                format:@"NSProgress object is already current on this thread %@", [NSThread currentThread]];
  }

  // Push the receiver onto the thread-local current progress stack.
  tls_current_progress_push(self);

  // Signal that the next instantiated progress object should become an implicit
  // child of the receiver.
  _allowImplicitChild = YES;
  _pendingUnitCountForChild = unitCount;
}

- (void) addChild: (NSProgress *)child
  withPendingUnitCount: (int64_t)inUnitCount
{
  // Weakly reference the parent progress from the child progress.
  [child _setParent: self];

  /* Do not add child to set if the progress is already finished */
  if ([child isFinished])
  {
    [self setCompletedUnitCount: [self completedUnitCount] + inUnitCount];
    return;
  }

  // Store the pending unit count in the child object. We will add it to the
  // parent after completion of the child progress.
  child->_pendingUnitCountForParent = inUnitCount;

  GS_MUTEX_LOCK(_lock);

  if (!_children)
  {
    _children = [[NSMutableSet alloc] initWithCapacity: 2];
  }
  // Track the unfinished child progress.
  [_children addObject: child];

  GS_MUTEX_UNLOCK(_lock);
}

- (void) resignCurrent
{
  // Pop the current progress from the thread-local current progress stack.
  tls_current_progress_pop();
}

- (int64_t) totalUnitCount
{
  int64_t count;
  
  GS_MUTEX_LOCK(_lock);
  count = _totalUnitCount;
  GS_MUTEX_UNLOCK(_lock);

  return count;
}

- (void) performAsCurrentWithPendingUnitCount: (int64_t)unitCount 
  usingBlock: (GSProgressPendingUnitCountBlock)work
{
  NSProgress *current = [NSProgress currentProgress];
  CALL_BLOCK_NO_ARGS(work);
  [current setCompletedUnitCount: [current completedUnitCount] + unitCount];
}


- (void) setTotalUnitCount: (int64_t)count
{
  double ratio;

  GS_MUTEX_LOCK(_lock);

  ratio = (double)count / _totalUnitCount;
  _totalUnitCount = count;
  [self _updateCompletedUnitsBy: 0
            fractionCompletedBy: (_fractionCompleted / ratio) - _fractionCompleted
           unitCountForFraction: _totalUnitCount];

  GS_MUTEX_UNLOCK(_lock);
}

- (int64_t) completedUnitCount
{
  int64_t count;

  GS_MUTEX_LOCK(_lock);
  count =  internal->_completedUnitCount;
  GS_MUTEX_UNLOCK(_lock);

  return count;
}

- (void) setCompletedUnitCount: (int64_t)count
{
  // This is one big atomic operation
  GS_MUTEX_LOCK(_lock);

  if (count != _completedUnitCount) {
    int64_t deltaCompletedUnit = count - _completedUnitCount;
    double deltaFraction = deltaCompletedUnit / (double) _totalUnitCount;
    [self _updateCompletedUnitsBy: deltaCompletedUnit
              fractionCompletedBy: deltaFraction
             unitCountForFraction: _totalUnitCount];
  }

  GS_MUTEX_UNLOCK(_lock);
}

- (double) fractionCompleted {
  double fraction;

  GS_MUTEX_LOCK(_lock);
  fraction = _fractionCompleted;
  GS_MUTEX_UNLOCK(_lock);

  return fraction;
}

/**
 * Progress Cancellation
 */

- (BOOL) isCancellable
{
  // _cancellable is atomic
  return internal->_cancellable;
}

- (BOOL) isCancelled
{
  // _cancelled is atomic
  return internal->_cancelled;
}

- (void) cancel
{
  if (!internal->_cancelled)
  {
    GS_MUTEX_LOCK(_lock);
    if (!internal->_cancelled)
    {
      [self willChangeValueForKey: @"cancelled"];
      CALL_BLOCK_NO_ARGS(internal->_cancellationHandler);
      internal->_cancelled = YES;
      [self didChangeValueForKey: @"cancelled"];

      // Cancel all child progresses
      FOR_IN(NSProgress*, child, _children)
        {
          [child cancel];
        }
      END_FOR_IN(children)
    }
    GS_MUTEX_UNLOCK(_lock);
  }
}

- (void) setCancellationHandler: (GSProgressCancellationHandler) handler
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_cancellationHandler, handler);
  GS_MUTEX_UNLOCK(_lock);
}

/**
 * Progress Pausation (Not Implemented)
 */

- (BOOL) isPausable
{
  // Stub
  return NO;
}

- (BOOL) isPaused
{
  // Stub
  return NO;
}

- (void) pause
{
  [self notImplemented: _cmd];
}

- (void) setPausingHandler: (GSProgressPausingHandler) handler
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_pausingHandler, handler);
  GS_MUTEX_UNLOCK(_lock);
}

- (BOOL) isFinished
{
  return internal->_finished;
}

/**
 * Progress Resumption (Not Implemented)
 */

- (void) resume
{
  [self notImplemented: _cmd];
}

- (void) setResumingHandler: (GSProgressResumingHandler) handler
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_resumingHandler, handler);
  GS_MUTEX_UNLOCK(_lock);
}

- (BOOL) isIndeterminate
{
  return NO;
}

- (BOOL) isOld
{
  // Stub
  return NO;
}

- (void) setKind: (NSProgressKind)k
{
  GS_MUTEX_LOCK(_lock);
  ASSIGN(internal->_kind, k);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSProgressKind) kind
{
  NSProgressKind kind;

  GS_MUTEX_LOCK(_lock);
  kind = AUTORELEASE(RETAIN(internal->_kind));
  GS_MUTEX_UNLOCK(_lock);

  return kind;
}

- (void)setUserInfoObject: (id)obj
                   forKey: (NSProgressUserInfoKey)key
{
  GS_MUTEX_LOCK(_lock);
  [internal->_userInfo setObject: obj forKey: key];
  GS_MUTEX_UNLOCK(_lock);
}

- (void) setEstimatedTimeRemaining: (NSNumber *)n
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_estimatedTimeRemaining, n);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSNumber *) estimatedTimeRemaining
{
  NSNumber *number;

  GS_MUTEX_LOCK(_lock);
  number = AUTORELEASE(RETAIN(internal->_estimatedTimeRemaining));
  GS_MUTEX_UNLOCK(_lock);

  return number;
}

- (void) setFileOperationKind: (NSProgressFileOperationKind)k
{
  GS_MUTEX_LOCK(_lock);
  ASSIGN(internal->_fileOperationKind, k);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSProgressFileOperationKind) fileOperationKind
{
  NSProgressFileOperationKind kind;

  GS_MUTEX_LOCK(_lock);
  kind =  AUTORELEASE(RETAIN(internal->_fileOperationKind));
  GS_MUTEX_UNLOCK(_lock);

  return kind;
}

- (void) setFileUrl: (NSURL *)u
{
  GS_MUTEX_LOCK(_lock);
  ASSIGN(internal->_fileUrl, u);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSURL*) fileUrl
{
  NSURL *url;

  GS_MUTEX_LOCK(_lock);
  url = AUTORELEASE(RETAIN(internal->_fileUrl));
  GS_MUTEX_UNLOCK(_lock);

  return url;
}

- (void) setFileCompletedCount: (NSNumber *)n
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_fileCompletedCount, n);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSNumber *) fileCompletedCount
{
  NSNumber *count;

  GS_MUTEX_LOCK(_lock);
  count = AUTORELEASE(RETAIN(internal->_fileCompletedCount));
  GS_MUTEX_UNLOCK(_lock);

  return count;
}

- (void) setFileTotalCount: (NSNumber *)n
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_fileTotalCount, n);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSNumber *) fileTotalCount
{
  NSNumber *count;

  GS_MUTEX_LOCK(_lock);
  count = AUTORELEASE(RETAIN(internal->_fileTotalCount));
  GS_MUTEX_UNLOCK(_lock);

  return count;
}

- (void) setThroughput: (NSNumber *)n
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_throughput, n);
  GS_MUTEX_UNLOCK(_lock);
}

- (NSNumber *) throughput
{
  NSNumber *throughput;

  GS_MUTEX_LOCK(_lock);
  throughput = AUTORELEASE(RETAIN(internal->_throughput));
  GS_MUTEX_UNLOCK(_lock);

  return throughput;
}

- (void) publish
{
  [self notImplemented: _cmd];
}

- (void) unpublish
{
  [self notImplemented: _cmd];
}

+ (id) addSubscriberForFileURL: (NSURL *)url 
         withPublishingHandler: (NSProgressPublishingHandler)publishingHandler
{
  return [self notImplemented: _cmd];
}

+ (void) removeSubscriber: (id)subscriber
{
  [self notImplemented: _cmd];
}

- (void) setLocalizedDescription: (NSString *)localDescription
{
  GS_MUTEX_LOCK(_lock);
  ASSIGNCOPY(internal->_localizedDescription, localDescription);
  GS_MUTEX_UNLOCK(_lock);
}


- (NSString *) localizedDescription
{
  NSString *description;

  GS_MUTEX_LOCK(_lock);
  description = AUTORELEASE(RETAIN(internal->_localizedDescription));
  GS_MUTEX_UNLOCK(_lock);

  return description;
}

- (NSString *) localizedAdditionalDescription
{
  NSString *description;

  GS_MUTEX_LOCK(_lock);
  description = AUTORELEASE(RETAIN(internal->_localizedAdditionalDescription));
  GS_MUTEX_UNLOCK(_lock);

  return description;
}

- (void) setLocalizedAdditionalDescription: (NSString *)localDescription
{
  ASSIGNCOPY(internal->_localizedAdditionalDescription, localDescription);
}

@end


