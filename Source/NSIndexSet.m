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

  if (NSNotFound - aRange.length < aRange.location)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: Bad range",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
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
	  i++;
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

- (NSString*) description
{
  NSMutableString	*m;
  unsigned		c = GSIArrayCount(_array);
  unsigned		i;

  m = [NSMutableString stringWithFormat:
    @"%@[number of indexes: %u (in %u ranges), indexes: ",
    [super description], [self count], c];
  for (i = 0; i < c; i++)
    {
      NSRange	r = GSIArrayItemAtIndex(_array, i).ext;

      [m appendFormat: @"(%u-%u) ", r.location, NSMaxRange(r) - 1];
    }
  [m appendString: @"]"];
  return m;
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

  if (aBuffer == 0 || aRange == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: nul pointer argument",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (NSNotFound - aRange->length < aRange->location)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: Bad range",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
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
      if (NSLocationInRange(aRange->location, r))
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
  if (r.location > anIndex)
    {
      return r.location;
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

  if (NSNotFound - aRange.length < aRange.location)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: Bad range",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
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
  unsigned	count = _other ? GSIArrayCount(_other) : 0;

  if (count != (_array ? GSIArrayCount(_array) : 0))
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
  return NSMaxRange(GSIArrayItemAtIndex(_array, GSIArrayCount(_array)-1).ext)-1;
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
  if (NSNotFound - aRange.length < aRange.location)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: Bad range",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (aRange.length == 0)
    {
      return;
    }
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
      unsigned	pos = posForIndex(_array, aRange.location);

      if (pos >= GSIArrayCount(_array))
	{
	  /*
	   * The start of the range to add lies beyond the existing
	   * ranges, so we can simply append it.
	   */
	  GSIArrayAddItem(_array, (GSIArrayItem)aRange);
	}
      else
	{
	  NSRange	r = GSIArrayItemAtIndex(_array, pos-1).ext;

	  if (NSLocationInRange(aRange.location, r))
	    {
	      pos++;
	    }
	  GSIArrayInsertItem(_array, (GSIArrayItem)aRange, pos);
	}

      /*
       * Combine with the preceding ranges if possible.
       */
      while (pos > 0)
	{
	  NSRange	r = GSIArrayItemAtIndex(_array, pos-1).ext;

	  if (NSMaxRange(r) < aRange.location)
	    {
	      break;
	    }
	  r.length += (NSMaxRange(aRange) - NSMaxRange(r));
	  GSIArrayRemoveItemAtIndex(_array, pos--);
	  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
	}

      /*
       * Combine with any following ranges where possible.
       */
      while (pos + 1 < GSIArrayCount(_array))
	{
	  NSRange	r = GSIArrayItemAtIndex(_array, pos+1).ext;

	  if (NSMaxRange(aRange) < r.location)
	    {
	      break;
	    }
	  GSIArrayRemoveItemAtIndex(_array, pos + 1);
	  if (NSMaxRange(r) > NSMaxRange(aRange))
	    {
	      int	offset = NSMaxRange(r) - NSMaxRange(aRange);

	      r = GSIArrayItemAtIndex(_array, pos).ext;
	      r.length += offset;
	      GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
	    }
	}
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
  [self removeIndexesInRange: NSMakeRange(anIndex, 1)];
}

- (void) removeIndexes: (NSIndexSet*)aSet
{
  unsigned	count = GSIArrayCount(_other);

  if (count > 0)
    {
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSRange	r = GSIArrayItemAtIndex(_other, i).ext;

	  [self removeIndexesInRange: r];
	}
    }
}

- (void) removeIndexesInRange: (NSRange)aRange
{
  unsigned	pos;

  if (NSNotFound - aRange.length < aRange.location)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@]: Bad range",
        NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (aRange.length == 0 || _array == 0 || GSIArrayCount(_array) == 0)
    {
      return;	// Already empty
    }
  pos = posForIndex(_array, aRange.location);

  /*
   * Remove any ranges contained entirely in the one to be removed.
   */
  while (pos < GSIArrayCount(_array))
    {
      NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;

      if (r.location < aRange.location || NSMaxRange(r) > NSMaxRange(aRange))
	{
	  break;
	}
      GSIArrayRemoveItemAtIndex(_array, pos);
    }

  if (pos < GSIArrayCount(_array))
    {
      NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;

      if (r.location <= aRange.location)
	{
	  /*
	   * The existing range might overlap or mcontain the range to remove.
	   */
	  if (NSMaxRange(r) >= NSMaxRange(aRange))
	    {
	      /*
	       * Range to remove is contained in the range we found ...
	       */
	      if (r.location == aRange.location)
		{
		  /*
		   * Remove from start of range.
		   */
		  r.length -= aRange.length;
		  r.location += aRange.length;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
		}
	      else if (NSMaxRange(r) == NSMaxRange(aRange))
		{
		  /*
		   * Remove from end of range.
		   */
		  r.length -= aRange.length;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
		}
	      else
		{
		  NSRange	t;
		  unsigned	p;

		  /*
		   * Split the range.
		   */
		  p = NSMaxRange(aRange);
		  t = NSMakeRange(p, NSMaxRange(r) - p);
		  GSIArrayInsertItem(_array, (GSIArrayItem)t, pos+1);
		  r.length = aRange.location - r.location;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
		}
	    }
	  else if (NSMaxRange(r) >= aRange.location)
	    {
	      /*
	       * The range to remove overlaps the one we found.
	       */
	      r.length = aRange.location - r.location;
	      GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);

	      if (++pos < GSIArrayCount(_array))
		{
		  NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;

		  if (r.location < NSMaxRange(aRange))
		    {
		      /*
		       * and also overlaps the following range.
		       */
		      r.length -= NSMaxRange(aRange) - r.location;
		      r.location = NSMaxRange(aRange);
		      GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
		    }
		}
	    }
	}
    }
}

- (void) shiftIndexesStartingAtIndex: (unsigned int)anIndex by: (int)amount
{
  if (amount != 0 && _array != 0 && GSIArrayCount(_array) > 0)
    {
      unsigned	c;
      unsigned	pos;

      if (amount > 0)
	{
	  c = GSIArrayCount(_array);
	  pos = posForIndex(_array, anIndex);

	  if (pos < c)
	    {
	      NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;

	      /*
	       * If anIndex is within an existing range, we split
	       * that range so we have one starting at anIndex.
	       */
	      if (r.location < anIndex)
		{
		  NSRange	t;

		  /*
		   * Split the range.
		   */
		  t = NSMakeRange(r.location, anIndex - r.location);
		  GSIArrayInsertItem(_array, (GSIArrayItem)t, pos);
		  c++;
		  r.length = NSMaxRange(r) - anIndex;
		  r.location = anIndex;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, ++pos);
		}

	      /*
	       * Shift all higher ranges to the right.
	       */
	      while (c > pos)
		{
		  NSRange	r = GSIArrayItemAtIndex(_array, --c).ext;

		  if (NSNotFound - amount <= r.location)
		    {
		      GSIArrayRemoveItemAtIndex(_array, c);
		    }
		  else if (NSNotFound - amount < NSMaxRange(r))
		    {
		      r.location += amount;
		      r.length = NSNotFound - r.location;
		      GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
		    }
		  else
		    {
		      r.location += amount;
		      GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
		    }
		}
	    }
	}
      else
	{
	  amount = -amount;

	  /*
	   * Delete range which will be overwritten.
	   */
	  if (amount >= anIndex)
	    {
	      [self removeIndexesInRange: NSMakeRange(0, anIndex)];
	    }
	  else
	    {
	      [self removeIndexesInRange:
		NSMakeRange(anIndex - amount, amount)];
	    }
	  pos = posForIndex(_array, anIndex);

	  /*
	   * Now shift everything left into the hole we made.
	   */
	  c = GSIArrayCount(_array);
	  while (c > pos)
	    {
	      NSRange	r = GSIArrayItemAtIndex(_array, --c).ext;

	      if (NSMaxRange(r) <= amount)
		{
		  GSIArrayRemoveItemAtIndex(_array, c);
		}
	      else if (r.location <= amount)
		{
		  r.length += (r.location - amount);
		  r.location = 0;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
		}
	      else
		{
		  r.location -= amount;
		  GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
		}
	    }
	}
    }
} 

@end

