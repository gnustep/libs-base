/* Implementation for Objective-C Set collection object
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

#include <objects/Set.h>
#include <objects/CollectionPrivate.h>
#include <objects/Coder.h>

#define DEFAULT_SET_CAPACITY 32

@implementation Set 

+ (void) initialize
{
  if (self == [Set class])
    [self setVersion:0];	/* beta release */
}

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_SET_CAPACITY;
}
  
// INITIALIZING AND FREEING;

/* This is the designated initializer of this class */
- initWithType:(const char *)encoding
    capacity: (unsigned)aCapacity 
{
  [super initWithType:encoding];
  _contents_hash = 
    coll_hash_new(POWER_OF_TWO(aCapacity),
		  elt_get_hash_function(encoding),
		  elt_get_comparison_function(encoding));
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) _encodeCollectionWithCoder: (Coder*) aCoder
{
  const char *enc = [self contentType];

  [super _encodeCollectionWithCoder:aCoder];
  [aCoder encodeValueOfSimpleType:@encode(char*) 
	  at:&enc
	  withName:"Set contents encoding"];
  [aCoder encodeValueOfSimpleType:@encode(unsigned) 
	  at:&(_contents_hash->size)
	  withName:"Set contents capacity"];
  return;
}

+ _newCollectionWithCoder: (Coder*) aCoder
{
  Set *newColl;
  char *encoding;
  unsigned size;

  newColl = [super _newCollectionWithCoder:aCoder];
  [aCoder decodeValueOfSimpleType:@encode(char*)
	  at:&encoding
	  withName:NULL];
  [aCoder decodeValueOfSimpleType:@encode(unsigned)
	  at:&size
	  withName:NULL];
  newColl->_contents_hash =
    coll_hash_new(size,
		  elt_get_hash_function(encoding),
		  elt_get_comparison_function(encoding));
  return newColl;
}

- _writeInit: (TypedStream*)aStream
{
  const char *encoding = [self contentType];

  [super _writeInit:aStream];
  /* This implicitly archives the key's comparison and hash functions */
  objc_write_type(aStream, @encode(char*), &encoding);
  objc_write_type(aStream, @encode(unsigned int), &(_contents_hash->size));
  return self;
}

- _readInit: (TypedStream*)aStream
{
  char *encoding;
  unsigned int size;

  [super _readInit:aStream];
  objc_read_type(aStream, @encode(char*), &encoding);
  objc_read_type(aStream, @encode(unsigned int), &size);
  _contents_hash =
    coll_hash_new(size,
		  elt_get_hash_function(encoding),
		  elt_get_comparison_function(encoding));
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Set *copy = [super emptyCopy];
  copy->_contents_hash =
    coll_hash_new(_contents_hash->size,
		  _contents_hash->hash_func,
		  _contents_hash->compare_func);
  return copy;
}

/* Override designated initializer of superclass */
- initWithType:(const char *)contentEncoding
{
  return [self initWithType:contentEncoding
	       capacity:[[self class] defaultCapacity]];
}

- initWithCapacity: (unsigned)aCapacity
{
  return [self initWithType:@encode(id) capacity:aCapacity];
}

- (void) dealloc
{
  coll_hash_delete(_contents_hash);
  [super dealloc];
}

// SET OPERATIONS;

- intersectWithCollection: (id <Collecting>)aCollection
{
  [self removeContentsNotIn:aCollection];
  return self;
}

- unionWithCollection: (id <Collecting>)aCollection
{
  [self addContentsOfIfAbsent:aCollection];
  return self;
}

- differenceWithCollection: (id <Collecting>)aCollection
{
  [self removeContentsIn:aCollection];
  return self;
}

- shallowCopyIntersectWithCollection: (id <Collecting>)aCollection
{
  id newColl = [self emptyCopyAs:[self species]];
  void doIt(elt e)
    {
      if ([aCollection includesElement:e])
	[newColl addElement:e];
    }
  [self withElementsCall:doIt];
  return newColl;
}

- shallowCopyUnionWithCollection: (id <Collecting>)aCollection
{
  id newColl = [self shallowCopy];
  
  [newColl addContentsOf:aCollection];
  return newColl;
}

- shallowCopyDifferenceWithCollection: (id <Collecting>)aCollection
{
  id newColl = [self emptyCopyAs:[self species]];
  void doIt(elt e)
    {
      if (![aCollection includesElement:e])
	[newColl addElement:e];
    }
  [self withElementsCall:doIt];
  return newColl;
}


// ADDING;

- addElement: (elt)anElement
{
  if (coll_hash_value_for_key(_contents_hash, anElement).void_ptr_u == 0)
    coll_hash_add(&_contents_hash, anElement, 1);
  RETAIN_ELT(anElement);
  return self;
}


// REMOVING AND REPLACING;

- (elt) removeElement: (elt)oldElement ifAbsent: (elt(*)(arglist_t))excFunc
{
  if (coll_hash_value_for_key(_contents_hash, oldElement).void_ptr_u == 0)
    coll_hash_remove(_contents_hash, oldElement);
  else
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
  return AUTORELEASE_ELT(oldElement);
}

/* This must work without sending any messages to content objects */
- empty
{
  coll_hash_empty(_contents_hash);
  return self;
}

- uniqueContents
{
  return self;
}


// TESTING;

- (int(*)(elt,elt)) comparisonFunction
{
  return _contents_hash->compare_func;
}

- (const char *) contentType
{
  return elt_get_encoding(_contents_hash->compare_func);
}

- (BOOL) includesElement: (elt)anElement
{
  if (coll_hash_value_for_key(_contents_hash, anElement).void_ptr_u != 0)
    return YES;
  else
    return NO;
}

- (unsigned) count
{
  return _contents_hash->used;
}

- (unsigned) occurrencesOfElement: (elt)anElement
{
  if ([self includesElement:anElement])
    return 1;
  else
    return 0;
}


// ENUMERATING;

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  coll_node_ptr node = coll_hash_next(_contents_hash, enumState);
  if (node)
    {
      *anElementPtr = node->key;
      return YES;
    }
  return NO;
}

- (void*) newEnumState
{
  return (void*)0;
}

- freeEnumState: (void**)enumState
{
  if (*enumState)
    OBJC_FREE(*enumState);
  return self;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  void *state = 0;
  coll_node_ptr node;

  while (*flag && (node = coll_hash_next(_contents_hash, &state))) 
    {
      (*aFunc)(node->key);
    }
  return self;
}

- withElementsCall: (void(*)(elt))aFunc
{
  void *state = 0;
  coll_node_ptr node = 0;

  while ((node = coll_hash_next(_contents_hash, &state)))
    {
      (*aFunc)(node->key);
    }
  return self;
}


@end

