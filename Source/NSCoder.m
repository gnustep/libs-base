/* NSCoder - coder object for serialization and persistance.
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995
   
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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCoder.h>

@implementation NSCoder

+ (void) initialize
{
  if (self == [NSCoder class])
    behavior_class_add_class (self, [NSCoderNonCore class]);
}

- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address
{
  [self subclassResponsibility:_cmd];
}

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self subclassResponsibility:_cmd];
}

- (void) encodeDataObject: (NSData*)data
{
  [self subclassResponsibility:_cmd];
}

- (NSData*) decodeDataObject
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (unsigned int) versionForClassName: (NSString*)className
{
  [self subclassResponsibility:_cmd];
  return 0;
}

@end

@implementation NSCoderNonCore

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

- (void) encodeBycopyObject: (id)anObject
{
  [self encodeObject:anObject];
}

- (void) encodeByrefObject: (id)anObject
{
  [self encodeObject:anObject];
}

- (void) encodeBytes: (void*)d length: (unsigned)l
{
  const char *type = @encode(unsigned char);
  const unsigned char *where = (const unsigned char*)d;

  [self encodeValueOfObjCType:@encode(unsigned) at:&l];
  while (l-- > 0)
    [self encodeValueOfObjCType:type at:where++];
}

- (void) encodeConditionalObject: (id)anObject
{
  [self encodeObject:anObject];
}

- (void) encodeObject: (id)anObject
{
  [self encodeValueOfObjCType:@encode(id)
	at: &anObject];
}

- (void) encodePropertyList: (id)plist
{
  [self notImplemented:_cmd];
}

- (void) encodePoint: (NSPoint)point
{
  [self encodeValueOfObjCType:@encode(NSPoint)
	at:&point];
}

- (void) encodeRect: (NSRect)rect
{
  [self encodeValueOfObjCType:@encode(NSRect)
	at:&rect];
}

- (void) encodeRootObject: (id)rootObject
{
  [self encodeObject:rootObject];
}

- (void) encodeSize: (NSSize)size
{
  [self encodeValueOfObjCType:@encode(NSSize)
	at:&size];
}

- (void) encodeValuesOfObjCTypes: (const char*)types,...
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
   at: (void*)address
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

- (void*) decodeBytesWithReturnedLength: (unsigned*)l
{
  unsigned count;
  const char *type = @encode(unsigned char);
  int i;
  unsigned char *where;
  unsigned char *array;

  [self decodeValueOfObjCType:@encode(unsigned) at:&count];
  *l = count;
  array = objc_malloc(count);
  while (count-- > 0)
    [self decodeValueOfObjCType:type at:where++];

  [NSData dataWithBytesNoCopy: array length: count];
  return array;
}

- (id) decodeObject
{
  id o;
  [self decodeValueOfObjCType:@encode(id)
	at:&o];
  return [o autorelease];
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

- (void) decodeValuesOfObjCTypes: (const char*)types,...
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

- (NSZone*) objectZone
{
  return NSDefaultMallocZone();
}

- (void) setObjectZone: (NSZone*)zone
{
  ;
}


// Getting a Version

- (unsigned int) systemVersion;
{
  return 1000;
}

@end
