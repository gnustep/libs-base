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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

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
    NSProxy*	ob = (NSProxy*) NSAllocateObject (self, 0, z);
    return ob;
}

+ autorelease
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

+ (BOOL) respondsToSelector: (SEL)aSelector
{
    return (class_get_class_method(self, aSelector) != METHOD_NULL);
}

+ (void) release
{
    /* Do nothing	*/
}

+ retain
{
    return self;
}

+ (Class) superclass
{
  return class_get_super_class (self);
}

- autorelease
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
    NSInvocation*	inv;
    NSMethodSignature*	sig;
    BOOL		result;

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
    return [NSString stringWithCString: object_get_class_name(self)];
}

- (void) forwardInvocation: (NSInvocation*)anInvocation
{
    [NSException raise: NSInvalidArgumentException
		    format: @"NSProxy should does not implement '%s'",
				sel_get_name(_cmd)];
}

- (unsigned int) hash
{
    return (unsigned int)self;
}

- init
{
    return self;
}

- (BOOL) isEqual: anObject
{
    return (self == anObject);
}

- (BOOL) isKindOfClass: (Class)aClass
{
    Class class = self->isa;

    while (class != nil) {
	if (class == aClass) {
	    return YES;
	}
	class = class_get_super_class(class);
    }
    return NO;
}

- (BOOL) isMemberOfClass: (Class)aClass
{
    return(self->isa == aClass);
}

- (BOOL) isProxy
{
    return YES;
}

- notImplemented: (SEL)aSel
{
    [NSException raise: NSGenericException
               format: @"NSProxy notImplemented %s", sel_get_name(aSel)];
    return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
    [self notImplemented: _cmd];
    return nil;
}

- perform: (SEL)aSelector
{
    IMP msg = objc_msg_lookup(self, aSelector);

    if (!msg) {
	[NSException raise: NSGenericException
		    format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
	return nil;
    }
    return (*msg)(self, aSelector);
}

- perform: (SEL)aSelector withObject: anObject
{
    IMP msg = objc_msg_lookup(self, aSelector);

    if (!msg) {
	[NSException raise: NSGenericException
		    format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
	return nil;
    }
    return (*msg)(self, aSelector, anObject);
}

- perform: (SEL)aSelector withObject: anObject withObject: anotherObject
{
    IMP msg = objc_msg_lookup(self, aSelector);

    if (!msg) {
	[NSException raise: NSGenericException
		    format: @"invalid selector passed to %s",
				sel_get_name(_cmd)];
	return nil;
    }
    return (*msg)(self, aSelector, anObject, anotherObject);
}

- (void) release
{
    if (_retain_count-- == 0) {
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

- retain
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

- self
{
    return self;
}

- (Class) superclass
{
    return object_get_super_class(self);
}

- (NSZone*)zone
{
    return NSZoneFromPointer(self);
}

@end

