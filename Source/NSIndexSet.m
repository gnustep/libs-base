/** Implementation for NSIndexSet, NSMutableIndexSet for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Feb 2004
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   */ 

#include	<Foundation/NSIndexSet.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSZone.h>

#define	GSI_ARRAY_TYPE	NSRange
#define GSI_ARRAY_TYPES	GSI_ARRAY_EXTRA

#define	GSI_ARRAY_NO_RELEASE	1
#define	GSI_ARRAY_NO_RETAIN	1

#include "GNUstepBase/GSIArray.h"

#define	_array	((GSIArray)(self->_data))
#define	_other	((GSIArray)(aSet->_data))

/*
 * Returns the position in the array at which the index should be inserted.
 * This may be the position of a range containing the index if it is already
 * present, otherwise it is the position of the first range containing an
 * index greater than the argument (or a position beyond the end of the
 * array).
 */
static unsigned posForIndex(GSIArray array, unsigned index)
{
  unsigned int	upper = GSIArrayCount(array);
  unsigned int	lower = 0;
  unsigned int	pos;

  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (pos = upper/2; upper != lower; pos = (upper+lower)/2)
    {
      NSRange	r = GSIArrayItemAtIndex(array, pos).ext;

      if (index < r.location)
        {
          upper = pos;
        }
      else if (index > NSMaxRange(r))
        {
          lower = pos + 1;
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
  while (pos < GSIArrayCount(array)
    && index >= NSMaxRange(GSIArrayItemAtIndex(array, pos).ext))
    {
      pos++;
    }
  return pos;
}

@implementation	NSIndexSet
+ (id) indexSet
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  o = [o init];
  return AUTORELEASE(o);
}

+ (id) indexSetWithIndex: (unsigned int)anIndex;
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  o = [o initWithIndex: anIndex];
  return AUTORELEASE(o);
}

+ (id) indexSetWithIndexesInRange: (NSRange)aRange;
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  o = [o initWithIndexesInRange: aRange];
  return AUTORELEASE(o);
}

- (BOOL) containsIndex: (unsigned int)anIndex
{
  unsigned	pos;
  NSRange	r;

  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
      return NO;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  return NSLocationInRange(anIndex, r);
}

- (BOOL) containsIndexes: (NSIndexSet*)aSet
{
  if (_array == 0 || GSIArrayCount(_array) == 0)
    {
      return NO;
    }
  [self notImplemented:_cmd];
  return NO;
}

- (BOOL) containsIndexesInRange: (NSRange)aRange
{
  unsigned	pos;
  NSRange	r;

  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, aRange.location)) >= GSIArrayCount(_array))
    {
      return NO;	// Empty ... contains no indexes.
    }
  if (aRange.length == 0)
    {
      return YES;	// No indexes needed.
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  if (NSLocationInRange(aRange.location, r)
    && NSLocationInRange(NSMaxRange(aRange)-1, r))
    {
      return YES;
    }
  return NO;
}

- (id) copyWithZone: (NSZone*)aZone
{
  if (NSShouldRetainWithZone(self, aZone))
    {
      return RETAIN(self);
    }
  else
    {
      NSIndexSet	*c = [NSIndexSet allocWithZone: aZone];

      return [c initWithIndexSet: self];
    }
}

- (unsigned int) count
{
  if (_array == 0 || GSIArrayCount(_array) == 0)
    {
      return 0;
    }
  else
    {
      unsigned	count = GSIArrayCount(_array);
      unsigned	total = 0;
      unsigned	i = 0;

      while (i < count)
	{
	  total += GSIArrayItemAtIndex(_array, i).ext.length;
	}
      return total;
    }
}

- (void) dealloc
{
  if (_array != 0)
    {
      GSIArrayClear(_array);
      NSZoneFree([self zone], _array);
      _data = 0;
    }
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self notImplemented:_cmd]; 
}

- (unsigned int) firstIndex
{
  if (_array == 0 || GSIArrayCount(_array) == 0)
    {
      return NSNotFound;
    }
  return GSIArrayItemAtIndex(_array, 0).ext.location;
}

- (unsigned int) getIndexes: (unsigned int*)aBuffer
		   maxCount: (unsigned int)aCount
	       inIndexRange: (NSRangePointer)aRange
{
  unsigned	pos;
  unsigned	i = 0;
  NSRange	r;

  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, aRange->location)) >= GSIArrayCount(_array))
    {
      *aRange = NSMakeRange(NSMaxRange(*aRange), 0);
      return 0;
    }

  while (aRange->length > 0 && i < aCount && pos < GSIArrayCount(_array))
    {
      r = GSIArrayItemAtIndex(_array, pos).ext;
      if (aRange->location < r.location)
	{
	  unsigned	skip = r.location - aRange->location;

	  if (skip > aRange->length)
	    {
	      skip = aRange->length;
	    }
	  aRange->location += skip;
	  aRange->length -= skip;
	}
      else if (NSLocationInRange(aRange->location, r))
	{
	  while (aRange->length > 0 && i < aCount
	    && aRange->location < NSMaxRange(r))
	    {
	      aBuffer[i++] = aRange->location++;
	      aRange->length--;
	    }
	}
      else
	{
	}
      pos++;
    }
  return i;
}

- (unsigned int) hash
{
  return [self count];
}

- (unsigned int) indexGreaterThanIndex: (unsigned int)anIndex
{
  unsigned	pos;
  NSRange	r;

  if (anIndex++ == NSNotFound)
    {
      return NSNotFound;
    }
  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  if (NSLocationInRange(anIndex, r))
    {
      return anIndex;
    }
  if (++pos >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  return r.location;
}

- (unsigned int) indexGreaterThanOrEqualToIndex: (unsigned int)anIndex
{
  unsigned	pos;
  NSRange	r;

  if (anIndex == NSNotFound)
    {
      return NSNotFound;
    }
  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  if (NSLocationInRange(anIndex, r))
    {
      return anIndex;
    }
  if (++pos >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  return r.location;
}

- (unsigned int) indexLessThanIndex: (unsigned int)anIndex
{
  unsigned	pos;
  NSRange	r;

  if (anIndex-- == 0)
    {
      return NSNotFound;
    }
  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  if (NSLocationInRange(anIndex, r))
    {
      return anIndex;
    }
  if (pos-- == 0)
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  return NSMaxRange(r) - 1;
}

- (unsigned int) indexLessThanOrEqualToIndex: (unsigned int)anIndex
{
  unsigned	pos;
  NSRange	r;

  if (_array == 0 || GSIArrayCount(_array) == 0
    || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  if (NSLocationInRange(anIndex, r))
    {
      return anIndex;
    }
  if (pos-- == 0)
    {
      return NSNotFound;
    }
  r = GSIArrayItemAtIndex(_array, pos).ext;
  return NSMaxRange(r) - 1;
}

- (id) init
{
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self notImplemented:_cmd]; 
  return self;
}

- (id) initWithIndex: (unsigned int)anIndex
{
  if (anIndex == NSNotFound)
    {
      DESTROY(self);	// NSNotFound is not legal
    }
  else
    {
      self = [self initWithIndexesInRange: NSMakeRange(anIndex, 1)];
    }
  return self;
}

- (id) initWithIndexesInRange: (NSRange)aRange
{
  if (aRange.length > 0)
    {
      if (NSMaxRange(aRange) == NSNotFound)
	{
	  DESTROY(self);	// NSNotFound is not legal
	}
      else
	{
	  _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
	  GSIArrayInitWithZoneAndCapacity(_array, [self zone], 1);
	  GSIArrayAddItem(_array, (GSIArrayItem)aRange);
	}
    }
  return self;
}

- (id) initWithIndexSet: (NSIndexSet*)aSet
{
  if (aSet == nil || [aSet isKindOfClass: [NSIndexSet class]] == NO)
    {
      DESTROY(self);
    }
  else
    {
      unsigned	count = GSIArrayCount(_other);

      if (count > 0)
	{
	  unsigned	i;

	  _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
	  GSIArrayInitWithZoneAndCapacity(_array, [self zone], count);
	  for (i = 0; i < count; i++)
	    {
	      GSIArrayAddItem(_array, GSIArrayItemAtIndex(_other, i));
	    }
	}
    }
  return self;
}

- (BOOL) intersectsIndexesInRange: (NSRange)aRange
{
  unsigned	p1;
  unsigned	p2;

  if (aRange.length == 0 || _array == 0 || GSIArrayCount(_array) == 0)
    {
      return NO;	// Empty
    }
  p1 = posForIndex(_array, aRange.location);
  p2 = posForIndex(_array, NSMaxRange(aRange) - 1);
  if (p1 != p2)
    {
      return YES;
    }
  if (p1 >= GSIArrayCount(_array))
    {
      return NO;
    }
  if (NSLocationInRange(aRange.location, GSIArrayItemAtIndex(_array, p1).ext))
    {
      return YES;
    }
  if (NSLocationInRange(NSMaxRange(aRange)-1,
      GSIArrayItemAtIndex(_array, p1).ext))
    {
      return YES;
    }
  return NO;
}

- (BOOL) isEqual: (id)aSet
{
  if ([aSet isKindOfClass: [NSIndexSet class]] == YES)
    {
      return [self isEqualToIndexSet: aSet];
    }
  return NO;
}

- (BOOL) isEqualToIndexSet: (NSIndexSet*)aSet
{
  unsigned	count = GSIArrayCount(_other);

  if (count != GSIArrayCount(_array))
    {
      return NO;
    }
  if (count > 0)
    {
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSRange	rself = GSIArrayItemAtIndex(_array, i).ext;
	  NSRange	rother = GSIArrayItemAtIndex(_other, i).ext;

	  if (NSEqualRanges(rself, rother) == NO)
	    {
	      return NO;
	    }
	}
    }
  return YES;
}

- (unsigned int) lastIndex
{
  if (_array == 0 || GSIArrayCount(_array) == 0)
    {
      return NSNotFound;
    }
  return GSIArrayItemAtIndex(_array, GSIArrayCount(_array)-1).ext.location;
}

- (id) mutableCopyWithZone: (NSZone*)aZone
{
  NSMutableIndexSet	*c = [NSMutableIndexSet allocWithZone: aZone];

  return [c initWithIndexSet: self];
}

@end


@implementation	NSMutableIndexSet

#undef	_other
#define	_other	((GSIArray)(((NSMutableIndexSet*)aSet)->_data))

- (void) addIndex: (unsigned int)anIndex
{
  [self addIndexesInRange: NSMakeRange(anIndex, 1)];
}

- (void) addIndexes: (NSIndexSet*)aSet
{
  unsigned	count = GSIArrayCount(_other);

  if (count > 0)
    {
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSRange	r = GSIArrayItemAtIndex(_other, i).ext;

	  [self addIndexesInRange: r];
	}
    }
} 

- (void) addIndexesInRange: (NSRange)aRange
{
  if (_array == 0)
    {
      _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(_array, [self zone], 1);
    }
  if (GSIArrayCount(_array) == 0)
    {
      GSIArrayAddItem(_array, (GSIArrayItem)aRange);
    }
  else
    {
      [self notImplemented:_cmd];
    }
}

- (id) copyWithZone: (NSZone*)aZone
{
  NSIndexSet	*c = [NSIndexSet allocWithZone: aZone];

  return [c initWithIndexSet: self];
}

- (void) removeAllIndexes
{
  if (_array != 0)
    {
      GSIArrayRemoveAllItems(_array);
    }
}

- (void) removeIndex: (unsigned int)anIndex
{
  [self notImplemented:_cmd];
}

- (void) removeIndexes: (NSIndexSet*)aSet
{
  [self notImplemented:_cmd];
}

- (void) removeIndexesInRange: (NSRange)aRange
{
  [self notImplemented:_cmd];
}

- (void) shiftIndexesStartingAtIndex: (unsigned int)anIndex by: (int)amount
{
  [self notImplemented:_cmd];
} 

@end

