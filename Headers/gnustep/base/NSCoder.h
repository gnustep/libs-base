/* Interface for NSCoder for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

#ifndef __NSCoder_h_GNUSTEP_BASE_INCLUDE
#define __NSCoder_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSZone.h>

@class NSMutableData, NSData, NSString;

@interface NSCoder : NSObject
@end

@interface NSCoderNonCore : NSCoder
@end

@interface NSCoder (Methods)

// Encoding Data

- (void) encodeArrayOfObjCType: (const char*)type
   count: (unsigned)count
   at: (const void*)array;
- (void) encodeBycopyObject: (id)anObject;
- (void) encodeConditionalObject: (id)anObject;
- (void) encodeDataObject: (NSData*)data;
- (void) encodeObject: (id)anObject;
- (void) encodePropertyList: (id)plist;
- (void) encodePoint: (NSPoint)point;
- (void) encodeRect: (NSRect)rect;
- (void) encodeRootObject: (id)rootObject;
- (void) encodeSize: (NSSize)size;
- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address;
- (void) encodeValuesOfObjCTypes: (const char*)types,...;

// Decoding Data

- (void) decodeArrayOfObjCType: (const char*)type
                         count: (unsigned)count
                            at: (void*)address;
- (NSData*) decodeDataObject;
- (id) decodeObject;
- (id) decodePropertyList;
- (NSPoint) decodePoint;
- (NSRect) decodeRect;
- (NSSize) decodeSize;
- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address;
- (void) decodeValuesOfObjCTypes: (const char*)types,...;

// Managing Zones

- (NSZone*) objectZone;
- (void) setObjectZone: (NSZone*)zone;

// Getting a Version

- (unsigned int) systemVersion;
- (unsigned int) versionForClassName: (NSString*)className;

@end

#ifndef NO_GNUSTEP

#include <gnustep/base/Coding.h>
#include <Foundation/NSCoder.h>
@interface NSCoder (GNU) <Encoding, Decoding>
@end

#endif /* NO_GNUSTEP */

#endif	/* __NSCoder_h_GNUSTEP_BASE_INCLUDE */
