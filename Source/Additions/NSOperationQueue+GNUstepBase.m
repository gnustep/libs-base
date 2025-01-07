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
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSOperation.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/NSOperationQueue+GNUstepBase.h"


@interface GSTargetOperation : NSOperation
{
  IMP		msg;
  id<NSObject>	target;
  SEL		selector;
  id<NSObject>	o1;
  id<NSObject>	o2;
  id<NSObject>	o3;
  id<NSObject>	o4;
  enum {
    argc_zero = 0,
    argc_one = 1,
    argc_two = 2,
    argc_three = 3,
    argc_four = 4
  } argc;
}
+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
			  withObject: (id<NSObject>)object3
			  withObject: (id<NSObject>)object4;
+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
			  withObject: (id<NSObject>)object3;
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
		        withMap: (id)firstKey, ...
{
  GSTargetOperation 	*top;
  NSDictionary		*map;

  map = [NSDictionary alloc];
  GS_USEIDPAIRLIST(firstKey,
    map = [map initWithObjects: __pairs forKeys: __objects count: __count/2]);

  top = [GSTargetOperation operationWithTarget: aTarget
			       performSelector: aSelector
				    withObject: AUTORELEASE(map)];
  [self addOperation: top];
}

- (void) addOperationWithTarget: (id<NSObject>)aTarget
		performSelector: (SEL)aSelector
		     withObject: (id<NSObject>)object1
		     withObject: (id<NSObject>)object2
		     withObject: (id<NSObject>)object3
		     withObject: (id<NSObject>)object4
{
  GSTargetOperation *top = [GSTargetOperation operationWithTarget: aTarget
						  performSelector: aSelector
						       withObject: object1
						       withObject: object2
						       withObject: object3
						       withObject: object4];
  [self addOperation: top];
}

- (void) addOperationWithTarget: (id<NSObject>)aTarget
		performSelector: (SEL)aSelector
		     withObject: (id<NSObject>)object1
		     withObject: (id<NSObject>)object2
		     withObject: (id<NSObject>)object3
{
  GSTargetOperation *top = [GSTargetOperation operationWithTarget: aTarget
						  performSelector: aSelector
						       withObject: object1
						       withObject: object2
						       withObject: object3];
  [self addOperation: top];
}

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

static IMP
check(Class c, SEL _cmd, id t, SEL s)
{
  IMP	msg;

  if (nil == t)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null target given", NSStringFromSelector(_cmd)];
  if (0 == s)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  /* The Apple runtime API would do:
   * msg = class_getMethodImplementation(object_getClass(self), aSelector);
   * but this cannot ask self for information about any method reached by
   * forwarding, so the returned forwarding function would ge a generic one
   * rather than one aware of hardware issues with returning structures
   * and floating points.  We therefore prefer the GNU API which is able to
   * use forwarding callbacks to get better type information.
   */
  msg = objc_msg_lookup(t, s);
  if (!msg)
    [NSException raise: NSGenericException
		format: @"%@ invalid selector '%s' passed to %s",
		   t, sel_getName(s), sel_getName(_cmd)];

  return msg;
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
			  withObject: (id<NSObject>)object3
			  withObject: (id<NSObject>)object4
{
  GSTargetOperation	*op;
  IMP			msg = check(self, _cmd, aTarget, aSelector);

  op = [[self alloc] init];
  op->msg = msg;
  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = RETAIN(object2);
  op->o3 = RETAIN(object3);
  op->o4 = RETAIN(object4);
  op->argc = argc_four;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
			  withObject: (id<NSObject>)object3
{
  GSTargetOperation 	*op;
  IMP			msg = check(self, _cmd, aTarget, aSelector);

  op = [[self alloc] init];
  op->msg = msg;
  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = RETAIN(object2);
  op->o3 = RETAIN(object3);
  op->o4 = nil;
  op->argc = argc_three;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
			  withObject: (id<NSObject>)object2
{
  GSTargetOperation 	*op;
  IMP			msg = check(self, _cmd, aTarget, aSelector);

  op = [[self alloc] init];
  op->msg = msg;
  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = RETAIN(object2);
  op->o3 = nil;
  op->o4 = nil;
  op->argc = argc_two;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
			  withObject: (id<NSObject>)object1
{
  GSTargetOperation 	*op;
  IMP			msg = check(self, _cmd, aTarget, aSelector);

  op = [[self alloc] init];
  op->msg = msg;
  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = RETAIN(object1);
  op->o2 = nil;
  op->o3 = nil;
  op->o4 = nil;
  op->argc = argc_one;
  return AUTORELEASE(op);
}

+ (instancetype) operationWithTarget: (id<NSObject>)aTarget
		     performSelector: (SEL)aSelector
{
  GSTargetOperation 	*op;
  IMP			msg = check(self, _cmd, aTarget, aSelector);

  op = [[self alloc] init];
  op->msg = msg;
  op->target = RETAIN(aTarget);
  op->selector = aSelector;
  op->o1 = nil;
  op->o2 = nil;
  op->o3 = nil;
  op->o4 = nil;
  op->argc = argc_zero;
  return AUTORELEASE(op);
}

- (void) dealloc
{
  RELEASE(target);
  if (argc > 0) RELEASE(o1);
  if (argc > 1) RELEASE(o2);
  if (argc > 2) RELEASE(o3);
  if (argc > 3) RELEASE(o4);
  DEALLOC
}

- (void) main
{
  switch (argc)
    {
      case argc_four:
	(*msg)(target, selector, o1, o2, o3, o4);
	return;
      case argc_three:
	(*msg)(target, selector, o1, o2, o3);
	return;
      case argc_two:
	(*msg)(target, selector, o1, o2);
	return;
      case argc_one:
	(*msg)(target, selector, o1);
	return;
      case argc_zero:
	(*msg)(target, selector);
	return;
    }
}
@end

