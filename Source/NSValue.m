/** NSValue.m - Object encapsulation for C types.
   Copyright (C) 1993, 1994, 1996, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995
   Updated by:  Richard frith-Macdonald <rfm@gnu.org>
   Date: Jan 2001

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
#include <base/preface.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>

@interface	GSPlaceholderValue : NSValue
@end

@class	GSValue;
@class	GSNonretainedObjectValue;
@class	GSPointValue;
@class	GSPointerValue;
@class	GSRangeValue;
@class	GSRectValue;
@class	GSSizeValue;

static Class	abstractClass;
static Class	concreteClass;
static Class	nonretainedObjectValueClass;
static Class	pointValueClass;
static Class	pointerValueClass;
static Class	rangeValueClass;
static Class	rectValueClass;
static Class	sizeValueClass;
static Class	GSPlaceholderValueClass;


static GSPlaceholderValue	*defaultPlaceholderValue;
static NSMapTable		*placeholderMap;
static NSLock			*placeholderLock;

@implementation NSValue

+ (void) initialize
{
  if (self == [NSValue class])
    {
      abstractClass = self;
      [abstractClass setVersion: 1];	// Version 1
      concreteClass = [GSValue class];
      nonretainedObjectValueClass = [GSNonretainedObjectValue class];
      pointValueClass = [GSPointValue class];
      pointerValueClass = [GSPointerValue class];
      rangeValueClass = [GSRangeValue class];
      rectValueClass = [GSRectValue class];
      sizeValueClass = [GSSizeValue class];
      GSPlaceholderValueClass = [GSPlaceholderValue class];

      /*
       * Set up infrastructure for placeholder values.
       */
      defaultPlaceholderValue = (GSPlaceholderValue*)
	NSAllocateObject(GSPlaceholderValueClass, 0, NSDefaultMallocZone());
      placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      placeholderLock = [NSLock new];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    {
      if (z == NSDefaultMallocZone() || z == 0)
	{
	  /*
	   * As a special case, we can return a placeholder for a value
	   * in the default malloc zone extremely efficiently.
	   */
	  return defaultPlaceholderValue;
	}
      else
	{
	  id	obj;

	  /*
	   * For anything other than the default zone, we need to
	   * locate the correct placeholder in the (lock protected)
	   * table of placeholders.
	   */
	  [placeholderLock lock];
	  obj = (id)NSMapGet(placeholderMap, (void*)z);
	  if (obj == nil)
	    {
	      /*
	       * There is no placeholder object for this zone, so we
	       * create a new one and use that.
	       */
	      obj = (id)NSAllocateObject(GSPlaceholderValueClass, 0, z);
	      NSMapInsert(placeholderMap, (void*)z, (void*)obj);
	    }
	  [placeholderLock unlock];
	  return obj;
	}
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

// NSCopying - always a simple retain.

- (id) copy
{
  return RETAIN(self);
}

- (id) copyWithZone: (NSZone *)zone
{
  return RETAIN(self);
}

/* Returns the concrete class associated with the type encoding */
+ (Class) valueClassWithObjCType: (const char *)type
{
  Class	theClass = concreteClass;

  /* Let someone else deal with this error */
  if (!type)
    return theClass;

  if (strcmp(@encode(id), type) == 0)
    theClass = nonretainedObjectValueClass;
  else if (strcmp(@encode(NSPoint), type) == 0)
    theClass = pointValueClass;
  else if (strcmp(@encode(void *), type) == 0)
    theClass = pointerValueClass;
  else if (strcmp(@encode(NSRange), type) == 0)
    theClass = rangeValueClass;
  else if (strcmp(@encode(NSRect), type) == 0)
    theClass = rectValueClass;
  else if (strcmp(@encode(NSSize), type) == 0)
    theClass = sizeValueClass;
  
  return theClass;
}

// Allocating and Initializing 

+ (NSValue*) value: (const void *)value
      withObjCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue*) valueWithBytes: (const void *)value
		   objCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue*) valueWithNonretainedObject: (id)anObject
{
  NSValue	*theObj;

  theObj = [nonretainedObjectValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &anObject objCType: @encode(id)];
  return AUTORELEASE(theObj);
}
	
+ (NSValue*) valueWithPoint: (NSPoint)point
{
  NSValue	*theObj;

  theObj = [pointValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &point objCType: @encode(NSPoint)];
  return AUTORELEASE(theObj);
}
 
+ (NSValue*) valueWithPointer: (const void *)pointer
{
  NSValue	*theObj;

  theObj = [pointerValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &pointer objCType: @encode(void*)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueWithRange: (NSRange)range
{
  NSValue	*theObj;

  theObj = [rangeValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &range objCType: @encode(NSRange)];
  return AUTORELEASE(theObj);
}
 
+ (NSValue*) valueWithRect: (NSRect)rect
{
  NSValue	*theObj;

  theObj = [rectValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &rect objCType: @encode(NSRect)];
  return AUTORELEASE(theObj);
}
 
+ (NSValue*) valueWithSize: (NSSize)size
{
  NSValue	*theObj;

  theObj = [sizeValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &size objCType: @encode(NSSize)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueFromString: (NSString *)string
{
  NSDictionary	*dict = [string propertyList];

  if (dict == nil)
    return nil;

  if ([dict objectForKey: @"location"])
    {
      NSRange range;
      range = NSMakeRange([[dict objectForKey: @"location"] intValue],
			[[dict objectForKey: @"length"] intValue]);
    }
  else if ([dict objectForKey: @"width"] && [dict objectForKey: @"x"])
    {
      NSRect rect;
      rect = NSMakeRect([[dict objectForKey: @"x"] floatValue],
		       [[dict objectForKey: @"y"] floatValue],
		       [[dict objectForKey: @"width"] floatValue],
		       [[dict objectForKey: @"height"] floatValue]);
      return [abstractClass valueWithRect: rect];
    }
  else if ([dict objectForKey: @"width"])
    {
      NSSize size;
      size = NSMakeSize([[dict objectForKey: @"width"] floatValue],
			[[dict objectForKey: @"height"] floatValue]);
      return [abstractClass valueWithSize: size];
    }
  else if ([dict objectForKey: @"x"])
    {
      NSPoint point;
      point = NSMakePoint([[dict objectForKey: @"x"] floatValue],
			[[dict objectForKey: @"y"] floatValue]);
      return [abstractClass valueWithPoint: point];
    }
  return nil;
}

- (id) initWithBytes: (const void*)data objCType: (const char*)type
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Accessing Data 
/* All the rest of these methods must be implemented by a subclass */
- (void) getValue: (void *)value
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: [self class]])
    {
      return [self isEqualToValue: other];
    }
  return NO;
}

- (BOOL) isEqualToValue: (NSValue*)other
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (const char *) objCType
{
  [self subclassResponsibility: _cmd];
  return 0;
}
 
- (id) nonretainedObjectValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}
 
- (void *) pointerValue
{
  [self subclassResponsibility: _cmd];
  return 0;
} 

- (NSRange) rangeValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeRange(0,0);
}
 
- (NSRect) rectValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeRect(0,0,0,0);
}
 
- (NSSize) sizeValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeSize(0,0);
}
 
- (NSPoint) pointValue
{
  [self subclassResponsibility: _cmd];
  return NSMakePoint(0,0);
}

- (Class) classForCoder
{
  return abstractClass;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  unsigned	size;
  char		*data;
  const char	*objctype = [self objCType];
  NSMutableData	*d;

  size = strlen(objctype)+1;
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
  [coder encodeArrayOfObjCType: @encode(signed char) count: size at: objctype];
  size = objc_sizeof_type(objctype);
  data = (void *)NSZoneMalloc(GSObjCZone(self), size);
  [self getValue: (void*)data];
  d = [NSMutableData new];
  [d serializeDataAt: data ofObjCType: objctype context: nil];
  [coder encodeValueOfObjCType: @encode(id) at: &d];
  RELEASE(d);
  NSZoneFree(NSDefaultMallocZone(), data);
}

- (id) initWithCoder: (NSCoder *)coder
{
  char		type[64];
  const char	*objctype;
  Class		c;
  id		o;
  unsigned	size;
  int		ver;

  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
  /*
   * For almost all type encodings, we can use space on the stack,
   * but to handle exceptionally large ones (possibly some huge structs)
   * we have a strategy of allocating and deallocating heap space too.
   */
  if (size <= 64)
    {
      objctype = type;
    }
  else
    {
      objctype = (void*)NSZoneMalloc(NSDefaultMallocZone(), size);
    }
  [coder decodeArrayOfObjCType: @encode(signed char)
			 count: size
			    at: (void*)objctype];
  c = [abstractClass valueClassWithObjCType: objctype];
  o = [c allocWithZone: [coder objectZone]];

  ver = [coder versionForClassName: @"NSValue"];
  if (ver < 1)
    {
      if (c == pointValueClass)
	{
	  NSPoint	v;

	  [coder decodeValueOfObjCType: @encode(NSPoint) at: &v];
	  o = [o initWithBytes: &v objCType: @encode(NSPoint)];
	}
      else if (c == sizeValueClass)
	{
	  NSSize	v;

	  [coder decodeValueOfObjCType: @encode(NSSize) at: &v];
	  o = [o initWithBytes: &v objCType: @encode(NSSize)];
	}
      else if (c == rangeValueClass)
	{
	  NSRange	v;

	  [coder decodeValueOfObjCType: @encode(NSRange) at: &v];
	  o = [o initWithBytes: &v objCType: @encode(NSRange)];
	}
      else if (c == rectValueClass)
	{
	  NSRect	v;

	  [coder decodeValueOfObjCType: @encode(NSRect) at: &v];
	  o = [o initWithBytes: &v objCType: @encode(NSRect)];
	}
      else
	{
	  unsigned char	*data;

	  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
	  data = (void *)NSZoneMalloc(NSDefaultMallocZone(), size);
	  [coder decodeArrayOfObjCType: @encode(unsigned char)
				 count: size
				    at: (void*)data];
	  o = [o initWithBytes: data objCType: objctype];
	  NSZoneFree(NSDefaultMallocZone(), data);
	}
    }
  else
    {
      NSData		*d;
      unsigned		cursor = 0;

      /*
       * For performance, decode small values directly onto the stack,
       * For larger values we allocate and deallocate heap space.  
       */
      size = objc_sizeof_type(objctype);
      if (size <= 64)
	{
	  unsigned char	data[size];

	  [coder decodeValueOfObjCType: @encode(id) at: &d];
	  [d deserializeDataAt: data
		    ofObjCType: objctype
		      atCursor: &cursor
		       context: nil];
	  o = [o initWithBytes: data objCType: objctype];
	  RELEASE(d);
	}
      else
	{
	  unsigned char	*data;

	  data = (void *)NSZoneMalloc(NSDefaultMallocZone(), size);
	  [coder decodeValueOfObjCType: @encode(id) at: &d];
	  [d deserializeDataAt: data
		    ofObjCType: objctype
		      atCursor: &cursor
		       context: nil];
	  o = [o initWithBytes: data objCType: objctype];
	  RELEASE(d);
	  NSZoneFree(NSDefaultMallocZone(), data);
	}
    }
  if (objctype != type)
    {
      NSZoneFree(NSDefaultMallocZone(), (void*)objctype);
    }
  RELEASE(self);
  self = o;
  return self;
}

@end



@implementation	GSPlaceholderValue

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised value");
  return self;		// placeholders never get released.
}

- (void) dealloc
{
  return;		// placeholders never get deallocated.
}

- (void) getData: (void*)data
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised value"];
}

- (id) initWithBytes: (const void*)data objCType: (const char*)type
{
  Class		c = [abstractClass valueClassWithObjCType: type];

  self = (id)NSAllocateObject(c, 0, GSObjCZone(self));
  return [self initWithBytes: data objCType: type];
}

- (const char*) objCType
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised value"];
  return 0;
}

- (void) release
{
  return;		// placeholders never get released.
}

- (id) retain
{
  return self;		// placeholders never get retained.
}
@end

