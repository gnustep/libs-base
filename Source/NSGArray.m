/* Concrete implementation of NSArray 
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   Rewrite by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSArray.h>
#include <gnustep/base/behavior.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>
#include <gnustep/base/Coding.h>

#define BADREALLOC 1

@interface NSGArray : NSArray
{
    id		*_contents_array;
    unsigned	_count;
}
@end

@interface NSGMutableArray : NSMutableArray
{
    id		*_contents_array;
    unsigned	_count;
    unsigned	_capacity;
    int		_grow_factor;
}
@end

@class NSArrayNonCore;

@implementation NSGArray

+ (void) initialize
{
    if (self == [NSGArray class]) {
        behavior_class_add_class(self, [NSArrayNonCore class]);
    }
}

- (void) dealloc
{
    if (_contents_array) {
	unsigned	i;

	for (i = 0; i < _count; i++) {
	    [_contents_array[i] release];
	}
	NSZoneFree([self zone], _contents_array);
    }
    [super dealloc];
}

/* This is the designated initializer for NSArray. */
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
    if (count > 0) {
	unsigned	i;

	_contents_array = NSZoneMalloc([self zone], sizeof(id)*count);
	if (_contents_array == 0) {
	    [self release];
	    return nil;
	}

	for (i = 0; i < count; i++) {
	    if ((_contents_array[i] = [objects[i] retain]) == nil) {
		_count = i;
		[self autorelease];
		[NSException raise: NSInvalidArgumentException
			    format: @"Tried to add nil"];
	    }
	}
	_count = count;
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    unsigned	i;

    [(id<Encoding>)aCoder encodeValueOfCType: @encode(unsigned)
					  at: &_count
				    withName: @"Array content count"];

    if ([aCoder isKindOfClass: [NSPortCoder class]] &&
	[(NSPortCoder*)aCoder isBycopy]) {
	for (i = 0; i < _count; i++) {
	    [(id<Encoding>)aCoder encodeBycopyObject: _contents_array[i]
					    withName: @"Array content"];
	}
    }
    else {
	for (i = 0; i < _count; i++) {
	    [(id<Encoding>)aCoder encodeObject: _contents_array[i]
				      withName: @"Array content"];
	}
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned    count;

    [(id<Decoding>)aCoder decodeValueOfCType: @encode(unsigned)
					  at: &count
				    withName: NULL];
    if (count > 0) {
	_contents_array = NSZoneMalloc([self zone], sizeof(id)*count);
	if (_contents_array == 0) {
	    [NSException raise: NSMallocException
			format: @"Unable to make array"];
	}
	while (_count < count) {
	    [(id<Decoding>)aCoder decodeObjectAt: &_contents_array[_count++]
					withName: NULL];
	}
    }
    return self;
}

- (id) init
{
    return [self initWithObjects: 0 count: 0];
}

- (unsigned) count
{
    return _count;
}

- (unsigned) indexOfObject: anObject
{
    unsigned	hash = [anObject hash];
    unsigned	i;

    for (i = 0; i < _count; i++) {
	if ([_contents_array[i] hash] == hash) {
	    if ([_contents_array[i] isEqual: anObject]) {
		return i;
	    }
	}
    }
    return NSNotFound;
}

- (unsigned) indexOfObjectIdenticalTo: anObject
{
    unsigned i;

    for (i = 0; i < _count; i++) {
	if (anObject == _contents_array[i]) {
	    return i;
	}
    }
    return NSNotFound;
}

- (id) objectAtIndex: (unsigned)index
{
    if (index >= _count) {
        [NSException raise: NSRangeException
		    format: @"Index out of bounds"];
    }
    return _contents_array[index];
}


- (void) getObjects: (id*)aBuffer
{
    unsigned i;

    for (i = 0; i < _count; i++) {
        aBuffer[i] = _contents_array[i];
    }
}

- (void) getObjects: (id*)aBuffer range: (IndexRange)aRange
{
    unsigned i, j = 0, e = aRange.location + aRange.length;

    if (_count < e) {
        e = _count;
    }
    for (i = aRange.location; i < _count; i++) {
        aBuffer[j++] = _contents_array[i];
    }
}

@end

@class NSMutableArrayNonCore;

@implementation NSGMutableArray

+ (void) initialize
{
    if (self == [NSGMutableArray class]) {
        behavior_class_add_class(self, [NSMutableArrayNonCore class]);
        behavior_class_add_class(self, [NSGArray class]);
    }
}

- (id) initWithCapacity: (unsigned)cap
{
    if (cap == 0) {
	cap = 1;
    }
    _contents_array = NSZoneMalloc([self zone], sizeof(id)*cap);
    _capacity = cap;
    _grow_factor = cap > 1 ? cap/2 : 1;
    return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned    count;

    [(id<Decoding>)aCoder decodeValueOfCType: @encode(unsigned)
					  at: &count
				    withName: NULL];
    if ([self initWithCapacity: count] == nil) {
	[NSException raise: NSMallocException
		    format: @"Unable to make array"];
    }
    while (_count < count) {
	[(id<Decoding>)aCoder decodeObjectAt: &_contents_array[_count++]
				    withName: NULL];
    }
    return self;
}

- (id) initWithObjects: (id*)objects count: (unsigned)count
{
    self = [self initWithCapacity: count];
    if (self != nil && count > 0) {
	unsigned	i;

	for (i = 0; i < count; i++) {
	    if ((_contents_array[i] = [objects[i] retain]) == nil) {
		_count = i;
		[self autorelease];
		[NSException raise: NSInvalidArgumentException
			    format: @"Tried to add nil"];
	    }
	}
	_count = count;
    }
    return self;
}

- (void) insertObject: (id)anObject atIndex: (unsigned)index
{
    unsigned	i;

    if (!anObject) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Tried to insert nil"];
    }
    if (index > _count) {
	[NSException raise: NSRangeException format:
		@"in insertObject:atIndex:, index %d is out of range", index];
    }
    if (_count == _capacity) {
	id	*ptr;
	size_t	size = (_capacity + _grow_factor)*sizeof(id);

#if BADREALLOC
	ptr = NSZoneMalloc([self zone], size);
#else
	ptr = NSZoneRealloc([self zone], _contents_array, size);
#endif
	if (ptr == 0) {
	    [NSException raise: NSMallocException
			format: @"Unable to grow"];
	}
#if BADREALLOC
	if (_contents_array) {
	    memcpy(ptr, _contents_array, _capacity*sizeof(id));
	    NSZoneFree([self zone], _contents_array);
	}
#endif
	_contents_array = ptr;
	_capacity += _grow_factor;
	_grow_factor = _capacity/2;
    }
    for (i = _count; i > index; i--) {
	_contents_array[i] = _contents_array[i - 1];
    }
    /*
     *	Make sure the array is 'sane' so that it can be deallocated
     *	safely by an autorelease pool if the '[anObject retain]' causes
     *	an exception.
     */
    _contents_array[index] = nil;
    _count++;
    _contents_array[index] = [anObject retain];
}

- (void) addObject: (id)anObject
{
    if (anObject == nil) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Tried to add nil"];
    }
    if (_count >= _capacity) {
	id	*ptr;
	size_t	size = (_capacity + _grow_factor)*sizeof(id);

#if BADREALLOC
	ptr = NSZoneMalloc([self zone], size);
#else
	ptr = NSZoneRealloc([self zone], _contents_array, size);
#endif
	if (ptr == 0) {
	    [NSException raise: NSMallocException
			format: @"Unable to grow"];
	}
#if BADREALLOC
	if (_contents_array) {
	    memcpy(ptr, _contents_array, _capacity*sizeof(id));
	    NSZoneFree([self zone], _contents_array);
	}
#endif
	_contents_array = ptr;
	_capacity += _grow_factor;
	_grow_factor = _capacity/2;
    }
    _contents_array[_count] = [anObject retain];
    _count++;	/* Do this AFTER we have retained the object.	*/
}

- (void) removeLastObject
{
    if (_count == 0) {
	[NSException raise: NSRangeException
		    format: @"Trying to remove from an empty array."];
    }
    _count--;
    [_contents_array[_count] release];
}

- (void) removeObjectAtIndex: (unsigned)index
{
    id	obj;

    if (index >= _count) {
	[NSException raise: NSRangeException format:
		@"in removeObjectAtIndex:, index %d is out of range", index];
    }
    obj = _contents_array[index];
    _count--;
    while (index < _count) {
	_contents_array[index] = _contents_array[index+1];
	index++;
    }
    [obj release];	/* Adjust array BEFORE releasing object.	*/
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: (id)anObject
{
    id	obj;

    if (index >= _count) {
	[NSException raise: NSRangeException format:
	    @"in replaceObjectAtIndex:withObject:, index %d is out of range",
	    index];
    }
    /*
     *	Swap objects in order so that there is always a valid object in the
     *	array in case a retain or release causes an exception.
     */
    obj = _contents_array[index];
    [anObject retain];
    _contents_array[index] = anObject;
    [obj release];
}

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
		   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  unsigned c,d, stride;
  BOOL found;
  int count = _count;

  stride = 1;
  while (stride <= count)
    stride = stride * STRIDE_FACTOR + 1;
    
  while(stride > (STRIDE_FACTOR - 1)) {
    // loop to sort for each value of stride
    stride = stride / STRIDE_FACTOR;
    for (c = stride; c < count; c++) {
      found = NO;
      if (stride > c)
	break;
      d = c - stride;
      while (!found) {
	// move to left until correct place
	id a = _contents_array[d + stride];
	id b = _contents_array[d];
	if ((*compare)(a, b, context) == NSOrderedAscending) {
	  _contents_array[d+stride] = b;
	  _contents_array[d] = a;
	  if (stride > d)
	    break;
	  d -= stride;		// jump by stride factor
	}
	else found = YES;
      }
    }
  }
}

@end
