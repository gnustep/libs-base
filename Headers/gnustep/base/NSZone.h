/* Zone memory management. -*- Mode: ObjC -*-
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@power1.snu.ac.kr>
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

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
  struct NSZoneStats (*stats)(struct _NSZone *zone);
  
  size_t gran; // Zone granularity
  NSString *name; // Name of zone (default is 'nil')
};


/* Default zone.  Name is hopelessly long so that no one will ever
   want to use it. ;) Private variable. */
extern NSZone* __nszone_private_hidden_default_zone;


extern NSZone* NSCreateZone (size_t start, size_t gran, BOOL canFree);

extern inline NSZone* NSDefaultMallocZone (void)
{ return __nszone_private_hidden_default_zone; }

extern void NSSetDefaultMallocZone (NSZone *zone); // Not in OpenStep

extern inline NSZone* NSZoneFromPointer (void *ptr)
{ return *((NSZone**)ptr-1); }

extern inline void* NSZoneMalloc (NSZone *zone, size_t size)
{ return (zone->malloc)(zone, size); }

extern void* NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes);

extern inline void* NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{ return (zone->realloc)(zone, ptr, size); }

extern inline void NSRecycleZone (NSZone *zone)
{ (zone->recycle)(zone); }

extern inline void NSZoneFree (NSZone *zone, void *ptr)
{ (zone->free)(zone, ptr); }

extern void NSSetZoneName (NSZone *zone, NSString *name);

extern inline NSString* NSZoneName (NSZone *zone)
{ return zone->name; }

/* Not in OpenStep */
extern void* NSZoneRegisterChunk (NSZone *zone, void *chunk);

extern size_t NSZoneChunkOverhead (void); // Not in OpenStep

extern inline BOOL NSZoneCheck (NSZone *zone) // Not in OpenStep
{ return (zone->check)(zone); }

extern inline struct NSZoneStats NSZoneStats (NSZone *zone) // Not in OpenStep
{ return (zone->stats)(zone); }

#endif /* not __NSZone_h_GNUSTEP_BASE_INCLUDE */
