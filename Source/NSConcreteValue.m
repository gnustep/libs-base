/* NSConcreteValue - Object encapsulation for C types.
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
#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSObjCRuntime.h>
#include <base/preface.h>

/* This is the real, general purpose value object.  I've implemented all the
   methods here (like pointValue) even though most likely, other concrete
   subclasses were created to handle these types */

@implementation NSConcreteValue

// Allocating and Initializing 

- (id) initWithBytes: (const void *)value
	    objCType: (const char *)type
{
  int	size;
  
  if (!value || !type) 
    {
      NSLog(@"Tried to create NSValue with NULL value or NULL type");
      RELEASE(self);
      return nil;
    }

  self = [super init];

  // FIXME: objc_sizeof_type will abort when it finds an invalid type, when
  // we really want to just raise an exception
  size = objc_sizeof_type(type);
  if (size <= 0) 
    {
      NSLog(@"Tried to create NSValue with invalid Objective-C type");
      RELEASE(self);
      return nil;
    }

  data = (void *)NSZoneMalloc(GSObjCZone(self), size);
  memcpy(data, value, size);

  objctype = (char *)NSZoneMalloc(GSObjCZone(self), strlen(type)+1);
  strcpy(objctype, type);
  return self;
}

- (void) dealloc
{
  if (objctype)
    NSZoneFree(GSObjCZone(self), objctype);
  if (data)
    NSZoneFree(GSObjCZone(self), data);
  [super dealloc];
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
  memcpy(value, data, objc_sizeof_type(objctype));
}

- (unsigned) hash
{
  unsigned	size = objc_sizeof_type(objctype);
  unsigned	hash = 0;

  while (size-- > 0)
    hash += ((unsigned char*)data)[size];
  return hash;
}

- (BOOL) isEqualToValue: (NSValue*)aValue
{
  if (aValue == nil)
    return NO;
  if (GSObjCClass(aValue) != GSObjCClass(self))
    return NO;
  if (strcmp(objctype, ((NSConcreteValue*)aValue)->objctype) != 0)
    return NO;
  else
    {
      unsigned	size = objc_sizeof_type(objctype);

      if (memcmp(((NSConcreteValue*)aValue)->data, data, size) != 0)
	return NO;
      return YES;
    }
}

- (const char *)objCType
{
  return objctype;
}
 
// FIXME: need to check to make sure these hold the right values...
- (id) nonretainedObjectValue
{
  return *((id *)data);
}
 
- (void *) pointerValue
{
  return *((void **)data);
} 

- (NSRect) rectValue
{
  return *((NSRect *)data);
}
 
- (NSSize) sizeValue
{
  return *((NSSize *)data);
}
 
- (NSPoint) pointValue
{
  return *((NSPoint *)data);
}

- (NSString *) description
{
  unsigned	size;
  NSData	*rep;

  size = objc_sizeof_type(objctype);
  rep = [NSData dataWithBytes: data length: size];
  return [NSString stringWithFormat: @"(%@) %@", objctype, [rep description]];
}

// NSCoding
- (void) encodeWithCoder: (NSCoder *)coder
{
  unsigned	size;

  size = strlen(objctype)+1;
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
  [coder encodeArrayOfObjCType: @encode(char) count: size at: objctype];
  size = objc_sizeof_type(objctype);
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
