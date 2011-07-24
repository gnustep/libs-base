/* Interface for NSDictionary for GNUStep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
  */ 

#ifndef _NSDictionary_h_GNUSTEP_BASE_INCLUDE
#define _NSDictionary_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSEnumerator.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray, NSString, NSURL;

@interface NSDictionary : NSObject <NSCoding, NSCopying, NSMutableCopying, NSFastEnumeration>
+ (id) dictionary;
+ (id) dictionaryWithContentsOfFile: (NSString*)path;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
+ (id) dictionaryWithContentsOfURL: (NSURL*)aURL;
#endif
+ (id) dictionaryWithDictionary: (NSDictionary*)otherDictionary;
+ (id) dictionaryWithObject: (id)object forKey: (id)key;
+ (id) dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
+ (id) dictionaryWithObjects: (const id[])objects
		     forKeys: (const id[])keys
		       count: (NSUInteger)count;
+ (id) dictionaryWithObjectsAndKeys: (id)firstObject, ...;

- (NSArray*) allKeys;
- (NSArray*) allKeysForObject: (id)anObject;
- (NSArray*) allValues;
- (NSUInteger) count;						// Primitive
- (NSString*) description;
- (NSString*) descriptionInStringsFileFormat;
- (NSString*) descriptionWithLocale: (id)locale;
- (NSString*) descriptionWithLocale: (id)locale
			     indent: (NSUInteger)level;

- (id) init;
- (id) initWithContentsOfFile: (NSString*)path;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (id) initWithContentsOfURL: (NSURL*)aURL;
#endif
- (id) initWithDictionary: (NSDictionary*)otherDictionary;
- (id) initWithDictionary: (NSDictionary*)other copyItems: (BOOL)shouldCopy;
- (id) initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys;
- (id) initWithObjectsAndKeys: (id)firstObject, ...;
- (id) initWithObjects: (const id[])objects
	       forKeys: (const id[])keys
		 count: (NSUInteger)count;			// Primitive
- (BOOL) isEqualToDictionary: (NSDictionary*)other;

- (NSEnumerator*) keyEnumerator;				// Primitive
- (NSArray*) keysSortedByValueUsingSelector: (SEL)comp;
- (NSEnumerator*) objectEnumerator;				// Primitive
- (id) objectForKey: (id)aKey;					// Primitive
- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)marker;
- (void)getObjects: (__unsafe_unretained id[])objects
           andKeys: (__unsafe_unretained id[])keys;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (id) valueForKey: (NSString*)key;
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxiliaryFile;
#endif
@end

@interface NSMutableDictionary: NSDictionary

+ (id) dictionaryWithCapacity: (NSUInteger)numItems;

- (void) addEntriesFromDictionary: (NSDictionary*)otherDictionary;
- (id) initWithCapacity: (NSUInteger)numItems;			// Primitive
- (void) removeAllObjects;
- (void) removeObjectForKey: (id)aKey;				// Primitive
- (void) removeObjectsForKeys: (NSArray*)keyArray;
- (void) setObject: (id)anObject forKey: (id)aKey;		// Primitive
- (void) setDictionary: (NSDictionary*)otherDictionary;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) takeStoredValue: (id)value forKey: (NSString*)key;
- (void) takeValue: (id)value forKey: (NSString*)key;
- (void) setValue: (id)value forKey: (NSString*)key;
#endif
@end

#if	defined(__cplusplus)
}
#endif

#endif
