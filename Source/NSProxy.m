/* Implementation for GNU Objective-C version of NSProxy
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */

#include <config.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSProxy.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include "limits.h"

#include <objc/objc-api.h>

@implementation NSProxy

+ (id) alloc
{
  return [self allocWithZone: NSDefaultMallocZone()];
}

+ (id) allocWithZone: (NSZone*)z
{
  NSProxy*	ob = (NSProxy*) NSAllocateObject(self, 0, z);
  return ob;
}

+ (id) autorelease
{
  return self;
}

+ (Class) class
{
  return self;
}

+ (void) load
{
  /* Do nothing	*/
}

+ (NSString*) description
{
  return [NSString stringWithFormat: @"<%s>", object_get_class_name(self)];
}

+ (BOOL) respondsToSelector: (SEL)aSelector
{
  return (class_get_class_method(self, aSelector) != METHOD_NULL);
}

+ (void) release
{
  /* Do nothing	*/
}

+ (id) retain
{
  return self;
}

+ (Class) superclass
{
  return class_get_super_class (self);
}

- (id) autorelease
{
  [NSAutoreleasePool addObject:self];
  return self;
}

- (Class) class
{
  return object_get_class(self);
}

#if 0
- (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  NSInvocation		*inv;
  NSMethodSignature	*sig;
  BOOL			result;

  sig = [self methodSignatureForSelector:@selector(conformsToProtocol:)];
  inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setSelector:@selector(conformsToProtocol:)];
  [inv setArgument:aProtocol atIndex:2];
  [self forwardInvocation:inv];
  [inv getReturnValue: &result];
  return result;
}
#endif

- (void) dealloc
{
  NSDeallocateObject((NSObject*)self);
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%s %lx>",
	object_get_class_name(self), (unsigned long)self];
}

- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  [NSException raise: NSInvalidArgumentException
	      format: @"NSProxy should not implement '%s'",
				sel_get_name(_cmd)];
}

- (unsigned int) hash
{
  return (unsigned int)self;
}

- (id) init
{
  return self;
}

- (BOOL) isEqual: (id)anObject
{
  return (self == anObject);
}

+ (BOOL) isKindOfClass: (Class)aClass
{
  return NO;
}

- (BOOL) isKindOfClass: (Class)aClass
{
  Class class = self->isa;

  while (class != nil)
    {
      if (class == aClass)
	{
	  return YES;
	}
      class = class_get_super_class(class);
    }
  return NO;
}

+ (BOOL) isMemberOfClass: (Class)aClass
{
  return(self == aClass);
}

- (BOOL) isMemberOfClass: (Class)aClass
{
  return(self->isa == aClass);
}

- (BOOL) isProxy
{
  return YES;
}

- (id) notImplemented: (SEL)aSel
{
  [NSException raise: NSGenericException
	      format: @"NSProxy notImplemented %s", sel_get_name(aSel)];
  return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  [NSException raise: NSInvalidArgumentException format:
	@"NSProxy should not implement 'methodSignatureForSelector:'"];
  return nil;
}

- (id) performSelector: (SEL)aSelector
{
  IMP msg = objc_msg_lookup(self, aSelector);

  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector);
}

- (id) performSelector: (SEL)aSelector
	    withObject: (id)anObject
{
  IMP msg = objc_msg_lookup(self, aSelector);

  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector, anObject);
}

- (id) performSelector: (SEL)aSelector
	    withObject: (id)anObject
	    withObject: (id)anotherObject
{
  IMP msg = objc_msg_lookup(self, aSelector);

  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector, anObject, anotherObject);
}

- (void) release
{
  if (_retain_count-- == 0)
    {
      [self dealloc];
    }
}

#if 0
- (BOOL) respondsToSelector: (SEL)aSelector
{
  NSInvocation*       inv;
  NSMethodSignature*  sig;
  BOOL		result;

  sig = [self methodSignatureForSelector:@selector(respondsToSelector:)];
  inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setSelector:@selector(respondsToSelector:)];
  [inv setArgument:(void*)aSelector atIndex:2];
  [self forwardInvocation:inv];
  [inv getReturnValue: &result];
  return result;
}
#endif

- (id) retain
{
  _retain_count++;
  return self;
}

- (unsigned int) retainCount
{
  return _retain_count + 1;
}

+ (unsigned) retainCount
{
  return UINT_MAX;
}

- (id) self
{
  return self;
}

- (Class) superclass
{
  return object_get_super_class(self);
}

- (NSZone*) zone
{
  return NSZoneFromPointer(self);
}

@end

