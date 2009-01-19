/** Zone memory management. -*- Mode: ObjC -*-
   Copyright (C) 1997,1998,1999 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@laplace.snu.ac.kr>
   Date: January 1997

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
void*
GSOutOfMemory(size_t size, BOOL retry);

NSZone*
NSCreateZone (size_t start, size_t gran, BOOL canFree);

NSZone*
NSDefaultMallocZone (void);

/**
 * Returns the default zone used for memory allocation, created at startup.
 * This zone cannot be recycled.
 */
NSZone*
GSAtomicMallocZone (void);

/**
 * Returns the default zone used for scanned memory allocation ... a
 * garbage collectable chunk of memory which is scanned for pointers.
 */
NSZone*
GSScannedMallocZone (void);

NSZone*
NSZoneFromPointer (void *ptr);

/**
 *  Allocates and returns memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
void*
NSZoneMalloc (NSZone *zone, size_t size);

/**
 *  Allocates and returns cleared memory for elems items of size bytes, in the
 *  given zone.  Returns NULL if allocation of size 0 requested.  Raises
 *  <code>NSMallocException</code> if not enough free memory in zone to
 *  allocate and no more can be obtained from system, unless using the
 *  default zone, in which case NULL is returned.
 */
void*
NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes);

/**
 *  Reallocates the chunk of memory in zone pointed to by ptr to a new one of
 *  size bytes.  Existing contents in ptr are copied over.  Raises an
 *  <code>NSMallocException</code> if insufficient memory is available in the
 *  zone and no more memory can be obtained from the system, unless using the
 *  default zone, in which case NULL is returned.
 */
void*
NSZoneRealloc (NSZone *zone, void *ptr, size_t size);

/**
 * Return memory for an entire zone to system.  In fact, this will not be done
 * unless all memory in the zone has been explicitly freed (by calls to
 * NSZoneFree()).  For "non-freeable" zones, the number of NSZoneFree() calls
 * must simply equal the number of allocation calls.  The default zone, on the
 * other hand, cannot be recycled.
 */
void
NSRecycleZone (NSZone *zone);

/**
 * Frees memory pointed to by ptr (which should have been allocated by a
 * previous call to NSZoneMalloc(), NSZoneCalloc(), or NSZoneRealloc()) and
 * returns it to zone.  Note, if this is a nonfreeable zone, the memory is
 * not actually freed, but the count of number of free()s is updated.
 */
void
NSZoneFree (NSZone *zone, void *ptr);

/**
 * Sets name of the given zone (useful for debugging and logging).
 */
void
NSSetZoneName (NSZone *zone, NSString *name);

/**
 * Sets name of the given zone (useful for debugging and logging).
 */
NSString*
NSZoneName (NSZone *zone);

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 * Checks integrity of a zone.  Not defined by OpenStep or OS X.
 */
BOOL
NSZoneCheck (NSZone *zone);

/**
 *  Obtain statistics about the zone.  Implementation emphasis is on
 *  correctness, not speed.  Not defined by OpenStep or OS X.
 */
struct NSZoneStats
NSZoneStats (NSZone *zone);

#endif

GS_EXPORT NSUInteger
NSPageSize (void) __attribute__ ((const));

GS_EXPORT NSUInteger
NSLogPageSize (void) __attribute__ ((const));

GS_EXPORT NSUInteger
NSRoundDownToMultipleOfPageSize (NSUInteger bytes) __attribute__ ((const));

GS_EXPORT NSUInteger
NSRoundUpToMultipleOfPageSize (NSUInteger bytes) __attribute__ ((const));

GS_EXPORT NSUInteger
NSRealMemoryAvailable (void);

GS_EXPORT void*
NSAllocateMemoryPages (NSUInteger bytes);

GS_EXPORT void
NSDeallocateMemoryPages (void *ptr, NSUInteger bytes);

GS_EXPORT void
NSCopyMemoryPages (const void *src, void *dest, NSUInteger bytes);

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, OS_API_LATEST)

enum {
  NSScannedOption = (1<<0),
  NSCollectorDisabledOption = (1<<1),
};

/** Allocate memory.  If garbage collection is not enabled this uses the
 * default malloc zone and the options are ignored.<br />
 * If garbage collection is enabled, the allocate memory is normally not
 * scanned for pointers but is isttself garbage collectable.  The options
 * argument is a bitmask in which NSScannedOption sets the memory to be
 * scanned for pointers by the garbage collector, and
 * NSCollectorDisabledOption causes the memory to be excempt from being
 * garbage collected itsself.
 */
GS_EXPORT void *
NSAllocateCollectable(NSUInteger size, NSUInteger options);

/** Reallocate memory to be of a different size and/or to have different
 * options settings.  The behavior of options is as for
 * the NSAllocateCollectable() function.
 */ 
GS_EXPORT void *
NSReallocateCollectable(void *ptr, NSUInteger size, NSUInteger options);

#endif

#if	defined(__cplusplus)
}
#endif

#endif /* not __NSZone_h_GNUSTEP_BASE_INCLUDE */
