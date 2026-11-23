/** Scripting additions to NSObject
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Fri Nov  1 00:25:37 EDT 2019

   This file is part of the GNUstep Library.
   
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

#ifndef _NSObjectScripting_h_GNUSTEP_BASE_INCLUDE
#define _NSObjectScripting_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSDictionary, NSScriptObjectSpecifier, NSString;

/**
 * Cocoa scripting hooks for scriptable objects.  These methods are currently
 * unimplemented in GNUstep and raise an exception unless overridden.
 */
@interface NSObject (NSScripting)

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2, GS_API_LATEST)
/** Returns the receiver's scriptable properties. */
- (NSDictionary *) scriptingProperties;

/** Sets the supplied scriptable properties of the receiver. */
- (void) setScriptingProperties: (NSDictionary *)properties;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/** Evaluates an object specifier in the receiving container. */
- (id) scriptingValueForSpecifier: (NSScriptObjectSpecifier *)objectSpecifier;

/** Copies a scripting value and sets the supplied properties on the copies. */
- (id) copyScriptingValue: (id)value
                  forKey: (NSString *)key
          withProperties: (NSDictionary *)properties;

/** Creates a scriptable object with the supplied contents and properties. */
- (id) newScriptingObjectOfClass: (Class)objectClass
                 forValueForKey: (NSString *)key
              withContentsValue: (id)contentsValue
                     properties: (NSDictionary *)properties;
#endif

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSObjectScripting_h_GNUSTEP_BASE_INCLUDE */

