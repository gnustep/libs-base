# line 1 "NSCTemplateValue.m"	/* So gdb knows which file we are in */
/* NSCTemplateValue - Object encapsulation for C types.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
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
#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <base/preface.h>
#include <base/fast.x>

/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 4 cooresponding to each value type */
#if TYPE_ORDER == 0
#  define NSCTemplateValue	NSNonretainedObjectValue
#  define TYPE_METHOD	nonretainedObjectValue
#  define TYPE_NAME	id
#elif TYPE_ORDER == 1
#  define NSCTemplateValue	NSPointValue
#  define TYPE_METHOD	pointValue
#  define TYPE_NAME	NSPoint
#elif TYPE_ORDER == 2
#  define NSCTemplateValue	NSPointerValue
#  define TYPE_METHOD	pointerValue
#  define TYPE_NAME	void *
#elif TYPE_ORDER == 3
#  define NSCTemplateValue	NSRectValue
#  define TYPE_METHOD	rectValue
#  define TYPE_NAME	NSRect
#elif TYPE_ORDER == 4
#  define NSCTemplateValue	NSSizeValue
#  define TYPE_METHOD	sizeValue
#  define TYPE_NAME	NSSize
#endif

@implementation NSCTemplateValue

// Allocating and Initializing 

- (id) initWithBytes: (const void *)value
	    objCType: (const char *)type
{
  typedef __typeof__(data) _dt;
  self = [super init];
  data = *(_dt *)value;
  return self;
}

// Accessing Data 
- (void) getValue: (void *)value
{
  if (!value)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Cannot copy value into NULL buffer"];
	/* NOT REACHED */
    }
  memcpy( value, &data, objc_sizeof_type([self objCType]) );
}

- (BOOL) isEqual: (id)other
{
  if (other != nil && fastInstanceIsKindOfClass(other, fastClass(self)))
    {
      return [self isEqualToValue: other];
    }
  return NO;
}

- (BOOL) isEqualToValue: (NSValue*)aValue
{
  typedef __typeof__(data) _dt;

  if (aValue != nil && fastInstanceIsKindOfClass(aValue, fastClass(self)))
    {
      _dt	val = [aValue TYPE_METHOD];
#if TYPE_ORDER == 0
      return [data isEqual: val];
#elif TYPE_ORDER == 1
      if (data.x == val.x && data.y == val.y)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 2
      if (data == val)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 3
      if (data.origin.x == val.origin.x && data.origin.y == val.origin.y
	&& data.size.width == val.size.width
	&& data.size.height == val.size.height)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 4
      if (data.width == val.width && data.height == val.height)
	return YES;
      else
	return NO;
#endif
    }
  return NO;
}

- (unsigned) hash
{
#if TYPE_ORDER == 0
  return [data hash];
#elif TYPE_ORDER == 1
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned      hash = 0;
  int           i;

  val.d = data.x + data.y;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#elif TYPE_ORDER == 2
  return (unsigned)(gsaddr)data;
#elif TYPE_ORDER == 3
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned      hash = 0;
  int           i;

  val.d = data.origin.x + data.origin.y + data.size.width + data.size.height;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#elif TYPE_ORDER == 4
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned      hash = 0;
  int           i;

  val.d = data.width + data.height;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#endif
}

- (const char *)objCType
{
  typedef __typeof__(data) _dt;
  return @encode(_dt);
}
 
- (TYPE_NAME)TYPE_METHOD
{
  return data;
}

- (NSString *) description
{
#if TYPE_ORDER == 0
  return [NSString stringWithFormat: @"{object = %@;}", [data description]];
#elif TYPE_ORDER == 1
  return NSStringFromPoint(data);
#elif TYPE_ORDER == 2
  return [NSString stringWithFormat: @"{pointer = %p;}", data];
#elif TYPE_ORDER == 3
  return NSStringFromRect(data);
#elif TYPE_ORDER == 4
  return NSStringFromSize(data);
#endif
}

// NSCoding
- (void) encodeWithCoder: (NSCoder *)coder
{
#if	TYPE_ORDER == 0
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to encode a non-retained object"];
#elif	TYPE_ORDER == 2
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to encode a pointer to void object"];
#else
  [coder encodeValueOfObjCType: @encode(TYPE_NAME) at: &data];
#endif
}

- (id) initWithCoder: (NSCoder *)coder
{
  [coder decodeValueOfObjCType: @encode(TYPE_NAME) at: &data];
  return self;
}

@end
