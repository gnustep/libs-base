/* Zone memory management. -*- Mode: ObjC -*-
   Copyright (C) 1997,1998,1999 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@laplace.snu.ac.kr>
   Date: January 1997

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */

#ifndef __NSZone_h_GNUSTEP_BASE_INCLUDE
#define __NSZone_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>

@class NSString;

typedef struct _NSZone NSZone;

/* The members are the same as the structure mstats which is in the
   GNU C library. */
struct NSZoneStats
{
  size_t bytes_total;
  size_t chunks_used;
  size_t bytes_used;
  size_t chunks_free;
  size_t bytes_free;
};

struct _NSZone
{
  /* Functions for zone. */
  void *(*malloc)(struct _NSZone *zone, size_t size);
  void *(*realloc)(struct _NSZone *zone, void *ptr, size_t size);
  void (*free)(struct _NSZone *zone, void *ptr);
  void (*recycle)(struct _NSZone *zone);
  BOOL (*check)(struct _NSZone *zone);
  BOOL (*lookup)(struct _NSZone *zone, void *ptr);
  struct NSZoneStats (*stats)(struct _NSZone *zone);
  
  size_t gran; // Zone granularity
  NSString *name; // Name of zone (default is 'nil')
  NSZone *next;
};

void *GSOutOfMemory(size_t size, BOOL retry);

/* Default zone.  Name is hopelessly long so that no one will ever
   want to use it. ;) Private variable. */
extern NSZone* __nszone_private_hidden_default_zone;

#ifndef	GS_WITH_GC
#define	GS_WITH_GC	0
#endif
#if	GS_WITH_GC

#include <gc.h>

extern NSZone* __nszone_private_hidden_atomic_zone;

#define
extern inline NSZone* NSCreateZone (size_t start, size_t gran, BOOL canFree)
{ return __nszone_private_hidden_default_zone; }

extern inline NSZone* NSDefaultMallocZone (void)
{ return __nszone_private_hidden_default_zone; }

extern inline NSZone* GSAtomicMallocZone (void)
{ return __nszone_private_hidden_atomict_zone; }

extern inline NSZone* NSZoneFromPointer (void *ptr)
{ return __nszone_private_hidden_default_zone; }

extern inline void* NSZoneMalloc (NSZone *zone, size_t size)
{
  void	*ptr;

  if (zone == GSAtomicMallocZone())
    *ptr = (void*)GC_MALLOC_ATOMIC(size);
  else
    *ptr = (void*)GC_MALLOC(size);

  if (ptr == 0)
    ptr = GSOutOfMemory(size, YES);
  return ptr;
}

extern inline void* NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes)
{
  size_t	size = elems * bytes;
  void		*ptr;

  if (zone == __nszone_private_hidden_atomic_zone)
    *ptr = (void*)GC_MALLOC_ATOMIC(size);
  else
    *ptr = (void*)GC_MALLOC(size);

  if (ptr == 0)
    ptr = GSOutOfMemory(size);
  memset(ptr, '\0', size);
  return ptr;
}

extern inline void* NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{
  ptr = GC_REALLOC(ptr, size);
  if (ptr == 0)
    GSOutOfMemory(size, NO);
  return ptr;
}

extern inline void NSRecycleZone (NSZone *zone)
{
}

extern inline void NSZoneFree (NSZone *zone, void *ptr)
{
  GC_FREE(ptr);
}

extern inline void NSSetZoneName (NSZone *zone, NSString *name)
{
}

extern inline NSString* NSZoneName (NSZone *zone)
{
  return nil;
}

#ifndef	NO_GNUSTEP

extern inline void* NSZoneMallocAtomic (NSZone *zone, size_t size)
{
  return NSZoneMalloc(GSAtomicmallocZone(), size);
}

extern inline BOOL NSZoneCheck (NSZone *zone)
{
  return YES;
}

extern inline struct NSZoneStats NSZoneStats (NSZone *zone)
{
  struct NSZoneStats stats = { 0 };
  return stats;
}
#endif

#else	/* GS_WITH_GC */

extern NSZone* NSCreateZone (size_t start, size_t gran, BOOL canFree);

extern inline NSZone* NSDefaultMallocZone (void)
{
  return __nszone_private_hidden_default_zone;
}

extern inline NSZone* GSAtomicMallocZone (void)
{
  return NSDefaultMallocZone();
}

extern NSZone* NSZoneFromPointer (void *ptr);

extern inline void* NSZoneMalloc (NSZone *zone, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->malloc)(zone, size);
}

extern void* NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes);

extern inline void* NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->realloc)(zone, ptr, size);
}

extern inline void NSRecycleZone (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  (zone->recycle)(zone);
}

extern inline void NSZoneFree (NSZone *zone, void *ptr)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  (zone->free)(zone, ptr);
}

extern void NSSetZoneName (NSZone *zone, NSString *name);

extern inline NSString* NSZoneName (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return zone->name;
}

#ifndef	NO_GNUSTEP
extern inline void* NSZoneMallocAtomic (NSZone *zone, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->malloc)(zone, size);
}

extern inline BOOL NSZoneCheck (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->check)(zone);
}

extern inline struct NSZoneStats NSZoneStats (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->stats)(zone);
}
#endif	/* NO_GNUSTEP */

#endif	/* GS_WITH_GC */

#endif /* not __NSZone_h_GNUSTEP_BASE_INCLUDE */
