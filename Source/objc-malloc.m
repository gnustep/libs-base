/* Memory allocation support for Objective-C: easy garbage collection.
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

   This file is part of the Gnustep Base Library.

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
*/ 

#ifdef __STDC__
#include <stddef.h>
#else
#define size_t unsigned long
#endif

#ifdef HAVE_VALLOC
#include <stdlib.h>
#else
#define valloc  malloc
#endif

#include <Foundation/NSException.h>

#define CHECK_ZERO_SIZE(S) if (size == 0) size = 1

void*
__objc_malloc (size_t size)
{
  void* res;
  CHECK_ZERO_SIZE (size);
  res = (void*) malloc(size);
  if (!res)
    [NSException raise: MemoryExhaustedException
		 format: @"Virtual memory exhausted"];
  return res;
}
 
void*
__objc_valloc (size_t size)
{
  void* res;
  CHECK_ZERO_SIZE(size);
  res = (void*) valloc(size);
  if (!res)
    [NSException raise: MemoryExhaustedException
		 format: @"Virtual memory exhausted"];
  return res;
}
 
void*
__objc_realloc (void* mem, size_t size)
{
  void* res;
  CHECK_ZERO_SIZE(size);
  res = (void*) realloc (mem, size);
  if (!res)
    [NSException raise: MemoryExhaustedException
		 format: @"Virtual memory exhausted"];
  return res;
}
 
void*
__objc_calloc (size_t nelem, size_t size)
{
  void* res;
  CHECK_ZERO_SIZE(size);
  res = (void*) calloc(nelem, size);
  if (!res)
    [NSException raise: MemoryExhaustedException
		 format: @"Virtual memory exhausted"];
  return res;
}

void
__objc_free (void* mem)
{
  free (mem);
}

/* We should put
     *(void**)obj = 0xdeadface;
   into object_dispose(); */

/* I do this to make substituting Boehm's Garbage Collector easy. */
void *(*objc_malloc)(size_t size) = __objc_malloc;
void *(*objc_valloc)(size_t size) = __objc_valloc;
void *(*objc_atomic_malloc)(size_t) = __objc_malloc;
void *(*objc_realloc)(void *optr, size_t size) = __objc_realloc;
void *(*objc_calloc)(size_t nelem, size_t size) = __objc_calloc;
void (*objc_free)(void *optr) = __objc_free;

NSString *MemoryExhaustedException = @"MemoryExhaustedException";
