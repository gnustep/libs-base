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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSArray_h_GNUSTEP_BASE_INCLUDE
#define __NSArray_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSUtilities.h>

@class NSString;

@interface NSArray : NSObject <NSCoding, NSCopying, NSMutableCopying>
- initWithObjects: (id*) objects count: (unsigned) count;
- (unsigned) count;
- objectAtIndex: (unsigned)index;
@end


@interface NSArray (NonCore)

+ array;
+ arrayWithArray: (NSArray*)array;
+ arrayWithContentsOfFile: (NSString*)file;
+ arrayWithObject: anObject;
+ arrayWithObjects: firstObj, ...;
+ arrayWithObjects: (id*)objects count: (unsigned)count;
- (NSArray*) arrayByAddingObject: anObject;
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray;
- initWithArray: (NSArray*)array;
- initWithContentsOfFile: (NSString*)file;
- initWithObjects: firstObj, ...;
- inttWithObjects: (id*)objects count: (unsigned)count;

- (BOOL) containsObject: anObject;
- (void) getObjects: (id*)objs;
- (void) getObjects: (id*)objs range: (NSRange)aRange;
- (unsigned) indexOfObject: anObject;
- (unsigned) indexOfObject: anObject inRange: (NSRange)aRange;
- (unsigned) indexOfObjectIdenticalTo: anObject;
- (unsigned) indexOfObjectIdenticalTo: anObject inRange: (NSRange)aRange;
- lastObject;

- firstObjectCommonWithArray: (NSArray*) otherArray;
- (BOOL) isEqualToArray: (NSArray*)otherArray;

#ifndef	STRICT_MACOS_X
- (void) makeObjectsPerform: (SEL) aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: argument;
#endif
#ifndef	STRICT_OPENSTEP
- (void) makeObjectsPerformSelector: (SEL) aSelector;
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: argument;
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

- (NSEnumerator*)  objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;

- (NSString*) description;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level;

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxilliaryFile;

@end


@interface NSMutableArray : NSArray
- (id) initWithCapacity: (unsigned)numItems;
- (void) addObject: anObject;
- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject;
- (void) insertObject: anObject atIndex: (unsigned)index;
- (void) removeObjectAtIndex: (unsigned)index;
@end

@interface NSMutableArray (NonCore)

+ arrayWithCapacity: (unsigned)numItems;
+ initWithCapacity: (unsigned)numItems;

- (void) addObjectsFromArray: (NSArray*)otherArray;
- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray;
- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray
			 range: (NSRange)anotherRange;
- (void) setArray: (NSArray *)otherArray;

- (void) removeAllObjects;
- (void) removeLastObject;
- (void) removeObject: anObject;
- (void) removeObject: anObject inRange: (NSRange)aRange;
- (void) removeObjectIdenticalTo: anObject;
- (void) removeObjectIdenticalTo: anObject inRange: (NSRange)aRange;
- (void) removeObjectsInArray: (NSArray*)otherArray;
- (void) removeObjectsInRange: (NSRange)aRange;
- (void) removeObjectsFromIndices: (unsigned*)indices 
		       numIndices: (unsigned)count;

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
		   context: (void*)context;
- (void) sortUsingSelector: (SEL) aSelector;

@end

#endif /* __NSArray_h_GNUSTEP_BASE_INCLUDE */
