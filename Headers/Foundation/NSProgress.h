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
@class GS_GENERIC_CLASS(NSDictionary, KeyT:id<NSCopying>, ValT);
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
 * A progress object tracks an amount of work that is yet to be completed.  Work
 * is tracked in units. A progress is finished when the completed number of unit
 * work is equal to the total number of unit work.
 *
 * Progress objects can be arranged in a tree formation. Children of a parent progress
 * continuosly report their progress and update the parents fractionCompleted property.
 * When a child is added to a parent progress, a pending unit count is
 * specified. This count is added to the parent after completion of the child.
 *
 * There are two mechanisms to add a progress as a child to another progress object:
 * One can explicitly add a child with -addChild:withPendingUnitCount:. There is also
 * a way to implicitly add newly instantiated progress object as a child to an existing progress.
 *
 * For this, we first need to define how the "currentProgress" API works:
 * Every thread has a thread-specific current progress stack. The top-most
 * element on this stack can be accessed by +currentProgress class method.  By
 * sending -becomeCurrentWithPendingUnitCount: to a progress, the progress
 * object is pushed onto the stack and becomes the new current progress.
 *
 * The next progress object instantiated (excluding creation with
 * discreteProgressWithTotalUnitCount:) becomes a child of this current progress.
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
 * thread, or nil.
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
 * Retrieve the first progress object that is on the thread-local current progress
 * stack.
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
 * The pending unit count represents the portion of work to perform in relation to
 * the total number of units of work, which is the value of the receivers
 * totalUnitCount property. The pending units of work should be less than or equal
 * to the total units of work of the receiver. Ensure that the total number is not
 * exceeded.
 *
 * Calls to this method must be matched by -[NSProgress resignCurrent].
 */
- (void) becomeCurrentWithPendingUnitCount: (int64_t)unitCount;
/**
 * Receiver resigns the role of the current progress. The receiver is popped
 * from the thread-local current progress stack.
 *
 * If the receiver is not the current progress, an exception will be thrown.
 */
- (void) resignCurrent;

/**
 * Adds the progress to the receiver as a child.  The pending unit count is
 * added to the receiver upon completion of the child progress.
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

- (NSString *) localizedDescription;
- (NSString *) localizedAdditionalDescription;

/**
 * Provides a fraction of completed work, including work done by child
 * progresses. Different from the completedUnitCount property, this property is
 * continuously updated, tracking the progress of children as well.
 */
- (double) fractionCompleted;

/**
 * Indicates whether the progress is cancellable. By default, a progress is
 * cancellable but not pausable.
 */
- (BOOL) isCancellable;
- (BOOL) isCancelled;

/**
 * Cancels a progress and its unfinished children.  If a cancellation handler is
 * set, it will be called before cancelling child progresses.
 */
- (void) cancel;
/**
 * Sets a cancellation handler that is called when a progress gets cancelled.
 */
- (void) setCancellationHandler: (GSProgressCancellationHandler) handler;

/**
 * Pausation of a progress is not implemented. This method always returns 'NO'.
 */
- (BOOL) isPausable;
/**
 * Pausation of a progress is not implemented. Therefore a progress is never
 * paused and this method always returns 'NO'.
 */
- (BOOL) isPaused;
/**
 * Pausation of a progress is not implemented. This method will throw an
 * exception.
 */
- (void) pause;
- (void) setPausingHandler: (GSProgressPausingHandler) handler;

- (void) resume;
- (void) setResumingHandler: (GSProgressResumingHandler) handler;

- (BOOL) isIndeterminate;

- (void) setKind: (NSProgressKind)k;
- (NSProgressKind) kind;

- (void) setUserInfoObject: (id)obj
                    forKey: (NSProgressUserInfoKey)key;
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
- (void) performAsCurrentWithPendingUnitCount: (int64_t)unitCount 
  usingBlock: (GSProgressPendingUnitCountBlock)work;

+ (id) addSubscriberForFileURL: (NSURL *)url 
         withPublishingHandler: (NSProgressPublishingHandler)publishingHandler;
+ (void) removeSubscriber: (id)subscriber;
  
@end


@protocol NSProgressReporting

- (NSProgress *) progress;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSProgress_h_GNUSTEP_BASE_INCLUDE */

