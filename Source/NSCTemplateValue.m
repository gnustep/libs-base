# line 1 "NSCTemplateValue.m"	/* So gdb knows which file we are in */
/* NSCTemplateValue - Object encapsulation for C types.
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
#include <gnustep/base/preface.h>

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

- initValue:(const void *)value
      withObjCType:(const char *)type
{
    typedef _dt = data;
    self = [super init];
    data = *(_dt *)value;
    return self;
}

// Accessing Data 
- (void)getValue:(void *)value
{
    if (!value) {
	[NSException raise:NSInvalidArgumentException
	    format:@"Cannot copy value into NULL buffer"];
	/* NOT REACHED */
    }
    memcpy( value, &data, objc_sizeof_type([self objCType]) );
}

- (const char *)objCType
{
    typedef _dt = data;
    return @encode(_dt);
}
 
- (TYPE_NAME)TYPE_METHOD
{
    return data;
}
 
// NSCoding
- (void)encodeWithCoder:(NSCoder *)coder
{
    const char *type;
    [super encodeWithCoder:coder];
    type = [self objCType];
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
