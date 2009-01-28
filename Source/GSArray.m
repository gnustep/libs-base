/** Concrete implementation of NSArray
   Copyright (C) 1995, 1996, 1998, 1999 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   Rewrite by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>

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

   $Date$ $Revision$
   */

#import "config.h"
#import "GNUstepBase/preface.h"
#import "Foundation/NSArray.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSValue.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"

#import "GSPrivate.h"

static SEL	eqSel;
static SEL	oaiSel;

#if	GS_WITH_GC
static Class	GSArrayClass;
#else
static Class	GSInlineArrayClass;
@class	GSInlineArray;
#endif

@class	GSArray;

@interface GSArrayEnumerator : NSEnumerator
{
  GSArray	*array;
  unsigned	pos;
}
- (id) initWithArray: (GSArray*)anArray;
@end

@interface GSArrayEnumeratorReverse : GSArrayEnumerator
@end

@interface GSMutableArray (GSArrayBehavior)
- (void) _raiseRangeExceptionWithIndex: (unsigned)index from: (SEL)sel;
@end

@implementation GSArray

- (void) _raiseRangeExceptionWithIndex: (unsigned)index from: (SEL)sel
{
  NSDictionary *info;
  NSException  *exception;
  NSString     *reason;

  info = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithUnsignedInt: index], @"Index",
    [NSNumber numberWithUnsignedInt: _count], @"Count",
    self, @"Array", nil, nil];

  reason = [NSString stringWithFormat:
    @"Index %d is out of range %d (in '%@')",
    index, _count, NSStringFromSelector(sel)];

  exception = [NSException exceptionWithName: NSRangeException
		                      reason: reason
                                    userInfo: info];
  [exception raise];
}

+ (void) initialize
{
  if (self == [GSArray class])
    {
      [self setVersion: 1];
      eqSel = @selector(isEqual:);
      oaiSel = @selector(objectAtIndex:);
#if	GS_WITH_GC
      GSArrayClass = [GSArray class];
#else
      GSInlineArrayClass = [GSInlineArray class];
#endif
    }
}

+ (id) allocWithZone: (NSZone*)zone
{
  GSArray	*array = (GSArray*)NSAllocateObject(self, 0, zone);

  return (id)array;
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);	// Optimised version
}

- (void) dealloc
{
  if (_contents_array)
    {
#if	!GS_WITH_GC
      unsigned	i;

      for (i = 0; i < _count; i++)
	{
	  [_contents_array[i] release];
	}
#endif
      NSZoneFree([self zone], _contents_array);
    }
  NSDeallocateObject(self);
  GSNOSUPERDEALLOC;
}

- (id) init
{
  return [self initWithObjects: 0 count: 0];
}

/* This is the designated initializer for NSArray. */
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  if (count > 0)
    {
      unsigned	i;

#if	GS_WITH_GC
      _contents_array = NSAllocateCollectable(sizeof(id)*count,
	NSScannedOption);
#else
      _contents_array = NSZoneMalloc([self zone], sizeof(id)*count);
#endif
      if (_contents_array == 0)
	{
	  RELEASE(self);
	  return nil;
       }

      for (i = 0; i < count; i++)
	{
	  if ((_contents_array[i] = RETAIN(objects[i])) == nil)
	    {
	      _count = i;
	      RELEASE(self);
	      [NSException raise: NSInvalidArgumentException
			  format: @"Tried to init array with nil to object"];
	    }
	}
      _count = count;
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [super encodeWithCoder: aCoder];
    }
  else
    {
      /* For performace we encode directly ... must exactly match the
       * superclass implemenation. */
      [aCoder encodeValueOfObjCType: @encode(unsigned)
				 at: &_count];
      if (_count > 0)
	{
	  [aCoder encodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents_array];
	}
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      self = [super initWithCoder: aCoder];
    }
  else
    {
      /* for performance, we decode directly into memory rather than
       * using the superclass method. Must exactly match superclass. */
      [aCoder decodeValueOfObjCType: @encode(unsigned)
				 at: &_count];
      if (_count > 0)
	{
#if	GS_WITH_GC
          _contents_array = NSAllocateCollectable(sizeof(id) * _count,
	    NSScannedOption);
#else
	  _contents_array = NSZoneCalloc([self zone], _count, sizeof(id));
#endif
	  if (_contents_array == 0)
	    {
	      [NSException raise: NSMallocException
			  format: @"Unable to make array"];
	    }
	  [aCoder decodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents_array];
	}
    }
  return self;
}

- (unsigned) count
{
  return _count;
}

- (unsigned) hash
{
  return _count;
}

- (unsigned) indexOfObject: anObject
{
  if (anObject == nil)
    return NSNotFound;
  /*
   *	For large arrays, speed things up a little by caching the method.
   */
  if (_count > 1)
    {
      BOOL		(*imp)(id,SEL,id);
      unsigned		i;

      imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: eqSel];

      for (i = 0; i < _count; i++)
	{
	  if ((*imp)(anObject, eqSel, _contents_array[i]))
	    {
	      return i;
	    }
	}
    }
  else if (_count == 1 && [anObject isEqual: _contents_array[0]])
    {
      return 0;
    }
  return NSNotFound;
}

- (unsigned) indexOfObjectIdenticalTo: anObject
{
  unsigned i;

  for (i = 0; i < _count; i++)
    {
      if (anObject == _contents_array[i])
	{
	  return i;
	}
    }
  return NSNotFound;
}

- (BOOL) isEqualToArray: (NSArray*)otherArray
{
  unsigned i;

  if (self == (id)otherArray)
    {
      return YES;
    }
  if (_count != [otherArray count])
    {
      return NO;
    }
  if (_count > 0)
    {
      IMP	get1 = [otherArray methodForSelector: oaiSel];

      for (i = 0; i < _count; i++)
	{
	  if (![_contents_array[i] isEqual: (*get1)(otherArray, oaiSel, i)])
	    {
	      return NO;
	    }
	}
    }
  return YES;
}

- (id) lastObject
{
  if (_count)
    {
      return _contents_array[_count-1];
    }
  return nil;
}

- (id) objectAtIndex: (unsigned)index
{
  if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  return _contents_array[index];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  unsigned i;

  for (i = 0; i < _count; i++)
    {
      [_contents_array[i] performSelector: aSelector];
    }
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: argument
{
  unsigned i;

  for (i = 0; i < _count; i++)
    {
      [_contents_array[i] performSelector: aSelector withObject: argument];
    }
}

- (void) getObjects: (id*)aBuffer
{
  unsigned i;

  for (i = 0; i < _count; i++)
    {
      aBuffer[i] = _contents_array[i];
    }
}

- (void) getObjects: (id*)aBuffer range: (NSRange)aRange
{
  unsigned i, j = 0, e = aRange.location + aRange.length;

  GS_RANGE_CHECK(aRange, _count);

  for (i = aRange.location; i < e; i++)
    {
      aBuffer[j++] = _contents_array[i];
    }
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (NSUInteger)len
{
  /* For immutable arrays we can return the contents pointer directly. */
  state->itemsPtr = _contents_array;
  return _count;
}
@end

#if	!GS_WITH_GC
/* This class stores objects inline in data beyond the end of the instance.
 * However, when GC is enabled the object data is typed, and all data after
 * the end of the class is ignored by the garbage collector (which would
 * mean that objects in the array could be collected).
 * We therefore do not provide the class ewhan GC is being used.
 */
@interface GSInlineArray : GSArray
{
}
@end

@implementation	GSInlineArray
- (void) dealloc
{
  if (_contents_array)
    {
      unsigned	i;

      for (i = 0; i < _count; i++)
	{
	  [_contents_array[i] release];
	}
    }
  NSDeallocateObject(self);
  GSNOSUPERDEALLOC;
}
- (id) init
{
  return [self initWithObjects: 0 count: 0];
}
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  _contents_array = (id*)&self[1];
  if (count > 0)
    {
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  if ((_contents_array[i] = RETAIN(objects[i])) == nil)
	    {
	      _count = i;
	      RELEASE(self);
	      [NSException raise: NSInvalidArgumentException
			  format: @"Tried to init array with nil object"];
	    }
	}
      _count = count;
    }
  return self;
}
@end
#endif

@implementation GSMutableArray

+ (void) initialize
{
  if (self == [GSMutableArray class])
    {
      [self setVersion: 1];
      GSObjCAddClassBehavior(self, [GSArray class]);
    }
}

- (void) addObject: (id)anObject
{
  _version++;
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to add nil to array"];
    }
  if (_count >= _capacity)
    {
      id	*ptr;
      size_t	size = (_capacity + _grow_factor)*sizeof(id);

      ptr = NSZoneRealloc([self zone], _contents_array, size);
      if (ptr == 0)
	{
	  [NSException raise: NSMallocException
		      format: @"Unable to grow array"];
	}
      _contents_array = ptr;
      _capacity += _grow_factor;
      _grow_factor = _capacity/2;
    }
  _contents_array[_count] = RETAIN(anObject);
  _count++;	/* Do this AFTER we have retained the object.	*/
  _version++;
}

/**
 * Optimised code for copying
 */
- (id) copyWithZone: (NSZone*)zone
{
  NSArray       *copy;

#if	GS_WITH_GC
  copy = (id)NSAllocateObject(GSArrayClass, 0, zone);
#else
  copy = (id)NSAllocateObject(GSInlineArrayClass, sizeof(id)*_count, zone);
#endif
  return [copy initWithObjects: _contents_array count: _count];
}

- (void) exchangeObjectAtIndex: (unsigned int)i1
             withObjectAtIndex: (unsigned int)i2
{
  _version++;
  if (i1 >= _count)
    {
      [self _raiseRangeExceptionWithIndex: i1 from: _cmd];
    }
  if (i2 >= _count)
    {
      [self _raiseRangeExceptionWithIndex: i2 from: _cmd];
    }
  if (i1 != i2)
    {
      id	tmp = _contents_array[i1];

      _contents_array[i1] = _contents_array[i2];
      _contents_array[i2] = tmp;
    }
  _version++;
}

- (id) init
{
  return [self initWithCapacity: 0];
}

- (id) initWithCapacity: (unsigned)cap
{
  if (cap == 0)
    {
      cap = 1;
    }
#if	GS_WITH_GC
  _contents_array = NSAllocateCollectable(sizeof(id)*cap, NSScannedOption);
#else
  _contents_array = NSZoneMalloc([self zone], sizeof(id)*cap);
#endif
  _capacity = cap;
  _grow_factor = cap > 1 ? cap/2 : 1;
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      NSArray *array = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
						@"NS.objects"];

      [self initWithArray: array];
    }
  else
    {
	unsigned    count;

	[aCoder decodeValueOfObjCType: @encode(unsigned)
			           at: &count];
	if ((self = [self initWithCapacity: count]) == nil)
	  {
	    [NSException raise: NSMallocException
			format: @"Unable to make array while initializing from coder"];
	  }
	if (count > 0)
	  {
	    [aCoder decodeArrayOfObjCType: @encode(id)
		                    count: count
				       at: _contents_array];
	    _count = count;
	  }
    }
  return self;
}

- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  self = [self initWithCapacity: count];
  if (self != nil && count > 0)
    {
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  if ((_contents_array[i] = RETAIN(objects[i])) == nil)
	    {
	      _count = i;
	      RELEASE(self);
	      [NSException raise: NSInvalidArgumentException
			  format: @"Tried to init array with nil object"];
	    }
	}
      _count = count;
    }
  return self;
}

- (void) insertObject: (id)anObject atIndex: (unsigned)index
{
  _version++;
  if (!anObject)
    {
      NSException  *exception;
      NSDictionary *info;

      info = [NSDictionary dictionaryWithObjectsAndKeys:
	[NSNumber numberWithUnsignedInt: index], @"Index",
	self, @"Array", nil, nil];

      exception = [NSException exceptionWithName: NSInvalidArgumentException
	reason: @"Tried to insert nil to array"
	userInfo: info];
      [exception raise];
    }
  if (index > _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  if (_count == _capacity)
    {
      id	*ptr;
      size_t	size = (_capacity + _grow_factor)*sizeof(id);

      ptr = NSZoneRealloc([self zone], _contents_array, size);
      if (ptr == 0)
	{
	  [NSException raise: NSMallocException
		      format: @"Unable to grow"];
	}
      _contents_array = ptr;
      _capacity += _grow_factor;
      _grow_factor = _capacity/2;
    }
  memmove(&_contents_array[index+1], &_contents_array[index],
    (_count - index) * sizeof(id));
  /*
   *	Make sure the array is 'sane' so that it can be deallocated
   *	safely by an autorelease pool if the '[anObject retain]' causes
   *	an exception.
   */
  _contents_array[index] = nil;
  _count++;
  _contents_array[index] = RETAIN(anObject);
  _version++;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
#ifndef NDEBUG
  GSDebugAllocationRemove(isa, self);
#endif
  isa = [GSArray class];
#ifndef NDEBUG
  GSDebugAllocationAdd(isa, self);
#endif
  return self;
}

- (void) removeLastObject
{
  _version++;
  if (_count == 0)
    {
      [NSException raise: NSRangeException
		  format: @"Trying to remove from an empty array."];
    }
  _count--;
  RELEASE(_contents_array[_count]);
  _contents_array[_count] = 0;
  _version++;
}

- (void) removeObject: (id)anObject
{
  unsigned	index;

  _version++;
  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  index = _count;
  if (index > 0)
    {
      BOOL	(*imp)(id,SEL,id);
#if	GS_WITH_GC == 0
      BOOL	retained = NO;
#endif

      imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: eqSel];
      while (index-- > 0)
	{
	  if ((*imp)(anObject, eqSel, _contents_array[index]) == YES)
	    {
	      unsigned	pos = index;
#if	GS_WITH_GC == 0
	      id	obj = _contents_array[index];

	      if (retained == NO)
		{
		  RETAIN(anObject);
		  retained = YES;
		}
#endif

	      while (++pos < _count)
		{
		  _contents_array[pos-1] = _contents_array[pos];
		}
	      _count--;
	      _contents_array[_count] = 0;
	      RELEASE(obj);
	    }
	}
#if	GS_WITH_GC == 0
      if (retained == YES)
	{
	  RELEASE(anObject);
	}
#endif
    }
  _version++;
}

- (void) removeObjectAtIndex: (unsigned)index
{
  id	obj;

  _version++;
  if (index >= _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  obj = _contents_array[index];
  _count--;
  while (index < _count)
    {
      _contents_array[index] = _contents_array[index+1];
      index++;
    }
  _contents_array[_count] = 0;
  RELEASE(obj);	/* Adjust array BEFORE releasing object.	*/
  _version++;
}

- (void) removeObjectIdenticalTo: (id)anObject
{
  unsigned	index;

  _version++;
  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  index = _count;
  while (index-- > 0)
    {
      if (_contents_array[index] == anObject)
	{
#if	GS_WITH_GC == 0
	  id		obj = _contents_array[index];
#endif
	  unsigned	pos = index;

	  while (++pos < _count)
	    {
	      _contents_array[pos-1] = _contents_array[pos];
	    }
	  _count--;
	  _contents_array[_count] = 0;
	  RELEASE(obj);
	}
    }
  _version++;
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: (id)anObject
{
  id	obj;

  _version++;
  if (index >= _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  if (!anObject)
    {
      NSException  *exception;
      NSDictionary *info;

      info = [NSDictionary dictionaryWithObjectsAndKeys:
	[NSNumber numberWithUnsignedInt: index], @"Index",
        _contents_array[index], @"OLdObject",
	self, @"Array", nil, nil];

      exception = [NSException exceptionWithName: NSInvalidArgumentException
	reason: @"Tried to replace object in array with nil"
	userInfo: info];
      [exception raise];
    }
  /*
   *	Swap objects in order so that there is always a valid object in the
   *	array in case a retain or release causes an exception.
   */
  obj = _contents_array[index];
  IF_NO_GC(RETAIN(anObject));
  _contents_array[index] = anObject;
  RELEASE(obj);
  _version++;
}

- (void) sortUsingFunction: (NSComparisonResult(*)(id,id,void*))compare
		   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  unsigned int	c;
  unsigned int	d;
  unsigned int	stride = 1;
  BOOL		found;
  unsigned int	count = _count;
#ifdef	GSWARN
  BOOL		badComparison = NO;
#endif

  _version++;
  while (stride <= count)
    {
      stride = stride * STRIDE_FACTOR + 1;
    }

  while (stride > (STRIDE_FACTOR - 1))
    {
      // loop to sort for each value of stride
      stride = stride / STRIDE_FACTOR;
      for (c = stride; c < count; c++)
	{
	  found = NO;
	  if (stride > c)
	    {
	      break;
	    }
	  d = c - stride;
	  while (!found)	/* move to left until correct place */
	    {
	      id			a = _contents_array[d + stride];
	      id			b = _contents_array[d];
	      NSComparisonResult	r;

	      r = (*compare)(a, b, context);
	      if (r < 0)
		{
#ifdef	GSWARN
		  if (r != NSOrderedAscending)
		    {
		      badComparison = YES;
		    }
#endif
		  _contents_array[d+stride] = b;
		  _contents_array[d] = a;
		  if (stride > d)
		    {
		      break;
		    }
		  d -= stride;		// jump by stride factor
		}
	      else
		{
#ifdef	GSWARN
		  if (r != NSOrderedDescending && r != NSOrderedSame)
		    {
		      badComparison = YES;
		    }
#endif
		  found = YES;
		}
	    }
	}
    }
#ifdef	GSWARN
  if (badComparison == YES)
    {
      NSWarnMLog(@"Detected bad return value from comparison");
    }
#endif
  _version++;
}

- (NSEnumerator*) objectEnumerator
{
  GSArrayEnumerator	*enumerator;

  enumerator = [GSArrayEnumerator allocWithZone: NSDefaultMallocZone()];
  return AUTORELEASE([enumerator initWithArray: (GSArray*)self]);
}

- (NSEnumerator*) reverseObjectEnumerator
{
  GSArrayEnumeratorReverse	*enumerator;

  enumerator = [GSArrayEnumeratorReverse allocWithZone: NSDefaultMallocZone()];
  return AUTORELEASE([enumerator initWithArray: (GSArray*)self]);
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (NSUInteger)len
{
  NSInteger count;

  /* This is cached in the caller at the start and compared at each
   * iteration.   If it changes during the iteration then
   * objc_enumerationMutation() will be called, throwing an exception.
   */
  state->mutationsPtr = (unsigned long*)_version;
  count = MIN(len, _count - state->state);
  /* If a mutation has occurred then it's possible that we are being asked to
   * get objects from after the end of the array.  Don't pass negative values
   * to memcpy.
   */
  if (count <= 0)
    {
      memcpy(stackbuf, _contents_array, count);
      state->state += count;
    }
  else
    {
      count = 0;
    }
  state->itemsPtr = stackbuf;
  return count;
}
@end



@implementation GSArrayEnumerator

- (id) initWithArray: (GSArray*)anArray
{
  [super init];
  array = anArray;
  IF_NO_GC(RETAIN(array));
  pos = 0;
  return self;
}

- (id) nextObject
{
  if (pos >= array->_count)
    return nil;
  return array->_contents_array[pos++];
}

- (void) dealloc
{
  RELEASE(array);
  NSDeallocateObject(self);
  GSNOSUPERDEALLOC;
}

@end

@implementation GSArrayEnumeratorReverse

- (id) initWithArray: (GSArray*)anArray
{
  [super initWithArray: anArray];
  pos = array->_count;
  return self;
}

- (id) nextObject
{
  if (pos == 0)
    return nil;
  return array->_contents_array[--pos];
}
@end

@implementation	GSArray (GNUstep)
/*
 *	The comparator function takes two items as arguments, the first is the
 *	item to be added, the second is the item already in the array.
 *      The function should return NSOrderedAscending if the item to be
 *      added is 'less than' the item in the array, NSOrderedDescending
 *      if it is greater, and NSOrderedSame if it is equal.
 */
- (unsigned) insertionPosition: (id)item
		 usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		       context: (void *)context
{
  unsigned	upper = _count;
  unsigned	lower = 0;
  unsigned	index;

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

  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*sorter)(item, _contents_array[index], context);
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
  while (index < _count
    && (*sorter)(item, _contents_array[index], context) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}

- (unsigned) insertionPosition: (id)item
		 usingSelector: (SEL)comp
{
  unsigned	upper = _count;
  unsigned	lower = 0;
  unsigned	index;
  NSComparisonResult	(*imp)(id, SEL, id);

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

  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*imp)(item, comp, _contents_array[index]);
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
  while (index < _count
    && (*imp)(item, comp, _contents_array[index]) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}
@end

@implementation	GSPlaceholderArray

+ (void) initialize
{
#if	GS_WITH_GC
  GSArrayClass = [GSArray class];
#else
  GSInlineArrayClass = [GSInlineArray class];
#endif
}

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised array");
  return self;		// placeholders never get released.
}

- (id) objectAtIndex: (unsigned)index
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to use uninitialised array"];
  return 0;
}

- (void) dealloc
{
  GSNOSUPERDEALLOC;	// placeholders never get deallocated.
}

- (id) init
{
  return [self initWithObjects: 0 count: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      NSArray *array = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
						@"NS.objects"];

      return RETAIN(array);
    }
  else
    {
      unsigned	c;
#if	GS_WITH_GC
      GSArray	*a;

      [aCoder decodeValueOfObjCType: @encode(unsigned) at: &c];
      a = (id)NSAllocateObject(GSArrayClass, 0, GSObjCZone(self));
      a->_contents_array = NSAllocateCollectable(sizeof(id)*c, NSScannedOption);
#else
      GSInlineArray	*a;

      [aCoder decodeValueOfObjCType: @encode(unsigned) at: &c];
      a = (id)NSAllocateObject(GSInlineArrayClass,
	sizeof(id)*c, GSObjCZone(self));
      a->_contents_array = (id*)&a[1];
#endif
      if (c > 0)
        {
	  [aCoder decodeArrayOfObjCType: @encode(id)
		                  count: c
				  at: a->_contents_array];
	}
      a->_count = c;
      return a;
    }
}

- (id) initWithObjects: (id*)objects count: (unsigned)count
{
#if	GS_WITH_GC
  self = (id)NSAllocateObject(GSArrayClass, 0, GSObjCZone(self));
#else
  self = (id)NSAllocateObject(GSInlineArrayClass, sizeof(id)*count,
    GSObjCZone(self));
#endif
  return [self initWithObjects: objects count: count];
}

- (unsigned) count
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to use uninitialised array"];
  return 0;
}

- (void) release
{
  return;		// placeholders never get released.
}

- (id) retain
{
  return self;		// placeholders never get retained.
}
@end

@interface	NSGArray : NSArray
@end
@implementation	NSGArray
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSArray class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

@interface	NSGMutableArray : NSMutableArray
@end
@implementation	NSGMutableArray
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSMutableArray class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

