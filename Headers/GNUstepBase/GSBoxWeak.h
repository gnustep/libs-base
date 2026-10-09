/**Interface for GSBoxWeak for GNUStep
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

#ifndef __GSBoxWeak_h_GNUSTEP_BASE_INCLUDE
#define __GSBoxWeak_h_GNUSTEP_BASE_INCLUDE

#import "GNUstepBase/GSConfig.h"
#import "GNUstepBase/GSVersionMacros.h"
#import <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	defined(__APPLE__)
OBJC_EXPORT void objc_destroyWeak(id *location);
OBJC_EXPORT id objc_initWeak(id *location, id val);
OBJC_EXPORT id objc_storeWeak(id *location, id val);
#endif

/** GSBoxWeak is a trivial class to provide an object which holds a weak
 * reference to another object value.  This allows easy use of weak references
 * in non-ARC code, so that you can write code which is portable to compilers
 * and systems other than Clang/Apple.
 */
GS_EXPORT_CLASS
@interface GSBoxWeak : NSObject
{
  id	value;
}
@property (assign, getter=value, setter=setValue:) id value;

/** Creates and returns an autorelease weak reference to the supplied value.
 */
+ (instancetype) boxWeak: (id)v;

/** Initialises an instance as a weak reference to the supplied value.
 */
- (instancetype) initWithValue: (id)v;

/** Sets the receiver as a weak reference to the supplied value.
 */
- (void) setValue: (id)v;

/** Returns the weakly referenced value or nil if the referenced object
 * has been deallocated.
 */
- (id) value;

@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSBoxWeak_h_GNUSTEP_BASE_INCLUDE */
