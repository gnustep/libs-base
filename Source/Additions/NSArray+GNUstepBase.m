/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#include "config.h"
#include "Foundation/Foundation.h"
#include "GNUstepBase/NSArray+GNUstepBase.h"
#include "GSPrivate.h"

@implementation NSArray (GNUstepBase)

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
  unsigned	c = [array count];
  GS_BEGINIDBUF(objects, c);

  if ([array isProxy])
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [array objectAtIndex: i];
	}
    }
  else
    {
      [array getObjects: objects];
    }
  if (shouldCopy == YES)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [objects[i] copy];
	}
      self = [self initWithObjects: objects count: c];
#if GS_WITH_GC == 0
      while (i > 0)
	{
	  [objects[--i] release];
	}
#endif
    }
  else
    {
      self = [self initWithObjects: objects count: c];
    }
  GS_ENDIDBUF();
  return self;
}

- (NSUInteger) insertionPosition: (id)item
		 usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		       context: (void *)context
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  SEL		oaiSel;
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (sorter == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }

  oaiSel = @selector(objectAtIndex:);
  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*sorter)(item, (*oai)(self, oaiSel, index), context);
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count && (*sorter)(item, (*oai)(self, oaiSel, index), context)
    != NSOrderedAscending)
    {
      index++;
    }
  return index;
}

- (NSUInteger) insertionPosition: (id)item
		 usingSelector: (SEL)comp
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  NSComparisonResult	(*imp)(id, SEL, id);
  SEL		oaiSel;
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (comp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }
  imp = (NSComparisonResult (*)(id, SEL, id))[item methodForSelector: comp];
  if (imp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with unknown method"];
    }

  oaiSel = @selector(objectAtIndex:);
  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*imp)(item, comp, (*oai)(self, oaiSel, index));
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count
    && (*imp)(item, comp, (*oai)(self, oaiSel, index)) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}

@end
