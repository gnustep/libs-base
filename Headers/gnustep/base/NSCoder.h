/* Interface for NSCoder for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.
   
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

#ifndef __NSCoder__include__
#define __NSCoder__include__

#include <foundation/NSObject.h>
#include <foundation/NSGeometry.h>
#include <foundation/NSZone.h>

@class NSMutableData, NSData, NSString;

@interface NSCoder : NSObject
{
    NSMutableData *_data;
}

// Encoding Data

- (void)encodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(const void *)array;
- (void)encodeBycopyObject:(id)anObject;
- (void)encodeConditionalObject:(id)anObject;
- (void)encodeDataObject:(NSData *)data;
- (void)encodeObject:(id)anObject;
- (void)encodePropertyList:(id)plist;
- (void)encodePoint:(NSPoint)point;
- (void)encodeRect:(NSRect)rect;
- (void)encodeRootObject:(id)rootObject;
- (void)encodeSize:(NSSize)size;
- (void)encodeValueOfObjCType:(const char *)type
                           at:(const void *)address;
- (void)encodeValuesOfObjCTypes:(const char *)types,...;

// Decoding Data

- (void)decodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(void *)address;
- (NSData *)decodeDataObject;
- (id)decodeObject;
- (id)decodePropertyList;
- (NSPoint)decodePoint;
- (NSRect)decodeRect;
- (NSSize)decodeSize;
- (void)decodeValueOfObjCType:(const char *)type
                           at:(void *)address;
- (void)decodeValuesOfObjCTypes:(const char *)types,...;

// Managing Zones

- (NSZone *)objectZone;
- (void)setObjectZone:(NSZone *)zone;

// Getting a Version

- (unsigned int)systemVersion;
- (unsigned int)versionForClassName:(NSString *)className;
	
@end

#endif	/* __NSCoder__include__ */
/* From:
 * (Preliminary Documentation) Copyright (c) 1994 by NeXT Computer, Inc.  
 * All Rights Reserved.
 *
 * NSCoder 
 *
 */
 
#ifndef __NSCoder__include__
#define __NSCoder__include__

#include <foundation/NSObject.h>
#include <foundation/NSGeometry.h>
#include <foundation/NSZone.h>

@class NSMutableData, NSData, NSString;

@interface NSCoder : NSObject
{
    NSMutableData *_data;
}

// Encoding Data

- (void)encodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(const void *)array;
 /*
  * Serializes data of Objective C types listed in types having count
  * elements residing at address array. 
  */
		
- (void)encodeBycopyObject:(id)anObject;
 /*
  * Overridden by subclasses to serialize the supplied Objective C object so
  * that a copy rather than a proxy of anObject is created upon
  * deserialization.  NSCoder's implementation simply invokes encodeObject:. 
  */
 
- (void)encodeConditionalObject:(id)anObject;
 /*
  * Overridden by subclasses to conditionally serialize the supplied
  * Objective C object.  The object should be serialized only if it is an
  * inherent member of the larger data structure.  NSCoder's implementation
  * simply invokes encodeObject:. 
  */
  
- (void)encodeDataObject:(NSData *)data;
 /*
  * Serializes the NSData object data. 
  */
 
- (void)encodeObject:(id)anObject;
 /*
  * Serializes the supplied Objective C object. 
  */
 
- (void)encodePropertyList:(id)plist;
 /*
  * Serializes the supplied property list (NSData, NSArray, NSDictionary, or
  * NSString objects). 
  */
 
- (void)encodePoint:(NSPoint)point;
 /*
  * Serializes the supplied point structure. 
  */
 
- (void)encodeRect:(NSRect)rect;
 /*
  * Serializes the supplied rectangle structure. 
  */
 
- (void)encodeRootObject:(id)rootObject;
 /*
  * Overridden by subclasses to start the serialization of an interconnected
  * group of  Objective C objects, starting with rootObject.  NSCoder's
  * implementation simply invokes encodeObject:. 
  */
 
- (void)encodeSize:(NSSize)size;
 /*
  * Serializes the supplied size structure. 
  */
 
- (void)encodeValueOfObjCType:(const char *)type
                           at:(const void *)address;
 /*
  * Serializes data of Objective C type type residing at address address. 
  */
		
- (void)encodeValuesOfObjCTypes:(const char *)types,...;
 /*
  * Serializes values corresponding to the Objective C types listed in types
  * argument list. 
  */

// Decoding Data

- (void)decodeArrayOfObjCType:(const char *)types
                        count:(unsigned)count
                           at:(void *)address;
 /*
  * Deserializes data of Objective C types listed in type having count
  * elements residing at address address. 
  */
		
- (NSData *)decodeDataObject;
 /*
  * Deserializes and returns an NSData object. 
  */
 
- (id)decodeObject;
 /*
  * Deserializes an Objective C object. 
  */
 
- (id)decodePropertyList;
 /*
  * Deserializes a property list (NSData, NSArray, NSDictionary, or NSString
  * objects). 
  */
 
- (NSPoint)decodePoint;
 /*
  * Deserializes a point structure. 
  */
 
- (NSRect)decodeRect;
 /*
  * Deserializes a rectangle structure. 
  */

- (NSSize)decodeSize;
 /*
  * Deserializes a size structure. 
  */
 
- (void)decodeValueOfObjCType:(const char *)type
                           at:(void *)address;
 /*
  * Deserializes data of Objective C type type residing at address address. 
  * You are responsible for releasing the resulting objects. 
  */
 
- (void)decodeValuesOfObjCTypes:(const char *)types,...;
 /*
  * Deserializes values corresponding to the Objective C types listed in
  * types argument list.  You are responsible for releasing the resulting
  * objects. 
  */

// Managing Zones

- (NSZone *)objectZone;
 /*
  * Returns the memory zone used by deserialized objects.  For instances of
  * NSCoder, this is the default memory zone, the one returned by
  * NSDefaultMallocZone(). 
  */
 
- (void)setObjectZone:(NSZone *)zone;
 /*
  * Sets the memory zone used by deserialized objects.  Instances of NSCoder
  * always use the default memory zone, the one returned by
  * NSDefaultMallocZone(), and so ignore this method. 
  */

// Getting a Version

- (unsigned int)systemVersion;
 /*
  * Returns the system version number as of the time the archive was created. 
  */
 
- (unsigned int)versionForClassName:(NSString *)className;
 /*
  * Returns the version number of  the class className as of the time it was
  * archived. 
  */
	
@end

#endif	/* __NSCoder__include__ */
