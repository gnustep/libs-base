/* Implementation for Objective-C MappedCollector collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
*/ 

#include <config.h>
#include <base/MappedCollector.h>
#include <base/Dictionary.h>
#include <base/CollectionPrivate.h>

@implementation MappedCollector

/* This is the designated initializer for this class */
- initWithCollection: (id <KeyedCollecting>)aDomain 
    map: (id <KeyedCollecting>)aMap
{
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

/* Override our superclass' designated initializer */
- initWithObjects: (id*)objects forKeys: (id*)keys count: (unsigned)c
{
  [self notImplemented: _cmd];
  return nil;
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
- (void) empty
{
  [_domain empty];
}

- objectAtKey: aKey
{
  return [_domain objectAtKey: [_map objectAtKey: aKey]];
}

- keyOfObject: aContentObject
{
  [self notImplemented: _cmd];
  return self;
}

- (void) replaceObjectAtKey: aKey with: newObject
{
  return [_domain replaceObjectAtKey: [_map objectAtKey: aKey]
		 with: newObject];
}

- (void) putObject: newObject atKey: aKey
{
  return [_domain putObject: newObject
		  atKey: [_map objectAtKey:aKey]];
}

- (void) removeObjectAtKey: aKey
{
  return [_domain removeObjectAtKey: [_map objectAtKey: aKey]];
}

- (BOOL) containsKey: aKey
{
  return [_domain containsKey: [_map objectAtKey:aKey]];
}

- (void*) newEnumState
{
  return [_domain newEnumState];
}

- (void) freeEnumState: (void**)enumState
{
  return [_domain freeEnumState: enumState];
}

- nextObjectAndKey: (id*)keyPtr withEnumState: (void**)enumState
{
  id mapContent;
  id domainKey;

  /* xxx This needs debugging; see checks/test02.m */
  while ((mapContent = [_map nextObjectAndKey:keyPtr withEnumState:enumState])
	 && 
	 (![_domain containsKey: (domainKey = [_map objectAtKey:*keyPtr])]))
    ;
  if (mapContent == NO_OBJECT)
    return NO_OBJECT;
  return [_domain objectAtKey: domainKey];
}

- species
{
  return [Dictionary class];
}

@end
