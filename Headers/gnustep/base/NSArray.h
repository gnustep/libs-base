/* Interface for NSArray for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1995
   
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

#ifndef __NSArray_h_GNUSTEP_BASE_INCLUDE
#define __NSArray_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSRange.h>
#include <Foundation/NSUtilities.h>

@class NSString;

@interface NSArray : NSObject <NSCoding, NSCopying, NSMutableCopying>

+ (id) array;
+ (id) arrayWithArray: (NSArray*)array;
+ (id) arrayWithContentsOfFile: (NSString*)file;
+ (id) arrayWithObject: (id)anObject;
+ (id) arrayWithObjects: (id)firstObj, ...;
+ (id) arrayWithObjects: (id*)objects count: (unsigned)count;

- (NSArray*) arrayByAddingObject: (id)anObject;
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray;
- (BOOL) containsObject: anObject;
- (unsigned) count;						// Primitive
- (void) getObjects: (id*)objs;
- (void) getObjects: (id*)objs range: (NSRange)aRange;
- (unsigned) indexOfObject: (id)anObject;
- (unsigned) indexOfObject: (id)anObject inRange: (NSRange)aRange;
- (unsigned) indexOfObjectIdenticalTo: (id)anObject;
- (unsigned) indexOfObjectIdenticalTo: (id)anObject inRange: (NSRange)aRange;
- (id) initWithArray: (NSArray*)array;
- (id) initWithContentsOfFile: (NSString*)file;
- (id) initWithObjects: firstObj, ...;
- (id) initWithObjects: (id*)objects count: (unsigned)count;	// Primitive

- (id) lastObject;
- (id) objectAtIndex: (unsigned)index;				// Primitive

- (id) firstObjectCommonWithArray: (NSArray*)otherArray;
- (BOOL) isEqualToArray: (NSArray*)otherArray;

#ifndef	STRICT_MACOS_X
- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument;
#endif
#ifndef	STRICT_OPENSTEP
- (void) makeObjectsPerformSelector: (SEL)aSelector;
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)argument;
#endif

- (NSData*) sortedArrayHint;
- (NSArray*) sortedArrayUsingFunction: (int (*)(id, id, void*))comparator 
			      context: (void*)context;
- (NSArray*) sortedArrayUsingFunction: (int (*)(id, id, void*))comparator 
			      context: (void*)context
				 hint: (NSData*)hint;
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator;
- (NSArray*) subarrayWithRange: (NSRange)range;

- (NSString*) componentsJoinedByString: (NSString*)separator;
- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions;

- (NSEnumerator*) objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;

- (NSString*) description;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxilliaryFile;

@end


@interface NSMutableArray : NSArray

+ (id) arrayWithCapacity: (unsigned)numItems;

- (void) addObject: (id)anObject;				// Primitive
- (void) addObjectsFromArray: (NSArray*)otherArray;
- (id) initWithCapacity: (unsigned)numItems;			// Primitive
- (void) insertObject: (id)anObject atIndex: (unsigned)index;	// Primitive
- (void) removeObjectAtIndex: (unsigned)index;			// Primitive
- (void) replaceObjectAtIndex: (unsigned)index
		   withObject: (id)anObject;			// Primitive
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
- (void) removeObjectsFromIndices: (unsigned*)indices 
		       numIndices: (unsigned)count;

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
		   context: (void*)context;
- (void) sortUsingSelector: (SEL) aSelector;

@end

@interface	NSArray (GNUstep)
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
 *	the reciever is 'less than' the item in the array.
 */
- (unsigned) insertionPosition: (id)item
		 usingFunction: (NSComparisonResult (*)(id, id))sorter;
- (unsigned) insertionPosition: (id)item
		 usingSelector: (SEL)comp;
@end

#endif /* __NSArray_h_GNUSTEP_BASE_INCLUDE */
