/* Modular memory management.  Better living through chemicals.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Oct 13 23:46:02 EDT 1994
 * Updated: Sat Feb 10 15:47:25 EST 1996
 * Serial: 96.02.10.01
 * 
 * This file is part of the GNU Objective C Class Library.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 
 */ 

#ifndef __allocs_h_OBJECTS_INCLUDE
#define __allocs_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef void *(*objects_malloc_func_t) (size_t, const void *);
typedef void *(*objects_calloc_func_t) (size_t, size_t, const void *);
typedef void *(*objects_realloc_func_t) (void *, size_t, const void *);
typedef void (*objects_free_func_t) (void *, const void *);

typedef struct _objects_allocs objects_allocs_t;

struct _objects_allocs
  {
    objects_malloc_func_t malloc;
    objects_calloc_func_t calloc;
    objects_realloc_func_t realloc;
    objects_free_func_t free;
    const void *user_data;
  };

/* Shorthand macros. */
#define OBJECTS_MALLOC(S)      objects_malloc(objects_standard_allocs(), (S))
#define OBJECTS_CALLOC(N, S)   objects_calloc(objects_standard_allocs(), (N), (S))
#define OBJECTS_REALLOC(P, S)  objects_realloc(objects_standard_allocs(), (P), (S))
#define OBJECTS_FREE(P)        objects_free(objects_standard_allocs(), (P))

/* Change these if you need different default allocs. */
extern objects_allocs_t __objects_allocs_standard;

/**** Function Prototypes ****************************************************/

/* Returns `__objects_allocs_standard', defined above. */
objects_allocs_t
objects_allocs_standard (void);

void *
  objects_malloc (objects_allocs_t allocs, size_t s);

void *
  objects_calloc (objects_allocs_t allocs, size_t n, size_t s);

void *
  objects_realloc (objects_allocs_t allocs, const void *p, size_t s);

void
  objects_free (objects_allocs_t allocs, const void *p);

size_t
objects_next_power_of_two (size_t start);

#endif /* __allocs_h_OBJECTS_INCLUDE */
