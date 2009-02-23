/* Interface for NSArray for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1995
   
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

#ifndef __NSArray_h_GNUSTEP_BASE_INCLUDE
#define __NSArray_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSRange.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSEnumerator;
@class NSString;
@class NSURL;
@class NSIndexSet;

@interface NSArray : NSObject <NSCoding, NSCopying, NSMutableCopying>

+ (id) array;
+ (id) arrayWithArray: (NSArray*)array;
+ (id) arrayWithContentsOfFile: (NSString*)file;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
+ (id) arrayWithContentsOfURL: (NSURL*)aURL;
#endif
+ (id) arrayWithObject: (id)anObject;
+ (id) arrayWithObjects: (id)firstObject, ...;
+ (id) arrayWithObjects: (id*)objects count: (NSUInteger)count;

- (NSArray*) arrayByAddingObject: (id)anObject;
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray;
- (BOOL) containsObject: anObject;
- (NSUInteger) count;						// Primitive
- (void) getObjects: (id*)aBuffer;
- (void) getObjects: (id*)aBuffer range: (NSRange)aRange;
- (NSUInteger) indexOfObject: (id)anObject;
- (NSUInteger) indexOfObject: (id)anObject inRange: (NSRange)aRange;
- (NSUInteger) indexOfObjectIdenticalTo: (id)anObject;
- (NSUInteger) indexOfObjectIdenticalTo: (id)anObject inRange: (NSRange)aRange;
- (id) init;
- (id) initWithArray: (NSArray*)array;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy;
#endif
- (id) initWithContentsOfFile: (NSString*)file;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (id) initWithContentsOfURL: (NSURL*)aURL;
#endif
- (id) initWithObjects: firstObject, ...;
- (id) initWithObjects: (id*)objects count: (NSUInteger)count;	// Primitive

- (id) lastObject;
- (id) objectAtIndex: (NSUInteger)index;			// Primitive
#if OS_API_VERSION(100400, GS_API_LATEST)
- (NSArray *) objectsAtIndexes: (NSIndexSet *)indexes;
#endif

- (id) firstObjectCommonWithArray: (NSArray*)otherArray;
- (BOOL) isEqualToArray: (NSArray*)otherArray;

#if OS_API_VERSION(GS_API_OPENSTEP, GS_API_MACOSX)
- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument;
#endif
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) makeObjectsPerformSelector: (SEL)aSelector;
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)arg;
#endif

- (NSData*) sortedArrayHint;
- (NSArray*) sortedArrayUsingFunction: (NSComparisonResult (*)(id, id, void*))comparator 
			      context: (void*)context;
- (NSArray*) sortedArrayUsingFunction: (NSComparisonResult (*)(id, id, void*))comparator 
			      context: (void*)context
				 hint: (NSData*)hint;
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator;
- (NSArray*) subarrayWithRange: (NSRange)aRange;

- (NSString*) componentsJoinedByString: (NSString*)separator;
- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions;

- (NSEnumerator*) objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;

- (NSString*) description;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (NSUInteger)level;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxiliaryFile;
- (id) valueForKey: (NSString*)key;
#endif
@end


@interface NSMutableArray : NSArray

+ (id) arrayWithCapacity: (NSUInteger)numItems;

- (void) addObject: (id)anObject;				// Primitive
- (void) addObjectsFromArray: (NSArray*)otherArray;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) exchangeObjectAtIndex: (NSUInteger)i1
	     withObjectAtIndex: (NSUInteger)i2;
#endif
- (id) initWithCapacity: (NSUInteger)numItems;			// Primitive
- (void) insertObject: (id)anObject atIndex: (NSUInteger)index;	// Primitive
#if OS_API_VERSION(100400, GS_API_LATEST)
- (void) insertObjects: (NSArray *)objects atIndexes: (NSIndexSet *)indexes;
#endif
- (void) removeObjectAtIndex: (NSUInteger)index;			// Primitive
- (void) removeObjectsAtIndexes: (NSIndexSet *)indexes;
- (void) replaceObjectAtIndex: (NSUInteger)index
		   withObject: (id)anObject;			// Primitive
#if OS_API_VERSION(100400, GS_API_LATEST)
- (void) replaceObjectsAtIndexes: (NSIndexSet *)indexes
                     withObjects: (NSArray *)objects;
#endif
- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray;
- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray
			 range: (NSRange)anotherRange;
- (void) setArray: (NSArray *)otherArray;

- (void) removeAllObjects;
- (void) removeLastObject;
- (void) removeObject: (id)anObject;
- (void) removeObject: (id)anObject inRange: (NSRange)aRange;
- (void) removeObjectIdenticalTo: (id)anObject;
- (void) removeObjectIdenticalTo: (id)anObject inRange: (NSRange)aRange;
- (void) removeObjectsInArray: (NSArray*)otherArray;
- (void) removeObjectsInRange: (NSRange)aRange;
- (void) removeObjectsFromIndices: (NSUInteger*)indices 
		       numIndices: (NSUInteger)count;

- (void) sortUsingFunction: (NSComparisonResult (*)(id,id,void*))compare 
		   context: (void*)context;
- (void) sortUsingSelector: (SEL)comparator;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) setValue: (id)value forKey: (NSString*)key;
#endif

@end

@interface	NSArray (GSCategories)
/*
 *	Extension methods for working with sorted arrays - use a binary chop
 *	to determine the insertion location for an nobject.  If equal objects
 *	already exist in the array, they will be located immediately before
 *	the insertion position.
 * 
 *	The comparator function takes two items as arguments, the first is the
 *	item to be added, the second is the item already in the array.
 *      The function should return NSOrderedAscending if the item to be
 *      added is 'less than' the item in the array, NSOrderedDescending
 *      if it is greater, and NSOrderedSame if it is equal.
 *
 *	The selector version works the same - returning NSOrderedAscending if
 *	the receiver is 'less than' the item in the array.
 */
- (NSUInteger) insertionPosition: (id)item
		   usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		         context: (void *)context;
- (NSUInteger) insertionPosition: (id)item
		   usingSelector: (SEL)comp;
@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSArray_h_GNUSTEP_BASE_INCLUDE */
