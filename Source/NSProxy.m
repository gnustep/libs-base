/** Implementation for GNU Objective-C version of NSProxy
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSProxy.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSObjCRuntime.h>
#include "limits.h"

#ifndef NeXT_RUNTIME
extern BOOL __objc_responds_to(id, SEL);
#endif

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

+ (NSString*) description
{
  return [NSString stringWithFormat: @"<%s>", object_get_class_name(self)];
}

+ (void) load
{
  /* Do nothing	*/
}

+ (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  struct objc_method	*mth;

  if (aSelector == 0)
    {
      return nil;
    }
  mth = class_get_class_method(GSObjCClass(self), aSelector);
  if (mth != 0)
    {
      const char	*types = mth->method_types;

      if (types != 0)
	{
	  return [NSMethodSignature signatureWithObjCTypes: types];
	}
    }
  return nil;
}

+ (void) release
{
  /* Do nothing	*/
}

+ (BOOL) respondsToSelector: (SEL)aSelector
{
  if (__objc_responds_to(self, aSelector))
    return YES;
  else
    return NO;
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
#if	GS_WITH_GC == 0
  [NSAutoreleasePool addObject: self];
#endif
  return self;
}

- (Class) class
{
  return object_get_class(self);
}

- (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  [NSException raise: NSGenericException
    format: @"subclass %s should override %s", object_get_class_name(self),
    sel_get_name(_cmd)];
  return NO;
}

- (void) dealloc
{
  NSDeallocateObject((NSObject*)self);
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%s %lx>",
	object_get_class_name(self), (unsigned long)self];
}

- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame
{
  NSInvocation *inv;

  inv = AUTORELEASE([[NSInvocation alloc] initWithArgframe: argFrame
						  selector: aSel]);
  [self forwardInvocation: inv];
  return [inv returnFrame: argFrame];
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
  [NSException raise: NSGenericException
    format: @"subclass %s should override %s", object_get_class_name(self),
    sel_get_name(_cmd)];
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

/*
 * If we respond to the method directly, create and return a method
 * signature.  Otherwise raise an exception.
 */
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  struct objc_method	*mth;

  if (aSelector == 0)
    {
      return nil;
    }
  mth = class_get_instance_method(GSObjCClass(self), aSelector);
  if (mth != 0)
    {
      const char	*types = mth->method_types;

      if (types != 0)
	{
	  return [NSMethodSignature signatureWithObjCTypes: types];
	}
    }
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
#if	GS_WITH_GC == 0
  if (_retain_count-- == 0)
    {
      [self dealloc];
    }
#endif
}

/*
 * If we respond to the method directly, return YES, otherwise
 * forward this request to the object we are acting as a proxy for.
 */
- (BOOL) respondsToSelector: (SEL)aSelector
{
  if (aSelector == 0)
    {
      return NO;
    }
  if (__objc_responds_to(self, aSelector))
    {
      return YES;
    }
  else
    {
      NSMethodSignature	*sig;
      NSInvocation	*inv;
      BOOL		ret;

      sig = [self methodSignatureForSelector: _cmd];
      inv = [NSInvocation invocationWithMethodSignature: sig];
      [inv setSelector: _cmd];
      [inv setArgument: &aSelector atIndex: 2];
      [self forwardInvocation: inv];
      [inv getReturnValue: &ret];
      return ret;
    }
}

- (id) retain
{
#if	GS_WITH_GC == 0
  _retain_count++;
#endif
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

