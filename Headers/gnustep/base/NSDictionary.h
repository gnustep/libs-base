/* Interface for NSDictionary for GNUStep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.

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

#ifndef _NSDictionary_h_GNUSTEP_BASE_INCLUDE
#define _NSDictionary_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSArray, NSString, NSEnumerator, NSURL;

@interface NSDictionary : NSObject <NSCoding, NSCopying, NSMutableCopying>
+ (id) dictionary;
+ (id) dictionaryWithContentsOfFile: (NSString*)path;
+ (id) dictionaryWithDictionary: (NSDictionary*)otherDictionary;
+ (id) dictionaryWithObject: (id)object forKey: (id)key;
+ (id) dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
+ (id) dictionaryWithObjects: (id*)objects
		     forKeys: (id*)keys
		       count: (unsigned)count;
+ (id) dictionaryWithObjectsAndKeys: (id)firstObject, ...;

- (NSArray*) allKeys;
- (NSArray*) allKeysForObject: (id)anObject;
- (NSArray*) allValues;
- (unsigned) count;						// Primitive
- (NSString*) description;
- (NSString*) descriptionInStringsFileFormat;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level;

- (id) initWithContentsOfFile: (NSString*)path;
- (id) initWithDictionary: (NSDictionary*)otherDictionary;
- (id) initWithDictionary: (NSDictionary*)other copyItems: (BOOL)shouldCopy;
- (id) initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
- (id) initWithObjectsAndKeys: (id)firstObject, ...;
- (id) initWithObjects: (id*)objects
	       forKeys: (id*)keys
		 count: (unsigned)count;			// Primitive
- (BOOL) isEqualToDictionary: (NSDictionary*)other;

- (NSEnumerator*) keyEnumerator;				// Primitive
- (NSArray*) keysSortedByValueUsingSelector: (SEL)comp;
- (NSEnumerator*) objectEnumerator;				// Primitive
- (id) objectForKey: (id)aKey;					// Primitive
- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)marker;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile;
#ifndef	STRICT_OPENSTEP
- (id) valueForKey: (NSString*)key;
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxiliaryFile;
#endif
@end

@interface NSMutableDictionary: NSDictionary

+ (id) dictionaryWithCapacity: (unsigned)numItems;

- (void) addEntriesFromDictionary: (NSDictionary*)otherDictionary;
- (id) initWithCapacity: (unsigned)numItems;			// Primitive
- (void) removeAllObjects;
- (void) removeObjectForKey: (id)aKey;				// Primitive
- (void) removeObjectsForKeys: (NSArray*)keyArray;
- (void) setObject: (id)anObject forKey: (id)aKey;		// Primitive
- (void) setDictionary: (NSDictionary*)otherDictionary;
#ifndef	STRICT_OPENSTEP
- (void) takeStoredValue: (id)value forKey: (NSString*)key;
- (void) takeValue: (id)value forKey: (NSString*)key;
#endif
@end

#ifndef NO_GNUSTEP

#include <Foundation/NSDictionary.h>

@interface NSMutableDictionary (GNU)
+ (unsigned) defaultCapacity;
- (id) initWithType: (const char*)contentEncoding
	    keyType: (const char*)keyEncoding
	   capacity: (unsigned)aCapacity;
@end

#endif /* NO_GNUSTEP*/

#endif
