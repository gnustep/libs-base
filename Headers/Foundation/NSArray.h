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
#import <Foundation/NSEnumerator.h>
#import <GNUstepBase/GSBlocks.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;
@class NSURL;
@class NSIndexSet;

@interface NSArray : NSObject <NSCoding, NSCopying, NSMutableCopying, NSFastEnumeration>

+ (id) array;
+ (id) arrayWithArray: (NSArray*)array;
+ (id) arrayWithContentsOfFile: (NSString*)file;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
+ (id) arrayWithContentsOfURL: (NSURL*)aURL;
#endif
+ (id) arrayWithObject: (id)anObject;
+ (id) arrayWithObjects: (id)firstObject, ...;
+ (id) arrayWithObjects: (const id[])objects count: (NSUInteger)count;

- (NSArray*) arrayByAddingObject: (id)anObject;
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray;
- (BOOL) containsObject: anObject;
- (NSUInteger) count;						// Primitive
- (void) getObjects: (__unsafe_unretained id[])aBuffer;
- (void) getObjects: (__unsafe_unretained id[])aBuffer range: (NSRange)aRange;
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
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count;	// Primitive

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
- (NSString*) descriptionWithLocale: (id)locale;
- (NSString*) descriptionWithLocale: (id)locale
			     indent: (NSUInteger)level;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxiliaryFile;
- (id) valueForKey: (NSString*)key;
#endif

#if OS_API_VERSION(100600, GS_API_LATEST)

DEFINE_BLOCK_TYPE(GSEnumeratorBlock, void, id, NSUInteger, BOOL*);
DEFINE_BLOCK_TYPE(GSPredicateBlock, BOOL, id, NSUInteger, BOOL*);
/**
 * Enumerate over the collection using the given block.  The first argument is
 * the object and the second is the index in the array.  The final argument is
 * a pointer to a BOOL indicating whether the enumeration should stop.  Setting
 * this to YES will interrupt the enumeration.
 */
- (void) enumerateObjectsUsingBlock: (GSEnumeratorBlock)aBlock;

/**
 * Enumerate over the collection using the given block.  The first argument is
 * the object and the second is the index in the array.  The final argument is
 * a pointer to a BOOL indicating whether the enumeration should stop.  Setting
 * this to YES will interrupt the enumeration.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (void) enumerateObjectsWithOptions: (NSEnumerationOptions)opts 
			  usingBlock: (GSEnumeratorBlock)aBlock;
/**
 * Enumerate over the specified indexes in the collection using the given
 * block.  The first argument is the object and the second is the index in the
 * array.  The final argument is a pointer to a BOOL indicating whether the
 * enumeration should stop.  Setting this to YES will interrupt the
 * enumeration.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (void) enumerateObjectsAtIndexes: (NSIndexSet*)indexSet
			   options: (NSEnumerationOptions)opts
			usingBlock: (GSEnumeratorBlock)block;
/**
 * Returns the indexes of the objects in a collection that match the condition
 * specified by the block.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (NSIndexSet *) indexesOfObjectsWithOptions: (NSEnumerationOptions)opts 
				 passingTest: (GSPredicateBlock)predicate;

/**
 * Returns the indexes of the objects in a collection that match the condition
 * specified by the block.
 */
- (NSIndexSet*) indexesOfObjectsPassingTest: (GSPredicateBlock)predicate;

/**
 * Returns the indexes of the objects in a collection that match the condition
 * specified by the block and are in the range specified by the index set.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (NSIndexSet*) indexesOfObjectsAtIndexes: (NSIndexSet*)indexSet
				  options: (NSEnumerationOptions)opts
			      passingTest: (GSPredicateBlock)predicate;

/**
 * Returns the index of the first object in the array that matches the
 * condition specified by the block.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (NSUInteger) indexOfObjectWithOptions: (NSEnumerationOptions)opts 
			    passingTest: (GSPredicateBlock)predicate;

/**
 * Returns the index of the first object in the array that matches the
 * condition specified by the block.
 */
- (NSUInteger) indexOfObjectPassingTest: (GSPredicateBlock)predicate;

/**
 * Returns the index of the first object in the specified range in a collection
 * that matches the condition specified by the block.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (NSUInteger) indexOfObjectAtIndexes: (NSIndexSet*)indexSet
			      options: (NSEnumerationOptions)opts
			  passingTest: (GSPredicateBlock)predicate;
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

#if	defined(__cplusplus)
}
#endif

#if	!NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import	<GNUstepBase/NSArray+GNUstepBase.h>
#endif

#endif /* __NSArray_h_GNUSTEP_BASE_INCLUDE */
