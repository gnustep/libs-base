/* NSCoder - coder obejct for serialization and persistance.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

   This file is part of the GNU Objective C Class Library.

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

#include <foundation/NSCoder.h>

@implementation NSCoder

// Encoding Data

- (void)encodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(const void *)array
{
    [self notImplemented:_cmd];
}
		
- (void)encodeBycopyObject:(id)anObject;
{
    [self notImplemented:_cmd];
}

- (void)encodeConditionalObject:(id)anObject;
{
    [self notImplemented:_cmd];
}
  
- (void)encodeDataObject:(NSData *)data;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeObject:(id)anObject;
{
    [self notImplemented:_cmd];
}
 
- (void)encodePropertyList:(id)plist;
{
    [self notImplemented:_cmd];
}
 
- (void)encodePoint:(NSPoint)point;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeRect:(NSRect)rect;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeRootObject:(id)rootObject;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeSize:(NSSize)size;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeValueOfObjCType:(const char *)type
                           at:(const void *)address;
{
    [self notImplemented:_cmd];
}
		
- (void)encodeValuesOfObjCTypes:(const char *)types,...;
{
    [self notImplemented:_cmd];
}

// Decoding Data

- (void)decodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(void *)address;
{
    [self notImplemented:_cmd];
}
		
- (NSData *)decodeDataObject;
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (id)decodeObject;
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (id)decodePropertyList
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (NSPoint)decodePoint
{
    NSPoint point;
    [self notImplemented:_cmd];
    return point;
}
 
- (NSRect)decodeRect
{
    NSRect rect;
    [self notImplemented:_cmd];
    return rect;
}

- (NSSize)decodeSize
{
    NSSize size;
    [self notImplemented:_cmd];
    return size;
}
 
- (void)decodeValueOfObjCType:(const char *)type
                           at:(void *)address
{
    [self notImplemented:_cmd];
}
 
- (void)decodeValuesOfObjCTypes:(const char *)types,...;
{
    [self notImplemented:_cmd];
}

// Managing Zones

- (NSZone *)objectZone;
{
    [self notImplemented:_cmd];
    return (NSZone *)0;
}
 
- (void)setObjectZone:(NSZone *)zone;
{
    [self notImplemented:_cmd];
}


// Getting a Version

- (unsigned int)systemVersion;
{
    [self notImplemented:_cmd];
    return 0;
}
 
- (unsigned int)versionForClassName:(NSString *)className;
{
    [self notImplemented:_cmd];
    return 0;
}
	
@end
/* From:
 * (Preliminary Documentation) Copyright (c) 1994 by NeXT Computer, Inc.  
 * All Rights Reserved.
 *
 * NSCoder 
 *
 */
 
#include "NSCoder.h"

@implementation NSCoder

// Encoding Data

- (void)encodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(const void *)array
{
    [self notImplemented:_cmd];
}


		
- (void)encodeBycopyObject:(id)anObject;
{
    [self notImplemented:_cmd];
}

- (void)encodeConditionalObject:(id)anObject;
{
    [self notImplemented:_cmd];
}
  
- (void)encodeDataObject:(NSData *)data;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeObject:(id)anObject;
{
    [self notImplemented:_cmd];
}
 
- (void)encodePropertyList:(id)plist;
{
    [self notImplemented:_cmd];
}
 
- (void)encodePoint:(NSPoint)point;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeRect:(NSRect)rect;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeRootObject:(id)rootObject;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeSize:(NSSize)size;
{
    [self notImplemented:_cmd];
}
 
- (void)encodeValueOfObjCType:(const char *)type
                           at:(const void *)address;
{
    [self notImplemented:_cmd];
}
		
- (void)encodeValuesOfObjCTypes:(const char *)types,...;
{
    [self notImplemented:_cmd];
}

// Decoding Data

- (void)decodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(void *)address;
{
    [self notImplemented:_cmd];
}
		
- (NSData *)decodeDataObject;
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (id)decodeObject;
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (id)decodePropertyList
{
    [self notImplemented:_cmd];
    return nil;
}
 
- (NSPoint)decodePoint
{
    NSPoint point;
    [self notImplemented:_cmd];
    return point;
}
 
- (NSRect)decodeRect
{
    NSRect rect;
    [self notImplemented:_cmd];
    return rect;
}

- (NSSize)decodeSize
{
    NSSize size;
    [self notImplemented:_cmd];
    return size;
}
 
- (void)decodeValueOfObjCType:(const char *)type
                           at:(void *)address
{
    [self notImplemented:_cmd];
}
 
- (void)decodeValuesOfObjCTypes:(const char *)types,...;
{
    [self notImplemented:_cmd];
}

// Managing Zones

- (NSZone *)objectZone;
{
    [self notImplemented:_cmd];
    return (NSZone *)0;
}
 
- (void)setObjectZone:(NSZone *)zone;
{
    [self notImplemented:_cmd];
}


// Getting a Version

- (unsigned int)systemVersion;
{
    [self notImplemented:_cmd];
   return 0;
}
 
- (unsigned int)versionForClassName:(NSString *)className;
{
    [self notImplemented:_cmd];
   return 0;
}
	
@end
