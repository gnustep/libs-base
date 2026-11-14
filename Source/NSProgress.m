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

#include "GNUstepBase/GSConfig.h"
#include "GNUstepBase/GSVersionMacros.h"
#include "GNUstepBase/GNUstep.h"
#import "GSPThread.h"
#include <math.h>
#include <string.h>

#define	GS_NSProgress_IVARS	 \
  NSProgressKind _kind;  \
  int64_t _totalUnitCount; \
  int64_t _completedUnitCount; \
  int64_t _creditedUnitCount; \
  double _childUnitCount; \
  int64_t _pendingUnitCountForParent; \
  int64_t _pendingUnitCountForChild; \
  GSProgressUserInfo *_userInfo; \
  BOOL _cancelled; \
  BOOL _cancellable; \
  BOOL _paused; \
  BOOL _pausable; \
  BOOL _finished; \
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
  gs_mutex_t _lock; \
  gs_mutex_t _changeLock; \
  NSUInteger _changeDepth; \
  NSMutableArray *_pendingActions; \
  NSThread *_actionsThread; \
  NSMutableArray *_runningActions; \
  id _delegate;

@class GSProgressUserInfo;
@class NSThread;

#define	EXPOSE_NSProgress_IVARS

#import "Foundation/NSException.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSString.h"
#import "Foundation/NSSet.h"
#import	"Foundation/NSProgress.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSAutoreleasePool.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/NSProgress+GNUstepBase.h"

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
static void GS_WINAPI tls_current_progress_destroy(void *value)
{
  NSMutableArray *stack = value;
  RELEASE(stack);
}
static void tls_create_keys(void)
{
  if (!GS_THREAD_KEY_INIT(tls_current_progress_key,
    tls_current_progress_destroy))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to initialise thread keys"];
    }
}

/* Returns an unretained pointer of the current progress */
static NSProgress *tls_current_progress_get(void)
{
  NSMutableArray *stack = GS_THREAD_KEY_GET(tls_current_progress_key);

  if (stack)
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

static inline BOOL
GSProgressIsIndeterminate(int64_t total, int64_t completed)
{
  return (total < 0
    || completed < 0
    || (total == 0 && completed == 0));
}

/* Units added by finished children are already part of childUnits */
static inline double
GSProgressFraction(int64_t total, int64_t completed, int64_t credited,
  double childUnits)
{
  double	fraction;

  if (GSProgressIsIndeterminate(total, completed))
    {
      return 0.0;
    }
  if (total == 0)
    {
      return 1.0;
    }
  fraction = (completed - credited + childUnits) / total;
  return (fraction < 0.0) ? 0.0 : fraction;
}

/* An update that a progress queues for its parent */
@interface GSProgressUpdate : NSObject
{
@public
  NSProgress	*parent;
  int64_t	completedUnitCount;
  double	childUnitCount;
  BOOL		finished;
}
@end

@implementation GSProgressUpdate
- (void) dealloc
{
  RELEASE(parent);
  DEALLOC
}
@end

/* Pausing, resuming or cancelling that a progress queues for its children */
@interface GSProgressPropagation : NSObject
{
@public
  SEL		selector;
  NSArray	*children;
  id		handler;
  id		delegate;
  SEL		delegateSelector;
}
@end

@implementation GSProgressPropagation
- (void) dealloc
{
  RELEASE(children);
  RELEASE(handler);
  RELEASE(delegate);
  DEALLOC
}
@end

/* Calls a handler or sends a message to the delegate of a progress, on the
 * queue running the callbacks of all progresses.
 */
@interface GSProgressCallback : NSOperation
{
@public
  NSProgress	*progress;
  id		handler;
  id		delegate;
  SEL		selector;
}
@end

@implementation GSProgressCallback
- (void) dealloc
{
  RELEASE(progress);
  RELEASE(handler);
  RELEASE(delegate);
  DEALLOC
}

- (void) main
{
  NS_DURING
    {
      if (handler != nil)
	{
	  GSProgressCancellationHandler	block;

	  block = (GSProgressCancellationHandler)handler;
	  CALL_BLOCK_NO_ARGS(block);
	}
      else
	{
	  [delegate performSelector: selector withObject: progress];
	}
    }
  NS_HANDLER
    {
      NSLog(@"Exception in callback of progress %@: %@",
	progress, localException);
    }
  NS_ENDHANDLER
}
@end

static NSOperationQueue	*callbackQueue = nil;
static NSSet	*manuallyNotifiedKeys = nil;

/* The userInfo of a progress, which may be used from any thread.  Like on
 * macOS, it is returned by -userInfo, changes are visible through it, and it
 * cannot be changed through it.  Each change replaces the immutable dictionary
 * it holds, so methods reading several entries use one of them as a snapshot.
 * It notifies observers of its keys itself, without holding its own lock.
 */
@interface GSProgressUserInfo : NSDictionary
{
  NSDictionary	*_dictionary;
  gs_mutex_t	_lock;
}
- (void) _storeObject: (id)anObject forKey: (id)aKey;
@end

@implementation GSProgressUserInfo

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *)key
{
  return NO;
}

- (id) init
{
  return [self initWithObjects: NULL forKeys: NULL count: 0];
}

- (id) initWithObjects: (const id[])objects
	       forKeys: (const id <NSCopying>[])keys
		 count: (NSUInteger)count
{
  _dictionary = [[NSDictionary alloc] initWithObjects: objects
					      forKeys: keys
						count: count];
  GS_MUTEX_INIT_RECURSIVE(_lock);
  return self;
}

- (void) dealloc
{
  RELEASE(_dictionary);
  GS_MUTEX_DESTROY(_lock);
  DEALLOC
}

- (NSDictionary *) _snapshot
{
  NSDictionary	*dictionary;

  GS_MUTEX_LOCK(_lock);
  dictionary = RETAIN(_dictionary);
  GS_MUTEX_UNLOCK(_lock);

  return AUTORELEASE(dictionary);
}

- (id) copyWithZone: (NSZone *)zone
{
  return RETAIN([self _snapshot]);
}

- (id) mutableCopyWithZone: (NSZone *)zone
{
  return [[self _snapshot] mutableCopyWithZone: zone];
}

- (NSUInteger) count
{
  return [[self _snapshot] count];
}

- (id) objectForKey: (id)aKey
{
  return [[self _snapshot] objectForKey: aKey];
}

- (NSString *) descriptionWithLocale: (id)locale indent: (NSUInteger)level
{
  return [[self _snapshot] descriptionWithLocale: locale indent: level];
}

- (BOOL) isEqualToDictionary: (NSDictionary *)other
{
  return [[self _snapshot] isEqualToDictionary: other];
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [[self _snapshot] encodeWithCoder: coder];
}

- (void) enumerateKeysAndObjectsWithOptions: (NSEnumerationOptions)opts
  usingBlock: (GSKeysAndObjectsEnumeratorBlock)aBlock
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  [[self _snapshot] enumerateKeysAndObjectsWithOptions: opts
					    usingBlock: aBlock];
#pragma GCC diagnostic pop
}

- (NSSet *) keysOfEntriesWithOptions: (NSEnumerationOptions)opts
  passingTest: (GSKeysAndObjectsPredicateBlock)aPredicate
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  return [[self _snapshot] keysOfEntriesWithOptions: opts
					passingTest: aPredicate];
#pragma GCC diagnostic pop
}

- (NSEnumerator *) keyEnumerator
{
  return [[self _snapshot] keyEnumerator];
}

- (NSEnumerator *) objectEnumerator
{
  return [[self _snapshot] objectEnumerator];
}

- (NSArray *) allKeys
{
  return [[self _snapshot] allKeys];
}

- (NSArray *) allValues
{
  return [[self _snapshot] allValues];
}

- (void) getObjects: (__unsafe_unretained id[])objects
	    andKeys: (__unsafe_unretained id[])keys
{
  [[self _snapshot] getObjects: objects andKeys: keys];
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  NSArray	*keys;
  NSUInteger	count;

  /* The snapshot of the keys may not fit into one unsigned long, and lasts
   * as long as the autorelease pool of the caller.
   */
  if (state->state == 0)
    {
      keys = [self allKeys];
      memcpy(state->extra, &keys, sizeof(keys));
      state->mutationsPtr = &state->extra[4];
    }
  memcpy(&keys, state->extra, sizeof(keys));
  count = [keys count] - state->state;
  if (count > len)
    {
      count = len;
    }
  [keys getObjects: stackbuf range: NSMakeRange(state->state, count)];
  state->state += count;
  state->itemsPtr = stackbuf;

  return count;
}

/* Sets the object, or removes it if it is nil */
- (void) _storeObject: (id)anObject forKey: (id)aKey
{
  NSMutableDictionary	*changed;
  NSDictionary		*old;

  if (aKey == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to set a userInfo object with a nil key"];
    }
  aKey = AUTORELEASE([aKey copy]);
  [self willChangeValueForKey: aKey];
  GS_MUTEX_LOCK(_lock);
  old = _dictionary;
  changed = [old mutableCopy];
  if (anObject == nil)
    {
      [changed removeObjectForKey: aKey];
    }
  else
    {
      [changed setObject: anObject forKey: aKey];
    }
  _dictionary = [changed copy];
  GS_MUTEX_UNLOCK(_lock);
  RELEASE(changed);
  RELEASE(old);
  [self didChangeValueForKey: aKey];
}

@end

@interface NSProgress (Private)
- (void) _setTotalUnitCount: (int64_t) count;

- (BOOL) _attachToParent: (NSProgress *)parent
	pendingUnitCount: (int64_t)count
		fraction: (double *)fraction
		finished: (BOOL *)finished;
- (void) _removeChild: (NSProgress *)child;

- (BOOL) _takeImplicitChildPendingUnitCount: (int64_t *)count;

- (void) _applyUpdate: (GSProgressUpdate *)update
	    fromChild: (NSProgress *)child;
- (void) _setCompletedUnitCount: (int64_t)count
		       relative: (BOOL)relative;
@end

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
 * We conducted experiments on macOS 15.5 and 26.6.2 to match this
 * implementation with the one present in Foundation.
 *
 * _lock protects the state.  It is never held while calling out, except
 * while -addChild:withPendingUnitCount: takes the lock of the child, so
 * adding two progresses to each other at the same time deadlocks.
 * _changeLock serializes the changes of a progress with their KVO
 * notifications.  Updates of the parent and children are made once the
 * outermost change of the receiver ends, without holding _changeLock.
 * Observers are called while _changeLock is held, so an observer that waits
 * for another thread changing the same progress, or changes other progresses
 * whose observers change it on other threads, deadlocks.  Changing the
 * userInfo dictionary is a change of the progress, but it has its own lock.
 */

@implementation NSProgress

+ (void) initialize
{
  if (self == [NSProgress class])
    {
      /* +initialize is called in a thread-safe manner and only once */
      tls_create_keys();
      callbackQueue = [NSOperationQueue new];
      [callbackQueue setName: @"NSProgress callbacks"];
      manuallyNotifiedKeys = [[NSSet alloc] initWithObjects:
	@"totalUnitCount", @"completedUnitCount", @"cancellable",
	@"pausable", @"kind", @"estimatedTimeRemaining", @"fileOperationKind",
	@"fileUrl", @"fileCompletedCount", @"fileTotalCount", @"throughput",
	@"localizedDescription", @"localizedAdditionalDescription", nil];
    }
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *)key
{
  /* Setters notify while holding _changeLock, as automatic notifications
   * would take the KVO lock before it.  The userInfo keys of the file
   * properties notify their dependent keys instead.  Not implemented with
   * automaticallyNotifiesObserversOf<Key>, which the legacy KVO
   * implementation ignores.
   */
  if ([manuallyNotifiedKeys containsObject: key])
    {
      return NO;
    }
  return [super automaticallyNotifiesObserversForKey: key];
}

+ (NSSet *)keyPathsForValuesAffectingLocalizedDescription
{
  return [NSSet setWithObjects: @"userInfo.NSProgressFileOperationKindKey",
				@"userInfo.NSProgressFileTotalCountKey",
				@"completedUnitCount",
				@"totalUnitCount",
				@"fractionCompleted",
				@"kind",
				nil];
}

+ (NSSet *)keyPathsForValuesAffectingLocalizedAdditionalDescription
{
  return [NSSet setWithObjects:
    @"userInfo.NSProgressEstimatedTimeRemainingKey",
    @"userInfo.NSProgressThroughputKey",
    @"userInfo.NSProgressFileTotalCountKey",
    @"userInfo.NSProgressFileCompletedCountKey",
    @"kind",
    nil];
}

+ (NSProgress *) currentProgress
{
  NSProgress *current = tls_current_progress_get();
  return AUTORELEASE(RETAIN(current));
}

- (instancetype) init
{
  return [self initWithParent: nil userInfo: nil];
}

- (instancetype) initWithParent: (NSProgress *)parent
                       userInfo: (NSDictionary *)userInfo
{
  if (parent != nil && ![parent isEqual: tls_current_progress_get()])
    {
      RELEASE(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"The parent of an NSProgress object must"
	@" be the currentProgress."];
    }

  self = [super init];
  if (self != nil)
    {
      GS_CREATE_INTERNAL(NSProgress);
      internal->_kind = nil;

      internal->_totalUnitCount = 0;
      internal->_completedUnitCount = 0;
      internal->_creditedUnitCount = 0;
      internal->_childUnitCount = 0;

      /* This pendingUnitCount is used by a child to track the unitCount that is
       * added to the parent, after completion of the child progress. */
      internal->_pendingUnitCountForParent = 0;

      /* A progress may hold a pendingUnitCount that is transferred to a newly
       * created (implicit) child. You can see the hand-off at the end of this
       * method. */
      internal->_pendingUnitCountForChild = 0;

      /* A copy, as another thread may be changing a userInfo */
      internal->_userInfo = [[GSProgressUserInfo alloc]
	initWithDictionary: AUTORELEASE([userInfo copy])];

      internal->_cancelled = NO;
      internal->_cancellable = YES;
      internal->_paused = NO;
      internal->_pausable = NO;
      internal->_finished = NO;
      internal->_localizedDescription = nil;
      internal->_localizedAdditionalDescription = nil;
      internal->_children = nil; // Lazily initialize this set
      internal->_allowImplicitChild = NO;
      internal->_changeDepth = 0;
      internal->_pendingActions = nil;

      objc_storeWeak(&internal->_parent, nil);
      GS_MUTEX_INIT_RECURSIVE(internal->_lock);
      GS_MUTEX_INIT_RECURSIVE(internal->_changeLock);

      /* Like on macOS, it is a child only if the parent is passed */
      if (parent != nil)
	{
	  int64_t	pendingUnitCount;

	  if ([parent _takeImplicitChildPendingUnitCount: &pendingUnitCount])
	    {
	      [parent addChild: self withPendingUnitCount: pendingUnitCount];
	    }
	}
    }
  return self;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      RELEASE(internal->_kind);
      RELEASE(internal->_userInfo);
      RELEASE(internal->_cancellationHandler);
      RELEASE(internal->_pausingHandler);
      RELEASE(internal->_resumingHandler);
      RELEASE(internal->_localizedDescription);
      RELEASE(internal->_localizedAdditionalDescription);
      RELEASE(internal->_children);
      RELEASE(internal->_pendingActions);

      objc_destroyWeak(&internal->_parent);
      objc_destroyWeak(&internal->_delegate);
      GS_MUTEX_DESTROY(internal->_lock);
      GS_MUTEX_DESTROY(internal->_changeLock);

      GS_DESTROY_INTERNAL(NSProgress);
    }
  DEALLOC
}

+ (NSProgress *) discreteProgressWithTotalUnitCount: (int64_t)unitCount
{
  NSProgress *p = [[NSProgress alloc] initWithParent: nil userInfo: nil];

  [p _setTotalUnitCount: unitCount];

  return AUTORELEASE(p);
}

+ (NSProgress *) progressWithTotalUnitCount: (int64_t)unitCount
{
  NSProgress *p = [[NSProgress alloc]
    initWithParent: tls_current_progress_get() userInfo: nil];

  [p _setTotalUnitCount: unitCount];

  return AUTORELEASE(p);
}

+ (NSProgress *)progressWithTotalUnitCount: (int64_t)unitCount
  parent: (NSProgress *)parent
  pendingUnitCount: (int64_t)portionOfParentTotalUnitCount
{
  /* Unlike with -initWithParent:userInfo:, the parent need not be current.
   * If it is, its pending unit count is left for its next implicit child.
   */
  NSProgress *p = [[NSProgress alloc] initWithParent: nil userInfo: nil];

  [p _setTotalUnitCount: unitCount];
  [parent addChild: p withPendingUnitCount: portionOfParentTotalUnitCount];

  return AUTORELEASE(p);
}

- (void) _setTotalUnitCount: (int64_t) count
{
  GS_MUTEX_LOCK(internal->_lock);
  internal->_totalUnitCount = count;
  GS_MUTEX_UNLOCK(internal->_lock);
}

/* Attaches the receiver to a parent, whose _lock is held, and returns NO if
 * it already has one.  The receiver's _lock keeps it from finishing
 * meanwhile, so that its pending unit count is added exactly once.
 */
- (BOOL) _attachToParent: (NSProgress *)parent
	pendingUnitCount: (int64_t)count
		fraction: (double *)fraction
		finished: (BOOL *)finished
{
  NSProgress	*oldParent;

  GS_MUTEX_LOCK(internal->_lock);
  oldParent = objc_loadWeakRetained(&internal->_parent);
  if (oldParent == nil)
    {
      objc_storeWeak(&internal->_parent, parent);
      internal->_pendingUnitCountForParent = count;
      *fraction = GSProgressFraction(internal->_totalUnitCount,
	internal->_completedUnitCount, internal->_creditedUnitCount,
	internal->_childUnitCount);
      *finished = internal->_finished;
    }
  GS_MUTEX_UNLOCK(internal->_lock);
  RELEASE(oldParent);

  return (oldParent == nil);
}

- (void) _removeChild: (NSProgress *)child
{
  GS_MUTEX_LOCK(internal->_lock);
  [internal->_children removeObject: child];
  GS_MUTEX_UNLOCK(internal->_lock);
}

- (BOOL) _takeImplicitChildPendingUnitCount: (int64_t *)count
{
  BOOL	allowed;

  GS_MUTEX_LOCK(internal->_lock);
  allowed = internal->_allowImplicitChild;
  if (allowed)
    {
      internal->_allowImplicitChild = NO;
      *count = internal->_pendingUnitCountForChild;
    }
  GS_MUTEX_UNLOCK(internal->_lock);

  return allowed;
}

- (void) _beginChange
{
  GS_MUTEX_LOCK(internal->_changeLock);
  internal->_changeDepth++;
}

/* Must be called during a change */
- (void) _queueAction: (id)action
{
  if (internal->_pendingActions == nil)
    {
      internal->_pendingActions = [[NSMutableArray alloc] initWithCapacity: 1];
    }
  [internal->_pendingActions addObject: action];
}

/* Must be called during a change.  Takes over the retained parent. */
- (void) _queueUpdateForParent: (NSProgress *)parent
		     finished: (BOOL)finished
	       completedUnits: (int64_t)completed
		   childUnits: (double)childUnits
{
  GSProgressUpdate	*update = [internal->_pendingActions lastObject];

  if ([update isKindOfClass: [GSProgressUpdate class]]
    && update->parent == parent)
    {
      RELEASE(parent);
    }
  else
    {
      update = AUTORELEASE([GSProgressUpdate new]);
      update->parent = parent;
      [self _queueAction: update];
    }
  update->completedUnitCount += completed;
  update->childUnitCount += childUnits;
  update->finished = update->finished || finished;
}

/* Sends the message to the delegate asynchronously, like a handler is
 * called.
 */
- (void) _scheduleDelegate: (id)delegate selector: (SEL)selector
{
  if ([delegate respondsToSelector: selector])
    {
      GSProgressCallback	*callback = [GSProgressCallback new];

      callback->progress = RETAIN(self);
      callback->delegate = RETAIN(delegate);
      callback->selector = selector;
      [callbackQueue addOperation: callback];
      RELEASE(callback);
    }
}

/* Calls the handler asynchronously.
 */
- (void) _scheduleHandler: (id)handler
{
  if (handler != nil)
    {
      GSProgressCallback	*callback = [GSProgressCallback new];

      callback->progress = RETAIN(self);
      callback->handler = RETAIN(handler);
      [callbackQueue addOperation: callback];
      RELEASE(callback);
    }
}

- (void) _scheduleCallbacks: (GSProgressPropagation *)propagation
{
  [self _scheduleHandler: propagation->handler];
  [self _scheduleDelegate: propagation->delegate
		 selector: propagation->delegateSelector];
}

/* Sends the message, keeping the first exception it raises in failure */
- (void) _send: (SEL)selector
	    to: (id)target
	  with: (id)argument
       failure: (NSException **)failure
{
  NS_DURING
    [target performSelector: selector withObject: argument];
  NS_HANDLER
    if (*failure == nil)
      {
	*failure = RETAIN(localException);
      }
  NS_ENDHANDLER
}

/* Ends a change.  Once the outermost change of the receiver ends, the queued
 * updates of its parent and children are made.  Updates queued while they
 * are made on this thread are made after them, so that they stay in order.
 */
- (void) _endChange
{
  NSThread		*thread = [NSThread currentThread];
  NSMutableArray	*actions = nil;
  NSException		*failure = nil;
  BOOL			ordered = NO;
  NSUInteger		index;

  internal->_changeDepth--;
  if (internal->_changeDepth == 0 && internal->_pendingActions != nil)
    {
      if (internal->_actionsThread == thread)
	{
	  [internal->_runningActions
	    addObjectsFromArray: internal->_pendingActions];
	  DESTROY(internal->_pendingActions);
	}
      else
	{
	  actions = internal->_pendingActions;
	  internal->_pendingActions = nil;
	  if (internal->_actionsThread == nil)
	    {
	      internal->_actionsThread = thread;
	      internal->_runningActions = actions;
	      ordered = YES;
	    }
	}
    }
  GS_MUTEX_UNLOCK(internal->_changeLock);

  if (actions == nil)
    {
      return;
    }

  /* The parent may hold the last reference to the receiver */
  RETAIN(self);
  for (index = 0; index < [actions count]; index++)
    {
      id	action = [actions objectAtIndex: index];

      if ([action isKindOfClass: [GSProgressUpdate class]])
	{
	  GSProgressUpdate	*update = action;

	  NS_DURING
	    [update->parent _applyUpdate: update fromChild: self];
	  NS_HANDLER
	    if (failure == nil)
	      {
		failure = RETAIN(localException);
	      }
	  NS_ENDHANDLER
	}
      else
	{
	  GSProgressPropagation	*propagation = action;
	  NSArray		*children = propagation->children;

	  [self _send: @selector(_scheduleCallbacks:)
		   to: self
		 with: propagation
	      failure: &failure];
	  GS_FOR_IN(NSProgress*, child, children)
	    {
	      if (![child isFinished])
		{
		  [self _send: propagation->selector
			   to: child
			 with: nil
		      failure: &failure];
		}
	    }
	  GS_END_FOR(children)
	}

      /* Only this thread appends to the actions */
      if (ordered && index + 1 == [actions count])
	{
	  GS_MUTEX_LOCK(internal->_changeLock);
	  internal->_actionsThread = nil;
	  internal->_runningActions = nil;
	  GS_MUTEX_UNLOCK(internal->_changeLock);
	}
    }
  RELEASE(actions);
  RELEASE(self);
  if (failure != nil)
    {
      [AUTORELEASE(failure) raise];
    }
}

/* Changes the unit counts, notifying KVO observers, and queues the update of
 * the parent.  Must be called during a change.
 */
- (void) _changeTotalUnitCount: (int64_t)newTotal
		      setTotal: (BOOL)setTotal
	    completedUnitCount: (int64_t)completed
		      relative: (BOOL)relative
		    creditedBy: (int64_t)deltaCredited
		  childUnitsBy: (double)deltaChildUnits
{
  NSProgress	*parent;
  int64_t	oldTotal;
  int64_t	oldCompleted;
  int64_t	newCompleted;
  int64_t	pending;
  double	oldFraction;
  double	newFraction;
  BOOL		wasIndeterminate;
  BOOL		nowIndeterminate;
  BOOL		wasFinished;
  BOOL		nowFinished;

  GS_MUTEX_LOCK(internal->_lock);
  oldTotal = internal->_totalUnitCount;
  oldCompleted = internal->_completedUnitCount;
  newCompleted = relative ? oldCompleted + completed : completed;
  oldFraction = GSProgressFraction(oldTotal, oldCompleted,
    internal->_creditedUnitCount, internal->_childUnitCount);
  newFraction = GSProgressFraction(newTotal, newCompleted,
    internal->_creditedUnitCount + deltaCredited,
    internal->_childUnitCount + ((newTotal > 0) ? deltaChildUnits : 0));
  wasFinished = internal->_finished;
  GS_MUTEX_UNLOCK(internal->_lock);

  wasIndeterminate = GSProgressIsIndeterminate(oldTotal, oldCompleted);
  nowIndeterminate = GSProgressIsIndeterminate(newTotal, newCompleted);
  nowFinished = (!nowIndeterminate && newCompleted >= newTotal);

  if (oldFraction != newFraction)
    {
      [self willChangeValueForKey: @"fractionCompleted"];
    }
  if (oldTotal != newTotal)
    {
      [self willChangeValueForKey: @"totalUnitCount"];
    }
  if (oldCompleted != newCompleted)
    {
      [self willChangeValueForKey: @"completedUnitCount"];
    }
  if (wasIndeterminate != nowIndeterminate)
    {
      [self willChangeValueForKey: @"indeterminate"];
    }
  if (wasFinished != nowFinished)
    {
      [self willChangeValueForKey: @"finished"];
    }

  /* Recomputed from the current state, which an observer called before the
   * change may have changed meanwhile.
   */
  GS_MUTEX_LOCK(internal->_lock);
  {
    int64_t	total = setTotal ? newTotal : internal->_totalUnitCount;
    int64_t	current = internal->_completedUnitCount;
    int64_t	written = relative ? current + completed : completed;
    double	before = GSProgressFraction(internal->_totalUnitCount, current,
      internal->_creditedUnitCount, internal->_childUnitCount);
    BOOL	writtenFinished;
    BOOL	finished;
    double	childUnits;

    internal->_totalUnitCount = total;
    internal->_completedUnitCount = written;
    internal->_creditedUnitCount += deltaCredited;
    /* Like on macOS, progress of children is lost while there is no total */
    if (total > 0)
      {
	internal->_childUnitCount += deltaChildUnits;
      }
    writtenFinished = (!GSProgressIsIndeterminate(total, written)
      && written >= total);
    finished = (writtenFinished && !internal->_finished);
    internal->_finished = writtenFinished;
    parent = objc_loadWeakRetained(&internal->_parent);
    pending = internal->_pendingUnitCountForParent;
    childUnits = (GSProgressFraction(total, written,
      internal->_creditedUnitCount, internal->_childUnitCount) - before)
      * pending;
    GS_MUTEX_UNLOCK(internal->_lock);

    /* Like on macOS, the pending unit count is added whenever the receiver
     * finishes, and a finished child is no longer paused or cancelled with
     * its parent.
     */
    if (parent != nil && (finished || childUnits != 0))
      {
	[self _queueUpdateForParent: parent
			   finished: finished
		     completedUnits: finished ? pending : 0
			 childUnits: childUnits];
      }
    else
      {
	RELEASE(parent);
      }
  }

  /* The order of notifications matches macOS */
  if (wasFinished != nowFinished)
    {
      [self didChangeValueForKey: @"finished"];
    }
  if (oldCompleted != newCompleted)
    {
      [self didChangeValueForKey: @"completedUnitCount"];
    }
  if (oldTotal != newTotal)
    {
      [self didChangeValueForKey: @"totalUnitCount"];
    }
  if (oldFraction != newFraction)
    {
      [self didChangeValueForKey: @"fractionCompleted"];
    }
  if (wasIndeterminate != nowIndeterminate)
    {
      [self didChangeValueForKey: @"indeterminate"];
    }
}

- (void) _changeCompletedBy: (int64_t)deltaCompleted
		 creditedBy: (int64_t)deltaCredited
	       childUnitsBy: (double)deltaChildUnits
{
  int64_t	total;

  GS_MUTEX_LOCK(internal->_lock);
  total = internal->_totalUnitCount;
  GS_MUTEX_UNLOCK(internal->_lock);
  [self _changeTotalUnitCount: total
		     setTotal: NO
	   completedUnitCount: deltaCompleted
		     relative: YES
		   creditedBy: deltaCredited
		 childUnitsBy: deltaChildUnits];
}

- (void) _applyUpdate: (GSProgressUpdate *)update
	    fromChild: (NSProgress *)child
{
  if (update->finished)
    {
      [self _removeChild: child];
    }

  [self _beginChange];
  NS_DURING
    [self _changeCompletedBy: update->completedUnitCount
		  creditedBy: update->completedUnitCount
		childUnitsBy: update->childUnitCount];
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

- (void) _setCompletedUnitCount: (int64_t)count
		       relative: (BOOL)relative
{
  int64_t	delta;
  int64_t	total;

  [self _beginChange];
  NS_DURING
    GS_MUTEX_LOCK(internal->_lock);
    delta = relative ? count : count - internal->_completedUnitCount;
    total = internal->_totalUnitCount;
    GS_MUTEX_UNLOCK(internal->_lock);
    if (delta != 0)
      {
	[self _changeTotalUnitCount: total
			   setTotal: NO
		 completedUnitCount: count
			   relative: relative
			 creditedBy: 0
		       childUnitsBy: 0];
      }
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

- (void) becomeCurrentWithPendingUnitCount: (int64_t)unitCount
{
  if ([self isEqual:[NSProgress currentProgress]])
    {
      [NSException raise: NSInvalidArgumentException
	format: @"NSProgress object is already current on this thread %@",
	  [NSThread currentThread]];
    }

  // Push the receiver onto the thread-local current progress stack.
  tls_current_progress_push(self);

  // Signal that the next instantiated progress object should become an implicit
  // child of the receiver.
  GS_MUTEX_LOCK(internal->_lock);
  internal->_allowImplicitChild = YES;
  internal->_pendingUnitCountForChild = unitCount;
  GS_MUTEX_UNLOCK(internal->_lock);
}

- (void) addChild: (NSProgress *)child
  withPendingUnitCount: (int64_t)inUnitCount
{
  NSException	*failure = nil;
  BOOL		attached;
  BOOL		finished = NO;
  BOOL		cancelled;
  BOOL		paused;
  double	fraction = 0.0;

  if (child == nil)
    {
      return;
    }

  GS_MUTEX_LOCK(internal->_lock);
  attached = [child _attachToParent: self
		   pendingUnitCount: inUnitCount
			   fraction: &fraction
			   finished: &finished];
  /* A finished child is not tracked, its pending unit count is added below */
  if (attached && !finished)
    {
      if (!internal->_children)
	{
	  internal->_children = [[NSMutableSet alloc] initWithCapacity: 2];
	}
      [internal->_children addObject: child];
    }
  cancelled = internal->_cancelled;
  paused = internal->_paused;
  GS_MUTEX_UNLOCK(internal->_lock);

  if (!attached)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"NSProgress %p was already the child of another"
	@" progress", child];
    }

  if (finished || fraction != 0.0)
    {
      [self _beginChange];
      NS_DURING
	[self _changeCompletedBy: finished ? inUnitCount : 0
		      creditedBy: finished ? inUnitCount : 0
		    childUnitsBy: fraction * inUnitCount];
      NS_HANDLER
	failure = RETAIN(localException);
      NS_ENDHANDLER
      [self _endChange];
    }

  /* A child added to a cancelled or paused progress gets cancelled or
   * paused, even if it is already finished.
   */
  if (cancelled)
    {
      [self _send: @selector(cancel) to: child with: nil failure: &failure];
    }
  if (paused)
    {
      [self _send: @selector(pause) to: child with: nil failure: &failure];
    }
  if (failure != nil)
    {
      [AUTORELEASE(failure) raise];
    }
}

- (void) resignCurrent
{
  BOOL		noChild;
  int64_t	pending;

  if (tls_current_progress_get() != self)
    {
      [NSException raise: NSInvalidArgumentException
	format: @"NSProgress was not the current progress on this thread %@",
	  [NSThread currentThread]];
    }

  // Pop the current progress from the thread-local current progress stack.
  tls_current_progress_pop();

  /* Like on macOS, the pending unit count is completed if no child used it */
  GS_MUTEX_LOCK(internal->_lock);
  noChild = internal->_allowImplicitChild;
  pending = internal->_pendingUnitCountForChild;
  internal->_allowImplicitChild = NO;
  GS_MUTEX_UNLOCK(internal->_lock);
  if (noChild)
    {
      [self _setCompletedUnitCount: pending relative: YES];
    }
}

- (int64_t) totalUnitCount
{
  int64_t count;

  GS_MUTEX_LOCK(internal->_lock);
  count = internal->_totalUnitCount;
  GS_MUTEX_UNLOCK(internal->_lock);

  return count;
}

- (void) performAsCurrentWithPendingUnitCount: (int64_t)unitCount
  usingBlock: (GSProgressPendingUnitCountBlock)work
{
  [self becomeCurrentWithPendingUnitCount: unitCount];
  NS_DURING
    CALL_BLOCK_NO_ARGS(work);
  NS_HANDLER
    [self resignCurrent];
    [localException raise];
  NS_ENDHANDLER
  [self resignCurrent];
}

- (void) setTotalUnitCount: (int64_t)count
{
  [self _beginChange];
  NS_DURING
    [self _changeTotalUnitCount: count
		       setTotal: YES
	     completedUnitCount: 0
		       relative: YES
		     creditedBy: 0
		   childUnitsBy: 0];
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

- (int64_t) completedUnitCount
{
  int64_t count;

  GS_MUTEX_LOCK(internal->_lock);
  count =  internal->_completedUnitCount;
  GS_MUTEX_UNLOCK(internal->_lock);

  return count;
}

- (void) setCompletedUnitCount: (int64_t)count
{
  [self _setCompletedUnitCount: count relative: NO];
}

- (double) fractionCompleted
{
  double fraction;

  GS_MUTEX_LOCK(internal->_lock);
  fraction = GSProgressFraction(internal->_totalUnitCount,
    internal->_completedUnitCount, internal->_creditedUnitCount,
    internal->_childUnitCount);
  GS_MUTEX_UNLOCK(internal->_lock);

  return fraction;
}

/* Sets the flag, notifying KVO observers only if it changes */
- (void) _changeFlag: (BOOL *)flag
	     toValue: (BOOL)value
	      forKey: (NSString *)key
{
  BOOL	changed;

  [self _beginChange];
  NS_DURING
    GS_MUTEX_LOCK(internal->_lock);
    changed = (*flag != value);
    GS_MUTEX_UNLOCK(internal->_lock);
    if (changed)
      {
	[self willChangeValueForKey: key];
	GS_MUTEX_LOCK(internal->_lock);
	*flag = value;
	GS_MUTEX_UNLOCK(internal->_lock);
	[self didChangeValueForKey: key];
      }
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

/* Sets the object, notifying KVO observers only if it changes */
- (void) _assign: (id)value
	      to: (id *)slot
	    copy: (BOOL)copy
	  forKey: (NSString *)key
{
  id	old;

  [self _beginChange];
  NS_DURING
    GS_MUTEX_LOCK(internal->_lock);
    old = *slot;
    GS_MUTEX_UNLOCK(internal->_lock);
    if (value != old && ![value isEqual: old])
      {
	[self willChangeValueForKey: key];
	value = copy ? [value copy] : RETAIN(value);
	GS_MUTEX_LOCK(internal->_lock);
	old = *slot;
	*slot = value;
	GS_MUTEX_UNLOCK(internal->_lock);
	RELEASE(old);
	[self didChangeValueForKey: key];
      }
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

/* Shared implementation of -cancel, -pause and -resume.  The flag is set
 * together with taking the handler and children, so that a handler or child
 * added meanwhile is called once.
 */
- (void) _changeFlag: (BOOL *)flag
	     toValue: (BOOL)value
	      forKey: (NSString *)key
	     handler: (id *)handlerSlot
    delegateSelector: (SEL)delegateSelector
       childSelector: (SEL)childSelector
{
  GSProgressPropagation	*propagation;
  BOOL			changed;

  [self _beginChange];
  NS_DURING
    GS_MUTEX_LOCK(internal->_lock);
    changed = (*flag != value);
    GS_MUTEX_UNLOCK(internal->_lock);
    if (changed)
      {
	[self willChangeValueForKey: key];
      }

    propagation = AUTORELEASE([GSProgressPropagation new]);
    propagation->selector = childSelector;
    propagation->delegateSelector = delegateSelector;
    GS_MUTEX_LOCK(internal->_lock);
    *flag = value;
    propagation->handler = RETAIN(*handlerSlot);
    propagation->delegate = objc_loadWeakRetained(&internal->_delegate);
    propagation->children = [internal->_children allObjects];
    RETAIN(propagation->children);
    GS_MUTEX_UNLOCK(internal->_lock);
    [self _queueAction: propagation];

    if (changed)
      {
	[self didChangeValueForKey: key];
      }
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

/* Replaces a handler, and returns whether the flag is set */
- (BOOL) _setHandler: (id)handler
		  to: (id *)handlerSlot
	     forFlag: (BOOL *)flag
{
  id	old;
  BOOL	set;

  handler = [handler copy];
  GS_MUTEX_LOCK(internal->_lock);
  old = *handlerSlot;
  *handlerSlot = handler;
  set = (flag != NULL) && *flag;
  GS_MUTEX_UNLOCK(internal->_lock);
  RELEASE(old);

  return set;
}

/**
 * Progress Cancellation
 */

- (BOOL) isCancellable
{
  BOOL cancellable;

  GS_MUTEX_LOCK(internal->_lock);
  cancellable =  internal->_cancellable;
  GS_MUTEX_UNLOCK(internal->_lock);

  return cancellable;
}

- (void) setCancellable: (BOOL) cancellable
{
  [self _changeFlag: &internal->_cancellable
	    toValue: cancellable
	     forKey: @"cancellable"];
}

- (BOOL) isCancelled
{
  BOOL cancelled;

  GS_MUTEX_LOCK(internal->_lock);
  cancelled = internal->_cancelled;
  GS_MUTEX_UNLOCK(internal->_lock);

  return cancelled;
}

- (void) cancel
{
  /*
   * You are still able to cancel a progress despite it being marked as
   * non-cancellable. We therefore do not exit early when cancellable is set to
   * false. This was tested on macOS 26.0 (25A354).
   */
  [self _changeFlag: &internal->_cancelled
	    toValue: YES
	     forKey: @"cancelled"
	    handler: (id *)&internal->_cancellationHandler
   delegateSelector: @selector(progressCancelled:)
      childSelector: @selector(cancel)];
}

- (GSProgressCancellationHandler) cancellationHandler
{
  id	handler;

  GS_MUTEX_LOCK(internal->_lock);
  handler = [(id)internal->_cancellationHandler copy];
  GS_MUTEX_UNLOCK(internal->_lock);

  return (GSProgressCancellationHandler)AUTORELEASE(handler);
}

- (void) setCancellationHandler: (GSProgressCancellationHandler) handler
{
  // The handler is also called if the progress is already cancelled.
  if ([self _setHandler: (id)handler
		     to: (id *)&internal->_cancellationHandler
		forFlag: &internal->_cancelled])
    {
      [self _scheduleHandler: (id)handler];
    }
}

/**
 * Progress Pausation
 */

- (BOOL) isPausable
{
  BOOL pausable;

  GS_MUTEX_LOCK(internal->_lock);
  pausable = internal->_pausable;
  GS_MUTEX_UNLOCK(internal->_lock);

  return pausable;
}

- (void) setPausable: (BOOL) pausable
{
  [self _changeFlag: &internal->_pausable
	    toValue: pausable
	     forKey: @"pausable"];
}

- (BOOL) isPaused
{
  BOOL paused;

  GS_MUTEX_LOCK(internal->_lock);
  paused = internal->_paused;
  GS_MUTEX_UNLOCK(internal->_lock);

  return paused;
}

- (void) pause
{
  /*
   * Like -cancel, this pauses a progress even if it is not marked as
   * pausable.
   */
  [self _changeFlag: &internal->_paused
	    toValue: YES
	     forKey: @"paused"
	    handler: (id *)&internal->_pausingHandler
   delegateSelector: @selector(progressPaused:)
      childSelector: @selector(pause)];
}

- (GSProgressPausingHandler) pausingHandler
{
  id	handler;

  GS_MUTEX_LOCK(internal->_lock);
  handler = [(id)internal->_pausingHandler copy];
  GS_MUTEX_UNLOCK(internal->_lock);

  return (GSProgressPausingHandler)AUTORELEASE(handler);
}

- (void) setPausingHandler: (GSProgressPausingHandler) handler
{
  // The handler is also called if the progress is already paused.
  if ([self _setHandler: (id)handler
		     to: (id *)&internal->_pausingHandler
		forFlag: &internal->_paused])
    {
      [self _scheduleHandler: (id)handler];
    }
}

- (BOOL) isFinished
{
  BOOL finished;

  GS_MUTEX_LOCK(internal->_lock);
  finished = internal->_finished;
  GS_MUTEX_UNLOCK(internal->_lock);

  return finished;
}

/**
 * Progress Resumption
 */

- (void) resume
{
  [self _changeFlag: &internal->_paused
	    toValue: NO
	     forKey: @"paused"
	    handler: (id *)&internal->_resumingHandler
   delegateSelector: @selector(progressResumed:)
      childSelector: @selector(resume)];
}

- (GSProgressResumingHandler) resumingHandler
{
  id	handler;

  GS_MUTEX_LOCK(internal->_lock);
  handler = [(id)internal->_resumingHandler copy];
  GS_MUTEX_UNLOCK(internal->_lock);

  return (GSProgressResumingHandler)AUTORELEASE(handler);
}

- (void) setResumingHandler: (GSProgressResumingHandler) handler
{
  [self _setHandler: (id)handler
		 to: (id *)&internal->_resumingHandler
	    forFlag: NULL];
}

- (id<GSProgressDelegate>) delegate
{
  return objc_loadWeak(&internal->_delegate);
}

- (void) setDelegate: (id<GSProgressDelegate>)delegate
{
  id	handlers[3];
  BOOL	cancelled;
  BOOL	paused;

  /* Like with the handlers it replaces, the delegate is sent a message if
   * the receiver is already cancelled or paused.
   */
  GS_MUTEX_LOCK(internal->_lock);
  objc_storeWeak(&internal->_delegate, delegate);
  handlers[0] = (id)internal->_cancellationHandler;
  handlers[1] = (id)internal->_pausingHandler;
  handlers[2] = (id)internal->_resumingHandler;
  internal->_cancellationHandler = NULL;
  internal->_pausingHandler = NULL;
  internal->_resumingHandler = NULL;
  cancelled = internal->_cancelled;
  paused = internal->_paused;
  GS_MUTEX_UNLOCK(internal->_lock);
  RELEASE(handlers[0]);
  RELEASE(handlers[1]);
  RELEASE(handlers[2]);

  if (cancelled)
    {
      [self _scheduleDelegate: delegate
		     selector: @selector(progressCancelled:)];
    }
  if (paused)
    {
      [self _scheduleDelegate: delegate
		     selector: @selector(progressPaused:)];
    }
}

- (BOOL) isIndeterminate
{
  BOOL indeterminate;

  GS_MUTEX_LOCK(internal->_lock);
  indeterminate = GSProgressIsIndeterminate(internal->_totalUnitCount,
                                            internal->_completedUnitCount);
  GS_MUTEX_UNLOCK(internal->_lock);

  return indeterminate;
}

- (BOOL) isOld
{
  // Stub
  return NO;
}

- (void) setKind: (NSProgressKind)k
{
  [self _assign: k
	    to: (id *)&internal->_kind
	  copy: NO
	forKey: @"kind"];
}

- (NSProgressKind) kind
{
  NSProgressKind kind;

  GS_MUTEX_LOCK(internal->_lock);
  kind = AUTORELEASE(RETAIN(internal->_kind));
  GS_MUTEX_UNLOCK(internal->_lock);

  return kind;
}

- (void)setUserInfoObject: (id)obj
                   forKey: (NSProgressUserInfoKey)key
{
  [self _beginChange];
  NS_DURING
    [internal->_userInfo _storeObject: obj forKey: key];
  NS_HANDLER
    [self _endChange];
    [localException raise];
  NS_ENDHANDLER
  [self _endChange];
}

- (NSDictionary *) userInfo
{
  return AUTORELEASE(RETAIN(internal->_userInfo));
}

/* Like on macOS, the file related properties are stored in userInfo */

- (void) setEstimatedTimeRemaining: (NSNumber *)n
{
  [self setUserInfoObject: n forKey: @"NSProgressEstimatedTimeRemainingKey"];
}

- (NSNumber *) estimatedTimeRemaining
{
  return [internal->_userInfo objectForKey:
    @"NSProgressEstimatedTimeRemainingKey"];
}

- (void) setFileOperationKind: (NSProgressFileOperationKind)k
{
  [self setUserInfoObject: k forKey: @"NSProgressFileOperationKindKey"];
}

- (NSProgressFileOperationKind) fileOperationKind
{
  return [internal->_userInfo objectForKey: @"NSProgressFileOperationKindKey"];
}

- (void) setFileUrl: (NSURL *)u
{
  [self setUserInfoObject: u forKey: @"NSProgressFileURLKey"];
}

- (NSURL*) fileUrl
{
  return [internal->_userInfo objectForKey: @"NSProgressFileURLKey"];
}

- (void) setFileCompletedCount: (NSNumber *)n
{
  [self setUserInfoObject: n forKey: @"NSProgressFileCompletedCountKey"];
}

- (NSNumber *) fileCompletedCount
{
  return [internal->_userInfo
    objectForKey: @"NSProgressFileCompletedCountKey"];
}

- (void) setFileTotalCount: (NSNumber *)n
{
  [self setUserInfoObject: n forKey: @"NSProgressFileTotalCountKey"];
}

- (NSNumber *) fileTotalCount
{
  return [internal->_userInfo objectForKey: @"NSProgressFileTotalCountKey"];
}

- (void) setThroughput: (NSNumber *)n
{
  [self setUserInfoObject: n forKey: @"NSProgressThroughputKey"];
}

- (NSNumber *) throughput
{
  return [internal->_userInfo objectForKey: @"NSProgressThroughputKey"];
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
  [self _assign: localDescription
	    to: (id *)&internal->_localizedDescription
	  copy: YES
	forKey: @"localizedDescription"];
}


- (NSString *) localizedDescription
{
  NSString *description;

  GS_MUTEX_LOCK(internal->_lock);
  description = AUTORELEASE(RETAIN(internal->_localizedDescription));
  GS_MUTEX_UNLOCK(internal->_lock);

  return description;
}

- (NSString *) localizedAdditionalDescription
{
  NSString *description;

  GS_MUTEX_LOCK(internal->_lock);
  description = AUTORELEASE(RETAIN(internal->_localizedAdditionalDescription));
  GS_MUTEX_UNLOCK(internal->_lock);

  return description;
}

- (void) setLocalizedAdditionalDescription: (NSString *)localDescription
{
  [self _assign: localDescription
	    to: (id *)&internal->_localizedAdditionalDescription
	  copy: YES
	forKey: @"localizedAdditionalDescription"];
}

@end
