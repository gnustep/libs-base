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

/*    
    FIXME - Some of NeXT's requirements escape me at this point. Why would
    you need to override classForCoder in subclasses? Can we encode void *
    or not?
*/

/* xxx This needs fixing because NSValue shouldn't have any 
   instance variables. -mccallum */

#include "NSValue.h"
#include "NSObjectPrivate.h"	/* For standard exceptions */
#include "NSString.h"
#include "NSCoder.h"
#include "object_zone.h"	/* Zone mallocing */

#include <objects/stdobjects.h>
#include <string.h>

@implementation NSValue

// NSCopying
- deepen
{
    void	*old_ptr;
    unsigned	size;

    size = objc_sizeof_type([objctype cString]);
    old_ptr = _dataptr;
    _dataptr = (void *)NSZoneMalloc([self zone], size);
    NS_CHECK_MALLOC(_dataptr)
    memcpy(_dataptr, old_ptr, size);

    objctype = [objctype copyWithZone:[self zone]];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
    	return [self retain];
    else
    	return [[super copyWithZone:zone] deepen];
}

// Allocating and Initializing 

/* This method is apperently not in the OpenStep specification, but it makes
   subclassing a lot easier */
- initValue:(const void *)value
      withObjCType:(const char *)type
{
    unsigned	size;
    
    if (!value || !type) {
    	[NSException raise:NSInvalidArgumentException
		format:TEMP_STRING("NULL value or NULL type")];
	/* NOT REACHED */
    }

    // FIXME: objc_sizeof_type will abort when it finds an invalid type, when
    // we really want to just raise an exception
    size = objc_sizeof_type(type);
    if (size <= 0) {
    	[NSException raise:NSInternalInconsistencyException
		format:TEMP_STRING("Invalid Objective-C type")];
	/* NOT REACHED */
    }

    _dataptr = (void *)NSZoneMalloc([self zone], size);
    NS_CHECK_MALLOC(_dataptr)
    memcpy(_dataptr, value, size);

    objctype = [[NSString stringWithCString:type] retain];
    return self;
}

+ (NSValue *)value:(const void *)value
      withObjCType:(const char *)type
{
    return [[[self alloc] initValue:value withObjCType:type] autorelease];
}
		
+ (NSValue *)valueWithNonretainedObject: (id)anObject
{
    return [self value:&anObject withObjCType:@encode(id)];
}
	
+ (NSValue *)valueWithPoint:(NSPoint)point
{
    return [self value:&point withObjCType:@encode(NSPoint)];
}
 
+ (NSValue *)valueWithPointer:(const void *)pointer
{
    return [self value:&pointer withObjCType:@encode(void *)];
}

+ (NSValue *)valueWithRect:(NSRect)rect
{
    return [self value:&rect withObjCType:@encode(NSRect)];
}
 
+ (NSValue *)valueWithSize:(NSSize)size
{
    return [self value:&size withObjCType:@encode(NSSize)];
}

- (void)dealloc
{
    [objctype release];
    NSZoneFree([self zone], _dataptr);
    [super dealloc];
}

// Accessing Data 
- (void)getValue:(void *)value
{
    if (!value) {
	[NSException raise:NSInvalidArgumentException
	    format:TEMP_STRING("Cannot copy value into NULL buffer")];
	/* NOT REACHED */
    }
    memcpy( value, _dataptr, objc_sizeof_type([objctype cString]) );
}

- (const char *)objCType
{
    return [objctype cString];
}
 
// FIXME: need to check to make sure these hold the right values...
- (id)nonretainedObjectValue
{
    return *((id *)_dataptr);
}
 
- (void *)pointerValue
{
    return *((void **)_dataptr);
} 

- (NSRect)rectValue
{
    return *((NSRect *)_dataptr);
}
 
- (NSSize)sizeValue
{
    return *((NSSize *)_dataptr);
}
 
- (NSPoint)pointValue
{
    return *((NSPoint *)_dataptr);
}

// NSCoding
- (void)encodeWithCoder:(NSCoder *)coder
{
    
    [super encodeWithCoder:coder];
    // FIXME: Do we need to check for encoding void, void * or will
    // NSCoder do this for us?
    [coder encodeObject:objctype];
    [coder encodeValueOfObjCType:[objctype cString] at:&_dataptr];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    objctype = [[coder decodeObject] retain];
    [coder decodeValueOfObjCType:[objctype cString] at:&_dataptr];
    return self;
}


@end

