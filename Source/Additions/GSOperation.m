/**Implementation for GSOperation for GNUStep
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

#import "common.h"
#import "Foundation/Foundation.h"
#import "GNUstepBase/GSOperation.h"
#import "GSPrivate.h"


@interface	GSOp : NSObject
{
  @public
  id	target;
  SEL	selector;
  id	object;
}
@end
@implementation	GSOp
- (void) dealloc
{
  RELEASE(target);
  RELEASE(object);
  DEALLOC
}
@end

@implementation GSOperation
- (void) _add: (GSOp*)op
{
  [_ops addObject: op];
}

- (void) addOperationTarget: (id)aTarget
	    performSelector: (SEL)aSelector
{
  [self addOperationTarget: aTarget performSelector: aSelector withObject: nil];
}

- (void) addOperationTarget: (id)aTarget
	    performSelector: (SEL)aSelector
		 withObject: (id)anObject
{
  GSOp		*op = [GSOp new];

  ASSIGN(op->target, aTarget);
  op->selector = aSelector;
  ASSIGN(op->object, anObject);
  [_ops addObject: op];
  RELEASE(op);
}

- (void) dealloc
{
  RELEASE(_ops);
  DEALLOC
}

- (void) getTarget: (id*)t
          selector: (SEL*)s 
            object: (id*)o 
            ofItem: (NSUInteger)i
{
  GSOp	*op = [_ops objectAtIndex: i];

  if (t)
    {
      *t = op->target;
    }
  if (s)
    {
      *s = op->selector;
    }
  if (o)
    {
      *o = op->object;
    }
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      _ops = [[NSMutableArray alloc] initWithCapacity: 4];
    }
  return self;
}

- (instancetype) initTarget: (id)aTarget
                   selector: (SEL)aSelector 
                     object: (id)anObject
{
  if (nil != (self = [super init]))
    {
      GSOp	*op = [GSOp new];

      _ops = [[NSMutableArray alloc] initWithCapacity: 4];
      ASSIGN(op->target, aTarget);
      op->selector = aSelector;
      ASSIGN(op->object, anObject);
      [_ops addObject: op];
      RELEASE(op);
    }
  return self;

}

- (NSUInteger) itemCount
{
  return [_ops count];
}

- (NSArray*) items
{
  return AUTORELEASE([_ops copy]);
}

- (void) main
{
  SEL		sel = @selector(shouldStopOperation:afterItemAt:completedWith:);
  id		del = [self delegate];
  unsigned	index = 0;

  if (NO == [del respondsToSelector: sel])
    {
      del = nil;
    }
  /* We can't use fast enumeration here because the delegate could add
   * a new item at the end of the _ops array while we are going through
   * it executing each item in turn.
   */
  while (index < [_ops count])
    {
      GSOp	*op = [_ops objectAtIndex: index];
      id	result;

      if (nil == op->target || NULL == op->selector)
	{
	  result = nil;
	}
      else
	{
	  NS_DURING
	    result = [op->target performSelector: op->selector
				      withObject: op->object];
	  NS_HANDLER
	    result = localException;
	  NS_ENDHANDLER
	}
      if ([del shouldStopOperation: self
		       afterItemAt: index
		     completedWith: result])
	{
	  break;
	}
      index++;
    }
  [_ops removeAllObjects];
}

- (void) setObject: (id)o atIndex: (NSUInteger)i
{
  GSOp	*op = [_ops objectAtIndex: i];

  ASSIGN(op->object, o);
}

- (void) setSelector: (SEL)s atIndex: (NSUInteger)i
{
  GSOp	*op = [_ops objectAtIndex: i];

  op->selector = s;
}

- (void) setTarget: (id)t atIndex: (NSUInteger)i
{
  GSOp	*op = [_ops objectAtIndex: i];

  ASSIGN(op->target, t);
}

@end

#if	__APPLE__

#import <objc/runtime.h>

@interface GSOperationDelegateWeak : NSObject
@property(nonatomic, weak) id value;
@end
@implementation GSOperationDelegateWeak
@end

@implementation	NSOperation (GNUstep)
+ (GSOperation*) operationTarget: (id)aTarget
                 performSelector: (SEL)aSelector
{
  return [self operationTarget: aTarget
	       performSelector: aSelector
		    withObject: nil];
}

+ (GSOperation*) operationTarget: (id)aTarget
                 performSelector: (SEL)aSelector
                      withObject: (id)anObject
{
  GSOperation	*o = [GSOperation alloc];

  o = [o initTarget: aTarget selector: aSelector object: anObject];
  return AUTORELEASE(o);
}

static char	*dKey = "GSOperationDelegateKey";

- (id<GSOperationCompletion>) delegate
{
  GSOperationDelegateWeak	*w = objc_getAssociatedObject(self, &dKey);

  return w ? w.valuei : nil;
}

- (void) setDelegate: (id<GSOperationCompletion>)anObject
{
  id	o;

  if (anObject)
    {
      GSOperationDelegateWeak	*w = [GSOperationDelegateWeak new];

      w.value = anobject;
    }
  else
    {
      o = nil;
    }
  objc_setAssociatedObject(self, &dKey, o, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  RELEASE(o);
  if (anObject && [anObject respondsToSelector: @selector(operationCompleted)])
    {
      [self setCompletionBlock: ^{[[self delegate] operationCompleted];}];
    }
  else
    {
      [self setCompletionBlock: NULL];
    }
}

@end
#endif

