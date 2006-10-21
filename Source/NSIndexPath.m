/** Implementation for NSIndexPath for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Feb 2006
   
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

   */ 

#include	<Foundation/NSByteOrder.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSHashTable.h>
#include	<Foundation/NSIndexPath.h>
#include	<Foundation/NSKeyedArchiver.h>
#include	<Foundation/NSLock.h>
#include	<Foundation/NSZone.h>
#include	"GNUstepBase/GSLock.h"

static	NSLock		*lock = nil;
static	NSHashTable	*shared = 0;
static	Class		myClass = 0;
static	NSIndexPath	*empty = nil;
static	NSIndexPath	*dummy = nil;

@implementation	NSIndexPath

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == myClass)
    {
      return empty;
    }
  return [super allocWithZone: aZone];
}

+ (id) indexPathWithIndex: (unsigned)anIndex
{
  return [self indexPathWithIndexes: &anIndex length: 1];
}

+ (id) indexPathWithIndexes: (unsigned*)indexes length: (unsigned)length
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  o = [o initWithIndexes: indexes length: length];
  AUTORELEASE(o);
  return o;
}

+ (void) initialize
{
  if (empty == nil)
    {
      myClass = self;
      empty = (NSIndexPath*)NSAllocateObject(self, 0, NSDefaultMallocZone());
      dummy = (NSIndexPath*)NSAllocateObject(self, 0, NSDefaultMallocZone());
      shared = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 1024);
      NSHashInsert(shared, empty);
      lock = [GSLazyRecursiveLock new];
    }
}

- (NSComparisonResult) compare: (NSIndexPath*)other
{
  if (other != self)
    {
      unsigned	olength = other->_length;
      unsigned	*oindexes = other->_indexes;
      unsigned	end = (_length > olength) ? _length : olength;
      unsigned	pos;

      for (pos = 0; pos < end; pos++)
	{
	  if (pos >= _length)
	    {
	      return NSOrderedDescending;
	    }
	  else if (pos >= olength)
	    {
	      return NSOrderedAscending;
	    }
	  if (oindexes[pos] < _indexes[pos])
	    {
	      return NSOrderedDescending;
	    }
	  if (oindexes[pos] > _indexes[pos])
	    {
	      return NSOrderedAscending;
	    }
	}
      /*
       * Should never get here.
       */
      NSLog(@"Argh ... two identical index paths exist!");
    }
  return NSOrderedSame;
}

- (id) copyWithZone: (NSZone*)aZone
{
  return RETAIN(self);
}

- (void) dealloc
{
  if (self != empty)
    {
      [lock lock];
      NSHashRemove(shared, self);
      [lock unlock];
      NSZoneFree(NSDefaultMallocZone(), _indexes);
      NSDeallocateObject(self);
    }
  GSNOSUPERDEALLOC;
}

- (NSString*) description
{
  NSMutableString	*m = [[super description] mutableCopy];
  unsigned		i;

  [m appendFormat: @"%u indexes [", _length];
  for (i = 0; i < _length; i++)
    {
      if (i > 0)
	{
	  [m appendString: @", "];
	}
      [m appendFormat: @"%u", _indexes[i]];
    }
  [m appendString: @"]"];
  return AUTORELEASE(m);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding] == YES)
    {
      [aCoder encodeInt: (int)_length forKey: @"NSIndexPathLength"];
      if (_length == 1)
	{
	  [aCoder encodeInt: (int)_indexes[0] forKey: @"NSIndexPathValue"];
	}
      else if (_length > 1)
	{
	  NSMutableData	*m;
	  unsigned	*buf;
	  unsigned	i;

	  m = [NSMutableData new];
	  [m setLength: _length * sizeof(unsigned)];
	  buf = [m mutableBytes];
	  for (i = 0; i < _length; i++)
	    {
	      buf[i] = NSSwapHostIntToBig(_indexes[i]);
	    }
	  [aCoder encodeObject: m forKey: @"NSIndexPathData"];
	  RELEASE(m);
	}
    }
  else
    {
      [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_length];
      if (_length > 0)
	{
	  [aCoder encodeArrayOfObjCType: @encode(unsigned)
				  count: _length
				     at: _indexes];
	}
    }
}

- (void) getIndexes: (unsigned*)aBuffer
{
  memcpy(aBuffer, _indexes, _length * sizeof(unsigned));
}

- (unsigned) hash
{
  return _hash;
}

- (unsigned) indexAtPosition: (unsigned)position
{
  if (position >= _length)
    {
      return NSNotFound;
    }
  return _indexes[position];
}

/**
 * Return path formed by adding the index to the receiver.
 */
- (NSIndexPath *) indexPathByAddingIndex: (unsigned)anIndex
{
  unsigned	buffer[_length + 1];

  [self getIndexes: buffer];
  buffer[_length] = anIndex;
  return [[self class] indexPathWithIndexes: buffer length: _length + 1];
}

- (NSIndexPath *) indexPathByRemovingLastIndex
{
  if (_length <= 1)
    {
      return empty;
    }
  else
    {
      return [[self class] indexPathWithIndexes: _indexes length: _length - 1];
    }
}
 
- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding] == YES)
    {
      unsigned	length;
      unsigned	index;

      length = (unsigned)[aCoder decodeIntForKey: @"NSIndexPathLength"];
      if (length == 1)
	{
	  index = (unsigned)[aCoder decodeIntForKey: @"NSIndexPathValue"];
	  self = [self initWithIndex: index];
	}
      else if (length > 1)
	{
	  // FIXME ... not MacOS-X
	  NSMutableData	*d = [aCoder decodeObjectForKey: @"NSIndexPathData"];
	  unsigned	l = [d length];
	  unsigned	s = l / length;
	  unsigned	i;

	  if (s == sizeof(unsigned))
	    {
	      unsigned	*ptr = (unsigned*)[d mutableBytes];

	      for (i = 0; i < _length; i++)
		{
		  ptr[i] = NSSwapBigIntToHost(ptr[i]);
		}
	      self = [self initWithIndexes: ptr length: length];
	    }
	  else
	    {
	      unsigned	*buf;

	      buf = (unsigned*)NSZoneMalloc(NSDefaultMallocZone(),
		length * sizeof(unsigned));
	      if (s == sizeof(long))
		{
		  long	*ptr = (long*)[d mutableBytes];

		  for (i = 0; i < _length; i++)
		    {
		      buf[i] = (unsigned)NSSwapBigLongToHost(ptr[i]);
		    }
		}
	      else if (s == sizeof(short))
		{
		  short	*ptr = (short*)[d mutableBytes];

		  for (i = 0; i < _length; i++)
		    {
		      buf[i] = (unsigned)NSSwapBigShortToHost(ptr[i]);
		    }
		}
	      else if (s == sizeof(long long))
		{
		  long long	*ptr = (long long*)[d mutableBytes];

		  for (i = 0; i < _length; i++)
		    {
		      buf[i] = (unsigned)NSSwapBigLongLongToHost(ptr[i]);
		    }
		}
	      else
		{
		  [NSException raise: NSGenericException format:
		    @"Unable to decode unsigned integers of size %u", s];
		}
	      self = [self initWithIndexes: buf length: length];
	      NSZoneFree(NSDefaultMallocZone(), buf);
	    }
	}
    }
  else
    {
      unsigned	length;

      [aCoder decodeValueOfObjCType: @encode(unsigned) at: &length];
      if (length == 0)
	{
	  RELEASE(self);
	  self = empty;
	}
      else
	{
	  unsigned	buf[16];
	  unsigned	*indexes = buf;

	  if (length > 16)
	    {
	      indexes = NSZoneMalloc(NSDefaultMallocZone(),
		length * sizeof(unsigned));
	    }
	  [aCoder decodeArrayOfObjCType: @encode(unsigned)
				  count: length
				     at: indexes];
	  self = [self initWithIndexes: indexes length: length];
	  if (indexes != buf)
	    {
	      NSZoneFree(NSDefaultMallocZone(), indexes);
	    }
	}
    }
  return self;
}

- (id) initWithIndex: (unsigned)anIndex
{
  return [self initWithIndexes: &anIndex length: 1];
}

/** <init />
 * Initialise the receiver to contain the specified indexes.<br />
 * May return an existing index path.
 */
- (id) initWithIndexes: (unsigned*)indexes length: (unsigned)length
{
  NSIndexPath	*found;
  unsigned	h = 0;
  unsigned	i;

  if (_length != 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to re-initialize NSIndexPath"];
    }
  // FIXME ... need better hash function?
  for (i = 0; i < length; i++)
    {
      h = (h << 5) ^ indexes[i];
    }

  [lock lock];
  dummy->_hash = h;
  dummy->_length = length;
  dummy->_indexes = indexes;
  found = NSHashGet(shared, dummy);
  if (found == nil)
    {
      if (self == empty)
	{
	  self = (NSIndexPath*)NSAllocateObject([self class],
	    0, NSDefaultMallocZone());
	}
      _hash = dummy->_hash;
      _length = dummy->_length;
      _indexes = NSZoneMalloc(NSDefaultMallocZone(),
	_length * sizeof(unsigned));
      memcpy(_indexes, dummy->_indexes, _length * sizeof(unsigned));
      NSHashInsert(shared, self);
    }
  else
    {
      RELEASE(self);
      self = RETAIN(found);
    }
  [lock unlock];
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    {
      return YES;
    }
  if (other == nil || GSObjCIsKindOf(GSObjCClass(other), myClass) == NO)
    {
      return NO;
    }
  if (((NSIndexPath*)other)->_length != _length)
    {
      return NO;
    }
  else
    {
      unsigned	*oindexes = ((NSIndexPath*)other)->_indexes;
      unsigned	pos = _length;

      while (pos-- > 0)
	{
	  if (_indexes[pos] != oindexes[pos])
	    {
	      return NO;
	    }
	}
    }
  return YES;
}

- (unsigned) length
{
  return _length;
}

- (void) release
{
  if (self != empty)
    {
      /* We lock the table while checking, to prevent
       * another thread from grabbing this object while we are
       * checking it.
       * If we are going to deallocate the object, we first remove
       * it from the table so that no other thread will find it
       * and try to use it while it is being deallocated.
       */
      [lock lock];
      if (NSDecrementExtraRefCountWasZero(self))
	{
	  [self dealloc];
	}
      [lock unlock];
    }
}

@end

