/* Implementation for Objective-C MappedCollector collection object
   Copyright (C) 1993,1994, 1995 Free Software Foundation, Inc.

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

#include <objects/MappedCollector.h>
#include <objects/Dictionary.h>
#include <objects/CollectionPrivate.h>

@implementation MappedCollector

/* This is the designated initializer for this class */
- initCollection: (id <KeyedCollecting>)aDomain 
    map: (id <KeyedCollecting>)aMap
{
  if (strcmp([aMap contentType], [aDomain keyType]))
    [self error:"map's contents are not the same as domain's keys"];
  [super initWithType:[aDomain contentType]
	 keyType:[aMap keyType]];
  _map = aMap;
  _domain = aDomain;
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- _writeInit: (TypedStream*)aStream
{
  [super _writeInit: aStream];
  objc_write_object(aStream, _map);
  objc_write_object(aStream, _domain);
  return self;
}

- _readInit: (TypedStream*)aStream
{
  [super _readInit: aStream];
  objc_read_object(aStream, &_map);
  objc_read_object(aStream, &_domain);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  MappedCollector *copy = [super emptyCopy];
  copy->_map = [_map emptyCopy];
  copy->_domain = [_domain emptyCopy];
  return copy;
}

/* This must work without sending any messages to content objects */
- empty
{
  [_domain empty];
  return self;
}

- (const char *) contentType
{
  return [_domain contentType];
}

- (const char *) keyType
{
  return [_map keyType];
}

- (int(*)(elt,elt)) comparisonFunction
{
  return [_domain comparisonFunction];
}

- (elt) elementAtKey: (elt)aKey
{
  return [_domain elementAtKey:[_map elementAtKey:aKey]];
}

- (elt) replaceElementAtKey: (elt)aKey with: (elt)newElement
{
  return [_domain replaceElementAtKey:[_map elementAtKey:aKey]
		 with:newElement];
}

- putElement: (elt)newElement atKey: (elt)aKey
{
  return [_domain putElement:newElement
		 atKey:[_map elementAtKey:aKey]];
}

- (elt) removeElementAtKey: (elt)aKey
{
  return [_domain removeElementAtKey:[_map elementAtKey:aKey]];
}

- (BOOL) includesKey: (elt)aKey
{
  return [_domain includesKey:[_map elementAtKey:aKey]];
}

- withKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc 
    whileTrue: (BOOL *)flag
{
  void doIt(elt e)
    {
      elt domainKey = [_map elementAtKey:e];
      if ([_domain includesKey:domainKey])
	(*aFunc)(e, [_domain elementAtKey:domainKey]);
    }
  [_map withKeyElementsCall:doIt];
  return self;
}

- (BOOL) getNextKey: (elt*)aKeyPtr content: (elt*)anElementPtr 
  withEnumState: (void**)enumState;
{
  BOOL ret;
  elt mapContent;
  elt domainKey;

  while ((ret = [_map getNextKey:aKeyPtr content:&mapContent 
		     withEnumState:enumState])
	 && 
	 (![_domain includesKey:(domainKey = [_map elementAtKey:*aKeyPtr])]))
    ;
  if (!ret)
    return NO;
  *anElementPtr = [_domain elementAtKey:domainKey];
  return YES;
}

- species
{
  return [Dictionary class];
}

@end
