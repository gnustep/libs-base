/* Callbacks for pointers to `int' and (maybe) structures whose first
 * field is an `int'.  Maybe.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Sun Feb 11 01:49:55 EST 1996
 * Serial: 96.02.11.04
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

#include <stdlib.h>
#include <objects/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

objects_callbacks_t objects_callbacks_for_int_p = 
{
  (objects_hash_func_t) objects_int_p_hash,
  (objects_compare_func_t) objects_int_p_compare,
  (objects_is_equal_func_t) objects_int_p_is_equal,
  (objects_retain_func_t) objects_int_p_retain,
  (objects_release_func_t) objects_int_p_release,
  (objects_describe_func_t) objects_int_p_describe,
  0
};

/**** Function Implementations ***********************************************/

size_t
objects_int_p_hash(void *iptr)
{
  return (size_t)(*((int *)iptr));
}

/* FIXME: Are these next two correct?  These seem rather useless to me. */

int
objects_int_p_compare(void *iptr, void *jptr)
{
  return *((int *)iptr) - *((int *)jptr);
}

int
objects_int_p_is_equal(void *iptr, void *jptr)
{
  return *((int *)iptr) == *((int *)jptr);
}

void *
objects_int_p_retain(void *iptr)
{
  return iptr;
}

void
objects_int_p_release(void *iptr)
{
  return;
}

void *
objects_int_p_describe(void *iptr)
{
  /* FIXME: Code this. */
  return 0;
}


