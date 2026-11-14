/**Definition of class NSProgress
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

#ifndef _NSProgress_h_GNUSTEP_BASE_INCLUDE
#define _NSProgress_h_GNUSTEP_BASE_INCLUDE

#import	<GNUstepBase/GSVersionMacros.h>
#import	<Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <GNUstepBase/GSBlocks.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class GS_GENERIC_CLASS(NSArray, ElementT);
@class GS_GENERIC_CLASS(NSDictionary, KeyT, ValT);
@class NSNumber, NSURL, NSProgress;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)

typedef NSString* NSProgressKind;
typedef NSString* NSProgressUserInfoKey;
typedef NSString* NSProgressFileOperationKind;

DEFINE_BLOCK_TYPE_NO_ARGS(GSProgressCancellationHandler, void);
DEFINE_BLOCK_TYPE_NO_ARGS(GSProgressPausingHandler, void);
DEFINE_BLOCK_TYPE(NSProgressPublishingHandler, void, NSProgress*);
DEFINE_BLOCK_TYPE_NO_ARGS(NSProgressUnpublishingHandler, void);
DEFINE_BLOCK_TYPE_NO_ARGS(GSProgressPendingUnitCountBlock, void);
DEFINE_BLOCK_TYPE_NO_ARGS(GSProgressResumingHandler, void);

/**
 * A progress object tracks an amount of work that is yet to be completed.
 * Work is tracked in units. A progress is finished when the completed
 * number of unit work is equal to the total number of unit work.
 *
 * Progress objects can be arranged in a tree formation. Children of a parent
 * progress continuosly report their progress and update the parents
 * fractionCompleted property.
 * When a child is added to a parent progress, a pending unit count is
 * specified. This count is added to the parent after completion of the child.
 *
 * There are two mechanisms to add a progress as a child to another progress
 * object:
 * One can explicitly add a child with -addChild:withPendingUnitCount:.
 * There is also a way to implicitly add newly instantiated progress object
 * as a child to an existing progress.
 *
 * For this, we first need to define how the "currentProgress" API works:
 * Every thread has a thread-specific current progress stack. The top-most
 * element on this stack can be accessed by +currentProgress class method.
 * By sending -becomeCurrentWithPendingUnitCount: to a progress, the progress
 * object is pushed onto the stack and becomes the new current progress.
 *
 * The next progress object instantiated (excluding creation with
 * discreteProgressWithTotalUnitCount:) becomes a child of this current
 * progress.
 * This is the second mechanism to implicitly add a child to a progress object.
 */

GS_EXPORT_CLASS
@interface NSProgress : NSObject
{
#if	GS_EXPOSE(NSProgress)
#endif
#if     GS_NONFRAGILE
#  if	defined(GS_NSProgress_IVARS)
@public
GS_NSProgress_IVARS;
#  endif
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

/**
 * Instantiate a new progress object by optionally supplying a parent and user
 * information dictionary.
 *
 * The parent progress must either be the current progress object of the current
 * thread, or nil.  With the current progress, the new progress becomes its
 * implicit child if it expects one.  With nil, it has no parent.
 */
- (instancetype) initWithParent: (NSProgress *)parent
		       userInfo: (NSDictionary *)userInfo;

/**
 * Creates a progress object for a total number of work units. This object will
 * not be part of an existing progress tree.
 *
 * This object cannot implicitly become a child of the current progress, even if
 * the current progress expects the next created progress object to be an
 * implicit child.
 */
+ (NSProgress *) discreteProgressWithTotalUnitCount: (int64_t)unitCount;

/**
 * Creates a progress object for a total number of work units.
 *
 * Note that this object may become an implicit child of the thread-local
 * current progress object, if requested by the current progress object.
 */
+ (NSProgress *) progressWithTotalUnitCount: (int64_t)unitCount;

/**
 * Creates a progress object for a total number of work units. This object is
 * then added as a child to the parent with a pending number of units.
 */
+ (NSProgress *) progressWithTotalUnitCount: (int64_t)unitCount
  parent: (NSProgress *)parent
  pendingUnitCount: (int64_t)portionOfParentTotalUnitCount;

/**
 * Retrieve the first progress object that is on the thread-local current
 * progress stack.
 */
+ (NSProgress *) currentProgress;

/**
 * Push the receiver to the thread-local current progress stack.
 * The first object on the stack can be accessed with
 * +[NSProgress currentProgress].
 *
 * Upon initialisation of the next progress object, the newly created object
 * becomes a child of receiver. Note that this only holds for the first object
 * created. If the child progress completes, the pending unit count is added to
 * the receiver.
 *
 * The pending unit count represents the portion of work to perform in
 * relation to the total number of units of work, which is the value of
 * the receivers totalUnitCount property. The pending units of work should
 * be less than or equal to the total units of work of the receiver.
 * Ensure that the total number is not exceeded.
 *
 * Calls to this method must be matched by -[NSProgress resignCurrent].
 */
- (void) becomeCurrentWithPendingUnitCount: (int64_t)unitCount;

/**
 * Receiver resigns the role of the current progress. The receiver is popped
 * from the thread-local current progress stack.  If no child was created
 * since the receiver became current, the pending unit count is added to the
 * completed unit count.
 *
 * If the receiver is not the current progress, an exception will be thrown.
 */
- (void) resignCurrent;

/**
 * Adds the progress to the receiver as a child.  The pending unit count is
 * added to the receiver whenever the child progress finishes.  Raises an
 * NSInvalidArgumentException if the child already has a parent.
 *
 * The pending unit count should not exceed the receivers total unit count.
 * However, this is not enforced in Apple's NSProgress implementation.
 */
- (void) addChild: (NSProgress *)child
  withPendingUnitCount: (int64_t)inUnitCount;

/**
 * Returns the total number of unit work to be tracked by the receiver.
 */
- (int64_t) totalUnitCount;

/**
 * Sets the total nubmer of unit work to be tracked by the receiver.
 */
- (void) setTotalUnitCount: (int64_t)unitCount;

/**
 * Returns the number of unit work already completed.
 */
- (int64_t) completedUnitCount;

/**
 * Updates the number of unit work already completed. Monotonicity of this
 * count is not enforced.
 */
- (void) setCompletedUnitCount: (int64_t)unitCount;

/**
 * Returns the localized description string.
 */
- (NSString *) localizedDescription;

/**
 * Sets the localized description string.
 */
- (void) setLocalizedDescription: (NSString *)desc;

/**
 * Returns the additional localized description string.
 */
- (NSString *) localizedAdditionalDescription;

/**
 * Sets the additional localized description string.
 */
- (void) setLocalizedAdditionalDescription: (NSString *)addDesc;

/**
 * Provides a fraction of completed work, including work done by child
 * progresses. Different from the completedUnitCount property, this property is
 * continuously updated, tracking the progress of children as well.
 */
- (double) fractionCompleted;

/**
 * Indicates whether the underlying work whose progress is being tracked
 * can be cancelled.  This has no effect on whether the receiver can be
 * cancelled.  By default, a progress instance assumes that the
 * work is cancellable but not pausable.
 */
- (BOOL) isCancellable;
- (void) setCancellable: (BOOL) cancellable;

/**
 * Returns YES if the reciever has been cancelled.
 */
- (BOOL) isCancelled;

/**
 * Cancels tracking by the receiver (so subsequent calls to -isCancelled will
 * return YES), and also cancels unfinished children.
 * If a cancellation handler is set, it is called asynchronously, even if the
 * receiver was already cancelled.
 */
- (void) cancel;

/**
 * Returns the cancellation handler.
 */
- (GSProgressCancellationHandler) cancellationHandler
  GS_NON_PORTABLE(use -setDelegate: to handle cancellation);

/**
 * Sets a cancellation handler that is called when the receiver gets
 * cancelled.  If the receiver is already cancelled, the handler is
 * scheduled immediately.
 */
- (void) setCancellationHandler: (GSProgressCancellationHandler) handler
  GS_NON_PORTABLE(use -setDelegate: to handle cancellation);

/**
 * Indicates whether the underlying work whose progress is being tracked
 * can be paused.  This has no effect on whether the receiver can be
 * paused.  By default, a progress instance is not pausable.
 */
- (BOOL) isPausable;
- (void) setPausable: (BOOL) pausable;

/**
 * Returns YES if the receiver has been paused and not resumed since.
 */
- (BOOL) isPaused;

/**
 * Pauses the receiver (so subsequent calls to -isPaused will return YES),
 * and also pauses unfinished children.
 * If a pausing handler is set, it is called like the cancellation handler,
 * even if the receiver was already paused.
 */
- (void) pause;

/**
 * Returns the pausing handler.
 */
- (GSProgressPausingHandler) pausingHandler
  GS_NON_PORTABLE(use -setDelegate: to handle pausing);

/**
 * Sets a pausing handler that is called when the receiver gets paused.  If
 * the receiver is already paused, the handler is scheduled immediately.
 */
- (void) setPausingHandler: (GSProgressPausingHandler) handler
  GS_NON_PORTABLE(use -setDelegate: to handle pausing);

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Resumes the receiver (so subsequent calls to -isPaused will return NO),
 * and also resumes unfinished children.
 * If a resuming handler is set, it is called like the cancellation handler,
 * even if the receiver was not paused.
 */
- (void) resume;

/**
 * Returns the resuming handler.
 */
- (GSProgressResumingHandler) resumingHandler
  GS_NON_PORTABLE(use -setDelegate: to handle resuming);

/**
 * Sets a resuming handler that is called when the receiver gets resumed.
 */
- (void) setResumingHandler: (GSProgressResumingHandler) handler
  GS_NON_PORTABLE(use -setDelegate: to handle resuming);
#endif

- (BOOL) isIndeterminate;

- (void) setKind: (NSProgressKind)k;
- (NSProgressKind) kind;

/**
 * Sets an object in the user info, or removes it if obj is nil.
 */
- (void) setUserInfoObject: (id)obj
		    forKey: (NSProgressUserInfoKey)key;

/**
 * Returns the user info, which also reflects later changes.  The file
 * related properties and the estimated time remaining and throughput are
 * stored in it.  Copy it to read several entries while it may change.
 */
- (NSDictionary *) userInfo;

- (void) setFileOperationKind: (NSProgressFileOperationKind)k;
- (NSProgressFileOperationKind) fileOperationKind;
- (void) setFileUrl: (NSURL *)u;

- (NSURL *) fileUrl;

- (BOOL) isFinished;
- (BOOL) isOld;

- (void) setEstimatedTimeRemaining: (NSNumber *)n;
- (NSNumber *) estimatedTimeRemaining;

- (void) setFileCompletedCount: (NSNumber *)n;
- (NSNumber *) fileCompletedCount;

- (void) setFileTotalCount: (NSNumber *)n;
- (NSNumber *) fileTotalCount;

- (void) setThroughput: (NSNumber *)n;
- (NSNumber *) throughput;

/**
 * The progress discovery functionality is not implemented. This method will
 * throw an exception.
 */
- (void) publish;
- (void) unpublish;

/**
 * Makes the receiver the current progress with the pending unit count while
 * performing the block, as -becomeCurrentWithPendingUnitCount: and
 * -resignCurrent do.
 */
- (void) performAsCurrentWithPendingUnitCount: (int64_t)unitCount
  usingBlock: (GSProgressPendingUnitCountBlock)work
  GS_NON_PORTABLE(use -becomeCurrentWithPendingUnitCount: and
    -resignCurrent instead);

+ (id) addSubscriberForFileURL: (NSURL *)url
	 withPublishingHandler: (NSProgressPublishingHandler)publishingHandler
  GS_NON_PORTABLE(use key-value observing of the progress instead);
+ (void) removeSubscriber: (id)subscriber
  GS_NON_PORTABLE(use key-value observing of the progress instead);

@end


@protocol NSProgressReporting

- (NSProgress *) progress;

@end

#if	defined(__cplusplus)
}
#endif

#if	!NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import	<GNUstepBase/NSProgress+GNUstepBase.h>
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSProgress_h_GNUSTEP_BASE_INCLUDE */
