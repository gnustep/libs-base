/* A fast inline array table implementation without objc method overhead.
 * Copyright (C) 1998  Free Software Foundation, Inc.
 * 
 * Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
 * Created:	Nov 1998
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#include <config.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>

/* To easily un-inline functions for debugging */
#ifndef	INLINE
#define INLINE inline
#endif

#define	NS_BLOCK_ASSERTIONS	1

/*
 *	This file should be INCLUDED in files wanting to use the FastArray
 *	functions - these are all declared inline for maximum performance.
 *
 *	The file including this one may predefine some macros to alter
 *	the behaviour (default macros assume the items are NSObjects
 *	that are to be retained in the array) ...
 *
 *	FAST_ARRAY_RETAIN()
 *		Macro to retain an array item
 *
 *	FAST_ARRAY_RELEASE()
 *		Macro to release the item.
 *
 */

#ifndef	FAST_ARRAY_RETAIN
#define	FAST_ARRAY_RETAIN(X)	[(X).o retain]
#endif

#ifndef	FAST_ARRAY_RELEASE
#define	FAST_ARRAY_RELEASE(X)	[(X).o release]
#endif

typedef	union {
  id		o;
  Class		c;
  int		i;
  unsigned	I;
  long 		l;
  unsigned long	L;
  void		*p;
  const void	*P;
  char		*s;
  const char	*S;
  SEL		C;
  gsu8		u8;
  gsu16		u16;
  gsu32		u32;
} FastArrayItem;

struct	_FastArray {
  FastArrayItem	*ptr;
  unsigned	count;
  unsigned	cap;
  unsigned	old;
  NSZone	*zone;
};
typedef	struct	_FastArray	FastArray_t;
typedef	struct	_FastArray	*FastArray;

static INLINE void
FastArrayAddItem(FastArray array, FastArrayItem item)
{
  if (array->count == array->cap)
    {
      unsigned		next;
      FastArrayItem	*tmp;

      next = array->cap + array->old;
      tmp = NSZoneRealloc(array->zone, array->ptr, next*sizeof(FastArrayItem));

      if (tmp == 0)
	{
	  [NSException raise: NSMallocException
		      format: @"failed to grow FastArray"];
	}
      array->ptr = tmp;
      array->old = array->cap;
      array->cap = next;
    }
  array->ptr[array->count++] = FAST_ARRAY_RETAIN(item);
}

static INLINE void
FastArrayRemoveItemAtIndex(FastArray array, unsigned index)
{
  NSCAssert(index < array->count, NSInvalidArgumentException);
  FAST_ARRAY_RELEASE(array->ptr[index]);
  while (++index < array->count)
    array->ptr[index-1] = array->ptr[index];
  array->count--;
}

static INLINE void
FastArraySetItemAtIndex(FastArray array, FastArrayItem item, unsigned index)
{
  NSCAssert(index < array->count, NSInvalidArgumentException);
  if (array->ptr[index].o != item.o)
    {
      FAST_ARRAY_RELEASE(array->ptr[index]);
      array->ptr[index] = FAST_ARRAY_RETAIN(item);
    }
}

static INLINE FastArrayItem
FastArrayItemAtIndex(FastArray array, unsigned index)
{
  NSCAssert(index < array->count, NSInvalidArgumentException);
  return array->ptr[index];
}

static INLINE unsigned
FastArrayCount(FastArray array)
{
  return array->count;
}

static INLINE void
FastArrayClear(FastArray array)
{
  if (array->ptr)
    {
      NSZoneFree(array->zone, (void*)array->ptr);
      array->ptr = 0;
    }
}

static INLINE void
FastArrayEmpty(FastArray array)
{
  unsigned	i = array->count;

  while (i-- > 0)
    FAST_ARRAY_RELEASE(array->ptr[i]);
  FastArrayClear(array);
  array->cap = 0;
  array->count = 0;
}

static INLINE FastArray
FastArrayInitWithZoneAndCapacity(FastArray array, NSZone *zone, size_t capacity)
{
  array->zone = zone;
  array->count = 0;
  if (capacity < 1)
    capacity = 2;
  array->cap = capacity;
  array->old = capacity/2;
  array->ptr=(FastArrayItem*)NSZoneMalloc(zone,capacity*sizeof(FastArrayItem));
  return array;
}


