/* Memory allocation support for Objective-C: easy garbage collection.
   Copyright (C) 1993,1994, 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#define CHECK_ZERO_SIZE(S) if (size == 0) size = 1

void*
__objc_malloc(size_t size)
{
  CHECK_ZERO_SIZE(size);
  void* res = (void*) malloc(size);
  if(!res)
    objc_fatal("Virtual memory exhausted\n");
  return res;
}
 
void*
__objc_valloc(size_t size)
{
  CHECK_ZERO_SIZE(size);
  void* res = (void*) valloc(size);
  if(!res)
    objc_fatal("Virtual memory exhausted\n");
  return res;
}
 
void*
__objc_realloc(void* mem, size_t size)
{
  CHECK_ZERO_SIZE(size);
  void* res = (void*) realloc(mem, size);
  if(!res)
    objc_fatal("Virtual memory exhausted\n");
  return res;
}
 
void*
__objc_calloc(size_t nelem, size_t size)
{
  CHECK_ZERO_SIZE(size);
  void* res = (void*) calloc(nelem, size);
  if(!res)
    objc_fatal("Virtual memory exhausted\n");
  return res;
}

void
__objc_free (void* mem)
{
  free(mem);
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
