/* NSValue.h - Object encapsulation for C types.
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

#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSCoder.h>

@implementation NSValue

// NSCopying
/* deepening is done by concrete subclasses */
- deepen
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
    	return [self retain];
    else
    	return [[super copyWithZone:zone] deepen];
}

/* Returns the concrete class associated with the type encoding */
+ (Class)valueClassWithObjCType:(const char *)type
{
    Class theClass = [NSConcreteValue class];

    /* Let someone else deal with this error */
    if (!type)
	return theClass;

    if (strcmp(@encode(id), type) == 0)
	theClass = [NSNonretainedObjectValue class];
    else if (strcmp(@encode(NSPoint), type) == 0)
	theClass = [NSPointValue class];
    else if (strcmp(@encode(void *), type) == 0)
	theClass = [NSPointerValue class];
    else if (strcmp(@encode(NSRect), type) == 0)
	theClass = [NSRectValue class];
    else if (strcmp(@encode(NSSize), type) == 0)
	theClass = [NSSizeValue class];
    
    return theClass;
}

// Allocating and Initializing 

+ (NSValue *)value:(const void *)value
      withObjCType:(const char *)type
{
    Class theClass = [self valueClassWithObjCType:type];
    return [[[theClass alloc] initValue:value withObjCType:type]
    		autorelease];
}
		
+ (NSValue *)valueWithNonretainedObject: (id)anObject
{
    return [[[NSNonretainedObjectValue alloc] 
    		initValue:&anObject withObjCType:@encode(id)]
    		autorelease];
}
	
+ (NSValue *)valueWithPoint:(NSPoint)point
{
    return [[[NSPointValue alloc] 
    		initValue:&point withObjCType:@encode(NSPoint)]
    		autorelease];
}
 
+ (NSValue *)valueWithPointer:(const void *)pointer
{
    return [[[NSPointerValue alloc] 
    		initValue:&pointer withObjCType:@encode(void*)]
    		autorelease];
}

+ (NSValue *)valueWithRect:(NSRect)rect
{
    return [[[NSRectValue alloc] initValue:&rect withObjCType:@encode(NSRect)]
    		autorelease];
}
 
+ (NSValue *)valueWithSize:(NSSize)size
{
    return [[[NSSizeValue alloc] initValue:&size withObjCType:@encode(NSSize)]
    		autorelease];
}

// Accessing Data 
/* All the rest of these methods must be implemented by a subclass */
- (void)getValue:(void *)value
{
    [self doesNotRecognizeSelector:_cmd];
}

- (const char *)objCType
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}
 
// FIXME: Is this an error or an exception???
- (id)nonretainedObjectValue
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}
 
- (void *)pointerValue
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
} 

- (NSRect)rectValue
{
    [self doesNotRecognizeSelector:_cmd];
    return NSMakeRect(0,0,0,0);
}
 
- (NSSize)sizeValue
{
    [self doesNotRecognizeSelector:_cmd];
    return NSMakeSize(0,0);
}
 
- (NSPoint)pointValue
{
    [self doesNotRecognizeSelector:_cmd];
    return NSMakePoint(0,0);
}

// NSCoding (done by subclasses)
- classForCoder
{
    return [self class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
//FIXME    [super encodeWithCoder:coder];
}

- (id)initWithCoder:(NSCoder *)coder
{
//FIXME    self = [super initWithCoder:coder];
    return self;
}

@end

