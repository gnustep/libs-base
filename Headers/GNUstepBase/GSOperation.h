/**Interface for GSOperation for GNUStep
   Copyright (C) 2026 Free Software Foundation, Inc.

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

#ifndef __GSOperation_h_GNUSTEP_BASE_INCLUDE
#define __GSOperation_h_GNUSTEP_BASE_INCLUDE

#include "GNUstepBase/GSConfig.h"
#import <Foundation/NSObject.h>

#if defined(__APPLE__)

#if	defined(__cplusplus)
extern "C" {
#endif

@protocol	GSOperationCompletion
@optional
/** Called on completion of the whole operation.
 */
- (void) operationCompleted;

/** Called on completion of making a target perform a selector within the
 * operation as a whole.<br />
 * The result will be either the return value of that message, or the
 * exception raised by that message.<br />
 * The delegate may return YES to indicate that processing of the operation
 * should complete without proceding to any items after the one which just
 * completed.
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

#if	defined(__cplusplus)
}
#endif

#endif	/* __APPLE__ */

#endif /* __NSOperation_h_GNUSTEP_BASE_INCLUDE */
