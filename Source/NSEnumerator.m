/** NSEnumerator abstrace class for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSEnumerator class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSUtilities.h"
#include "Foundation/NSArray.h"

/**
 *  Simple class for iterating over a collection of objects, usually returned
 *  from an [NSArray] or similar.
 */
@implementation NSEnumerator

/**
 *  Returns all objects remaining in the enumeration as an array.
 */
- (NSArray*) allObjects
{
  NSMutableArray	*array;
  id			obj;
  SEL			nsel;
  IMP			nimp;
  SEL			asel;
  IMP			aimp;

  array = [NSMutableArray arrayWithCapacity: 10];

  nsel = @selector(nextObject);
  nimp = [self methodForSelector: nsel];
  asel = @selector(addObject:);
  aimp = [array methodForSelector: asel];

  while ((obj = (*nimp)(self, nsel)) != nil)
    {
      (*aimp)(array, asel, obj);
    }
  return array;
}

/**
 *  Returns next object in enumeration, or nil if none remain.  Use code like
 *  <code>while (object = [enumerator nextObject]) { ... }</code>.
 */
- (id) nextObject
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end
