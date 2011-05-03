/** Zone memory management. -*- Mode: ObjC -*-
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

    AutogsdocSource:	NSZone.m
    AutogsdocSource:	NSPage.m

   */

#ifndef __NSZone_h_GNUSTEP_BASE_INCLUDE
#define __NSZone_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

/**
 * Primary structure representing an <code>NSZone</code>.  Technically it
 * consists of a set of function pointers for zone upkeep functions plus some
 * other things-
<example>
{
  // Functions for zone.
  void *(*malloc)(struct _NSZone *zone, size_t size);
  void *(*realloc)(struct _NSZone *zone, void *ptr, size_t size);
  void (*free)(struct _NSZone *zone, void *ptr);
  void (*recycle)(struct _NSZone *zone);
  BOOL (*check)(struct _NSZone *zone);
  BOOL (*lookup)(struct _NSZone *zone, void *ptr);

  // Zone statistics (not always maintained).
  struct NSZoneStats (*stats)(struct _NSZone *zone);
  
  size_t gran;    // Zone granularity (passed in on initialization)
  NSString *name; // Name of zone (default is 'nil')
  NSZone *next;   // Pointer used for internal management of multiple zones.
}</example>
 */
typedef struct _NSZone NSZone;

#import	<Foundation/NSObjCRuntime.h>

@class NSString;

#if	defined(__cplusplus)
extern "C" {
#endif


/**
 *  <code>NSZoneStats</code> is the structure returned by the NSZoneStats()
 *  function that summarizes the current usage of a zone.  It is similar to
 *  the structure <em>mstats</em> in the GNU C library.  It has 5 fields of
 *  type <code>size_t</code>-
 *  <deflist>
 *    <term><code>bytes_total</code></term>
 *    <desc>
 *    This is the total size of memory managed by the zone, in bytes.</desc>
 *    <term><code>chunks_used</code></term>
 *    <desc>This is the number of memory chunks in use in the zone.</desc>
 *    <term><code>bytes_used</code></term>
 *    <desc>This is the number of bytes in use.</desc>
 *    <term><code>chunks_free</code></term>
 *    <desc>This is the number of memory chunks that are not in use.</desc>
 *    <term><code>bytes_free</code></term>
 *    <desc>
 *    This is the number of bytes managed by the zone that are not in use.
 *    </desc>
 *  </deflist>
 */
struct NSZoneStats
{
  size_t bytes_total;
  size_t chunks_used;
  size_t bytes_used;
  size_t chunks_free;
  size_t bytes_free;
};

/**
 * Primary structure representing an <code>NSZone</code>.  Technically it
 * consists of a set of function pointers for zone upkeep functions plus some
 * other things-
<example>
{
  // Functions for zone.
  void *(*malloc)(struct _NSZone *zone, size_t size);
  void *(*realloc)(struct _NSZone *zone, void *ptr, size_t size);
  void (*free)(struct _NSZone *zone, void *ptr);
  void (*recycle)(struct _NSZone *zone);
  BOOL (*check)(struct _NSZone *zone);
  BOOL (*lookup)(struct _NSZone *zone, void *ptr);

  // Zone statistics (not always maintained).
  struct NSZoneStats (*stats)(struct _NSZone *zone);
  
  size_t gran;    // Zone granularity (passed in on initialization)
  NSString *name; // Name of zone (default is 'nil')
  NSZone *next;   // Pointer used for internal management of multiple zones.
}</example>
*/
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

/**
 * Try to get more memory - the normal process has failed.
 * If we can't do anything, just return a null pointer.
 * Try to do some logging if possible.
 */
void *GSOutOfMemory(size_t size, BOOL retry);

#ifdef	IN_NSZONE_M
#define	GS_ZONE_SCOPE	extern
#define GS_ZONE_ATTR	
#else
#define	GS_ZONE_SCOPE	static inline
#define GS_ZONE_ATTR	__attribute__((unused))
#endif

/* Default zone.  Name is hopelessly long so that no one will ever
   want to use it. ;) Private variable. */
GS_EXPORT NSZone* __nszone_private_hidden_default_zone;

#ifndef	GS_WITH_GC
#define	GS_WITH_GC	0
#endif
#if	GS_WITH_GC

#include <gc.h>

GS_EXPORT NSZone* __nszone_private_hidden_atomic_zone;

GS_ZONE_SCOPE NSZone* NSCreateZone (size_t start, size_t gran, BOOL canFree)
{ return __nszone_private_hidden_default_zone; }

GS_ZONE_SCOPE NSZone* NSDefaultMallocZone (void)
{ return __nszone_private_hidden_default_zone; }

GS_ZONE_SCOPE NSZone* GSAtomicMallocZone (void)
{ return __nszone_private_hidden_atomic_zone; }

GS_ZONE_SCOPE NSZone* NSZoneFromPointer (void *ptr)
{ return __nszone_private_hidden_default_zone; }

/**
 *  Allocates and returns memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
GS_ZONE_SCOPE void* NSZoneMalloc (NSZone *zone, size_t size)
{
  void	*ptr;

  if (zone == GSAtomicMallocZone())
    ptr = (void*)GC_MALLOC_ATOMIC(size);
  else
    ptr = (void*)GC_MALLOC(size);

  if (ptr == 0)
    ptr = GSOutOfMemory(size, YES);
  return ptr;
}

/**
 *  Allocates and returns cleared memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
GS_ZONE_SCOPE void* NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes)
{
  size_t	size = elems * bytes;
  void		*ptr;

  if (zone == __nszone_private_hidden_atomic_zone)
    ptr = (void*)GC_MALLOC_ATOMIC(size);
  else
    ptr = (void*)GC_MALLOC(size);

  if (ptr == 0)
    ptr = GSOutOfMemory(size, NO);
  memset(ptr, '\0', size);
  return ptr;
}

GS_ZONE_SCOPE void* NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{
  ptr = GC_REALLOC(ptr, size);
  if (ptr == 0)
    GSOutOfMemory(size, NO);
  return ptr;
}

GS_ZONE_SCOPE void NSRecycleZone (NSZone *zone)
{
}

GS_ZONE_SCOPE void NSZoneFree (NSZone *zone, void *ptr)
{
  GC_FREE(ptr);
}

/**
 * Sets name of the given zone (useful for debugging and logging).
 */
GS_ZONE_SCOPE void NSSetZoneName (NSZone *zone, NSString *name)
{
}

/**
 * Sets name of the given zone (useful for debugging and logging).
 */
GS_ZONE_SCOPE NSString* NSZoneName (NSZone *zone)
{
  return nil;
}

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 * Allocates mmemory of size bytes from zone, with the assumption that the
 * memory will never contain pointers.  This is only relevant in situations
 * where a form of garbage collection is enabled, and NSZoneMalloc() should
 * always be used otherwise.  Not defined by OpenStep or OS X.
 */
GS_ZONE_SCOPE void* NSZoneMallocAtomic (NSZone *zone, size_t size)
{
  return NSZoneMalloc(GSAtomicMallocZone(), size);
}

GS_ZONE_SCOPE BOOL NSZoneCheck (NSZone *zone)
{
  return YES;
}

GS_ZONE_SCOPE struct NSZoneStats NSZoneStats (NSZone *zone)
{
  struct NSZoneStats stats = { 0 };
  return stats;
}
#endif

#else	/* GS_WITH_GC */

GS_EXPORT NSZone* NSCreateZone (size_t start, size_t gran, BOOL canFree);

GS_ZONE_SCOPE NSZone* NSDefaultMallocZone (void) GS_ZONE_ATTR;

/**
 * Returns the default zone used for memory allocation, created at startup.
 * This zone cannot be recycled.
 */
GS_ZONE_SCOPE NSZone* NSDefaultMallocZone (void)
{
  return __nszone_private_hidden_default_zone;
}

GS_ZONE_SCOPE NSZone* GSAtomicMallocZone (void) GS_ZONE_ATTR;

/**
 * Returns the default zone used for atomic memory allocation (see
 * NSMallocAtomic()), if no zone is specified.
 */
GS_ZONE_SCOPE NSZone* GSAtomicMallocZone (void)
{
  return NSDefaultMallocZone();
}

GS_EXPORT NSZone* NSZoneFromPointer (void *ptr);

GS_ZONE_SCOPE void* NSZoneMalloc (NSZone *zone, size_t size) GS_ZONE_ATTR;

/**
 *  Allocates and returns cleared memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
GS_ZONE_SCOPE void* NSZoneMalloc (NSZone *zone, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->malloc)(zone, size);
}

/**
 *  Allocates and returns cleared memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
GS_EXPORT void* NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes);

GS_ZONE_SCOPE void* 
NSZoneRealloc (NSZone *zone, void *ptr, size_t size) GS_ZONE_ATTR;

/**
 *  Reallocates the chunk of memory in zone pointed to by ptr to a new one of
 *  size bytes.  Existing contents in ptr are copied over.  Raises an
 *  <code>NSMallocException</code> if insufficient memory is available in the
 *  zone and no more memory can be obtained from the system, unless using the
 *  default zone, in which case NULL is returned.
 */
GS_ZONE_SCOPE void* NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->realloc)(zone, ptr, size);
}

GS_ZONE_SCOPE void NSRecycleZone (NSZone *zone) GS_ZONE_ATTR;

/**
 * Return memory for an entire zone to system.  In fact, this will not be done
 * unless all memory in the zone has been explicitly freed (by calls to
 * NSZoneFree()).  For "non-freeable" zones, the number of NSZoneFree() calls
 * must simply equal the number of allocation calls.  The default zone, on the
 * other hand, cannot be recycled.
 */
GS_ZONE_SCOPE void NSRecycleZone (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  (zone->recycle)(zone);
}

GS_ZONE_SCOPE void NSZoneFree (NSZone *zone, void *ptr) GS_ZONE_ATTR;

/**
 * Frees memory pointed to by ptr (which should have been allocated by a
 * previous call to NSZoneMalloc(), NSZoneCalloc(), or NSZoneRealloc()) and
 * returns it to zone.  Note, if this is a nonfreeable zone, the memory is
 * not actually freed, but the count of number of free()s is updated.
 */
GS_ZONE_SCOPE void NSZoneFree (NSZone *zone, void *ptr)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  (zone->free)(zone, ptr);
}

GS_EXPORT void NSSetZoneName (NSZone *zone, NSString *name);

GS_ZONE_SCOPE NSString* NSZoneName (NSZone *zone) GS_ZONE_ATTR;

/**
 * Returns the name assigned to the zone, if one has been given (see
 * NSSetZoneName()), otherwise nil.  Useful for debugging/logging.
 */
GS_ZONE_SCOPE NSString* NSZoneName (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return zone->name;
}

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
GS_ZONE_SCOPE void* 
NSZoneMallocAtomic (NSZone *zone, size_t size) GS_ZONE_ATTR;

/**
 * Allocates memory of size bytes from zone, with the assumption that the
 * memory will never contain pointers.  This is only relevant in situations
 * where a form of garbage collection is enabled, and NSZoneMalloc() should
 * always be used otherwise.  Not defined by OpenStep or OS X.
 */
GS_ZONE_SCOPE void* NSZoneMallocAtomic (NSZone *zone, size_t size)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->malloc)(zone, size);
}

GS_ZONE_SCOPE BOOL NSZoneCheck (NSZone *zone) GS_ZONE_ATTR;

/**
 * Checks integrity of a zone.  Not defined by OpenStep or OS X.
 */
GS_ZONE_SCOPE BOOL NSZoneCheck (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->check)(zone);
}

GS_ZONE_SCOPE struct NSZoneStats NSZoneStats (NSZone *zone) GS_ZONE_ATTR;

/**
 *  Obtain statistics about the zone.  Implementation emphasis is on
 *  correctness, not speed.  Not defined by OpenStep or OS X.
 */
GS_ZONE_SCOPE struct NSZoneStats NSZoneStats (NSZone *zone)
{
  if (!zone)
    zone = NSDefaultMallocZone();
  return (zone->stats)(zone);
}
#endif	/* GS_API_NONE */

#endif	/* GS_WITH_GC */


GS_EXPORT unsigned NSPageSize (void) __attribute__ ((const));

GS_EXPORT unsigned NSLogPageSize (void) __attribute__ ((const));

GS_EXPORT unsigned NSRoundDownToMultipleOfPageSize (unsigned bytes)
  __attribute__ ((const));

GS_EXPORT unsigned NSRoundUpToMultipleOfPageSize (unsigned bytes)
  __attribute__ ((const));

GS_EXPORT unsigned NSRealMemoryAvailable (void);

GS_EXPORT void* NSAllocateMemoryPages (unsigned bytes);

GS_EXPORT void NSDeallocateMemoryPages (void *ptr, unsigned bytes);

GS_EXPORT void NSCopyMemoryPages (const void *src, void *dest, unsigned bytes);

#if	defined(__cplusplus)
}
#endif

#endif /* not __NSZone_h_GNUSTEP_BASE_INCLUDE */
