/* NSZone memory management.
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@power1.snu.ac.kr>
   Date: September 1996
   
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

   See NSZone.c for additional information. */
  
#ifndef __NSZone_h_GNUSTEP_BASE_INCLUDE
#define __NSZone_h_GNUSTEP_BASE_INCLUDE

#include <objc/thr.h>
#include <gnustep/base/config.h>

@class NSString;

typedef objc_mutex_t ZoneLock;
typedef struct _NSZone NSZone;

struct _NSZone
{
  unsigned granularity;
  void *(*malloc)(struct _NSZone *zonep, unsigned size);
  void *(*realloc)(struct _NSZone *zonep, void *ptr, unsigned size);
  void (*free)(struct _NSZone *zonep, void *ptr);
  void (*recycle)(struct _NSZone *zonep);
  ZoneLock lock;
  NSString *name;
  void *table, *bblocks;
  void *sblocks; /* Block with highest address comes first. */
};

/* Create a new zone with its own memory pool.
   The library will automatically set the start size and/or the
   granularity if STARTSIZE and/or GRANULARITY are zero. Also, there
   is no advantage in setting startSize or granularity to multiples of
   NSPageSize(). */
extern NSZone*
NSCreateZone(unsigned startSize, unsigned granularity, BOOL canFree);

extern NSZone *NSDefaultMallocZone(void);

extern NSZone *NSZoneFromPointer(void *pointer);

extern inline void *NSZoneMalloc(NSZone *zone, unsigned size)
{
  return (zone->malloc)(zone, size);
}

extern void *NSZoneCalloc(NSZone *zone, unsigned numElems, unsigned numBytes);

extern inline void *NSZoneRealloc(NSZone *zone, void *pointer, unsigned size)
{
  return (zone->realloc)(zone, pointer, size);
}

/* For a non-freeable zone, ALL memory will be returned, regardless
   of whether there are objects in it that are still in use. */
extern inline void NSRecycleZone(NSZone *zone)
{
  (zone->recycle)(zone);
}

/* Will do nothing if pointer == NULL. */
extern inline void NSZoneFree(NSZone *zone, void *pointer)
{
  (zone->free)(zone, pointer);
}

extern void NSSetZoneName (NSZone *zone, NSString *name);

extern NSString *NSZoneName (NSZone *zone);

/* Debugging Helpers. */
 
/* Will print to stdout if this pointer is in the malloc heap, free
   status, and size. */
extern void NSZonePtrInfo(void *ptr);

/* Will verify all internal malloc information.
   This is what malloc_debug calls. */
extern BOOL NSMallocCheck(void);

/* Memory-Page-related functions. */

extern unsigned NSPageSize(void);
extern unsigned NSLogPageSize(void);
extern unsigned NSRoundUpToMultipleOfPageSize(unsigned bytes);
extern unsigned NSRoundDownToMultipleOfPageSize(unsigned bytes);

extern unsigned NSRealMemoryAvailable(void);

extern void *NSAllocateMemoryPages(unsigned bytes);
extern void NSDeallocateMemoryPages(void *ptr, unsigned bytes);
extern void NSCopyMemoryPages(const void *source, void *dest, unsigned bytes);

#endif /* __NSZone_h_GNUSTEP_BASE_INCLUDE */
