/* A fast inline array table implementation without objc method overhead.
 * Copyright (C) 1998,1999  Free Software Foundation, Inc.
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

/* To turn assertions on, comment out the following four lines */
#ifndef	NS_BLOCK_ASSERTIONS
#define	NS_BLOCK_ASSERTIONS	1
#define	FAST_ARRAY_BLOCKED_ASSERTIONS	1
#endif

#define	FAST_ARRAY_CHECK NSCAssert(array->count <= array->cap && array->old <= array->cap && array->old >= 1, NSInternalInconsistencyException)

/*
 This file should be INCLUDED in files wanting to use the FastArray
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
 *	The next two values can be defined in order to let us optimise
 *	even further when either retain or release operations are not needed.
 *
 *	FAST_ARRAY_NO_RELEASE
 *		Defined if no release operation is needed for an item
 *	FAST_ARRAY_NO_RETAIN
 *		Defined if no retain operation is needed for a an item
 */
#ifndef	FAST_ARRAY_RETAIN
#define	FAST_ARRAY_RETAIN(X)	[(X).obj retain]
#endif

#ifndef	FAST_ARRAY_RELEASE
#define	FAST_ARRAY_RELEASE(X)	[(X).obj release]
#endif

/*
 *	If there is no bitmask defined to supply the types that
 *	may be stored in the array, default to permitting all types.
 */
#ifndef	FAST_ARRAY_TYPES
#define	FAST_ARRAY_TYPES	GSUNION_ALL
#endif

/*
 *	Set up the name of the union to store array elements.
 */
#ifdef	GSUNION
#undef	GSUNION
#endif
#define	GSUNION	FastArrayItem

/*
 *	Set up the types that will be storable in the union.
 *	See 'GSUnion.h' for details.
 */
#ifdef	GSUNION_TYPES
#undef	GSUNION_TYPES
#endif
#define	GSUNION_TYPES	FAST_ARRAY_TYPES
#ifdef	GSUNION_EXTRA
#undef	GSUNION_EXTRA
#endif
#ifdef	FAST_ARRAY_EXTRA
#define	GSUNION_EXTRA	FAST_ARRAY_EXTRA
#endif

/*
 *	Generate the union typedef
 */
#include <base/GSUnion.h>

struct	_FastArray {
  FastArrayItem	*ptr;
  unsigned	count;
  unsigned	cap;
  unsigned	old;
  NSZone	*zone;
};
typedef	struct	_FastArray	FastArray_t;
typedef	struct	_FastArray	*FastArray;

static INLINE unsigned
FastArrayCount(FastArray array)
{
  return array->count;
}

static INLINE void
FastArrayGrow(FastArray array)
{
  unsigned	next;
  unsigned	size;
  FastArrayItem	*tmp;

  next = array->cap + array->old;
  size = next*sizeof(FastArrayItem);
#if	GS_WITH_GC
  tmp = (FastArrayItem*)GC_REALLOC(size);
#else
  tmp = NSZoneRealloc(array->zone, array->ptr, size);
#endif

  if (tmp == 0)
    {
      [NSException raise: NSMallocException
		  format: @"failed to grow FastArray"];
    }
  array->ptr = tmp;
  array->old = array->cap;
  array->cap = next;
}

static INLINE void
FastArrayInsertItem(FastArray array, FastArrayItem item, unsigned index)
{
  unsigned	i;

  FAST_ARRAY_RETAIN(item);
  FAST_ARRAY_CHECK;
  if (array->count == array->cap)
    {
      FastArrayGrow(array);
    }
  for (i = array->count++; i > index; i--)
    {
      array->ptr[i] = array->ptr[i-1];
    }
  array->ptr[i] = item;
  FAST_ARRAY_CHECK;
}

static INLINE void
FastArrayInsertItemNoRetain(FastArray array, FastArrayItem item, unsigned index)
{
  unsigned	i;

  FAST_ARRAY_CHECK;
  if (array->count == array->cap)
    {
      FastArrayGrow(array);
    }
  for (i = array->count++; i > index; i--)
    {
      array->ptr[i] = array->ptr[i-1];
    }
  array->ptr[i] = item;
  FAST_ARRAY_CHECK;
}

static INLINE void
FastArrayAddItem(FastArray array, FastArrayItem item)
{
  FAST_ARRAY_RETAIN(item);
  FAST_ARRAY_CHECK;
  if (array->count == array->cap)
    {
      FastArrayGrow(array);
    }
  array->ptr[array->count++] = item;
  FAST_ARRAY_CHECK;
}

static INLINE void
FastArrayAddItemNoRetain(FastArray array, FastArrayItem item)
{
  FAST_ARRAY_CHECK;
  if (array->count == array->cap)
    {
      FastArrayGrow(array);
    }
  array->ptr[array->count++] = item;
  FAST_ARRAY_CHECK;
}

/*
 *	The comparator function takes two items as arguments, the first is the
 *	item to be added, the second is the item already in the array.
 *	The function should return <0 if the item to be added is 'less than'
 *	the item in the array, >0 if it is greater, and 0 if it is equal.
 */
static INLINE unsigned
FastArrayInsertionPosition(FastArray array, FastArrayItem item, int (*sorter)())
{
  unsigned	upper = array->count;
  unsigned	lower = 0;
  unsigned	index;

  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      int	comparison = (*sorter)(item.obj, (array->ptr[index]).obj);

      if (comparison < 0)
	{
	  upper = index;
        }
      else if (comparison > 0)
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
  while (index < array->count && (*sorter)(item.obj, (array->ptr[index]).obj) >= 0)
    {
      index++;
    }
  NSCAssert(index <= array->count, NSInternalInconsistencyException);
  return index;
}

#ifndef	NS_BLOCK_ASSERTIONS
static INLINE void
FastArrayCheckSort(FastArray array, int (*sorter)())
{
  unsigned	i;

  for (i = 1; i < array->count; i++)
    {
      NSCAssert(((*sorter)((array->ptr[i-1]).obj, (array->ptr[i]).obj) <= 0),
	NSInvalidArgumentException);
    }
}
#endif

static INLINE void
FastArrayInsertSorted(FastArray array, FastArrayItem item, int (*sorter)())
{
  unsigned	index;

  index = FastArrayInsertionPosition(array, item, sorter);
  FastArrayInsertItem(array, item, index);
#ifndef	NS_BLOCK_ASSERTIONS
  FastArrayCheckSort(array, sorter);
#endif
}

static INLINE void
FastArrayInsertSortedNoRetain(FastArray array, FastArrayItem item, int (*sorter)())
{
  unsigned	index;

  index = FastArrayInsertionPosition(array, item, sorter);
  FastArrayInsertItemNoRetain(array, item, index);
#ifndef	NS_BLOCK_ASSERTIONS
  FastArrayCheckSort(array, sorter);
#endif
}

static INLINE void
FastArrayRemoveItemAtIndex(FastArray array, unsigned index)
{
  FastArrayItem	tmp;
  NSCAssert(index < array->count, NSInvalidArgumentException);
  tmp = array->ptr[index];
  while (++index < array->count)
    array->ptr[index-1] = array->ptr[index];
  array->count--;
  FAST_ARRAY_RELEASE(tmp);
}

static INLINE void
FastArrayRemoveItemAtIndexNoRelease(FastArray array, unsigned index)
{
  FastArrayItem	tmp;
  NSCAssert(index < array->count, NSInvalidArgumentException);
  tmp = array->ptr[index];
  while (++index < array->count)
    array->ptr[index-1] = array->ptr[index];
  array->count--;
}

static INLINE void
FastArraySetItemAtIndex(FastArray array, FastArrayItem item, unsigned index)
{
  FastArrayItem	tmp;
  NSCAssert(index < array->count, NSInvalidArgumentException);
  tmp = array->ptr[index];
  FAST_ARRAY_RETAIN(item);
  array->ptr[index] = item;
  FAST_ARRAY_RELEASE(tmp);
}

static INLINE FastArrayItem
FastArrayItemAtIndex(FastArray array, unsigned index)
{
  NSCAssert(index < array->count, NSInvalidArgumentException);
  return array->ptr[index];
}

static INLINE void
FastArrayClear(FastArray array)
{
  if (array->ptr)
    {
#if	GS_WITH_GC
      GC_FREE((void*)array->ptr);
#else
      NSZoneFree(array->zone, (void*)array->ptr);
#endif
      array->ptr = 0;
      array->cap = 0;
    }
}

static INLINE void
FastArrayEmpty(FastArray array)
{
#ifdef	FAST_ARRAY_NO_RELEASE
  array->count = 0;
#else
  while (array->count--)
    {
      FAST_ARRAY_RELEASE(array->ptr[array->count]);
    }
#endif
  FastArrayClear(array);
}

static INLINE FastArray
FastArrayInitWithZoneAndCapacity(FastArray array, NSZone *zone, size_t capacity)
{
  unsigned	size;

  array->zone = zone;
  array->count = 0;
  if (capacity < 2)
    capacity = 2;
  array->cap = capacity;
  array->old = capacity/2;
  size = capacity*sizeof(FastArrayItem);
#if	GS_WITH_GC
  /*
   *	If we use a nil zone, objects we point to are subject to GC
   */
  if (zone == 0)
    array->ptr = (FastArrayItem*)GC_MALLOC_ATOMIC(size);
  else
    array->ptr = (FastArrayitem)GC_MALLOC(zone, size);
#else
  array->ptr = (FastArrayItem*)NSZoneMalloc(zone, size);
#endif
  return array;
}

#ifdef	FAST_ARRAY_BLOCKED_ASSERTIONS
#undef	NS_BLOCK_ASSERTIONS
#undef	FAST_ARRAY_BLOCKED_ASSERTIONS
#endif

