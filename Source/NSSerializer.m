/* Class for serialization in GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdoanld <richard@brainstorm.co.uk>
   Date: August 1997

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
#include <gnustep/base/preface.h>
#include <Foundation/byte_order.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

@class	NSGMutableCString;
@class	NSGCString;
#ifdef	UNICODE
@class	NSGString;
@class	NSGMutableString;
#endif
@class	NSGArray;
@class	NSGMutableArray;
@class	NSGDictionary;
@class	NSGMutableDictionary;

typedef	enum {
  ST_CSTRING,
  ST_MCSTRING,
  ST_STRING,
  ST_MSTRING,
  ST_DATA,
  ST_MDATA,
  ST_ARRAY,
  ST_MARRAY,
  ST_DICT,
  ST_MDICT
} SerializerType;

@implementation NSSerializer
+ (NSData*) serializePropertyList: (id)propertyList
{
    NSMutableData*	d = [NSMutableData new];

    [self serializePropertyList: propertyList intoData: d];
    return [d autorelease];
}

+ (void) serializePropertyList: (id)propertyList
		      intoData: (NSMutableData*)d
{
    NSSerializer*	s = [self new];

    [d serializeDataAt: &propertyList
	    ofObjCType: @encode(id)
	       context: s];
    [s release];
}

- (void) deserializeObjectAt: (id*)object
		  ofObjCType: (const char *)type
		    fromData: (NSData*)data
		    atCursor: (unsigned*)cursor
{
    [self notImplemented:_cmd];
}

- (void) serializeObjectAt: (id*)objPtr
		ofObjCType: (const char *)type
		  intoData: (NSMutableData*)data
{
    id	object;

    assert(objPtr != 0);
    assert(type == @encode(id));
    object = *objPtr;
    if ([object isKindOfClass: [NSMutableData class]]) {
	[data serializeInt: ST_MDATA];
	[data serializeInt: [object length]];
	[data appendBytes: [object bytes] length: [object length]];
    }
    else if ([object isKindOfClass: [NSData class]]) {
	[data serializeInt: ST_DATA];
	[data serializeInt: [object length]];
	[data appendBytes: [object bytes] length: [object length]];
    }
    else if ([object isKindOfClass: [NSGMutableCString class]]) {
	[data serializeInt: ST_MCSTRING];
	[data serializeInt: [object cStringLength]];
	[data appendBytes: [object cString] length: [object cStringLength]];
    }
    else if ([object isKindOfClass: [NSGCString class]]) {
	[data serializeInt: ST_CSTRING];
	[data serializeInt: [object cStringLength]];
	[data appendBytes: [object cString] length: [object cStringLength]];
    }
#ifdef	UNICODE
    else if ([object isKindOfClass: [NSMutableString class]] ||
        [object isKindOfClass: [NSGMutableString class]]) {
	[data serializeInt: ST_MSTRING];
	[data serializeInt: [object cStringLength]];
	[data appendBytes: [object cString] length: [object cStringLength]];
    }
    else if ([object isKindOfClass: [NSString class]] ||
        [object isKindOfClass: [NSGString class]]) {
	[data serializeInt: ST_STRING];
	[data serializeInt: [object cStringLength]];
	[data appendBytes: [object cString] length: [object cStringLength]];
    }
#endif
    else if ([object isKindOfClass: [NSMutableArray class]] ||
        [object isKindOfClass: [NSGMutableArray class]]) {
	unsigned int i;

	[data serializeInt: ST_MARRAY];
	[data serializeInt: [object count]];
	for (i = 0; i < [object count]; i++) {
	    id	o = [object objectAtIndex: i];

	    [data serializeDataAt: &o
		       ofObjCType: @encode(id)
		          context: self];
	}
    }
    else if ([object isKindOfClass: [NSArray class]] ||
        [object isKindOfClass: [NSGArray class]]) {
	unsigned int i;

	[data serializeInt: ST_ARRAY];
	[data serializeInt: [object count]];
	for (i = 0; i < [object count]; i++) {
	    id	o = [object objectAtIndex: i];

	    [data serializeDataAt: &o
		       ofObjCType: @encode(id)
		          context: self];
	}
    }
    else if ([object isKindOfClass: [NSMutableDictionary class]] ||
        [object isKindOfClass: [NSGMutableDictionary class]]) {
	NSEnumerator*	e = [object keyEnumerator];
	id		k;

	[data serializeInt: ST_MDICT];
	[data serializeInt: [object count]];
	while ((k = [e nextObject]) != nil) {
	    id o = [object objectForKey:k];

	    [data serializeDataAt: &k
		       ofObjCType: @encode(id)
		          context: self];
	    [data serializeDataAt: &o
		       ofObjCType: @encode(id)
		          context: self];
	}
    }
    else if ([object isKindOfClass: [NSDictionary class]] ||
        [object isKindOfClass: [NSGDictionary class]]) {
	NSEnumerator*	e = [object keyEnumerator];
	id		k;

	[data serializeInt: ST_DICT];
	[data serializeInt: [object count]];
	while ((k = [e nextObject]) != nil) {
	    id o = [object objectForKey:k];

	    [data serializeDataAt: &k
		       ofObjCType: @encode(id)
		          context: self];
	    [data serializeDataAt: &o
		       ofObjCType: @encode(id)
		          context: self];
	}
    }
    else {
	[NSException raise: NSGenericException
		    format: @"Unknown class in property list"];
    }
}
@end

@implementation NSDeserializer
+ (id) deserializePropertyListFromData: (NSData*)data
                              atCursor: (unsigned int*)cursor
                     mutableContainers: (BOOL)flag
{
    NSDeserializer*	s = [self new];
    id			o = nil;

    s->mutableContainer = flag;
    [data deserializeDataAt: &o
		 ofObjCType: @encode(id)
		   atCursor: cursor
		    context: s];
    [s release];
    return o;
}

+ (id) deserializePropertyListFromData: (NSData*)data
                     mutableContainers: (BOOL)flag
{
    unsigned int	cursor = 0;

    return [self deserializePropertyListFromData: data
					atCursor: &cursor
			       mutableContainers: flag];
}

- (void) deserializeObjectAt: (id*)object
		  ofObjCType: (const char *)type
		    fromData: (NSData*)data
		    atCursor: (unsigned*)cursor
{
    SerializerType	code;
    unsigned int	size;

    assert(type == @encode(id));
    code = (SerializerType)[data deserializeIntAtCursor: cursor];
    size = (unsigned int)[data deserializeIntAtCursor: cursor];

    switch (code) {
        case ST_MDATA:
	{
	    NSMutableData*	d = [NSMutableData dataWithCapacity: size];
	    void*		b = [d mutableBytes];
	
	    [data deserializeBytes: b length: size atCursor: cursor];
	    *object = d;
	    break;
	}

	case ST_DATA:
	{
	    NSMutableData*	d;
	    void*		b = objc_malloc(size);
	
	    [data deserializeBytes: b length: size atCursor: cursor];
	    d = [NSData dataWithBytesNoCopy: b length: size];
	    *object = d;
	    break;
	}

	case ST_MCSTRING:
	case ST_MSTRING:
	{
	    NSMutableString*	s;
	    char*		b = objc_malloc(size+1);
	
	    b[size] = '\0';
	    [data deserializeBytes: b length: size atCursor: cursor];
	    s = [[[NSMutableString alloc] initWithCStringNoCopy: b
							 length: size
						   freeWhenDone: YES]
							autorelease];
	    *object = s;
	    break;
	}

	case ST_CSTRING:
	case ST_STRING:
	{
	    NSString*	s;
	    char*	b = objc_malloc(size+1);
	
	    b[size] = '\0';
	    [data deserializeBytes: b length: size atCursor: cursor];
	    s = [[[NSString alloc] initWithCStringNoCopy: b
						  length: size
					    freeWhenDone: YES] autorelease];
	    *object = s;
	    break;
	}

	case ST_MARRAY:
	case ST_ARRAY:
	{
	    id	*objects = objc_malloc(size*sizeof(id));
	    id	a;
	    int	i;

	    for (i = 0; i < size; i++) {
		[data deserializeDataAt: &objects[i]
			     ofObjCType: type
			       atCursor: cursor
				context: self];
	    }
	    if (code == ST_MARRAY || mutableContainer) {
		a = [[NSMutableArray alloc] initWithObjects: objects
						      count: size];
	    }
	    else {
		a = [[NSArray alloc] initWithObjects: objects
					       count: size];
	    }
	    objc_free(objects);
	    [a autorelease];
	    *object = a;
	    break;
	}

	case ST_MDICT:
	case ST_DICT:
	{
	    id	*keys = objc_malloc(size*sizeof(id));
	    id	*objects = objc_malloc(size*sizeof(id));
	    id	d;
	    int	i;

	    for (i = 0; i < size; i++) {
		[data deserializeDataAt: &keys[i]
			     ofObjCType: type
			       atCursor: cursor
				context: self];
		[data deserializeDataAt: &objects[i]
			     ofObjCType: type
			       atCursor: cursor
				context: self];
	    }
	    if (code == ST_MDICT || mutableContainer) {
		d = [NSMutableDictionary dictionaryWithObjects: objects
						       forKeys: keys
							 count: size];
	    }
	    else {
		d = [NSDictionary dictionaryWithObjects: objects
						forKeys: keys
						  count: size];
	    }
	    objc_free(keys);
	    objc_free(objects);
	    *object = d;
	    break;
	}

	default:
	    [NSException raise: NSGenericException
		        format: @"Unknown class in property list"];
    }
}

- (void) serializeObjectAt: (id*)object
		ofObjCType: (const char *)type
		  intoData: (NSMutableData*)data
{
    [self notImplemented:_cmd];
}
@end

