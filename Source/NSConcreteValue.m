/* NSConcreteValue - Object encapsulation for C types.
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
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <gnustep/base/prefix.h>

/* This is the real, general purpose value object.  I've implemented all the
   methods here (like pointValue) even though most likely, other concrete
   subclasses were created to handle these types */

#define NS_RAISE_MALLOC \
	[NSException raise:NSMallocException \
	    format:@"No memory left to allocate"]

#define NS_CHECK_MALLOC(ptr) \
	if (!ptr) {NS_RAISE_MALLOC;}

@implementation NSConcreteValue

// NSCopying
- deepen
{
    void	*old_ptr;
    int		size;

    size = objc_sizeof_type([objctype cString]);
    old_ptr = data;
    data = (void *)NSZoneMalloc([self zone], size);
    NS_CHECK_MALLOC(data)
    memcpy(data, old_ptr, size);

    objctype = [objctype copyWithZone:[self zone]];
    return self;
}

// Allocating and Initializing 

- initValue:(const void *)value
      withObjCType:(const char *)type
{
    int	size;
    
    if (!value || !type) {
    	[NSException raise:NSInvalidArgumentException
		format:@"Cannot create with NULL value or NULL type"];
	/* NOT REACHED */
    }

    self = [super init];

    // FIXME: objc_sizeof_type will abort when it finds an invalid type, when
    // we really want to just raise an exception
    size = objc_sizeof_type(type);
    if (size <= 0) {
    	[NSException raise:NSInternalInconsistencyException
		format:@"Invalid Objective-C type"];
	/* NOT REACHED */
    }

    data = (void *)NSZoneMalloc([self zone], size);
    NS_CHECK_MALLOC(data)
    memcpy(data, value, size);

    objctype = [[NSString stringWithCString:type] retain];
    return self;
}

- (void)dealloc
{
    [objctype release];
    NSZoneFree([self zone], data);
    [super dealloc];
}

// Accessing Data 
- (void)getValue:(void *)value
{
    if (!value) {
	[NSException raise:NSInvalidArgumentException
	    format:@"Cannot copy value into NULL buffer"];
	/* NOT REACHED */
    }
    memcpy( value, data, objc_sizeof_type([objctype cString]) );
}

- (const char *)objCType
{
    return [objctype cString];
}
 
// FIXME: need to check to make sure these hold the right values...
- (id)nonretainedObjectValue
{
    return *((id *)data);
}
 
- (void *)pointerValue
{
    return *((void **)data);
} 

- (NSRect)rectValue
{
    return *((NSRect *)data);
}
 
- (NSSize)sizeValue
{
    return *((NSSize *)data);
}
 
- (NSPoint)pointValue
{
    return *((NSPoint *)data);
}

// NSCoding
- (void)encodeWithCoder:(NSCoder *)coder
{
    const char *type;
    [super encodeWithCoder:coder];
    // FIXME: Do we need to check for encoding void, void * or will
    // NSCoder do this for us?
    type = [objctype cString];
    [coder encodeValueOfObjCType:@encode(char *) at:&type];
    [coder encodeValueOfObjCType:type at:&data];
}

- (id)initWithCoder:(NSCoder *)coder
{
    [NSException raise:NSInconsistentArchiveException
	format:@"Cannot unarchive class - Need NSValueDecoder."];
    return self;
}

@end
