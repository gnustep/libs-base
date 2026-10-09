/**Interface for NSOperation for GNUStep
   Copyright (C) 2008-2022 Free Software Foundation, Inc.

   Written by:  Gregory Casamento <greg.casamento@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   */

#ifndef __NSOperation_h_GNUSTEP_BASE_INCLUDE
#define __NSOperation_h_GNUSTEP_BASE_INCLUDE

#include "GNUstepBase/GSConfig.h"
#import <Foundation/NSObject.h>
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)


#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST) \
  && GS_USE_LIBDISPATCH == 1
#include "dispatch/dispatch.h"
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
#import <GNUstepBase/GSBlocks.h>
DEFINE_BLOCK_TYPE_NO_ARGS(GSOperationCompletionBlock, void);
DEFINE_BLOCK_TYPE_NO_ARGS(GSBlockOperationBlock, void);
#endif  

@class GSOperation;
@class NSInvocation;
@class NSMutableArray;

enum {
  NSOperationQueuePriorityVeryLow = -8,
  NSOperationQueuePriorityLow = -4,
  NSOperationQueuePriorityNormal = 0,
  NSOperationQueuePriorityHigh = 4,
  NSOperationQueuePriorityVeryHigh = 8
};

typedef NSInteger NSOperationQueuePriority;

GS_EXPORT_CLASS
@interface NSOperation : NSObject
{
#if	GS_NONFRAGILE
#  if	defined(GS_NSOperation_IVARS)
@public GS_NSOperation_IVARS
#  endif
#else
@private id _internal;
#endif
}

/** Adds a dependency to the receiver.<br />
 * The receiver is not considered ready to execute until all of its
 * dependencies have finished executing.<br />
 * You must not add a particular object to the receiver more than once.<br />
 * You must not create loops of dependencies (this would cause deadlock).<br />
 */
- (void) addDependency: (NSOperation *)op;

/** Marks the operation as cancelled (causes subsequent calls to the
 * -isCancelled method to return YES).<br />
 * This does not directly cause the receiver to stop executing ... it is the
 * responsibility of the receiver to call -isCancelled while executing and
 * act accordingly.<br />
 * If an operation in a queue is cancelled before it starts executing, it
 * will be removed from the queue (though not necessarily immediately).<br />
 * Calling this method on an object which has already finished executing
 * has no effect.
 */
- (void) cancel;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns the block that will be executed after the operation finishes.
 */
- (GSOperationCompletionBlock) completionBlock
  GS_NON_PORTABLE(use -setDelegate: to handle operation completion);
#endif

/** Returns all the dependencies of the receiver in the order in which they
 * were added.
 */
- (NSArray *) dependencies;

/** This method should return YES if the -cancel method has been called.<br />
 * NB. a cancelled operation may still be executing.
 */
- (BOOL) isCancelled;

/** This method returns YES if the receiver handles its own environment or
 * threading rather than expecting to run in an evironment set up elsewhere
 * (eg, by an [NSOperationQueue] instance).<br />
 * The default implementation returns NO.
 */
- (BOOL) isConcurrent;

/** This method should return YES if the receiver is currently executing its
 * -main method (even if -cancel has been called).
 */
- (BOOL) isExecuting;

/** This method should return YES if the receiver has finished executing its
 * -main method (irrespective of whether the execution completed due to
 * cancellation, failure, or success).
 */
- (BOOL) isFinished;

/** This method should return YES when the receiver is ready to begin
 * executing.  That is, the receiver must have no dependencies which
 * have not finished executing.<br />
 * Also returns YES if the operation has been cancelled (even if there
 * are unfinished dependencies).<br />
 * An executing or finished operation is also considered to be ready.
 */
- (BOOL) isReady;

/** <override-subclass/>
 * This is the method which actually performs the operation ...
 * the default implementation does nothing.<br />
 * You MUST ensure that your implemention of -main does not raise any
 * exception or call [NSThread+exit] as either of these will terminate
 * the operation prematurely resulting in the operation never reaching
 * the -isFinished state.<br />
 * If you are writing a concurrent subclass, you should override -start
 * instead of (or as well as) the -main method.
 */
- (void) main;

/** Returns the priority set using the -setQueuePriority: method, or
 * NSOperationQueuePriorityNormal if no priority has been set.
 */
- (NSOperationQueuePriority) queuePriority;

/** Removes a dependency from the receiver.
 */
- (void) removeDependency: (NSOperation *)op;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Sets the block that will be executed when the operation has finished.
 */
- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
  GS_NON_PORTABLE(use -setDelegate: to handle operation completion);
#endif

/** Sets the priority for the receiver.  If the value supplied is not one of
 * the predefined queue priorities, it is converted into the next available
 * defined value moving towards NSOperationQueuePriorityNormal.
 */
- (void) setQueuePriority: (NSOperationQueuePriority)priority;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Sets the thread priority to be used while executing then -main method.
 * The priority change is implemented in the -start method, so if you are
 * replacing -start you are responsible for managing this.<br />
 * The valid range is 0.0 to 1.0
 */
- (void) setThreadPriority: (double)prio;
#endif

/** This method is called to start execution of the receiver.<br />
 * <p>For concurrent operations, the subclass must override this method
 * to set up the environment for the operation to execute, must execute the
 * -main method, must ensure that -isExecuting and -isFinished return the
 * correct values, and must manually call key-value-observing methods to
 * notify observers of the state of those two properties.<br />
 * The subclass implementation must NOT call the superclass implementation.
 * </p>
 * <p>For non-concurrent operations, the default implementation of this method
 * performs all the work of setting up environment etc, and the subclass only
 * needs to override the -main method.
 * </p>
 */
- (void) start;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Returns the thread priority to be used executing the -main method.
 * The default is 0.5
 */
- (double) threadPriority;

/** This method blocks the current thread until the receiver finishes.<br />
 * Care must be taken to avoid deadlock ... you must not call this method
 * from the same thread that the receiver started in.
 */
- (void) waitUntilFinished;
#endif

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/** The GSOperationCompletion protocol specifies messages which will be sent
 * to the delegate of an operation.
 */
@protocol	GSOperationCompletion
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (GSOperationCompletion)
#endif
/** Called on completion of the whole operation.  This notifies the delegate
 * that the entire operation has completed, but provides no information about
 * whether the operation did its job successfully or not.
 */
- (void) operationCompleted;

/** Called on completion of each item in a [GSOperation], after sending a
 * message (making a target perform a selector).<br />
 * The result will be either the return value of that message, or the
 * exception raised by that message.<br />
 * The delegate may return YES to indicate that processing of the operation
 * as a whole should complete without proceding to any items after the one
 * which just completed.
 */
- (BOOL) shouldStopOperation: (GSOperation*)op
		 afterItemAt: (NSUInteger)index
	       completedWith: (id)result;
@end

/** The GSOperation class provides for traditional messaging to one or more
 * objects, where the message has zero or one object argument and returns
 * an object.<br />
 * The constructor creates an instance with one such item, but you can add
 * more items describing messagng to be performed in sequences.<br />
 * The instance methods in this class may be used either before the operation
 * is added to a queue or by the delegate handling a
 * -shouldStopOperation:afterItemAt:completedWith: message.
 */
GS_EXPORT_CLASS
@interface GSOperation : NSOperation
{
  @private
  NSMutableArray	*_ops;
}
- (void) addOperationTarget: (id)aTarget
            performSelector: (SEL)aSelector;
- (void) addOperationTarget: (id)aTarget
            performSelector: (SEL)aSelector
                 withObject: (id)anObject;
- (void) getTarget: (id*)t
	  selector: (SEL*)s
	    object: (id*)o
	    ofItem: (NSUInteger)i;
- (instancetype) initTarget: (id)aTarget
		   selector: (SEL)aSelector
		     object: (id)anObject;
- (NSUInteger) itemCount;
- (void) setObject: (id)o atIndex: (NSUInteger)i;
- (void) setSelector: (SEL)s atIndex: (NSUInteger)i;
- (void) setTarget: (id)t atIndex: (NSUInteger)i;
@end

@interface	NSOperation (GNUstep)

/** Calls +operationTarget:performSelector:withObject: passing a nil object.
 */
+ (GSOperation*) operationTarget: (id)aTarget
		 performSelector: (SEL)aSelector;

/** Creates and returns an autoreleased GSOperation instance set up with one
 * item to make a target object perform a selector.
 */
+ (GSOperation*) operationTarget: (id)aTarget
		 performSelector: (SEL)aSelector
		      withObject: (id)anObject;

/** Returns the delegate (if any) set to handle completion of the operation.
 * Use this rather than -completionBlock (do not attempt to use both).
 */
- (id<GSOperationCompletion>) delegate;

/** Sets the delegate that will be messaged when the operation has finished.
 * The operation uses a weak reference to the delegate, it does not retain it.
 * Use this rather than -setCompletionBlock: (do not attempt to use both).
 */
- (void) setDelegate: (id<GSOperationCompletion>)anObject;

@end

#endif

/** The NSBlockOperation class is inherently non-portable due to its
 * dependency on a single compiler.  Any portable code with a use for
 * similar functionality should use the NSInvocationBlock instead.
 */
GS_EXPORT_CLASS
@interface NSBlockOperation : NSOperation
{
  @private
    NSMutableArray *_executionBlocks;
    void *_reserved;
}

/**
 * Creates and returns an NSBlockOperationObject and adds the block.
 */
+ (instancetype) blockOperationWithBlock: (GSBlockOperationBlock)block
  GS_NON_PORTABLE(use the GSOperation or NSInvocationOperation class instead);

/**
 * Adds the execution block to the NSOperationBlock.
 */
- (void) addExecutionBlock: (GSBlockOperationBlock)block;

/**
 * Returns the block added to the NSOperationBlock.
 */
- (NSArray *) executionBlocks;

@end

/**
 * NSOperationQueue
 */

// Enumerated type for default operation count.
enum {
   NSOperationQueueDefaultMaxConcurrentOperationCount = -1
};

/**
 * An NSOperationQueue manages a number of NSOperation objects, scheduling
 * them for execution and managing their dependencies.
 *
 * Depending on the configuration of the queue, operations may be executed
 * concurrently or serially.
 *
 * Worker threads are named "NSOperationQ_&lt;number&gt;" by default, but
 * you can set a name for the queue using the -setName: method.
 * The suffix "_&lt;number&gt;"" is automatically added to the thread name.
 */
GS_EXPORT_CLASS
@interface NSOperationQueue : NSObject
{
#if	GS_NONFRAGILE
#  if	defined(GS_NSOperationQueue_IVARS)
@public GS_NSOperationQueue_IVARS
#  endif
#else
@private id _internal;
#endif
}
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** If called from within the -main method of an operation which is
 * currently being executed by a queue, this returns the queue instance
 * in use.
 */
+ (id) currentQueue;

/** Returns the default queue on the main thread.
 */
+ (id) mainQueue;
#endif

/** Adds an operation to the receiver.
 */
- (void) addOperation: (NSOperation *)op;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Adds multiple operations to the receiver and (optionally) waits for
 * all the operations in the queue to finish.
 */
- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait;
  
/** This method wraps a block in an operation and adds it to the queue.
 */
- (void) addOperationWithBlock: (GSBlockOperationBlock)block
  GS_NON_PORTABLE(use the GSOperation or NSInvocationOperation class instead);

/** This method wraps an invocation in an operation and adds it to the queue.
 */
- (void) addOperationWithInvocation: (NSInvocation*)inv;
#endif

/** Cancels all outstanding operations in the queue.
 */
- (void) cancelAllOperations;

/** Returns a flag indicating whether the queue is currently suspended.
 */
- (BOOL) isSuspended;

/** Returns the value set using the -setMaxConcurrentOperationCount:
 * method, or NSOperationQueueDefaultMaxConcurrentOperationCount if
 * none has been set.<br />
 */
- (NSInteger) maxConcurrentOperationCount;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Return the name of this operation queue.
 */
- (NSString*) name;

/** Return the number of operations in the queue at an instant.
 */
- (NSUInteger) operationCount;
#endif

/** Returns all the operations in the queue at an instant.
 */
- (NSArray *) operations;

/** Sets the number of concurrent operations permitted.<br />
 * The default (NSOperationQueueDefaultMaxConcurrentOperationCount)
 * means that the queue should decide how many it does based on
 * system load etc.
 */
- (void) setMaxConcurrentOperationCount: (NSInteger)cnt;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Sets the name for this operation queue.
 */
- (void) setName: (NSString*)s;
#endif

/** Marks the receiver as suspended ... while suspended an operation queue
 * will not start any more operations.
 */
- (void) setSuspended: (BOOL)flag;

/** Waits until all operations in the queue have finished (or been cancelled
 * and removed from the queue).
 */
- (void) waitUntilAllOperationsAreFinished;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST) \
  && GS_USE_LIBDISPATCH == 1
  /** Returns the underlying dispatch queue.
   */
- (dispatch_queue_t) underlyingQueue
  GS_NON_PORTABLE(libdispatch is only available on some platforms);

  /** Sets the underlying dispatch queue.
   *
   * Throws `NSInvalidArgumentException` if:
   *  - The argument is `NULL`
   *  - There are operations in the queue `(operationCount > 0)`
   *  - The argument is the value returned by `dispatch_get_main_queue()`
   */
- (void) setUnderlyingQueue: (dispatch_queue_t)dispatchQueue
  GS_NON_PORTABLE(libdispatch is only available on some platforms);
#endif
@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif /* __NSOperation_h_GNUSTEP_BASE_INCLUDE */
