/* Modular memory management through structures.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Oct 13 23:45:49 EDT 1994
 * Updated: Sat Feb 10 15:19:32 EST 1996
 * Serial: 96.02.10.03
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

/**** Included Headers *******************************************************/

#include <objects/allocs.h>

/**** Type, Constant, and Macro Definitions **********************************/

static objects_allocs_t __objects_allocs_standard =
{
  (objects_malloc_func_t) malloc,
  (objects_calloc_func_t) calloc,
  (objects_realloc_func_t) realloc,
  (objects_free_func_t) free,
  (void *) 0
};

/**** Function Implementations ***********************************************/

objects_allocs_t
objects_allocs_standard (void)
{
  return __objects_allocs_standard;
}

void *
objects_malloc (objects_allocs_t allocs, size_t s)
{
  return (*(allocs.malloc)) (s, allocs.user_data);
}

void *
objects_calloc (objects_allocs_t allocs, size_t n, size_t s)
{
  return (*(allocs.calloc)) (n, s, allocs.user_data);
}

void *
objects_realloc (objects_allocs_t allocs, void *p, size_t s)
{
  return (*(allocs.realloc)) (p, s, allocs.user_data);
}

void
objects_free (objects_allocs_t allocs, void *p)
{
  (*(allocs.free)) (p, allocs.user_data);
  return;
}

size_t
objects_next_power_of_two (size_t beat)
{
  size_t start = 1;
  while ((start <= beat) && (start <<= 1));
  return start;
}
