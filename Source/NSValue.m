/* NSValue.h - Object encapsulation for C types.
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

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

#include <gnustep/base/prefix.h>
#include <Foundation/NSConcreteValue.h>
#include <Foundation/NSCoder.h>

/* NSValueDecoder is a Class whose only purpose is to decode coded NSValue
   objects.  The only method(s) that should ever be called are +newWithCoder:
   or -initWithCoder:.  Should disallow any other method calls... */
@interface NSValueDecoder : NSValue
{
}

@end

@implementation NSValueDecoder

- initValue:(const void *)value
      withObjCType:(const char *)type
{
    [self shouldNotImplement:_cmd];
    return self;
}

/* xxx What's going on here?  This doesn't look right to me -mccallum. */
#if 0
+ (id) newWithCoder: (NSCoder *)coder
{
    char *type;
    void *data;
    id   new_value;

    [coder decodeValueOfObjCType:@encode(char *) at:&type];
    [coder decodeValueOfObjCType:type at:&data];
    /* Call NSNumber's implementation of this method, because NSValueDecoder
       also stores NSNumber types */
    new_value = [[NSNumber valueClassWithObjCType:type] 
	allocWithZone:[coder objectZone]];
    [new_value initValue:data withObjCType:type];
    OBJC_FREE(data);
    OBJC_FREE(type);
    return new_value;
}

/* Are you convinced that +newWithCoder is a better idea?  Otherwise we
   have to release ourselves and return a new instance of the correct
   object. We hope that the calling method knows this and has nested the
   alloc and init calls or knows that the object has been replaced. */
- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder:coder];
    [self autorelease];
    return [NSValueDecoder newWithCoder:coder];
}
#endif

@end

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
    [self subclassResponsibility:_cmd];
}

- (const char *)objCType
{
    [self subclassResponsibility:_cmd];
    return 0;
}
 
// FIXME: Is this an error or an exception???
- (id)nonretainedObjectValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}
 
- (void *)pointerValue
{
    [self subclassResponsibility:_cmd];
    return 0;
} 

- (NSRect)rectValue
{
    [self subclassResponsibility:_cmd];
    return NSMakeRect(0,0,0,0);
}
 
- (NSSize)sizeValue
{
    [self subclassResponsibility:_cmd];
    return NSMakeSize(0,0);
}
 
- (NSPoint)pointValue
{
    [self subclassResponsibility:_cmd];
    return NSMakePoint(0,0);
}

// NSCoding (done by subclasses)
- classForCoder
{
    return [NSValueDecoder class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    return self;
}

@end

