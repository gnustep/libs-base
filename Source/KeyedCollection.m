/* Implementation for Objective-C KeyedCollection collection object
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

#include <objects/KeyedCollection.h>
#include <objects/CollectionPrivate.h>
#include <stdio.h>
#include <objects/Array.h>

@implementation KeyedCollection

+ (void) initialize
{
  if (self == [KeyedCollection class])
    [self setVersion:0];	/* beta release */
}


// NON-OBJECT ELEMENT METHOD NAMES;

// INITIALIZING;

/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding
    keyType: (const char *)keyEncoding
{
  [super initWithType:contentEncoding];
  if (!elt_get_comparison_function(contentEncoding))
    [self error:"There is no elt comparison function for type encoding %s",
	  keyEncoding];
  return self;
}

- initKeyType: (const char *)keyEncoding
{
  // default contents are objects;
  return [self initWithType:@encode(id) keyType:keyEncoding];
}

/* Override designated initializer of superclass */
- initWithType: (const char *)contentEncoding
{
  // default keys are objects;
  return [self initWithType:contentEncoding
	       keyType:@encode(id)];
}

- (void) dealloc
{
  // ?? ;
  [super dealloc];
}


// ADDING OR REPLACING;

- putElement: (elt)newContentElement atKey: (elt)aKey
{
  return [self subclassResponsibility:_cmd];
}

- addContentsOf: (id <KeyedCollecting>)aKeyedCollection
{
  id (*putElementAtKeyImp)(id,SEL,elt,elt) = (id(*)(id,SEL,elt,elt))
    objc_msg_lookup(self, @selector(putElement:atKey:));
  void doIt(elt k, elt c)
    {
      (*putElementAtKeyImp)(self, @selector(putElement:atKey:),
			       c, k);
    }
  [aKeyedCollection withKeyElementsAndContentElementsCall:doIt];
  return self;
}

/* The right thing?  Or should this be subclass responsibility? */
- (elt) replaceElementAtKey: (elt)aKey with: (elt)newContentElement
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(aKey);
    }
  return [self replaceElementAtKey:aKey with:newContentElement
	       ifAbsentCall:err];
}

- (elt) replaceElementAtKey: (elt)aKey with: (elt)newContentElement
    ifAbsentCall: (elt(*)(arglist_t))excFunc;
{
  elt err(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  elt ret;

  ret = [self removeElementAtKey:aKey ifAbsentCall:err];
  [self putElement:newContentElement atKey:aKey];
  return ret;
}

- swapAtKeys: (elt)key1 : (elt)key2
{
  /* Use two tmp's so that when we add reference counting, the count will
     stay correct. */
  elt tmp1 = [self removeElementAtKey:key1];
  elt tmp2 = [self removeElementAtKey:key2];
  [self putElement:tmp2 atKey:key1];
  [self putElement:tmp1 atKey:key2];
  return self;
}

// REMOVING;

- (elt) removeElementAtKey: (elt)aKey
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(aKey);
    }
  return [self removeElementAtKey:aKey ifAbsentCall:err];
}

- (elt) removeElementAtKey: (elt)aKey  
    ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  return [self subclassResponsibility:_cmd];
}
  
- removeObjectAtKey: (elt)aKey
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeElementAtKey:aKey].id_u;
}


// GETTING ELEMENTS AND KEYS;

- (elt) elementAtKey: (elt)aKey
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(aKey);
    }
  return [self elementAtKey:aKey ifAbsentCall:err];
}

- (elt) elementAtKey: (elt)aKey ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  return [self subclassResponsibility:_cmd];
}

- (elt) keyElementOfElement: (elt)aContent
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(aContent);
    }
  return [self keyElementOfElement:aContent ifAbsentCall:err];
}

- (elt) keyElementOfElement: (elt)aContent
    ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  elt theKey;
  BOOL notDone = YES;
  int (*cf)(elt,elt) = [self comparisonFunction];
  void doIt(elt key, elt content)
    {
      if (!((*cf)(aContent, content)))
	{
	  theKey = key;
	  notDone = NO;
	}
    }
  [self withKeyElementsAndContentElementsCall:doIt whileTrue:&notDone];
  if (notDone)
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
  return theKey;
}

- objectAtKey: (elt)aKey
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self elementAtKey:aKey].id_u;
}

- keyObjectOfObject: aContent
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self keyElementOfElement:aContent].id_u;
}


// TESTING;

- (const char *) keyType
{
  [self subclassResponsibility:_cmd];
  return "";
}

- (BOOL) includesKey: (elt)aKey
{
  [self subclassResponsibility:_cmd];
  return NO;
}

// COPYING;

- shallowCopyAs: (id <Collecting>)aCollectionClass
{
  id (*putElementAtKeyImp)(id,SEL,elt,elt);
  id newColl;

  void addKeysAndContents(const elt key, elt content)
    {
      putElementAtKeyImp(newColl, @selector(putElement:atKey:),
			    content, key);
    }

  if ([aCollectionClass conformsToProtocol:@protocol(KeyedCollecting)])
    {
      newColl = [self emptyCopyAs:aCollectionClass];
      putElementAtKeyImp = (id(*)(id,SEL,elt,elt))
	objc_msg_lookup(newColl, @selector(putElement:atKey:));
      [self withKeyElementsAndContentElementsCall:addKeysAndContents];
      return newColl;
    }
  else
    return [super shallowCopyAs:aCollectionClass];
}


// ENUMERATING;

- (BOOL) getNextKey: (elt*)aKeyPtr content: (elt*)anElementPtr 
  withEnumState: (void**)enumState;
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  elt key;
  return [self getNextKey:&key content:anElementPtr 
	       withEnumState:enumState];
}

- withKeyElementsCall: (void(*)(const elt))aFunc
{
  void doIt(elt key, elt content)
    {
      (*aFunc)(key);
    }
  [self withKeyElementsAndContentElementsCall:doIt];
  return self;
}

- safeWithKeyElementsCall: (void(*)(const elt))aFunc
{
  id tmpColl = [[Array alloc] initWithType:[self keyType]
		capacity:[self count]];
  void addKey(elt k, elt c)
    {
      [tmpColl addElement:k];
    }
  [self withKeyElementsAndContentElementsCall:addKey];
  [tmpColl withElementsCall:aFunc];
  [tmpColl release];
  return self;
}

- withKeyObjectsCall: (void(*)(id))aFunc
{
  void doIt(elt key, elt content)
    {
      (*aFunc)(key.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withKeyElementsAndContentElementsCall:doIt];
  return self;
}

- safeWithKeyObjectsCall: (void(*)(id))aFunc
{
  void doIt(elt key)
    {
      (*aFunc)(key.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithKeyElementsCall:doIt];
  return self;
}

- withKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc
{
  BOOL flag = YES;

  [self withKeyElementsAndContentElementsCall:aFunc whileTrue:&flag];
  return self;
}

- safeWithKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc
{
  BOOL flag = YES;

  [self safeWithKeyElementsAndContentElementsCall:aFunc whileTrue:&flag];
  return self;
}

- withKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc
{
  BOOL flag = YES;
  void doIt(elt k, elt c)
    {
      (*aFunc)(k.id_u, c.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withKeyElementsAndContentElementsCall:doIt whileTrue:&flag];
  return self;
}

- safeWithKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc
{
  BOOL flag = YES;
  void doIt(elt k, elt c)
    {
      (*aFunc)(k.id_u, c.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithKeyElementsAndContentElementsCall:doIt whileTrue:&flag];
  return self;
}

- withKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc 
    whileTrue: (BOOL *)flag
{
  void *s = [self newEnumState];
  elt key, content;

  while (*flag && [self getNextKey:&key content:&content withEnumState:&s])
    (*aFunc)(key, content);
  [self freeEnumState:&s];
  return self;
}

- withKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc 
    whileTrue: (BOOL *)flag
{
  void doIt(elt k, elt c)
    {
      (*aFunc)(k.id_u, c.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self withKeyElementsAndContentElementsCall:doIt whileTrue:flag];
  return self;
}

- safeWithKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc 
    whileTrue: (BOOL *)flag
{
  void doIt(elt k, elt c)
    {
      (*aFunc)(k.id_u, c.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  [self safeWithKeyElementsAndContentElementsCall:doIt whileTrue:flag];
  return self;
}

- safeWithKeyElementsAndContentElementsCall: (void(*)(elt,elt))aFunc 
    whileTrue: (BOOL *)flag
{
  int i, count = [self count];
  id keyTmpColl = [[Array alloc] initWithType:[self keyType]
		   capacity:count];
  id contentTmpColl = [[Array alloc] initWithType:[self contentType]
		       capacity:count];
  void appendKeyAndContent(elt k, elt c)
    {
      [keyTmpColl appendElement:k];
      [contentTmpColl appendElement:c];
    }
  [self withKeyElementsAndContentElementsCall:appendKeyAndContent];
  for (i = 0; *flag && i < count; i++)
    (*aFunc)([keyTmpColl elementAtIndex:i], [contentTmpColl elementAtIndex:i]);
  [keyTmpColl release];
  [contentTmpColl release];
  return self;
}


// ADDING OR REPLACING;

- putObject: newContentObject atKey: (elt)aKey
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self putElement:newContentObject atKey:aKey];
}

- replaceObjectAtKey: (elt)aKey with: newContentObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self replaceElementAtKey:aKey with:newContentObject].id_u;
}


// GETTING COLLECTIONS OF CONTENTS SEPARATELY;

- shallowCopyKeysAs: aCollectionClass;
{
  id newColl = [self emptyCopyAs:aCollectionClass];
  id(*addElementImp)(id,SEL,elt) = (id(*)(id,SEL,elt))
    objc_msg_lookup(newColl, @selector(addElement:));
  void doIt(elt e)
    {
      addElementImp(newColl, @selector(addElement:), e);
    }

  [self withKeyElementsCall:doIt];
  return self;
}

- shallowCopyContentsAs: aCollectionClass
{
  return [super shallowCopyAs:aCollectionClass];
}


// ENUMERATIONS;

- printForDebugger
{
  const char *kd = [self keyType];
  const char *cd = [self contentType];
  void doIt(const elt key, elt content)
    {
      printf("(");
      elt_fprintf_elt(stdout, kd, key);
      printf(",");
      elt_fprintf_elt(stdout, cd, content);
      printf(") ");
    }
  [self withKeyElementsAndContentElementsCall:doIt];
  printf(" :%s\n", [self name]);
  return self;
}

- (void) _encodeContentsWithCoder: (Coder*)aCoder
{
  unsigned int count = [self count];
  const char *ce = [self contentType];
  const char *ke = [self keyType];
  void archiveKeyAndContent(elt key, elt content)
    {
      [aCoder encodeValueOfType:ke
	      at:elt_get_ptr_to_member(ke, &key)
	      withName:"KeyedCollection key element"];
      [aCoder encodeValueOfType:ce
	      at:elt_get_ptr_to_member(ce, &content)
	      withName:"KeyedCollection content element"];
    }

  [aCoder encodeValueOfSimpleType:@encode(unsigned)
	  at:&count
	  withName:"Collection element count"];
  [self withKeyElementsAndContentElementsCall:archiveKeyAndContent];
}

- (void) _decodeContentsWithCoder: (Coder*)aCoder
{
  unsigned int count, i;
  elt newKey, newContent;
  const char *ce = [self contentType];
  const char *ke = [self keyType];

  [aCoder decodeValueOfSimpleType:@encode(unsigned)
	  at:&count
	  withName:NULL];
  for (i = 0; i < count; i++)
    {
      [aCoder decodeValueOfType:ke
	      at:elt_get_ptr_to_member(ke, &newKey)
	      withName:NULL];
      [aCoder decodeValueOfType:ce
	      at:elt_get_ptr_to_member(ce, &newContent)
	      withName:NULL];
      [self putElement:newContent atKey:newKey];
    }
}


- _writeContents: (TypedStream*)aStream
{
  unsigned int count = [self count];
  const char *ce = [self contentType];
  const char *ke = [self keyType];
  void archiveKeyAndContent(elt key, elt content)
    {
      objc_write_types(aStream, ke,
		       elt_get_ptr_to_member(ke, &key));
      objc_write_types(aStream, ce,
		       elt_get_ptr_to_member(ce, &content));
    }

  objc_write_type(aStream, @encode(unsigned int), &count);
  [self withKeyElementsAndContentElementsCall:archiveKeyAndContent];
  return self;
}

- _readContents: (TypedStream*)aStream
{
  unsigned int count, i;
  elt newKey, newContent;
  const char *ce = [self contentType];
  const char *ke = [self keyType];

  objc_read_type(aStream, @encode(unsigned int), &count);
  for (i = 0; i < count; i++)
    {
      objc_read_types(aStream, ke, 
		      elt_get_ptr_to_member(ke, &newKey));
      objc_read_types(aStream, ce, 
		      elt_get_ptr_to_member(ce, &newContent));
      [self putElement:newContent atKey:newKey];
    }
  return self;
}

@end
