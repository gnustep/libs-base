/* Interface for NSCoder for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

#ifndef __NSCoder_h_GNUSTEP_BASE_INCLUDE
#define __NSCoder_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSZone.h>

@class NSMutableData, NSData, NSString;

@interface NSCoder : NSObject
// Encoding Data

- (void) encodeArrayOfObjCType: (const char*)type
			 count: (unsigned)count
			    at: (const void*)array;
- (void) encodeBycopyObject: (id)anObject;
- (void) encodeByrefObject: (id)anObject;
- (void) encodeBytes: (void*)d length: (unsigned)l;
- (void) encodeConditionalObject: (id)anObject;
- (void) encodeDataObject: (NSData*)data;
- (void) encodeObject: (id)anObject;
- (void) encodePropertyList: (id)plist;
- (void) encodePoint: (NSPoint)point;
- (void) encodeRect: (NSRect)rect;
- (void) encodeRootObject: (id)rootObject;
- (void) encodeSize: (NSSize)size;
- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)address;
- (void) encodeValuesOfObjCTypes: (const char*)types,...;

// Decoding Data

- (void) decodeArrayOfObjCType: (const char*)type
                         count: (unsigned)count
                            at: (void*)address;
- (void*) decodeBytesWithReturnedLength: (unsigned*)l;
- (NSData*) decodeDataObject;
- (id) decodeObject;
- (id) decodePropertyList;
- (NSPoint) decodePoint;
- (NSRect) decodeRect;
- (NSSize) decodeSize;
- (void) decodeValueOfObjCType: (const char*)type
			    at: (void*)address;
- (void) decodeValuesOfObjCTypes: (const char*)types,...;

// Managing Zones

- (NSZone*) objectZone;
- (void) setObjectZone: (NSZone*)zone;

// Getting a Version

- (unsigned int) systemVersion;
- (unsigned int) versionForClassName: (NSString*)className;

#ifndef	STRICT_OPENSTEP
/*
 * MacOS-X adds some typedefs that GNUstep already has by another name.
 */
#include <GSConfig.h>
#define	uint8_t	gsu8
#define	int32_t	gss32
#define	int64_t	gss64


/** <override-subclass />
 * Returns a flag indicating whether the receiver supported keyed coding.
 * the default implementation returns NO.  Subclasses supporting keyed
 * coding must override this to return YES.
 */
- (BOOL) allowsKeyedCoding;

/** <override-subclass />
 * Returns a class indicating whether an encoded value corresponding
 * to aKey exists.
 */
- (BOOL) containsValueForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a boolean value associated with aKey.  This value must previously
 * have been encoded using -encodeBool:forKey:
 */
- (BOOL) decodeBoolForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a pointer to a byte array associated with aKey.<br />
 * Returns the length of the data in aLength.<br />
 * This value must previously have been encoded using
 * -encodeBytes:length:forKey:
 */
- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
		      returnedLength: (unsigned*)alength;

/** <override-subclass />
 * Returns a double value associated with aKey.  This value must previously
 * have been encoded using -encodeDouble:forKey: or -encodeFloat:forKey:
 */
- (double) decodeDoubleForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a float value associated with aKey.  This value must previously
 * have been encoded using -encodeFloat:forKey: or -encodeDouble:forKey:<br />
 * Precision may be lost (or an exception raised if the value will not fit
 * in a float) if the value was encoded using -encodeDouble:forKey:,
 */
- (float) decodeFloatForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns an integer value associated with aKey.  This value must previously
 * have been encoded using -encodeInt:forKey:, -encodeInt32:forKey:, or
 * -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in an integer.
 */
- (int) decodeIntForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a 32-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in a 32-bit integer.
 */
- (int32_t) decodeInt32ForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a 64-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.
 */
- (int64_t) decodeInt64ForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns an object value associated with aKey.  This value must
 * previously have been encoded using -encodeObject:forKey: or
 * -encodeConditionalObject:forKey:
 */
- (id) decodeObjectForKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes aBool and associates the encoded value with aKey.
 */
- (void) encodeBool: (BOOL) aBool forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes the data of the specified length and pointed to by aPointeraBool,
 * and associates the encoded value with aKey.
 */
- (void) encodeBytes: (const uint8_t*)aPointer
	      length: (unsigned)length
	      forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anObject and associates the encoded value with aKey, but only
 * if anObject has already been encoded using -encodeObject:forKey:
 */
- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes aDouble and associates the encoded value with aKey.
 */
- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes aFloat and associates the encoded value with aKey.
 */
- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anObject and associates the encoded value with aKey.
 */
- (void) encodeObject: (id)anObject forKey: (NSString*)aKey;
#endif
@end

#ifndef NO_GNUSTEP

@interface NSCoder (GNUstep)
/* Compatibility with libObjects */
- (void) decodeArrayOfObjCType: (const char*)type
		         count: (unsigned)count
			    at: (void*)buf
		      withName: (id*)name;
- (void) decodeIndent;
- (void) decodeObjectAt: (id*)anObject
	       withName: (id*)name;
- (void) decodeValueOfCType: (const char*)type
			 at: (void*)buf
		   withName: (id*)name;
- (void) decodeValueOfObjCType: (const char*)type
			    at: (void*)buf
		      withName: (id*)name;
- (void) encodeArrayOfObjCType: (const char*)type
		         count: (unsigned)count
			    at: (const void*)buf
		      withName: (id)name;
- (void) encodeIndent;
- (void) encodeObjectAt: (id*)anObject
	       withName: (id)name;
- (void) encodeValueOfCType: (const char*)type
			 at: (const void*)buf
		   withName: (id)name;
- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)buf
		      withName: (id)name;
@end

#endif /* NO_GNUSTEP */

#endif	/* __NSCoder_h_GNUSTEP_BASE_INCLUDE */
