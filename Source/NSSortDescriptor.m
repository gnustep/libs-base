/* Implementation for NSSortDescriptor for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Saso Kiselkov <diablos@manga.sk>
   Date: 2005

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

#import "common.h"

#define	EXPOSE_NSSortDescriptor_IVARS	1
#import "Foundation/NSSortDescriptor.h"

#import "Foundation/NSBundle.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueCoding.h"

#import "GNUstepBase/GSObjCRuntime.h"
#import "GSPrivate.h"

@implementation NSSortDescriptor

- (BOOL) ascending
{
  return _ascending;
}

- (NSComparisonResult) compareObject: (id) object1 toObject: (id) object2
{
  NSComparisonResult result;
  id comparedKey1 = [object1 valueForKeyPath: _key];
  id comparedKey2 = [object2 valueForKeyPath: _key];

  result = (NSComparisonResult) [comparedKey1 performSelector: _selector
                                                   withObject: comparedKey2];
  if (_ascending == NO)
    {
      if (result == NSOrderedAscending)
	{
	  result = NSOrderedDescending;
	}
      else if (result == NSOrderedDescending)
	{
	  result = NSOrderedAscending;
	}
    }

  return result;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  return [[NSSortDescriptor allocWithZone: zone]
    initWithKey: _key ascending: _ascending selector: _selector];
}

- (void) dealloc
{
  TEST_RELEASE(_key);
  [super dealloc];
}

- (unsigned) hash
{
  const char	*sel = GSNameFromSelector(_selector);

  return _ascending + GSPrivateHash(sel, strlen(sel), 16, YES) + [_key hash];
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

- (BOOL) isEqual: (id)other
{
  if (other == self)
    {
      return YES;
    }
  if ([other isKindOfClass: [NSSortDescriptor class]] == NO)
    {
      return NO;
    }
  if (((NSSortDescriptor*)other)->_ascending != _ascending)
    {
      return NO;
    }
  if (!sel_eq(((NSSortDescriptor*)other)->_selector, _selector))
    {
      return NO;
    }
  return [((NSSortDescriptor*)other)->_key isEqualToString: _key];
}

- (NSString *) key
{
  return _key;
}

- (id) reversedSortDescriptor
{
  return AUTORELEASE([[NSSortDescriptor alloc]
    initWithKey: _key ascending: !_ascending selector: _selector]);
}

- (SEL) selector
{
  return _selector;
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

- (id) initWithCoder: (NSCoder *)decoder
{
  if ((self = [super init]) != nil)
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
    }
  return self;
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
SortObjectsWithDescriptor(id *objects,
                          NSRange sortRange,
                          NSSortDescriptor *sortDescriptor)
{
  if (sortRange.length > 1)
    {
      id pivot = objects[sortRange.location];
      unsigned int left = sortRange.location + 1;
      unsigned int right = NSMaxRange(sortRange);

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

@implementation NSArray (NSSortDescriptorSorting)

- (NSArray *) sortedArrayUsingDescriptors: (NSArray *) sortDescriptors
{
  NSMutableArray *sortedArray = [GSMutableArray arrayWithArray: self];

  [sortedArray sortUsingDescriptors: sortDescriptors];

  return [sortedArray makeImmutableCopyOnFail: NO];
}

@end

/* Sort the objects in range using the first descriptor and, if there
 * are more descriptors, recursively call the function to sort each range
 * of adhacent equal objects using the remaining descriptors.
 */
static void
SortRange(id *objects, NSRange range, id *descriptors,
  unsigned numDescriptors)
{
  NSSortDescriptor	*sd = (NSSortDescriptor*)descriptors[0];

  SortObjectsWithDescriptor(objects, range, sd);
  if (numDescriptors > 1)
    {
      unsigned	start = range.location;
      unsigned	finish = NSMaxRange(range);

      while (start < finish)
	{
	  unsigned	pos = start + 1;

	  /* Find next range of adjacent objects.
	   */
	  while (pos < finish
	    && [sd compareObject: objects[start]
	      toObject: objects[pos]] == NSOrderedSame)
	    {
	      pos++;
	    }

	  /* Sort the range using remaining descriptors.
	   */
	  if (pos - start > 1)
	    {
	      SortRange(objects, NSMakeRange(start, pos - start),
		descriptors + 1, numDescriptors - 1);
	    }
	  start = pos;
	}
    }
}

@implementation NSMutableArray (NSSortDescriptorSorting)

- (void) sortUsingDescriptors: (NSArray *)sortDescriptors
{
  unsigned	count = [self count];
  unsigned	numDescriptors = [sortDescriptors count];

  if (count > 1 && numDescriptors > 0)
    {
      id	descriptors[numDescriptors];
      NSArray	*a;
      GS_BEGINIDBUF(objects, count);

      [self getObjects: objects];
      if ([sortDescriptors isProxy])
	{
	  unsigned	i;

	  for (i = 0; i < numDescriptors; i++)
	    {
	      descriptors[i] = [sortDescriptors objectAtIndex: i];
	    }
	}
      else
	{
	  [sortDescriptors getObjects: descriptors];
	}
      SortRange(objects, NSMakeRange(0, count), descriptors, numDescriptors);
      a = [[NSArray alloc] initWithObjects: objects count: count];
      [self setArray: a];
      RELEASE(a);
      GS_ENDIDBUF();
    }
}

@end

@implementation GSMutableArray (NSSortDescriptorSorting)

- (void) sortUsingDescriptors: (NSArray *)sortDescriptors
{
  unsigned	dCount = [sortDescriptors count];

  if (_count > 1 && dCount > 0)
    {
      GS_BEGINIDBUF(descriptors, dCount);

      if ([sortDescriptors isProxy])
	{
	  unsigned	i;

	  for (i = 0; i < dCount; i++)
	    {
	      descriptors[i] = [sortDescriptors objectAtIndex: i];
	    }
	}
      else
	{
	  [sortDescriptors getObjects: descriptors];
	}
      SortRange(_contents_array, NSMakeRange(0, _count), descriptors, dCount);

      GS_ENDIDBUF();
    }
}

@end
