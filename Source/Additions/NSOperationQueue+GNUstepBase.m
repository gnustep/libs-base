/* Implementation of extension methods to base additions

   Copyright (C) 2025 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/
#import "../common.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSOperation.h"
#import "GNUstepBase/NSOperationQueue+GNUstepBase.h"


@interface GSTargetOperation : NSOperation
{
  id<NSObject>	target;
  SEL		selector;
  id<NSObject>	o1;
  id<NSObject>	o2;
  enum {
    argc_zero = 0,
    argc_one = 1,
    argc_two = 2
  } argc;
}
+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2;
+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1;
+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector;
@end

/**
 * Extension methods for the NSObjectQueue class
 */
@implementation NSOperationQueue (GNUstepBase)

- (void) addOperationWithTarget: (id<NSObject>)aTarget
		performSelector: (SEL)aSelector
		     withObject: (id<NSObject>)object1
		     withObject: (id<NSObject>)object2
{
  GSTargetOperation *top = [GSTargetOperation operationWithTarget: aTarget
						  performSelector: aSelector
						       withObject: object1
						       withObject: object2];
  [self addOperation: top];
}

- (void) addOperationWithTarget: (id<NSObject>)aTarget
		performSelector: (SEL)aSelector
		     withObject: (id<NSObject>)object1
{
  GSTargetOperation *top = [GSTargetOperation operationWithTarget: aTarget
						  performSelector: aSelector
						       withObject: object1];
  [self addOperation: top];
}

- (void) addOperationWithTarget: (id<NSObject>)aTarget
		performSelector: (SEL)aSelector
{
  GSTargetOperation *top = [GSTargetOperation operationWithTarget: aTarget
						  performSelector: aSelector];
  [self addOperation: top];
}

@end


@implementation GSTargetOperation

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
{
  GSTargetOperation *op = [[self alloc] init];

  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = RETAIN(object2);
  op->argc = argc_two;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
{
  GSTargetOperation *op = [[self alloc] init];

  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = nil;
  op->argc = argc_one;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
{
  GSTargetOperation *op = [[self alloc] init];

  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = nil;
  op->o2 = nil;
  op->argc = argc_zero;
  return AUTORELEASE(op);
}

- (void) dealloc
{
  RELEASE(target);
  if (argc > 0) RELEASE(o1);
  if (argc > 1) RELEASE(o2);
  DEALLOC
}

- (void) main
{
  switch (argc)
    {
      case argc_two:
	[target performSelector: selector withObject: o1 withObject: o2];
	return;
      case argc_one:
	[target performSelector: selector withObject: o1];
	return;
      case argc_zero:
	[target performSelector: selector];
	return;
    }
}
@end

