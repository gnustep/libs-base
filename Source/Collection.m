/* Implementation for Objective-C Collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <objects/Collection.h>
#include <objects/CollectionPrivate.h>
#include <stdarg.h>
#include <objects/Bag.h>		/* for -contentsEqual: */
#include <objects/Array.h>		/* for -safeWithElementsCall: */
#include <objects/Coder.h>

@implementation Collection

+ (void) initialize
{
  if (self == [Collection class])
    {
      [self setVersion:0];	// beta release;
    }
}

// INITIALIZING AND RELEASING;

// This is the designated initializer of this class;
- initWithType:(const char *)contentEncoding
{
  [super init];
  if (!elt_get_comparison_function(contentEncoding))
    [self error:"There is no elt comparison function for type encoding %s",
	  contentEncoding];
  return self;
}

- init
{
  // default contents are objects;
  return [self initWithType:@encode(id)];
}

/* Subclasses can override this for efficiency.  For example, Array can 
   init itself with enough capacity to hold aCollection. */
- initWithContentsOf: (id <Collecting>)aCollection
{
  [self initWithType:[aCollection contentType]];
  [self addContentsOf:aCollection];
  return self;
}

- (void) dealloc
{
  // ?;
  [super dealloc];
}

/* May be inefficient.  Could be overridden; */
- empty
{
  if (CONTAINS_OBJECTS)
    [self safeMakeObjectsPerform:@selector(release)];
  [self empty];
  return self;
}

// ADDING;

- addElement: (elt)newElement
{
  return [self subclassResponsibility:_cmd];
}

- addElementIfAbsent: (elt)newElement
{
  if (![self includesElement:newElement])
    return [self addElement:newElement];
  return nil;
}

- addContentsOf: (id <Collecting>)aCollection
{
  id (*addElementImp)(id,SEL,elt) = (id(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(addElement:));

  void doIt(elt e) 
    {
      (*addElementImp)(self, @selector(addElement:), e);
    }

  [aCollection withElementsCall:doIt];
  return self;
}

- addContentsOfIfAbsent: (id <Collecting>)aCollection
{
  id (*addElementImp)(id,SEL,elt) = (id(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(addElement:));
  BOOL (*includesElementImp)(id,SEL,elt) = (BOOL(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(includesElement:));

  void doIt(elt e) 
    {
      if (!((*includesElementImp)(self, @selector(includesElement), e)))
	(*addElementImp)(self, @selector(addElement:), e);
    }

  [aCollection withElementsCall:doIt];
  return self;
}

- addElementsCount: (unsigned)count, ...
{
  va_list ap;

  // could use objc_msg_lookup here also;
  va_start(ap, count);
  while (count--)
    [self addElement:va_arg(ap, elt)];
  va_end(ap);
  return self;
}


// REMOVING AND REPLACING;

- (elt) removeElement: (elt)oldElement
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(oldElement);
    }
  return [self removeElement:oldElement ifAbsentCall:err];
}

- (elt) removeElement: (elt)oldElement ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  return [self subclassResponsibility:_cmd];
}
  

- removeAllOccurrencesOfElement: (elt)oldElement
{
  BOOL (*includesElementImp)(id,SEL,elt) = (BOOL(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(includesElement:));
  elt (*removeElementImp)(id,SEL,elt) = (elt(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(removeElement:));

  while ((*includesElementImp)(self, @selector(includesElement:), oldElement))
    {
      (*removeElementImp)(self, @selector(removeElement:), oldElement);
    }
  return self;
}

- removeContentsIn: (id <Collecting>)aCollection
{
  BOOL (*includesElementImp)(id,SEL,elt) = (BOOL(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(includesElement:));
  elt (*removeElementImp)(id,SEL,elt) = (elt(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(removeElement:));

  void doIt(elt e)
    {
      if ((*includesElementImp)(self, @selector(includesElement:), e))
	(*removeElementImp)(self, @selector(removeElement:), e);
    }

  [aCollection withElementsCall:doIt];
  return self;
}

- removeContentsNotIn: (id <Collecting>)aCollection
{
  BOOL (*includesElementImp)(id,SEL,elt) = (BOOL(*)(id,SEL,elt))
    objc_msg_lookup(aCollection, @selector(includesElement:));
  elt (*removeElementImp)(id,SEL,elt) = (elt(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(removeElement:));

  void doIt(elt e)
    {
      if (!(*includesElementImp)(aCollection, @selector(includesElement:), e))
	(*removeElementImp)(self, @selector(removeElement:), e);
    }

  [self safeWithElementsCall:doIt];
  return self;
}

// remember this has to be overridden for IndexedCollection's;
- (elt) replaceElement: (elt )oldElement with: (elt )newElement
    ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  elt err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  elt ret;
  ret = [self removeElement:oldElement ifAbsentCall:err];
  [self addElement:newElement];
  return ret;
}

- (elt) replaceElement: (elt )oldElement with: (elt)newElement
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(oldElement);
    }
  return [self replaceElement:oldElement with:newElement
	       ifAbsentCall:err];
}

- replaceAllOccurrencesOfElement: (elt)oldElement with: (elt)newElement
{
  BOOL (*includesElementImp)(id,SEL,elt) = (BOOL(*)(id,SEL,elt))
    objc_msg_lookup(self, @selector(includesElement:));
  elt (*replaceElementImp)(id,SEL,elt,elt) = (elt(*)(id,SEL,elt,elt))
    objc_msg_lookup(self, @selector(replaceElement:with:));

  if (ELEMENTS_EQUAL(oldElement, newElement))
    return self;
  while ((*includesElementImp)(self,@selector(includesElement:),oldElement))
    (*replaceElementImp)(self,@selector(replaceElement:with:),
			 oldElement, newElement);
  return self;
}

/* This is pretty inefficient?  Try to come up with something better. */
- uniqueContents
{
  // Use objc_msg_lookup here also;
  void doIt(elt e)
    {
      while ([self occurrencesOfElement:e] > 1)
	[self removeElement:e];
    }
  [self safeWithElementsCall:doIt];
  return self;
}

/* This must work without sending any messages to content objects.
   Content objects already may be dealloc'd when this is executed. */
- _empty
{
  [self subclassResponsibility:_cmd];
  return self;
}

// TESTING;

- (BOOL) isEmpty
{
  return ([self count] == 0);
}

// Potentially inefficient, may be overridden in subclasses;
- (BOOL) includesElement: (elt)anElement
{
  int (*cf)(elt,elt) = [self comparisonFunction];
  BOOL test(elt e)
    {
      if (!((*cf)(anElement, e)))
	return YES;
      else
	return NO;
    }

  return [self trueForAnyElementsByCalling:test];
}

- (BOOL) isSubsetOf: (id <Collecting>)aCollection
{
  BOOL test(elt e) 
    { 
      return [aCollection includesElement:e]; 
    }
  return [self trueForAllElementsByCalling:test];
}
 
- (BOOL) contentsEqual: (id <Collecting>)aCollection
{
  id bag;
  BOOL flag;

  // Could use objc_msg_lookup here also;
  void doIt(elt e)
    {
      if ([bag includesElement:e])
	[bag removeElement:e];
      else
	flag = NO;
    }

  if ([self count] != [aCollection count]
      || ([self comparisonFunction] != [aCollection comparisonFunction]))
    return NO;
  bag = [[Bag alloc] initWithContentsOf:aCollection];
  flag = YES;
  [self withElementsCall:doIt whileTrue:&flag];
  if ((!flag) || [bag count])
    flag = NO;
  else
    flag = YES;
  [bag release];
  return flag;
}

/* This is what I'd like the -compare: implementation in Object.m to 
   look like. */
- (int) _objectCompare: anObject
{
  if (self == anObject)
    return 0;
  if (self > anObject)
    return 1;
  else
    return -1;
}

// Fix this ;
// How do we want to compare unordered contents?? ;
- (int) compareContentsOf: (id <Collecting>)aCollection
{
  if ([self contentsEqual:aCollection])
    return 0;
  if (self > aCollection)
    return 1;
  return -1;
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

- (BOOL) isEqual: anObject
{
  if (self == anObject) 
    return YES;
  if ([anObject class] == [self class]
      && [self contentsEqual: anObject] )
    return YES;
  else
    return NO;
}

- (BOOL) isDisjointFrom: (id <Collecting>)aCollection
{
  // Use objc_msg_lookup here also;
  BOOL flag = YES;
  void doIt(elt e)
    {
      if (![aCollection includesElement:e])
	flag = NO;
    }
  [self withElementsCall:doIt whileTrue:&flag];
  return !flag;
}

- (BOOL) trueForAllElementsByCalling: (BOOL(*)(elt))aFunc
{
  BOOL flag = YES;
  void doIt(elt e)
    {
      if (!((*aFunc)(e)))
	flag = NO;
    }
  [self withElementsCall:doIt whileTrue:&flag];
  return flag;
}

- (BOOL) trueForAllObjectsByCalling: (BOOL(*)(id))aFunc
{
  BOOL flag = YES;
  void doIt(elt e)
    {
      if (!((*aFunc)(e.id_u)))
	flag = NO;
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt whileTrue:&flag];
  return flag;
}

- (BOOL) trueForAnyElementsByCalling: (BOOL(*)(elt))aFunc;
{
  BOOL flag = YES;
  void doIt(elt e)
    {
      if ((*aFunc)(e))
	flag = NO;
    }
  [self withElementsCall:doIt whileTrue:&flag];
  return !flag;
}

- (BOOL) trueForAnyObjectsByCalling: (BOOL(*)(id))aFunc;
{
  BOOL flag = YES;
  void doIt(elt e)
    {
      if ((*aFunc)(e.id_u))
	flag = NO;
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt whileTrue:&flag];
  return !flag;
}

// Inefficient, so should be overridden in subclasses;
- (unsigned) count
{
  unsigned n = 0;
  void doIt(elt e)
    {
      n++;
    }
  [self withElementsCall:doIt];
  return n;
}

- (unsigned) occurrencesOfElement: (elt)anElement
{
  unsigned count = 0;
  int (*cf)(elt,elt) = [self comparisonFunction];
  void doIt(elt e) 
    {
      if (!((*cf)(anElement, e)))
	count++;
    }
  [self withElementsCall:doIt];
  return count;
}

- (unsigned) occurrencesOfObject: anObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self occurrencesOfElement:anObject];
}

- (BOOL) contentsAreObjects
{
  return CONTAINS_OBJECTS;
}

/* The two default implementations below are used by the node collection 
   objects: the collections whose contents are required to be objects
   conforming to some <...Comprising> protocol. */

/* some subclasses will have to override this for correctness */
- (const char *) contentType
{
  /* objects are the default */
  return @encode(id);
}

/* some subclasses will have to override this for correctness */
- (int(*)(elt,elt)) comparisonFunction
{
  /* objects are the default */
  return elt_compare_objects;
}

// ENUMERATING;

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (void*) newEnumState
{
  return (void*)0;
}

- freeEnumState: (void**)enumState
{
  *enumState = (void*)0;
  return self;
}

// Getting objects one at a time.  Pass *enumState == 0 to start.;
- (BOOL) getNextObject:(id *)anObjectPtr withEnumState: (void**)enumState;
{
  elt o;

  CHECK_CONTAINS_OBJECTS_ERROR();
  if ([self getNextElement:&o withEnumState:enumState])
    {
      *anObjectPtr = o.id_u;
      return YES;
    }
  return NO;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag
{
  void *enumState = [self newEnumState];
  elt e;

  while (*flag && [self getNextElement:&e withEnumState:&enumState])
    (*aFunc)(e);
  [self freeEnumState:&enumState];
  return self;
}

- withElementsCall: (void(*)(elt))aFunc
{
  BOOL flag = YES;
  return [self withElementsCall:aFunc whileTrue:&flag];
}

- safeWithElementsCall: (void(*)(elt))aFunc
{
  id tmp = [[Array alloc] initWithContentsOf:self];
  [tmp withElementsCall:aFunc];
  [tmp release];
  return self;
}

- safeWithElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag
{
  id tmp = [[Array alloc] initWithContentsOf:self];
  [tmp withElementsCall:aFunc whileTrue:flag];
  [tmp release];
  return self;
}

// COPYING;

- allocCopy
{
#if NeXT_runtime
  return object_copy(self, 0);
#else
  return object_copy(self);
#endif
}

// the copy to be filled by -shallowCopyAs: etc... ;
- emptyCopy
{
  // This will copy all instance vars;
  // Subclasses will have to change instance vars like Array's _contents_array;
  return [self allocCopy];
}

// the copy to be filled by -shallowCopyAs: etc... ;
- emptyCopyAs: (id <Collecting>)aCollectionClass
{
  if (aCollectionClass == [self species])
    return [self emptyCopy];
  else
    return [[(id)aCollectionClass alloc] 
	    initWithType:[self contentType]];
}

- shallowCopy
{
  return [self shallowCopyAs:[self species]];
}

- shallowCopyAs: (id <Collecting>)aCollectionClass
{
  id newColl = [self emptyCopyAs:aCollectionClass];
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
  void addCopy(elt e)
    {
      [newColl addElement:[e.id_u copy]];
    }
  if (CONTAINS_OBJECTS)
    [self withElementsCall:addCopy];
  else
    [newColl addContentsOf:self];
  return newColl;
}

- copy
{
  return [self copyAs:[self species]];
}

// This method shouldn't be necessary any more;
// (Yuck---replaceElement: is inefficient for many subclasses;
// Also, override this in KeyedCollection and IndexedCollection;)
- deepen
{
  // could use objc_msg_lookup here too;
  void doIt(elt o)
    {
      [self replaceElement:o with:[[o.id_u shallowCopy] deepen]];
    }

  [self error:"Collections don't use -deepen.  Use -copy instead."];
  if (!CONTAINS_OBJECTS)
    return self;
  [self safeWithElementsCall:doIt];
  return self;
}

- species
{
  return [self class];
}


// FILTERED ENUMERATING;

- withElementsTrueByCalling: (BOOL(*)(elt))testFunc 
    call: (void(*)(elt))destFunc
{
  void doIt(elt e)
    {
      if ((*testFunc)(e))
	(*destFunc)(e);
    }
  [self withElementsCall:doIt];
  return self;
}

- withObjectsTrueByCalling: (BOOL(*)(id))testFunc 
    call: (void(*)(id))destFunc
{
  void doIt(elt e)
    {
      if ((*testFunc)(e.id_u))
	(*destFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

- withElementsFalseByCalling: (BOOL(*)(elt))testFunc 
    call: (void(*)(elt))destFunc
{
  void doIt(elt e)
    {
      if (!(*testFunc)(e))
	(*destFunc)(e);
    }
  [self withElementsCall:doIt];
  return self;
}

- withObjectsFalseByCalling: (BOOL(*)(id))testFunc 
    call: (void(*)(id))destFunc
{
  void doIt(elt e)
    {
      if (!(*testFunc)(e.id_u))
	(*destFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

- withElementsTransformedByCalling: (elt(*)(elt))transFunc
    call: (void(*)(elt))destFunc
{
  void doIt(elt e)
    {
      (*destFunc)((*transFunc)(e));
    }
  [self withElementsCall:doIt];
  return self;
}

- withObjectsTransformedByCalling: (id(*)(id))transFunc
    call: (void(*)(id))destFunc
{
  void doIt(elt e)
    {
      (*destFunc)((*transFunc)(e.id_u));
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}


// NON-COPYING ENUMERATORS;

- (elt) detectElementByCalling: (BOOL(*)(elt))aFunc 
    ifNoneCall: (elt(*)(arglist_t))excFunc
{
  BOOL flag = YES;
  elt detectedElement;
  void doIt(elt e)
    {
      if ((*aFunc)(e)) {
	flag = NO;
	detectedElement = e;
      }
    }
  [self withElementsCall:doIt whileTrue:&flag];
  if (flag)
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
  else
    return detectedElement;
}

- (elt) detectElementByCalling: (BOOL(*)(elt))aFunc
{
  elt err(arglist_t argFrame)
    {
      return NO_ELEMENT_FOUND_ERROR();
    }
  return [self detectElementByCalling:aFunc ifNoneCall:err];
}

- (elt) maxElementByCalling: (int(*)(elt,elt))aFunc
{
  elt max;
  BOOL firstTime = YES;
  void doIt(elt e)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  max = e;
	}
      else
	{
	  if ((*aFunc)(e,max) > 0)
	    max = e;
	}
    }
  if (![self count])
    NO_ELEMENT_FOUND_ERROR();
  [self withElementsCall:doIt];
  return max;
}

- (elt) maxElement
{
  return [self maxElementByCalling:COMPARISON_FUNCTION];
}

- (elt) minElementByCalling: (int(*)(elt,elt))aFunc
{
  elt min;
  BOOL firstTime = YES;
  void doIt(elt e)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  min = e;
	}
      else
	{
	  if ((*aFunc)(e,min) < 0)
	    min = e;
	}
    }
  if (![self count])
    NO_ELEMENT_FOUND_ERROR();
  [self withElementsCall:doIt];
  return min;
}

- (elt) minElement
{
  return [self minElementByCalling:COMPARISON_FUNCTION];
}

- (elt) injectElement: (elt)initialData byCalling: (elt(*)(elt,elt))aFunc
{
  void doIt(elt e)
    {
	initialData = (*aFunc)(initialData, e);
    }
  [self withElementsCall:doIt];
  return initialData;
}

- injectObject: (id)initialObject byCalling: (id(*)(id,id))aFunc
{
  void doIt(elt e)
    {
	initialObject = (*aFunc)(initialObject, e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return initialObject;
}


- maxObjectByCalling: (int(*)(id,id))aFunc
{
  id max;
  BOOL firstTime = YES;
  void doIt(id e)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  max = e;
	}
      else
	{
	  if ((*aFunc)(e,max) > 0)
	    max = e;
	}
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  if (![self count])
    NO_ELEMENT_FOUND_ERROR();
  [self withObjectsCall:doIt];
  return max;
}

- maxObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self maxElement].id_u;
}

- minObjectByCalling: (int(*)(id,id))aFunc
{
  id min;
  BOOL firstTime = YES;
  void doIt(id e)
    {
      if (firstTime)
	{
	  firstTime = NO;
	  min = e;
	}
      else
	{
	  if ((*aFunc)(e,min) < 0)
	    min = e;
	}
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  if (![self count])
    NO_ELEMENT_FOUND_ERROR();
  [self withObjectsCall:doIt];
  return min;
}

- minObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self minElement].id_u;
}



// OBJECT-COMPATIBLE MESSAGE NAMES

// ADDING;

- addObject: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self addElement:newObject];
}

- addObjectIfAbsent: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self addElementIfAbsent:newObject];
}

- addObjectsCount: (unsigned)count, ...
{
  va_list ap;

  CHECK_CONTAINS_OBJECTS_ERROR();
  // could use objc_msg_lookup here also;
  va_start(ap, count);
  while (count--)
    [self addElement:va_arg(ap, id)];
  va_end(ap);
  return self;
}

// REMOVING AND REPLACING;

- removeObject: oldObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeElement:oldObject].id_u;
}

- removeObject: oldObject ifAbsentCall: (id(*)(arglist_t))excFunc
{
  elt elt_err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeElement:oldObject ifAbsentCall:elt_err].id_u;
}

- removeAllOccurrencesOfObject: oldObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeAllOccurrencesOfElement:oldObject];
}

- replaceObject: oldObject with: newObject
    ifAbsentCall: (id(*)(arglist_t))excFunc
{
  elt elt_err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self replaceElement:oldObject with: newObject 
	       ifAbsentCall:elt_err].id_u;
}
  
- replaceObject: oldObject with: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self replaceElement:oldObject with:newObject].id_u;
}

- replaceAllOccurrencesOfObject: oldObject with: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self replaceAllOccurrencesOfElement:oldObject with:newObject];
}

// TESTING;

- (BOOL) includesObject: anObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self includesElement:anObject];
}


// ENUMERATING

- withObjectsCall: (void(*)(id))aFunc
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsCall:doIt];
}

- safeWithObjectsCall: (void(*)(id))aFunc
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsCall:doIt];
}

- withObjectsCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsCall:doIt whileTrue:flag];
}

- safeWithObjectsCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsCall:doIt whileTrue:flag];
}

- makeObjectsPerform: (SEL)aSel
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel];
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

- safeMakeObjectsPerform: (SEL)aSel
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel];
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithElementsCall:doIt];
  return self;
}

- safeMakeObjectsPerform: (SEL)aSel with: argObject
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel with:argObject];
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithElementsCall:doIt];
  return self;
}

- makeObjectsPerform: (SEL)aSel with: argObject
{
  void doIt(elt e)
    {
      /* xxx change these to objc runtime functions,
	 in case object doesn't responds to "perform" methods. */
      [e.id_u perform:aSel with:argObject];
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

/* xxx What about adding "-askObjectsPerform: (SEL)aSel with: argObject"
   that doesn't perform is object doesn't respond to aSel */

- withObjectsPerform: (SEL)aSel in: selObject
{
  id (*aSelImp)(id,SEL,id) = (id(*)(id,SEL,id))
    objc_msg_lookup(selObject, aSel);
  void doIt(elt e)
    {
      aSelImp(selObject, aSel, e.id_u);
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

- safeWithObjectsPerform: (SEL)aSel in: selObject
{
  id (*aSelImp)(id,SEL,id) = (id(*)(id,SEL,id))
    objc_msg_lookup(selObject, aSel);
  void doIt(elt e)
    {
      aSelImp(selObject, aSel, e.id_u);
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithElementsCall:doIt];
  return self;
}

- withObjectsPerform: (SEL)aSel in: selObject with: argObject
{
  id (*aSelImp)(id,SEL,id,id) = (id(*)(id,SEL,id,id))
    objc_msg_lookup(selObject, aSel);
  void doIt(elt e)
    {
      aSelImp(selObject, aSel, e.id_u, argObject);
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withElementsCall:doIt];
  return self;
}

- safeWithObjectsPerform: (SEL)aSel in: selObject with: argObject
{
  id (*aSelImp)(id,SEL,id,id) = (id(*)(id,SEL,id,id))
    objc_msg_lookup(selObject, aSel);
  void doIt(elt e)
    {
      aSelImp(selObject, aSel, e.id_u, argObject);
    }

  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithElementsCall:doIt];
  return self;
}


// NON-COPYING ENUMERATORS;

- detectObjectByCalling: (BOOL(*)(id))aFunc 
{
  id err(arglist_t argFrame)
    {
      return NO_ELEMENT_FOUND_ERROR();
    }
  return [self detectObjectByCalling:aFunc ifNoneCall:err];
}

- detectObjectByCalling: (BOOL(*)(id))aFunc 
    ifNoneCall: (id(*)(arglist_t))excFunc
{
  elt err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  BOOL test(elt e)
    {
      return (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self detectElementByCalling:test ifNoneCall:err].id_u;
}

// This printing stuff will change when we get Stream objects;

- printElement: (elt)anElement
{
  elt_fprintf_elt(stdout, [self contentType], anElement);
  return self;
}

- printForDebugger
{
  void doIt(elt e)
    {
      [self printElement:e];
      printf(" ");
    }
  [self withElementsCall:doIt];
  printf(" :%s\n", [self name]);
  return self;
}

- _libobjectsMethodNotYetImplemented: (SEL)aSel
{
  [self error:"method %s in libobjects not yet implemented.\n\
Contact mccallum@gnu.ai.mit.edu (R. Andrew McCallum)\n\
for info about latest version.",
   sel_get_name(aSel)];
  return self;
}

- (const char *) libobjectsLicense
{
  const char *licenseString = 
    "Copyright (C) 1993,1994,1994 Free Software Foundation, Inc.\n"
    "\n"
    "Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>\n"
    "Date: May 1993\n"
    "\n"
    "This object is part of the GNU Objective C Class Library.\n"
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

- (void) encodeWithCoder: (Coder*)aCoder
{
  [self _encodeCollectionWithCoder:aCoder];
  [self _encodeContentsWithCoder:aCoder];
}

+ newWithCoder: (Coder*)aCoder
{
  id newCollection = [self _newCollectionWithCoder:aCoder];
  [newCollection _decodeContentsWithCoder:aCoder];
  return newCollection;
}

@end


@implementation Collection (ArchivingHelpers)

- (void) _encodeCollectionWithCoder: (Coder*) aCoder
{
  [super encodeWithCoder:aCoder];
  // there are no instance vars;
  return;
}

+ _newCollectionWithCoder: (Coder*) aCoder
{
  // there are no instance vars;
  return [super newWithCoder:aCoder];
}

- _writeInit: (TypedStream*)aStream
{
  // there are no instance vars;
  return self;
}

- _readInit: (TypedStream*)aStream
{
  // there are no instance vars;
  return self;
}

- (void) _encodeContentsWithCoder: (Coder*)aCoder
{
  unsigned int count = [self count];
  const char *encoding = [self contentType];
  void archiveElement(elt e)
    {
      [aCoder encodeValueOfType:encoding
	      at:elt_get_ptr_to_member(encoding, &e)
	      withName:"Collection element"];
    }

  [aCoder encodeValueOfSimpleType:@encode(unsigned)
	  at:&count
	  withName:"Collection element count"];
  [self withElementsCall:archiveElement];
}

- (void) _decodeContentsWithCoder: (Coder*)aCoder
{
  unsigned int count, i;
  elt newElement;  
  const char *encoding = [self contentType];

  [aCoder decodeValueOfSimpleType:@encode(unsigned)
	  at:&count
	  withName:NULL];
  for (i = 0; i < count; i++)
    {
      [aCoder decodeValueOfType:encoding
	      at:elt_get_ptr_to_member(encoding, &newElement)
	      withName:NULL];
      [self addElement:newElement];
    }
}

- _writeContents: (TypedStream*)aStream
{
  unsigned int count = [self count];
  const char *encoding = [self contentType];
  void archiveElement(elt e)
    {
      objc_write_type(aStream, encoding,
		      elt_get_ptr_to_member(encoding, &e));
    }

  objc_write_type(aStream, @encode(unsigned int), &count);
  [self withElementsCall:archiveElement];
  return self;
}

- _readContents: (TypedStream*)aStream
{
  unsigned int count, i;
  elt newElement;  
  const char *encoding = [self contentType];

  objc_read_type(aStream, @encode(unsigned int), &count);
  for (i = 0; i < count; i++)
    {
      objc_read_type(aStream, encoding, 
		     elt_get_ptr_to_member(encoding, &newElement));
      [self addElement:newElement];
    }
  return self;
}

@end

