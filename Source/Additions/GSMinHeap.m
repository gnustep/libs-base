/** Implementation for MSMinHeap

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: July 2026

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "common.h"

#import	"GNUstepBase/GSMinHeap.h"

typedef struct {
  id 			*data;
  size_t 		size;
  size_t 		capacity;
  GSMinHeapComparator	compare;
} MinHeapInternal;

#define	internal	((MinHeapInternal*)_internal)

static NSComparisonResult
GSMinHeapDefaultComparator(id a, id b)
{         
  return [a compare: b];
}

static BOOL
heap_resize(MinHeapInternal *h)
{
  size_t	want;
  id		*tmp;

  if (h->capacity * sizeof(id) > SIZE_MAX / 2)
    {
      return NO;
    }
  if (h->capacity > 1024 * 16)
    {
      want = h->capacity * 3 / 2;
    }
  else
    {
      want = h->capacity * 2;
    }
  tmp = NSZoneRealloc(NSDefaultMallocZone(), h->data, sizeof(id) * want);
  if (NULL == tmp)
    {
      return NO;
    }
  h->capacity = want;
  h->data = tmp;
  return YES;
}

static id
heap_pop(MinHeapInternal *h)
{
  id	result;

  if (0 == h->size)
    {
      return nil;
    }
  result = h->data[0];

  if (--h->size > 0)
    {
      id	value = h->data[h->size];
      size_t	i = 0;

      h->data[h->size] = nil;
      while (1)
	{
	  size_t	left = (i << 1) + 1;
	  size_t	right;
	  size_t	child;

	  if (left >= h->size)
	    {
	      break;
	    }
	  right = left + 1;
	  child = left;

	  if (right < h->size
	    && h->compare(h->data[right], h->data[left]) == NSOrderedAscending)
	    {
	      child = right;
	    }
	  if (h->compare(h->data[child], value) != NSOrderedAscending)
	    {
	      break;
	    }
	  h->data[i] = h->data[child];
	  i = child;
	}
      h->data[i] = value;
    }
  else
    {
      h->data[0] = nil;
    }

  return result;
}

static BOOL
heap_push(MinHeapInternal *h, id value)
{
  size_t	i;

  if (h->size == h->capacity)
    {
      if (NO == heap_resize(h))
	{
	  return NO;
	}
    }
  i = h->size++;
  
  while (i > 0)
    {
      size_t parent = (i - 1) / 2;

      if (h->compare(h->data[parent], value) != NSOrderedDescending)
	{
	  break;
	}
      h->data[i] = h->data[parent];
      i = parent;
    }
  h->data[i] = value;
  return YES;
}

static id
heap_remove(MinHeapInternal *h, size_t index)
{
  id	result;

  if (index >= h->size)
    {
      return nil;
    }

  result = h->data[index];

  if (--h->size == index)
    {
      /* Removed the last element. */
      h->data[index] = nil;
      return result;
    }
  else
    {
      id	value = h->data[h->size];
      size_t	i = index;

      h->data[h->size] = nil;

      /* First try moving the replacement upwards. */
      while (i > 0)
        {
          size_t parent = (i - 1) / 2;

          if (h->compare(h->data[parent], value) != NSOrderedDescending)
            {
              break;
            }
          h->data[i] = h->data[parent];
          i = parent;
        }

      if (i != index)
        {
          h->data[i] = value;
        }
      else
        {
          /* Didn't move up, so sift down instead. */
          while (1)
            {
              size_t	left = (i << 1) + 1;
              size_t	right;
              size_t	child;

              if (left >= h->size)
                {
                  break;
                }

              right = left + 1;
              child = left;

              if (right < h->size
                && h->compare(h->data[right], h->data[left]) == NSOrderedAscending)
                {
                  child = right;
                }

              if (h->compare(h->data[child], value) != NSOrderedAscending)
                {
                  break;
                }

              h->data[i] = h->data[child];
              i = child;
            }
          h->data[i] = value;
        }
    }

  return result;
}

@implementation	GSMinHeap

- (BOOL) containsObject: (id)obj
{
  size_t	index = internal->size;

  while (index-- > 0)
    {
      if ([obj isEqual: internal->data[index]])
        {
          return YES;
	}
    }
  return NO;
}

- (BOOL) containsObjectIdenticalTo: (id)obj
{
  size_t	index = internal->size;

  while (index-- > 0)
    {
      if (obj == internal->data[index])
        {
          return YES;
	}
    }
  return NO;
}

- (NSUInteger) count
{
  return internal->size;
}

- (void) dealloc
{
  if (_internal)
    {
      [self empty];
      free(internal->data);
      free(_internal);
    }
  DEALLOC
}

- (void) drop
{
  if (internal->size > 0)
    {
      RELEASE(heap_pop(internal));
    }
}

- (void) empty
{
  size_t	i;

  for (i = 0; i < internal->size; i++)
    {
      DESTROY(internal->data[i]);
    }
  internal->size = 0;
}

- (instancetype) init
{
  return [self initWithCapacity: 0 andComparator: NULL];
}

- (instancetype) initWithCapacity: (size_t)cap
		    andComparator: (GSMinHeapComparator)cmp
{
  if (nil != (self = [super init]))
    {
      _internal
	= NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(MinHeapInternal));
      if (NULL == _internal)
	{
	  DESTROY(self);
	  return nil;
	}
      internal->size = 0;
      if (cap < 1)
	{
	  cap = 1;
	}
      internal->capacity = cap;
      if (NULL == cmp)
	{
	  cmp = GSMinHeapDefaultComparator;
	}
      internal->compare = cmp;
      internal->data = NSZoneCalloc(NSDefaultMallocZone(), sizeof(id), cap);
      if (NULL == internal->data)
	{
	  DESTROY(self);
	  return nil;
	}
    }
  return self;
}

- (id) next
{
  if (internal->size > 0)
    {
      RELEASE(heap_pop(internal));
    }
  if (0 == internal->size)
    {
      return nil;
    }
  return internal->data[0];
}

- (id) peek
{
  if (0 == internal->size)
    {
      return nil;
    }
  return internal->data[0];
}

- (id) pop
{
  return AUTORELEASE(heap_pop(internal));
}

- (BOOL) push: (id)obj
{
  if (obj != nil)
    {
      if (heap_push(internal, obj))
	{
	  RETAIN(obj);
	  return YES;
	}
    }
  return NO;
}

- (BOOL) pushIfNotPresent: (id)obj
{
  if (obj != nil)
    {
      size_t	index = internal->size;

      while (index-- > 0)
	{
	  if (obj == internal->data[index])
	    {
	      return YES;
	    }
	}
      if (heap_push(internal, obj))
	{
	  RETAIN(obj);
	  return YES;
	}
    }
  return NO;
}

- (void) removeObject: (id)obj
{
  size_t	index = internal->size;

  while (index-- > 0)
    {
      if ([obj isEqual: internal->data[index]])
        {
          RELEASE(heap_remove(internal, index));
	}
    }
}

- (void) removeObjectIdenticalTo: (id)obj
{
  size_t	index = internal->size;

  while (index-- > 0)
    {
      if (obj == internal->data[index])
        {
          RELEASE(heap_remove(internal, index));
	}
    }
}

- (id) repositionObject: (id)obj
{
  size_t	index = internal->size;
  id		found = nil;

  while (index-- > 0)
    {
      if (obj == internal->data[index])
        {
	  if (nil == found)
	    {
              found = heap_remove(internal, index);
	    }
	  else
	    {
              RELEASE(heap_remove(internal, index));
	    }
	}
    }
  if (found)
    {
      heap_push(internal, found);
    }
  return found;
}

@end

