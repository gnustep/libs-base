/* NSValue.m - Object encapsulation for C types.
   Copyright (C) 1993, 1994, 1996, 1999 Free Software Foundation, Inc.

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
#include <base/preface.h>
#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSZone.h>

static Class	abstractClass;
static Class	concreteClass;
static Class	nonretainedObjectValueClass;
static Class	pointValueClass;
static Class	pointerValueClass;
static Class	rectValueClass;
static Class	sizeValueClass;
  

@implementation NSValue

+ (void) initialize
{
  if (self == [NSValue class])
    {
      abstractClass = self;
      concreteClass = [NSConcreteValue class];
      nonretainedObjectValueClass = [NSNonretainedObjectValue class];
      pointValueClass = [NSPointValue class];
      pointerValueClass = [NSPointerValue class];
      rectValueClass = [NSRectValue class];
      sizeValueClass = [NSSizeValue class];
    }
}

+ (id) alloc
{
  if (self == abstractClass)
    return NSAllocateObject(concreteClass, 0, NSDefaultMallocZone());
  else
    return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    return NSAllocateObject(concreteClass, 0, z);
  else
    return NSAllocateObject(self, 0, z);
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
  else if (strcmp(@encode(NSRect), type) == 0)
    theClass = rectValueClass;
  else if (strcmp(@encode(NSSize), type) == 0)
    theClass = sizeValueClass;
  
  return theClass;
}

// Allocating and Initializing 

+ (NSValue *)value: (const void *)value
      withObjCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue *)valueWithBytes: (const void *)value
		   objCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue *) valueWithNonretainedObject: (id)anObject
{
  NSValue	*theObj;

  theObj = [NSNonretainedObjectValue allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &anObject objCType: @encode(id)];
  return AUTORELEASE(theObj);
}
	
+ (NSValue *) valueWithPoint: (NSPoint)point
{
  NSValue	*theObj;

  theObj = [NSPointValue allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &point objCType: @encode(NSPoint)];
  return AUTORELEASE(theObj);
}
 
+ (NSValue *)valueWithPointer: (const void *)pointer
{
  NSValue	*theObj;

  theObj = [NSPointerValue allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &pointer objCType: @encode(void*)];
  return AUTORELEASE(theObj);
}

+ (NSValue *)valueWithRect: (NSRect)rect
{
  NSValue	*theObj;

  theObj = [NSRectValue allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &rect objCType: @encode(NSRect)];
  return AUTORELEASE(theObj);
}
 
+ (NSValue *)valueWithSize: (NSSize)size
{
  NSValue	*theObj;

  theObj = [NSSizeValue allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &size objCType: @encode(NSSize)];
  return AUTORELEASE(theObj);
}

+ (NSValue*)valueFromString: (NSString *)string
{
  NSDictionary	*dict = [string propertyList];

  if (!dict)
    return nil;

  if ([dict objectForKey: @"width"] && [dict objectForKey: @"x"])
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
- (void)getValue: (void *)value
{
  [self subclassResponsibility: _cmd];
}

- (BOOL)isEqual: (id)other
{
  if ([other isKindOfClass: [self class]])
    {
	return [self isEqualToValue: other];
    }
  return NO;
}

- (BOOL)isEqualToValue: (NSValue*)other
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (const char *)objCType
{
  [self subclassResponsibility: _cmd];
  return 0;
}
 
- (id)nonretainedObjectValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}
 
- (void *)pointerValue
{
  [self subclassResponsibility: _cmd];
  return 0;
} 

- (NSRect)rectValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeRect(0,0,0,0);
}
 
- (NSSize)sizeValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeSize(0,0);
}
 
- (NSPoint)pointValue
{
  [self subclassResponsibility: _cmd];
  return NSMakePoint(0,0);
}

// NSCoding (done by subclasses)

- (void) encodeWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
  return self;
}

@end

