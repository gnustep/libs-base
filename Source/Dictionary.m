/* Implementation for Objective-C Dictionary collection object
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

#include <objects/Dictionary.h>
#include <objects/CollectionPrivate.h>

#define DEFAULT_DICTIONARY_CAPACITY 32

@implementation Dictionary

+ (void) initialize
{
  if (self == [Dictionary class])
    [self setVersion:0];	/* beta release */
}

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_DICTIONARY_CAPACITY;
}
  
// INITIALIZING;

/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding
    keyType: (const char *)keyEncoding
    capacity: (unsigned)aCapacity
{
  [super initWithType:contentEncoding
	 keyType:keyEncoding];
  _contents_hash = 
    coll_hash_new(POWER_OF_TWO(aCapacity),
		  elt_get_hash_function(keyEncoding),
		  elt_get_comparison_function(keyEncoding));
  _comparison_function = elt_get_comparison_function(contentEncoding);
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: (Coder*)aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- _writeInit: (TypedStream*)aStream
{
  const char *ce = [self contentType];
  const char *ke = [self keyType];

  [super _writeInit:aStream];
  /* This implicitly archives the key's comparison and hash functions */
  objc_write_type(aStream, @encode(char*), &ke);
  objc_write_type(aStream, @encode(unsigned int), &(_contents_hash->size));
  /* This implicitly archives the content's comparison function */
  objc_write_type(aStream, @encode(char*), &ce);
  return self;
}

- _readInit: (TypedStream*)aStream
{
  char *keyEncoding, *contentEncoding;
  unsigned int size;

  [super _readInit:aStream];
  objc_read_type(aStream, @encode(char*), &keyEncoding);
  objc_read_type(aStream, @encode(unsigned int), &size);
  _contents_hash =
    coll_hash_new(size,
		  elt_get_hash_function(keyEncoding),
		  elt_get_comparison_function(keyEncoding));
  objc_read_type(aStream, @encode(char*), &contentEncoding);
  _comparison_function = elt_get_comparison_function(contentEncoding);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */

- emptyCopy
{
  Dictionary *copy = [super emptyCopy];
  copy->_contents_hash =
    coll_hash_new(_contents_hash->size,
		  _contents_hash->hash_func,
		  _contents_hash->compare_func);
  return copy;
}

/* To make sure that former KeyedCollection init'ers go through
   Dictionary init, we override the designated initializer for 
   KeyedCollection. */ 
- initWithType: (const char *)contentEncoding
    keyType: (const char *)keyEncoding
{
  return [self initWithType:contentEncoding
	       keyType:keyEncoding
	       capacity:[[self class] defaultCapacity]];
}

- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity
{
  return [self initWithType:contentEncoding
	       keyType:@encode(id)
	       capacity:aCapacity];
}

- initWithCapacity: (unsigned)aCapacity
{
  return [self initWithType:@encode(id) 
	       capacity:aCapacity];
}

- (void) dealloc
{
  coll_hash_delete(_contents_hash);
  [super dealloc];
}

/* This must work without sending any messages to content objects */
- empty
{
  coll_hash_empty(_contents_hash);
  return self;
}


// ADDING OR REPLACING;

- addElement: (elt)anElement
{
  return [self shouldNotImplement:_cmd];
  /* or should I make up some default behavior here? 
     Base it on object conforming to <Associating> protocol, perhaps */
}

- putElement: (elt)newContentElement atKey: (elt)aKey
{
  coll_node_ptr node = coll_hash_node_for_key(_contents_hash, aKey);
  if (node)
    node->value = newContentElement;
  else
    coll_hash_add(&_contents_hash, aKey, 
		  newContentElement);
  return self;
}


// REMOVING;

- (elt) removeElementAtKey: (elt)aKey ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  coll_node_ptr node = coll_hash_node_for_key(_contents_hash, aKey);
  elt ret;

  if (node)
    {
      ret = node->value;
      coll_hash_remove(_contents_hash, aKey);
      return ret;
    }
  else
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
}

- (elt) removeElement: (elt)oldElement ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  elt err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  elt key = [self keyElementOfElement:oldElement ifAbsentCall:err];
  return [self removeElementAtKey:key];
}


// GETTING ELEMENTS;

- (elt) elementAtKey: (elt)aKey ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  coll_node_ptr node = coll_hash_node_for_key(_contents_hash, aKey);
  if (node)
    return node->value;
  else
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
}



// TESTING;

- (int(*)(elt,elt)) comparisonFunction
{
  return _comparison_function;
}

- (const char *) contentType
{
  return elt_get_encoding(_comparison_function);
}

- (const char *) keyType
{
  return elt_get_encoding(_contents_hash->compare_func);
}

- (BOOL) includesKey: (elt)aKey
{
  if (coll_hash_node_for_key(_contents_hash, aKey))
    return YES;
  else
    return NO;
}

// ENUMERATIONS;

- (BOOL) getNextKey: (elt*)aKeyPtr content: (elt*)anElementPtr 
  withEnumState: (void**)enumState
{
  coll_node_ptr node = coll_hash_next(_contents_hash, enumState);
  if (node)
    {
      *aKeyPtr = node->key;
      *anElementPtr = node->value;
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


- withKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc 
    whileTrue: (BOOL *)flag
{
  void *state = 0;
  coll_node_ptr node = 0;

  while (flag && (node = coll_hash_next(_contents_hash, &state)))
    (*aFunc)(node->key, node->value);
  return self;
}


@end
