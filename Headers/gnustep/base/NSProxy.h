/* Interface for GNU Objective-C version of NSProxy
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

#ifndef __NSProxy_h_GNUSTEP_BASE_INCLUDE
#define __NSProxy_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <Foundation/NSObject.h>


@interface NSProxy <NSObject>
{
@public
    Class		isa;
@private
    unsigned int	_retain_count;
}

+ (id) alloc;
+ (id) allocWithZone: (NSZone*)zone;
+ (Class) class;
+ (void) load;
+ (BOOL) respondsToSelector: (SEL)aSelector;

- (void) dealloc;
- (NSString*) description;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;

@end

@interface NSProxy(GNUstepExtensions)
- (id) forward: (SEL)aSel :(arglist_t)frame;
@end

@interface Object (IsProxy)
- (BOOL) isProxy;
@end

#endif /* __NSProxy_h_GNUSTEP_BASE_INCLUDE */
