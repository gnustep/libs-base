/* Implementation for Objective-C Collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <config.h>
#include <gnustep/base/Collection.h>
#include <gnustep/base/CollectionPrivate.h>
#include <stdarg.h>
#include <gnustep/base/Bag.h>		/* for -contentsEqual: */
#include <gnustep/base/Array.h>		/* for -safeWithElementsCall: */
#include <gnustep/base/Coder.h>
#include <gnustep/base/NSString.h>

@implementation Enumerator

- initWithCollection: coll
{
  self = [super init];
  if (self)
    {
      collection = [coll retain];
      enum_state = [coll newEnumState];
    }
  return self;
}

- nextObject
{
  return [collection nextObjectWithEnumState: &enum_state];
}

- (void) dealloc
{
  [collection freeEnumState: &enum_state];
  [collection release];
  [super dealloc];
}

@end

@implementation ConstantCollection


// INITIALIZING AND RELEASING;

- init
{
  return [self initWithObjects: NULL count: 0];
}

// This is the designated initializer of this class;
- initWithObjects: (id*)objc count: (unsigned)c
{
  [self subclassResponsibility: _cmd];
  return self;
}

- initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self initWithObjects:firstObject rest:ap];
  va_end(ap);
  return self;
}

#define INITIAL_OBJECTS_SIZE 10
- initWithObjects: firstObject rest: (va_list)ap
{
  id *objects;
  int i = 0;
  int s = INITIAL_OBJECTS_SIZE;

  OBJC_MALLOC(objects, id, s);
  if (firstObject != nil)
    {
      objects[i++] = firstObject;
      while ((objects[i++] = va_arg(ap, id)))
	{
	  if (i >= s)
	    {
	      s *= 2;
	      OBJC_REALLOC(objects, id, s);
	    }
	}
    }
  self = [self initWithObjects:objects count:i-1];
  OBJC_FREE(objects);
  return self;
}

/* Subclasses can override this for efficiency.  For example, Array can 
   init itself with enough capacity to hold aCollection. */
- initWithContentsOf: (id <Collecting>)aCollection
{
  int count = [aCollection count];
  id contents_array[count];
  id o;
  int i = 0;

  FOR_COLLECTION(aCollection, o)
    {
      contents_array[i++] = o;
    }
  END_FOR_COLLECTION(aCollection);
  return [self initWithObjects: contents_array count: count];
}

- (void) dealloc
{
  /* xxx Get rid of this since Set, Bag, Dictionary, and String
     subclasses don't want to use it? */
  [self _collectionReleaseContents];
  [self _collectionDealloc];
  [super dealloc];
}


// QUERYING COUNTS;

- (BOOL) isEmpty
{
  return ([self count] == 0);
}

// Inefficient, so should be overridden in subclasses;
- (unsigned) count
{
  unsigned n = 0;
  id o;

  FOR_COLLECTION(self, o)
    {
      n++;
    }
  END_FOR_COLLECTION(self);
  return n;
}

// Potentially inefficient, may be overridden in subclasses;
- (BOOL) containsObject: anObject
{
  id o;
  FOR_COLLECTION (self, o)
    {
      if ([anObject isEqual: o])
	return YES;
    }
  END_FOR_COLLECTION(self);
  return NO;
}

- (unsigned) occurrencesOfObject: anObject
{
  unsigned count = 0;
  id o;

  FOR_COLLECTION(self, o)
    {
      if ([anObject isEqual: o])
	count++;
    }
  END_FOR_COLLECTION(self);
  return count;
}


// COMPARISON WITH OTHER COLLECTIONS;

- (BOOL) isSubsetOf: (id <Collecting>)aCollection
{
  id o;
  FOR_COLLECTION (self, o)
    {
      if (![aCollection containsObject: o])
	return NO;
    }
  END_FOR_COLLECTION (self);
  return YES;
}
 
- (BOOL) isDisjointFrom: (id <Collecting>)aCollection
{
  // Use objc_msg_lookup here also;
  BOOL flag = YES;
  id o;

  FOR_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      if (![aCollection containsObject: o])
	flag = NO;
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
  return !flag;
}

// xxx How do we want to compare unordered contents?? ;
- (int) compareContentsOf: (id <Collecting>)aCollection
{
  if ([self contentsEqual:aCollection])
    return 0;
  if (self > aCollection)
    return 1;
  return -1;
}

- (BOOL) isEqual: anObject
{
  if (self == anObject) 
    return YES;
  if ( [self contentsEqual: anObject] )
    return YES;
  else
    return NO;
}

// Deal with this in IndexedCollection also ;
// How do we want to compare collections? ;
- (int) compare: anObject
{
  if ([self isEqual:anObject])
    return 0;
  if (self > anObject)
    return 1;
  return -1;
}

- (BOOL) contentsEqual: (id <Collecting>)aCollection
{
  id bag, o;
  BOOL flag;

  if ([self count] != [aCollection count])
    return NO;
  bag = [[Bag alloc] initWithContentsOf:aCollection];
  flag = YES;
  FOR_COLLECTION_WHILE_TRUE (self, o, flag)
    {
      if ([bag containsObject: o])
	[bag removeObject: o];
      else
	flag = NO;
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
  if ((!flag) || [bag count])
    flag = NO;
  else
    flag = YES;
  [bag release];
  return flag;
}


// PROPERTIES OF CONTENTS;

- (BOOL) trueForAllObjectsByInvoking: (id <Invoking>)anInvocation
{
  BOOL flag = YES;
  id o;

  FOR_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      [anInvocation invokeWithObject: o];
      if (![anInvocation returnValueIsTrue])
	flag = NO;
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
  return flag;
}

- (BOOL) trueForAnyObjectsByInvoking: (id <Invoking>)anInvocation;
{
  BOOL flag = YES;
  id o;

  FOR_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      [anInvocation invokeWithObject: o];
      if ([anInvocation returnValueIsTrue])
	flag = NO;
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
  return !flag;
}

- detectObjectByInvoking: (id <Invoking>)anInvocation;
{
  BOOL flag = YES;
  id detectedObject = nil;
  id o;

  FOR_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      [anInvocation invokeWithObject: o];
      if ([anInvocation returnValueIsTrue])
	{
	  flag = NO;
	  detectedObject = o;
	}
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
  if (flag)
    return NO_OBJECT;
  else
    return detectedObject;
}

- maxObject
{
  id o, max = nil;
  BOOL firstTime = YES;

  FOR_COLLECTION(self, o)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  max = o;
	}
      else
	{
	  if ([o compare: max] > 0)
	    max = o;
	}
    }
  END_FOR_COLLECTION(self);
  return max;
}

- minObject
{
  id o, min = nil;
  BOOL firstTime = YES;

  FOR_COLLECTION(self, o)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  min = o;
	}
      else
	{
	  if ([o compare: min] < 0)
	    min = o;
	}
    }
  END_FOR_COLLECTION(self);
  return min;
}

/* Consider adding:
   - maxObjectByInvoking: (id <Invoking>)anInvocation;
   - minObjectByInvoking: (id <Invoking>)anInvocation;
   */


// ENUMERATING;

- (id <Enumerating>) objectEnumerator
{
  return [[[Enumerator alloc] initWithCollection: self]
	   autorelease];
}

- (void) withObjectsInvoke: (id <Invoking>)anInvocation
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [anInvocation invokeWithObject: o];
    }
  END_FOR_COLLECTION(self);
}

- (void) withObjectsInvoke: (id <Invoking>)anInvocation whileTrue:(BOOL *)flag;
{
  id o;

  FOR_COLLECTION_WHILE_TRUE(self, o, *flag)
    {
      [anInvocation invokeWithObject: o];
    }
  END_FOR_COLLECTION_WHILE_TRUE(self);
}

- (void) makeObjectsPerform: (SEL)aSel
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [o performSelector: aSel];
    }
  END_FOR_COLLECTION(self);
}

- (void) makeObjectsPerform: (SEL)aSel withObject: argObject
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [o performSelector: aSel withObject: argObject];
    }
  END_FOR_COLLECTION(self);
}



// FILTERED ENUMERATING;

- (void) withObjectsTrueByInvoking: (id <Invoking>)testInvocation
    invoke: (id <Invoking>)anInvocation
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [testInvocation invokeWithObject: o];
      if ([testInvocation returnValueIsTrue])
	[anInvocation invokeWithObject: o];
    }
  END_FOR_COLLECTION(self);
}

- (void) withObjectsFalseByInvoking: (id <Invoking>)testInvocation
    invoke: (id <Invoking>)anInvocation
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [testInvocation invokeWithObject: o];
      if (![testInvocation returnValueIsTrue])
	[anInvocation invokeWithObject: o];
    }
  END_FOR_COLLECTION(self);
}

- (void) withObjectsTransformedByInvoking: (id <Invoking>)transInvocation
    invoke: (id <Invoking>)anInvocation
{
  id o;

  FOR_COLLECTION(self, o)
    {
      [transInvocation invokeWithObject: o];
      [anInvocation invokeWithObject: [transInvocation objectReturnValue]];
    }
  END_FOR_COLLECTION(self);
}



// LOW-LEVEL ENUMERATING;

- (void*) newEnumState
{
  return (void*)0;
}

- nextObjectWithEnumState: (void**)enumState;
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (void) freeEnumState: (void**)enumState
{
  *enumState = (void*)0;
}



// COPYING;

- allocCopy
{
  return NSCopyObject (self, 0, [self zone]);
}

// the copy to be filled by -shallowCopyAs: etc... ;
- emptyCopy
{
  // This will copy all instance vars;
  // Subclasses will have to change instance vars like Array's _contents_array;
  return [self allocCopy];
}

// the copy to be filled by -shallowCopyAs: etc... ;
- emptyCopyAs: (Class)aCollectionClass
{
  if (aCollectionClass == [self species])
    return [self emptyCopy];
  else
    return [[(id)aCollectionClass alloc] init];
}

- shallowCopy
{
  return [self shallowCopyAs:[self species]];
}

- shallowCopyAs: (Class)aCollectionClass
{
  id newColl = [self emptyCopyAs:aCollectionClass];
  //#warning fix this addContentsOf for ConstantCollection
  [newColl addContentsOf:self];
  return newColl;
}

/* We can avoid the ugly [self safeWithElementsCall:doIt];
   in -deepen with something like this instead.
   This fits with a scheme in which we get rid of the -deepen method, an
   idea that I like since calling deepen on an object that has not just
   been -shallowCopy'ed can cause major memory leakage. */
- copyAs: (id <Collecting>)aCollectionClass
{
  id newColl = [self emptyCopyAs:aCollectionClass];
  id o;

  FOR_COLLECTION(self, o)
    {
      //#warning fix this addObject for ConstantCollection
      id n = [o copy];
      [newColl addObject:n];
      [n release];
    }
  END_FOR_COLLECTION(self);
  return newColl;
}

- species
{
  return [self class];
}


// EXTRAS;

- (const char *) libobjectsLicense
{
  const char *licenseString = 
    "Copyright (C) 1993,1994,1995,1996 Free Software Foundation, Inc.\n"
    "\n"
    "Chief Maintainer: Andrew McCallum <mccallum@gnu.ai.mit.edu>\n"
    "\n"
    "This object is part of the GNUstep Base Library.\n"
    "\n"
    "This library is free software; you can redistribute it and/or\n"
    "modify it under the terms of the GNU Library General Public\n"
    "License as published by the Free Software Foundation; either\n"
    "version 2 of the License, or (at your option) any later version.\n"
    "\n"
    "This library is distributed in the hope that it will be useful,\n"
    "but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
    "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU\n"
    "Library General Public License for more details.\n"
    "\n"
    "You should have received a copy of the GNU Library General Public\n"
    "License along with this library; if not, write to the Free\n"
    "Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.\n";
  return licenseString;
}

- printForDebugger
{
  id o;
  FOR_COLLECTION(self, o)
    {
      printf("%s ", [[o description] cString]);
    }
  END_FOR_COLLECTION(self);
  printf(": %s\n", object_get_class_name (self));
  return self;
}

- (void) encodeWithCoder: aCoder
{
  [self _encodeCollectionWithCoder:aCoder];
  [self _encodeContentsWithCoder:aCoder];
}

- initWithCoder: aCoder
{
  [self _initCollectionWithCoder:aCoder];
  [self _decodeContentsWithCoder:aCoder];
  return self;
}

@end


@implementation ConstantCollection (ArchivingHelpers)

- (void) _encodeCollectionWithCoder: aCoder
{
  [super encodeWithCoder:aCoder];
  // there are no instance vars;
  return;
}

- _initCollectionWithCoder: aCoder
{
  // there are no instance vars;
  return [super initWithCoder:aCoder];
}

- (void) _encodeContentsWithCoder: (id <Encoding>)aCoder
{
  unsigned int count = [self count];
  id o;

  [aCoder encodeValueOfCType: @encode(unsigned)
	  at: &count
	  withName: @"Collection content count"];
  FOR_COLLECTION(self, o)
    {
      [aCoder encodeObject: o
	      withName:@"Collection element"];
    }
  END_FOR_COLLECTION(self);
}

- (void) _decodeContentsWithCoder: (id <Decoding>)aCoder
{
  id *content_array;
  unsigned int count, i;

  [aCoder decodeValueOfCType:@encode(unsigned)
	  at:&count
	  withName:NULL];
  content_array = alloca (sizeof (id) * count);
  for (i = 0; i < count; i++)
    [aCoder decodeObjectAt: &(content_array[i])
	    withName:NULL];
  [self initWithObjects: content_array count: count];
  for (i = 0; i < count; i++)
    [content_array[i] release];
}

@end


@implementation ConstantCollection (DeallocationHelpers)

/* This must work without sending any messages to content objects.
   Content objects already may be dealloc'd when this is executed. */
- (void) _collectionEmpty
{
  [self subclassResponsibility:_cmd];
}

- (void) _collectionReleaseContents
{
  int c = [self count];
  if (c)
    {
      id *array = (id*) alloca (c * sizeof(id));
      int i = 0;
      void *es = [self newEnumState];
      id o;
      while ((o = [self nextObjectWithEnumState:&es]))
	{
	  array[i++] = o;
	}
      [self freeEnumState: &es];
      assert (c == i);
      for (i = 0; i < c; i++)
	[array[i] release];
    }
}

- (void) _collectionDealloc
{
  return;
}

@end


@implementation Collection

// ADDING;

- (void) addObject: anObject
{
  [self subclassResponsibility:_cmd];
}

- (void) addObjectIfAbsent: newObject;
{
  if (![self containsObject: newObject])
    [self addObject: newObject];
}

- (void) addContentsOf: (id <Collecting>)aCollection
{
  id o;

  FOR_COLLECTION(aCollection, o)
    {
      [self addObject: o];
    }
  END_FOR_COLLECTION(aCollection);
}

- (void) addContentsIfAbsentOf: (id <Collecting>)aCollection
{
  id o;

  FOR_COLLECTION(aCollection, o)
    {
      if (![self containsObject:o])
	[self addObject: o];
    }
  END_FOR_COLLECTION(aCollection);
}

- (void) addWithObjects: (id*)objc count: (unsigned)c
{
  [self notImplemented: _cmd];
}

- (void) addObjects: firstObject, ...
{
  [self notImplemented: _cmd];
}

- (void) addObjects: firstObject rest: (va_list)ap
{
  [self notImplemented: _cmd];
}


// REMOVING AND REPLACING;

- (void) removeObject: oldObject
{
  [self subclassResponsibility: _cmd];
}

- (void) removeAllOccurrencesOfObject: oldObject
{
  while ([self containsObject: oldObject])
    [self removeObject: oldObject];
}

- (void) removeContentsIn: (id <ConstantCollecting>)aCollection
{
  id o;

  FOR_COLLECTION(aCollection, o)
    {
      [self removeObject: o];
    }
  END_FOR_COLLECTION(aCollection);
}

- (void) removeContentsNotIn: (id <ConstantCollecting>)aCollection
{
  id o;

  FOR_COLLECTION(self, o)
    {
      if (![aCollection containsObject: o])
	[self removeObject: o];
    }
  END_FOR_COLLECTION(self);
}

- (void) uniqueContents
{
  id cp = [self shallowCopy];
  int count;
  id o;

  FOR_COLLECTION(cp, o)
    {
      count = [self occurrencesOfObject: o];
      if (!count)
	continue;
      while (count--)
	[self removeObject: o];
    }
  END_FOR_COLLECTION(cp);
}

/* May be inefficient.  Could be overridden; */
- (void) empty
{
  if ([self isEmpty])
    return;
  [self _collectionReleaseContents];
  [self _collectionEmpty];
}


// REPLACING;

- (void) replaceObject: oldObject withObject: newObject
{
  if ([newObject isEqual: newObject])
    return;
  [oldObject retain];
  [self removeObject: oldObject];
  [self addObject: newObject];
  [oldObject release];
}

- (void) replaceAllOccurrencesOfObject: oldObject withObject: newObject
{
  if ([oldObject isEqual: newObject])
    return;
  while ([self containsObject: oldObject])
    [self replaceObject: oldObject withObject: newObject];
}

@end
