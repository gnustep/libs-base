/* Callbacks for pointers to `int'.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSString.h>
#include <objects/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_AN_INT_P_MARKER (const void *)(-1)

const void *objects_not_an_int_p_marker = _OBJECTS_NOT_AN_INT_P_MARKER;

objects_callbacks_t objects_callbacks_for_int_p = 
{
  (objects_hash_func_t) objects_int_p_hash,
  (objects_compare_func_t) objects_int_p_compare,
  (objects_is_equal_func_t) objects_int_p_is_equal,
  (objects_retain_func_t) objects_int_p_retain,
  (objects_release_func_t) objects_int_p_release,
  (objects_describe_func_t) objects_int_p_describe,
  _OBJECTS_NOT_AN_INT_P_MARKER
};

/**** Function Implementations ***********************************************/

size_t
objects_int_p_hash(const int *iptr)
{
  return (size_t)(iptr) / 4;
}

int
objects_int_p_compare(const int *iptr, const int *jptr)
{
  if (iptr < jptr)
    return -1;
  else if (iptr > jptr)
    return 1;
  else /* (iptr == jptr) */
    return 0;
}

int
objects_int_p_is_equal(const int *iptr, const int *jptr)
{
  /* FIXME: Is this right?  If not, what else could it be? */
  return iptr == jptr;
}

const void *
objects_int_p_retain(const int *iptr)
{
  return (const void *)iptr;
}

void
objects_int_p_release(int *iptr)
{
  return;
}

NSString *
objects_int_p_describe(const int *iptr)
{
  /* FIXME: Code this. */
  return nil;
}


