/* NSCoder - coder object for serialization and persistance.
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
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

#include <objects/stdobjects.h>
#include <foundation/NSCoder.h>
#include <foundation/NSGCoder.h>
#include <objects/NSCoder.h>

@implementation NSCoder

// Encoding Data

- (void) encodeArrayOfObjCType: (const char*)type
   count: (unsigned)count
   at: (const void*)array
{
  int i, size = objc_sizeof_type(type);
  const char *where = array;

  [self encodeValueOfObjCType:@encode(unsigned)
	at:&count];
  for (i = 0; i < count; i++, where += size)
    [self encodeValueOfObjCType:type
	  at:where];
}

- (void) encodeBycopyObject: (id)anObject;
{
  [self encodeObject:anObject];
}

- (void) encodeConditionalObject: (id)anObject;
{
  [self encodeObject:anObject];
}

- (void) encodeDataObject: (NSData*)data;
{
  [self notImplemented:_cmd];
}

- (void) encodeObject: (id)anObject;
{
  [self notImplemented:_cmd];
}

- (void) encodePropertyList: (id)plist;
{
  [self notImplemented:_cmd];
}

- (void) encodePoint: (NSPoint)point;
{
  [self encodeValueOfObjCType:@encode(NSPoint)
	at:&point];
}

- (void) encodeRect: (NSRect)rect;
{
  [self encodeValueOfObjCType:@encode(NSRect)
	at:&rect];
}

- (void) encodeRootObject: (id)rootObject;
{
  [self encodeObject:rootObject];
}

- (void) encodeSize: (NSSize)size;
{
  [self encodeValueOfObjCType:@encode(NSSize)
	at:&size];
}

- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address;
{
  [self notImplemented:_cmd];
}

- (void) encodeValuesOfObjCTypes: (const char*)types,...;
{
  va_list ap;
  va_start(ap, types);
  while (*types)
    {
      [self encodeValueOfObjCType:types
	    at:va_arg(ap, void*)];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

// Decoding Data

- (void) decodeArrayOfObjCType: (const char*)type
   count: (unsigned)count
   at: (void*)address;
{
  unsigned encoded_count;
  int i, size = objc_sizeof_type(type);
  char *where = address;

  [self decodeValueOfObjCType:@encode(unsigned)
	at:&encoded_count];
  assert(encoded_count == count); /* xxx fix this */
  for (i = 0; i < count; i++, where += size)
    [self decodeValueOfObjCType:type
	  at:where];
}

- (NSData*) decodeDataObject;
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) decodeObject;
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) decodePropertyList
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSPoint) decodePoint
{
  NSPoint point;
  [self decodeValueOfObjCType:@encode(NSPoint)
	at:&point];
  return point;
}

- (NSRect) decodeRect
{
  NSRect rect;
  [self decodeValueOfObjCType:@encode(NSRect)
	at:&rect];
  return rect;
}

- (NSSize) decodeSize
{
  NSSize size;
  [self decodeValueOfObjCType:@encode(NSSize)
	at:&size];
  return size;
}

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self notImplemented:_cmd];
}

- (void) decodeValuesOfObjCTypes: (const char*)types,...;
{
  va_list ap;
  va_start(ap, types);
  while (*types)
    {
      [self decodeValueOfObjCType:types
	    at:va_arg(ap, void*)];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

// Managing Zones

- (NSZone*) objectZone;
{
  [self notImplemented:_cmd];
  return (NSZone*)0;
}

- (void) setObjectZone: (NSZone*)zone;
{
  [self notImplemented:_cmd];
}


// Getting a Version

- (unsigned int) systemVersion;
{
  [self notImplemented:_cmd];
  return 0;
}

- (unsigned int) versionForClassName: (NSString*)className;
{
  [self notImplemented:_cmd];
  return 0;
}

@end
