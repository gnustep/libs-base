/* Implementation for NSSortDescriptor for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Saso Kiselkov <diablos@manga.sk>
   Date: 2005

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */

#include "Foundation/NSSortDescriptor.h"

#include "Foundation/NSString.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSException.h"
#include "Foundation/NSBundle.h"

@implementation NSSortDescriptor

- (void) dealloc
{
  TEST_RELEASE(_key);

  [super dealloc];
}

- (id) initWithKey: (NSString *) key ascending: (BOOL) ascending
{
  return [self initWithKey: key ascending: ascending selector: NULL];
}

- (id) initWithKey: (NSString *) key
         ascending: (BOOL) ascending
          selector: (SEL) selector
{
  if ([self init])
    {
      if (key == nil)
        {
          [NSException raise: NSInvalidArgumentException
                      format: _(@"Passed nil key when initializing "
            @"an NSSortDescriptor.")];
        }
      if (selector == NULL)
        {
          selector = @selector(compare:);
        }

      ASSIGN(_key, key);
      _ascending = ascending;
      _selector = selector;

      return self;
    }
  else
    {
      return nil;
    }
}

- (BOOL) ascending
{
  return _ascending;
}

- (NSString *) key
{
  return _key;
}

- (SEL) selector
{
  return _selector;
}

- (NSComparisonResult) compareObject: (id) object1 toObject: (id) object2
{
  NSComparisonResult result;
  id comparedKey1 = [object1 valueForKey: _key],
     comparedKey2 = [object2 valueForKey: _key];

  result = (NSComparisonResult) [comparedKey1 performSelector: _selector
                                                   withObject: comparedKey2];

  if (_ascending != YES)
    {
      result = -result;
    }

  return result;
}

- (id) reversedSortDescriptor
{
  return [[[NSSortDescriptor alloc]
    initWithKey: _key ascending: !_ascending selector: _selector]
    autorelease];
}

- (void) encodeWithCoder: (NSCoder *) coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _key forKey: @"Key"];
      [coder encodeBool: _ascending forKey: @"Ascending"];
      [coder encodeObject: NSStringFromSelector(_selector)
                   forKey: @"Selector"];
    }
  else
    {
      [coder encodeObject: _key];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &_ascending];
      [coder encodeValueOfObjCType: @encode(SEL) at: &_selector];
    }
}

- initWithCoder: (NSCoder *) decoder
{
  if ([super init])
    {
      if ([decoder allowsKeyedCoding])
        {
          ASSIGN(_key, [decoder decodeObjectForKey: @"Key"]);
          _ascending = [decoder decodeBoolForKey: @"Ascending"];
          _selector = NSSelectorFromString([decoder
            decodeObjectForKey: @"Selector"]);
        }
      else
        {
          ASSIGN(_key, [decoder decodeObject]);
          [decoder decodeValueOfObjCType: @encode(BOOL) at: &_ascending];
          [decoder decodeValueOfObjCType: @encode(SEL) at: &_selector];
        }

      return self;
    }
  else
    {
      return nil;
    }
}

- (id) copyWithZone: (NSZone*) zone
{
  return [[NSSortDescriptor allocWithZone: zone]
    initWithKey: _key ascending: _ascending selector: _selector];
}

@end

/// Swaps the two provided objects.
static inline void
SwapObjects(id * o1, id * o2)
{
  id temp;

  temp = *o1;
  *o1 = *o2;
  *o2 = temp;
}

/**
 * Sorts the provided object array's sortRange according to sortDescriptor.
 */
// Quicksort algorithm copied from Wikipedia :-).
static void
SortObjectsWithDescriptor(id * objects,
                          NSRange sortRange,
                          NSSortDescriptor * sortDescriptor)
{
  if (sortRange.length > 1)
    {
      id pivot = objects[sortRange.location];
      unsigned int left = sortRange.location + 1,
                   right = NSMaxRange(sortRange);

      while (left < right)
        {
          if ([sortDescriptor compareObject: objects[left] toObject: pivot] ==
            NSOrderedDescending)
            {
              SwapObjects(&objects[left], &objects[--right]);
            }
          else
            {
              left++;
            }
        }

      SwapObjects(&objects[--left], &objects[sortRange.location]);
      SortObjectsWithDescriptor(objects, NSMakeRange(sortRange.location, left
        - sortRange.location), sortDescriptor);
      SortObjectsWithDescriptor(objects, NSMakeRange(right,
        NSMaxRange(sortRange) - right), sortDescriptor);
    }
}

/**
 * Finds all objects in the provided range of the objects array that
 * are next to each other and evaluate with the provided sortDescriptor
 * as being NSOrderedSame, records their ranges in the provided
 * recordedRanges array (enlarging it as necessary) and adjusts the
 * numRanges argument to indicate the new size of the range array.
 * A pointer to the new location of the array of ranges is returned.
 */
static NSRange *
FindEqualityRanges(id * objects,
                   NSRange searchRange,
                   NSSortDescriptor * sortDescriptor,
                   NSRange * ranges,
                   unsigned int * numRanges)
{
  unsigned int i = searchRange.location,
               n = NSMaxRange(searchRange);

  if (n > 1)
    {
      while (i < n - 1)
        {
          unsigned int j;

          for (j=i + 1;
            j < n &&
            [sortDescriptor compareObject: objects[i] toObject: objects[j]]
            == NSOrderedSame;
            j++);

          if (j - i > 1)
            {
              (*numRanges)++;
              ranges = (NSRange *) realloc(ranges, (*numRanges) *
                sizeof(NSRange));
              ranges[(*numRanges)-1].location = i;
              ranges[(*numRanges)-1].length = j - i;

              i = j;
            }
          else
            {
              i++;
            }
        }
    }

  return ranges;
}

@implementation NSArray (NSSortDescriptorSorting)

- (NSArray *) sortedArrayUsingDescriptors: (NSArray *) sortDescriptors
{
  NSMutableArray * sortedArray = [NSMutableArray arrayWithArray: self];

  [sortedArray sortUsingDescriptors: sortDescriptors];

  return [sortedArray makeImmutableCopyOnFail:NO];
}

@end

@implementation NSMutableArray (NSSortDescriptorSorting)

/**
 * This method works like this: first, it sorts the entire
 * contents of the array using the first sort descriptor. Then,
 * after each sort-run, it looks whether there are sort
 * descriptors left to process, and if yes, looks at the partially
 * sorted array, finds all portions in it which are equal
 * (evaluate to NSOrderedSame) and applies the following
 * descriptor onto them. It repeats this either until all
 * descriptors have been applied or there are no more equal
 * portions (equality ranges) left in the array.
 */
- (void) sortUsingDescriptors: (NSArray *) sortDescriptors
{
  id * objects;
  unsigned int count;

  NSRange * equalityRanges;
  unsigned int numEqualityRanges;

  unsigned int i, n;

  count = [self count];
  objects = (id *) calloc(count, sizeof(id));
  [self getObjects: objects];

  equalityRanges = (NSRange *) calloc(1, sizeof(NSRange));
  equalityRanges[0].location = 0;
  equalityRanges[0].length = count;
  numEqualityRanges = 1;

  for (i=0, n = [sortDescriptors count]; i < n && equalityRanges != NULL; i++)
    {
      unsigned int j;
      NSSortDescriptor * sortDescriptor = [sortDescriptors objectAtIndex: i];

      // pass through all equality ranges and sort each of them
      for (j=0; j < numEqualityRanges; j++)
        {
          SortObjectsWithDescriptor(objects, equalityRanges[j],
            sortDescriptor);
        }

      // then, if there are sort descriptors left to process
      if (i < n - 1)
        // reconstruct the equality ranges anew.
        {
          NSRange * newRanges = NULL;
          unsigned newNumRanges = 0;

          // process only contents of old equality ranges
          for (j=0; j < numEqualityRanges; j++)
            {
              newRanges = FindEqualityRanges(objects, equalityRanges[j],
                sortDescriptor, newRanges, &newNumRanges);
            }

          free(equalityRanges);
          equalityRanges = newRanges;
          numEqualityRanges = newNumRanges;
        }
    }

  free(equalityRanges);

  // now, reconstruct our contents according to the sorted object buffer
  [self setArray: [NSArray arrayWithObjects: objects count: count]];

  free(objects);
}

@end
