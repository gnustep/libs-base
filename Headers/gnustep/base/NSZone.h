/* NSZone memory management.
   Copyright (C) 1994 NeXT Computer, Inc.
 
   This file is part of the GNU Objective C Class Library.

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

#ifndef h_zone_NS_h
#define h_zone_NS_h

#ifdef __NeXT__
#import <objc/zone.h>
#define NSZone NXZone
#else
#include <stdio.h>
#include <stdlib.h>

/*
 * This the NeXTStep zone typedef.   It is nothing like the implementation
 * below.
 */
/*
typedef struct _NSZone {
    void *(*realloc)(struct _NSZone *zonep, void *ptr, size_t size);
    void *(*malloc)(struct _NSZone *zonep, size_t size);
    void (*free)(struct _NSZone *zonep, void *ptr);
    void (*destroy)(struct _NSZone *zonep);
} NSZone;
*/

#define MAXZONENAMELENGTH 20

typedef struct _llist {
    int Count,Size;
    int ElementSize;
    void *LList;
} llist;

typedef struct _NSZone {
    void *base;
    size_t size;
    size_t granularity;
    int canFree;
    char name[MAXZONENAMELENGTH+1];
    llist heap;
    struct _NSZone *parent;
} NSZone;

/* 
 * try to find the page size.   If these fail on your system,
 * consider some other methods used by Emacs.   See the file
 * getpagesize.h of the Emacs source code
 */
#ifndef vm_page_size
# include <unistd.h>
# ifdef _SC_PAGESIZE
#  define vm_page_size sysconf(_SC_PAGESIZE)
# else
#  ifdef _SC_PAGE_SIZE
#   define vm_page_size sysconf(_SC_PAGE_SIZE)
#  else
/* #   ifndef HAVE_LIBC_H */
/* suggested change by Gregor Hoffleit <flight@mathi.uni-heidelberg.DE> */
#   if !defined(HAVE_LIBC_H) && !defined(linux)
     int getpagesize(void);
#   endif /* not HAVE_LIBC_H */
#   define vm_page_size getpagesize()
#  endif /* _SC_PAGE_SIZE */
# endif /* _SC_PAGESIZE */
#endif /* vm_page_size */

#define NS_NOZONE  ((NSZone *)0)

/*
 * Returns the default zone used by the malloc(3) calls.
 */
extern NSZone *NSDefaultMallocZone(void);

/* 
 * Create a new zone with its own memory pool.
 * If canfree is 0 the allocator will never free memory and mallocing will be fast
 */
extern NSZone *NSCreateZone(size_t startSize, size_t granularity, int canFree);

/*
 * Create a new zone who obtains memory from another zone.
 * Returns NS_NOZONE if the passed zone is already a child.
 */
extern NSZone  *NSCreateChildZone(NSZone *parentZone, size_t startSize,
                                  size_t granularity, int canFree);

/*
 * The zone is destroyed and all memory reclaimed.
 */
extern void NSDestroyZone(NSZone *zonep);
        
/*
 * Will merge zone with the parent zone. Malloced areas are still valid.
 * Must be an child zone.
 */
extern void NSMergeZone(NSZone *zonep);

extern void *NSZoneMalloc(NSZone *zonep, size_t size);

extern void *NSZoneRealloc(NSZone *zonep, void *ptr, size_t size);
extern void NSZoneFree(NSZone *zonep, void *ptr);

/*
 * Calls NSZoneMalloc and then bzero.
 */
extern void *NSZoneCalloc(NSZone *zonep, size_t numElems, size_t byteSize);

/*
 * Returns the zone for a pointer.
 * NS_NOZONE if not in any zone.
 * The ptr must have been returned from a malloc or realloc call.
 */
extern NSZone *NSZoneFromPtr(void *ptr);

/*
 * Debugging Helpers.
 */
 
 /*  
  * Will print to stdout if this pointer is in the malloc heap, free status, and size.
  */
extern void NSZonePtrInfo(void *ptr);

/*
 * Will verify all internal malloc information.
 * This is what malloc_debug calls.
 */
extern int NSMallocCheck(void);

/*
 * Give a zone a name.
 *
 * The string will be copied.
 */
extern void NSNameZone(NSZone *z, const char *name);

#endif /* __NeXT__ */
#endif /* h_zone_NS_h */
