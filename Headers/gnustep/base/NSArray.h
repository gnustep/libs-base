/* Interface for NSArray for GNUStep
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

#ifndef __NSArray_h_OBJECTS_INCLUDE
#define __NSArray_h_OBJECTS_INCLUDE

#include <objects/Array.h>
#include <foundation/NSRange.h>

@class NSString;

enum {NSNotInArray = 0x7fffffff}; // to be obsoleted soon

@interface NSArray: Array 

+ allocWithZone:(NSZone *)zone;
+ array;
+ arrayWithObject:anObject;
+ arrayWithObjects:firstObj, ...;
- initWithObjects:(id *)objects count:(unsigned)count;
- initWithObjects:firstObj, ...;
- initWithArray:(NSArray *)array;

- (unsigned)count;
- objectAtIndex:(unsigned)index;
    
- (unsigned)indexOfObjectIdenticalTo:anObject;
- (unsigned)indexOfObject:anObject;
- (BOOL)containsObject:anObject;
- (BOOL)isEqualToArray:(NSArray *)otherArray;
- lastObject;

- (void)makeObjectsPerform:(SEL)aSelector;
- (void)makeObjectsPerform:(SEL)aSelector withObject:argument;
    
- (NSArray *)sortedArrayUsingSelector:(SEL)comparator;
- (NSArray *)sortedArrayUsingFunction:(int (*)(id, id, void *))comparator 
	context:(void *)context;
- (NSString *)componentsJoinedByString:(NSString *)separator;

- firstObjectCommonWithArray:(NSArray *)otherArray;
- (NSArray *)subarrayWithRange:(NSRange)range;
//- (id <NSEnumerator>)objectEnumerator;
//- (id <NSEnumerator>)reverseObjectEnumerator;
- (NSString *)description;
- (NSString *)descriptionWithIndent:(unsigned)level;

@end

@interface NSMutableArray: NSArray

+ allocWithZone:(NSZone *)zone;
+ arrayWithCapacity:(unsigned)numItems;
- initWithCapacity:(unsigned)numItems;

- (void)addObject:anObject;
- (void)replaceObjectAtIndex:(unsigned)index withObject:anObject;
- (void)removeLastObject;
- (void)insertObject:anObject atIndex:(unsigned)index;
- (void)removeObjectAtIndex:(unsigned)index;
    
- (void)removeObjectIdenticalTo:anObject;
- (void)removeObject:anObject;
- (void)removeAllObjects;
- (void)addObjectsFromArray:(NSArray *)otherArray;
- (void)removeObjectsFromIndices:(unsigned *)indices numIndices:(unsigned)count;
- (void)removeObjectsInArray:(NSArray *)otherArray;
- (void)sortUsingFunction:(int (*)(id, id, void *))compare 
	context:(void *)context;

@end

#endif /* __NSArray_h_OBJECTS_INCLUDE */
/* Interface for NSArray for GNUStep
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

#ifndef __NSArray_h_OBJECTS_INCLUDE
#define __NSArray_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Array.h>
#include <foundation/NSRange.h>

@class NSEnumerator;

@interface NSArray : Array <NSCopying, NSMutableCopying>

+ (id) array;
+ (id) arrayWithObject: anObject;
+ (id) arrayWithObjects: firstObject, ...;
- (id) initWithArray: (NSArray*)array;
- (id) initWithObjects: (id)firstObject, ...;
- (id) initWithObjects: (id*)objects count: (unsigned int)count;
- (BOOL) containsObject: (id)candidate;
- (unsigned) count;		/* inherited */
- (unsigned) indexOfObject: (id)anObject; /* inherited */
- (unsigned) indexOfObjectIdenticalTo: (id)anObject;
- (id) lastObject;		/* inherited */
- (id) objectAtIndex: (unsigned)index; /* inherited */
- (NSEnumerator*) objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;
- (void) makeObjectsPerform: (SEL)aSelector; /* inherited */
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)anObject; /* inh */
- (id) firstObjectCommonWithArray: (NSArray*)otherArray;
- (BOOL) isEqualToArray: (NSArray*)otherArray;
- (NSArray*) sortedArrayUsingFunction: (int(*)(id,id,void*))comparator
   context: (void*)context;
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator;
- (NSArray*) subarrayWithRange: (NSRange)range;
- (NSString*) componentsJoinedByString: (NSString*)separator;
- (NSString*) description;

@end

@interface NSMutableArray : NSArray
@end

#endif /* __NSArray_h_OBJECTS_INCLUDE */
