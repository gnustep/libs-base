/* Implementation of Objective C NeXT-compatible HashTable object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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
#include <base/preface.h>
#include <objc/HashTable.h>

#define DEFAULT_HASH_CAPACITY 32


/* Some useful hash and compare functions not provided by hash.h */

static inline unsigned int
hash_object (cache_ptr cache, const void *key)
{
  return (([((id)key) hash]) & cache->mask);
}

static inline int
compare_objects (const void *k1, const void *k2)
{
  return (int)[(id)k1 isEqual:(id)k2];
}

static inline unsigned int
hash_int (cache_ptr cache, const void *key)
{
  return ((unsigned int)key & cache->mask);
}

static inline int
compare_ints (const void *k1, const void *k2)
{
  return !((int)k1 - (int)k2);
}

static inline int
compare_long_ints (const void *k1, const void *k2)
{
  return !((long int)k1 - (long int)k2);
}

@implementation HashTable
  
+ initialize
{
  if (self == [HashTable class])
    [self setVersion:0];	/* beta release */
  return self;
}

- initKeyDesc: (const char *)aKeyDesc 
  valueDesc: (const char *)aValueDesc 
  capacity: (unsigned) aCapacity
{
  hash_func_type hf;
  compare_func_type cf;
  
  if (!aKeyDesc) 
    [self error:"in %s, NULL keyDesc\n", sel_get_name(_cmd)];
  if (!aValueDesc) 
    [self error:"in %s, NULL valueDesc\n", sel_get_name(_cmd)];
  count = 0;
  keyDesc = aKeyDesc;
  valueDesc = aValueDesc;
  switch (*aKeyDesc) 
    {
    case _C_ATOM:
    case _C_CHARPTR : 
      hf = (hash_func_type)hash_string;
      cf = (compare_func_type)compare_strings;
      break;
    case _C_ID:
    case _C_CLASS:
      hf = (hash_func_type)hash_object;
      cf = (compare_func_type)compare_objects;
      break;
    case _C_PTR: 
      hf = (hash_func_type)hash_ptr;
      cf = (compare_func_type)compare_ptrs;
      break;
    case _C_INT: 
    case _C_SEL:
    case _C_UINT: 
      hf = (hash_func_type)hash_int;
      cf = (compare_func_type)compare_ints;
      break;
    case _C_LNG: 
    case _C_ULNG: 
      hf = (hash_func_type)hash_int;
      cf = (compare_func_type)compare_long_ints;
      break;
    case _C_FLT:
      /* Fix this.  Do something better with floats. */
      hf = (hash_func_type)hash_int;
      cf = (compare_func_type)compare_ints;
      break;
    default: 
      hf = (hash_func_type)hash_int;
      cf = (compare_func_type)compare_ints;
      break;
    }
  _buckets = hash_new(aCapacity, hf, cf);
  _nbBuckets = _buckets->size;
  return self;
}

- initKeyDesc:(const char *)aKeyDesc 
  valueDesc:(const char *)aValueDesc
{
  return [self initKeyDesc:aKeyDesc 
	       valueDesc:aValueDesc 
	       capacity:DEFAULT_HASH_CAPACITY];
}

- initKeyDesc: (const char *)aKeyDesc
{
  return [self initKeyDesc:aKeyDesc
	       valueDesc:@encode(id)];
}

- init
{
  return [self initKeyDesc:@encode(id)];
}

- free
{
  hash_delete(_buckets);
  return [super free];
}

- freeObjects
{
  node_ptr node;
  void *val;
  
  while ((node = hash_next(_buckets, 0)))
    {
      val = node->value;
      hash_remove(_buckets, node->key);
      if (*valueDesc == _C_ID)
	[(id)val free];
    }
  count = 0;
  _nbBuckets = _buckets->size;
  return self;
}

- freeKeys:(void (*) (void *))keyFunc 
  values:(void (*) (void *))valueFunc
{
  /* What exactly is this supposed to do? */
  [self notImplemented:_cmd];
  return self;
}

- empty
{
  node_ptr node;
  
  while ((node = hash_next(_buckets, 0)))
    hash_remove(_buckets, node->key);
  count = 0;
  _nbBuckets = _buckets->size;
  return self;
}

- shallowCopy
{
  HashTable *c;
  node_ptr node;
  
  c = [super shallowCopy];
  c->_buckets = hash_new(_buckets->size, 
			 _buckets->hash_func, 
			 _buckets->compare_func);
  /* copy nodes to new copy */
  node = 0;
  while ((node = hash_next(_buckets, node)))
    [c insertKey:node->key value:node->value];

  return c;
}

- deepen
{
  node_ptr node = 0;
  
  if (*valueDesc == _C_ID) 
    {
      while ((node = hash_next(_buckets, node)))
	{
	  node->value = [(id)(node->value) deepCopy];
	}
    }
  /* If the hashtable contains strings should we copy them too??
     But we definitely shouldn't copy "%" keys. */
  return self;
}

- (unsigned) count
{
  return count;
}

- (BOOL) isKey:(const void *)aKey
{
  return hash_is_key_in_hash(_buckets, aKey);
}

- (void *) valueForKey:(const void *)aKey
{
  return hash_value_for_key(_buckets, aKey);
}

- (void *) insertKey:(const void *)aKey value:(void *)aValue
{
  void *prevValue;
  
  prevValue = hash_value_for_key(_buckets, aKey);
  if (prevValue)
    hash_remove(_buckets, aKey);
  hash_add(&_buckets, aKey, aValue);
  count = _buckets->used;
  _nbBuckets = _buckets->size;
  return prevValue;
}

- (void *) removeKey:(const void *)aKey
{
  if (hash_value_for_key(_buckets, aKey)) 
    {
      hash_remove(_buckets, aKey);
      count = _buckets->used;
      _nbBuckets = _buckets->size;
    }
  return nil;
}

- (NXHashState) initState
{
  return (NXHashState) 0;
}

- (BOOL) nextState:(NXHashState *)aState 
         key:(const void **)aKey 
         value:(void **)aValue
{
  *aState = hash_next(_buckets, *aState);
  if (*aState) 
    {
      *aKey = (*aState)->key;
      *aValue = (*aState)->value;
      return YES;
    }
  else
    return NO;
}

- write: (TypedStream*)aStream
{
  NXHashState state = [self initState];
  const void *k;
  void *v;

  if (!strcmp(keyDesc, "%"))
    [self error:"Archiving atom strings, @encode()=\"%\", not yet handled"];
  [super write: aStream];
  objc_write_types(aStream, "II**", 
		   [self count], _nbBuckets, keyDesc, valueDesc);
  while ([self nextState:&state key:&k value:&v])
    {
      objc_write_type(aStream, keyDesc, &k);
      objc_write_type(aStream, valueDesc, &v);
    }
  return self;
}

- read: (TypedStream*)aStream
{
  unsigned cnt, capacity;
  int i;
  const void *k;
  void *v;

  [super read:aStream];
  objc_read_types(aStream, "II**", 
		  &cnt, &capacity, &keyDesc, &valueDesc);
  if (!strcmp(keyDesc, "%"))
    [self error:"Archiving atom strings, @encode()=\"%\", not yet handled"];
  [self initKeyDesc:keyDesc valueDesc:valueDesc capacity:capacity];
  for (i = 0; i < cnt; i++)
    {
      objc_read_type(aStream, keyDesc, &k);
      objc_read_type(aStream, valueDesc, &v);
      [self insertKey:k value:v];
    }
  return self;
}


+ newKeyDesc: (const char *)aKeyDesc
{
  return [[[self class] alloc] initKeyDesc:aKeyDesc];
}

+ newKeyDesc:(const char *)aKeyDesc 
  valueDesc:(const char *)aValueDesc
{
  return [[self alloc] 
	  initKeyDesc:aKeyDesc
	  valueDesc:aValueDesc];
}

+ newKeyDesc:(const char *)aKeyDesc 
  valueDesc:(const char *)aValueDesc
  capacity:(unsigned)aCapacity
{
  return [[self alloc]
	  initKeyDesc:aKeyDesc
	  valueDesc:aValueDesc
	  capacity:aCapacity];
}

- makeObjectsPerform:(SEL)aSel
{
  node_ptr node = 0;
  
  while ((node = hash_next(_buckets, node)))
    [(id)(node->value) perform:aSel];
  return self;
}

- makeObjectsPerform:(SEL)aSel with:anObject
{
  node_ptr node = 0;
  
  while ((node = hash_next(_buckets, node)))
    [(id)(node->value) perform:aSel with:anObject];
  return self;
}

@end
