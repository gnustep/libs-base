/* GSValue - Object encapsulation for C types.
   Copyright (C) 1993,1994,1995,1999 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <config.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSObjCRuntime.h>
#include <base/preface.h>

@interface GSValue : NSValue
{
  void *data;
  char *objctype;
}
@end

/* This is the real, general purpose value object.  I've implemented all the
   methods here (like pointValue) even though most likely, other concrete
   subclasses were created to handle these types */

@implementation GSValue

static inline int
typeSize(const char* type)
{
  switch (*type)
    {
      case _C_ID:	return sizeof(id);
      case _C_CLASS:	return sizeof(Class);
      case _C_SEL:	return sizeof(SEL);
      case _C_CHR:	return sizeof(char);
      case _C_UCHR:	return sizeof(unsigned char);
      case _C_SHT:	return sizeof(short);
      case _C_USHT:	return sizeof(unsigned short);
      case _C_INT:	return sizeof(int);
      case _C_UINT:	return sizeof(unsigned int);
      case _C_LNG:	return sizeof(long);
      case _C_ULNG:	return sizeof(unsigned long);
      case _C_LNG_LNG:	return sizeof(long long);
      case _C_ULNG_LNG:	return sizeof(unsigned long long);
      case _C_FLT:	return sizeof(float);
      case _C_DBL:	return sizeof(double);
      case _C_PTR:	return sizeof(void*);
      case _C_CHARPTR:	return sizeof(char*);
      case _C_BFLD:
      case _C_ARY_B:
      case _C_UNION_B:
      case _C_STRUCT_B:	return objc_sizeof_type(type);
      case _C_VOID:	return 0;
      default:		return -1;
    }
}

// Allocating and Initializing 

- (id) initWithBytes: (const void *)value
	    objCType: (const char *)type
{
  if (!value || !type) 
    {
      NSLog(@"Tried to create NSValue with NULL value or NULL type");
      RELEASE(self);
      return nil;
    }

  self = [super init];
  if (self != nil)
    {
      int	size = typeSize(type);
  
      if (size < 0) 
	{
	  NSLog(@"Tried to create NSValue with invalid Objective-C type");
	  RELEASE(self);
	  return nil;
	}
      if (size > 0)
	{
	  data = (void *)NSZoneMalloc(GSObjCZone(self), size);
	  memcpy(data, value, size);
	}
      objctype = (char *)NSZoneMalloc(GSObjCZone(self), strlen(type)+1);
      strcpy(objctype, type);
    }
  return self;
}

- (void) dealloc
{
  if (objctype != 0)
    NSZoneFree(GSObjCZone(self), objctype);
  if (data != 0)
    NSZoneFree(GSObjCZone(self), data);
  [super dealloc];
}

// Accessing Data 
- (void) getValue: (void *)value
{
  unsigned	size;

  size = (unsigned)typeSize(objctype);
  if (size > 0)
    {
      if (value != 0)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Cannot copy value into NULL buffer"];
	  /* NOT REACHED */
	}
      memcpy(value, data, size);
    }
}

- (unsigned) hash
{
  unsigned	size = typeSize(objctype);
  unsigned	hash = 0;

  while (size-- > 0)
    {
      hash += ((unsigned char*)data)[size];
    }
  return hash;
}

- (BOOL) isEqualToValue: (NSValue*)aValue
{
  if (aValue == nil)
    return NO;
  if (GSObjCClass(aValue) != GSObjCClass(self))
    return NO;
  if (strcmp(objctype, ((GSValue*)aValue)->objctype) != 0)
    return NO;
  else
    {
      unsigned	size = (unsigned)typeSize(objctype);

      if (memcmp(((GSValue*)aValue)->data, data, size) != 0)
	return NO;
      return YES;
    }
}

- (const char *)objCType
{
  return objctype;
}
 
- (id) nonretainedObjectValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(void*))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as object", size];
    }
  return *((id *)data);
}
 
- (NSPoint) pointValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(NSPoint))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as NSPoint", size];
    }
  return *((NSPoint *)data);
}

- (void *) pointerValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(void*))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as pointer", size];
    }
  return *((void **)data);
}

- (NSRect) rectValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(NSRect))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as NSRect", size];
    }
  return *((NSRect *)data);
}
 
- (NSSize) sizeValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(NSSize))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as NSSize", size];
    }
  return *((NSSize *)data);
}
 
- (NSString *) description
{
  unsigned	size;
  NSData	*rep;

  size = (unsigned)typeSize(objctype);
  rep = [NSData dataWithBytes: data length: size];
  return [NSString stringWithFormat: @"(%s) %@", objctype, [rep description]];
}

// NSCoding
- (void) encodeWithCoder: (NSCoder *)coder
{
  unsigned	size;

  size = strlen(objctype)+1;
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
  [coder encodeArrayOfObjCType: @encode(char) count: size at: objctype];
  size = (unsigned)typeSize(objctype);
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
  [coder encodeArrayOfObjCType: @encode(unsigned char) count: size at: data];
}

- (id) initWithCoder: (NSCoder *)coder
{
  unsigned	size;

  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
  objctype = (void *)NSZoneMalloc(GSObjCZone(self), size);
  [coder decodeArrayOfObjCType: @encode(char) count: size at: objctype];
  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
  data = (void *)NSZoneMalloc(GSObjCZone(self), size);
  [coder decodeArrayOfObjCType: @encode(unsigned char) count: size at: data];

  return self;
}

@end
