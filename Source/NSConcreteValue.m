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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <config.h>
#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <base/preface.h>
#include <base/fast.x>

/* This is the real, general purpose value object.  I've implemented all the
   methods here (like pointValue) even though most likely, other concrete
   subclasses were created to handle these types */

#define NS_RAISE_MALLOC \
	[NSException raise: NSMallocException \
	    format: @"No memory left to allocate"]

#define NS_CHECK_MALLOC(ptr) \
	if (!ptr) {NS_RAISE_MALLOC;}

@implementation NSConcreteValue

// NSCopying
- (id) deepen
{
  void	*old_ptr;
  char	*old_typ;
  int	size;

  size = objc_sizeof_type(objctype);
  old_ptr = data;
  data = (void *)NSZoneMalloc(fastZone(self), size);
  NS_CHECK_MALLOC(data)
  memcpy(data, old_ptr, size);

  old_typ = objctype;
  objctype = (char *)NSZoneMalloc(fastZone(self), strlen(old_typ)+1);
  NS_CHECK_MALLOC(objctype)
  strcpy(objctype, old_typ);

  return self;
}

// Allocating and Initializing 

- (id) initValue: (const void *)value
      withObjCType: (const char *)type
{
  int	size;
  
  if (!value || !type) 
    {
      NSLog(@"Tried to create NSValue with NULL value or NULL type");
      [self release];
      return nil;
    }

  self = [super init];

  // FIXME: objc_sizeof_type will abort when it finds an invalid type, when
  // we really want to just raise an exception
  size = objc_sizeof_type(type);
  if (size <= 0) 
    {
      NSLog(@"Tried to create NSValue with invalid Objective-C type");
      [self release];
      return nil;
    }

  data = (void *)NSZoneMalloc(fastZone(self), size);
  NS_CHECK_MALLOC(data)
  memcpy(data, value, size);

  objctype = (char *)NSZoneMalloc(fastZone(self), strlen(type)+1);
  NS_CHECK_MALLOC(objctype)
  strcpy(objctype, type);
  return self;
}

- (void) dealloc
{
  if (objctype)
    NSZoneFree(fastZone(self), objctype);
  if (data)
    NSZoneFree(fastZone(self), data);
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
  const char*	type;

  if (fastClass(aValue) != fastClass(self))
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
  int size;
  NSData *rep;

  size = objc_sizeof_type(objctype);
  rep = [NSData dataWithBytes: data length: size];
  return [NSString stringWithFormat: @"(%@) %@", objctype, [rep description]];
}

// NSCoding
- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  // FIXME: Do we need to check for encoding void, void * or will
  // NSCoder do this for us?
  [coder encodeValueOfObjCType: @encode(char *) at: &objctype];
  [coder encodeValueOfObjCType: objctype at: &data];
}

- (id) initWithCoder: (NSCoder *)coder
{
  [NSException raise: NSInconsistentArchiveException
      format: @"Cannot unarchive class - Need NSValueDecoder."];
  return self;
}

@end
