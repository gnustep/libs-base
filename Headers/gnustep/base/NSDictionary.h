/* Interface for NSDictionary for GNUStep
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef _NSDictionary_h_GNUSTEP_BASE_INCLUDE
#define _NSDictionary_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

@class NSArray, NSString, NSEnumerator;

@interface NSDictionary : NSObject
- initWithObjects: (id*)objects
	  forKeys: (NSObject**)keys
	    count: (unsigned)count;
- (unsigned) count;
- objectForKey: (NSObject*)aKey;
- (NSEnumerator*) keyEnumerator;
- (NSEnumerator*) objectEnumerator;
@end

@interface NSDictionary (NonCore) <NSCopying, NSMutableCopying>

+ allocWithZone: (NSZone*)zone;
+ dictionary;
+ dictionaryWithContentsOfFile:(NSString *)path;
+ dictionaryWithDictionary: (NSDictionary*)aDict;
+ dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
+ dictionaryWithObjects: (id*)objects forKeys: (id*)keys
		  count: (unsigned)count;
+ dictionaryWithObjectsAndKeys: (id)object, ...;
- initWithContentsOfFile: (NSString*)path;
- initWithDictionary: (NSDictionary*)otherDictionary;
- initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
- initWithObjectsAndKeys: (id)object, ...;

- (BOOL) isEqualToDictionary: (NSDictionary*)other;

- (NSArray*) allKeys;
- (NSArray*) allKeysForObject: anObject;
- (NSArray*) allValues;
- (NSArray*) keysSortedByValueUsingSelector: (SEL)comp;
- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)abObject;

- (NSString*) description;
- (NSString*) descriptionInStringsFileFormat;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile;

@end

@interface NSMutableDictionary: NSDictionary
- initWithCapacity: (unsigned)numItems;
- (void) setObject:anObject forKey:(NSObject *)aKey;
- (void) removeObjectForKey:(NSObject *)aKey;
@end

@interface NSMutableDictionary (NonCore)

+ allocWithZone: (NSZone*)zone;
+ dictionaryWithCapacity: (unsigned)numItems;

- (void) removeAllObjects;
- (void) removeObjectsForKeys: (NSArray*)keyArray;
- (void) addEntriesFromDictionary: (NSDictionary*)otherDictionary;
- (void) setDictionary: (NSDictionary*)otherDictionary;

@end

#ifndef NO_GNUSTEP

#include <gnustep/base/KeyedCollecting.h>
#include <Foundation/NSDictionary.h>

/* Eventually we'll make a Constant version of this protocol. */
@interface NSDictionary (GNU) <KeyedCollecting>
@end

@interface NSMutableDictionary (GNU)
+ (unsigned) defaultCapacity;
- initWithType: (const char *)contentEncoding
    keyType: (const char *)keyEncoding
    capacity: (unsigned)aCapacity;
@end

#endif /* NO_GNUSTEP */

#endif
