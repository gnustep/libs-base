/* Callbacks for `int' (and smaller) things.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Sun Feb 11 01:47:14 EST 1996
 * Serial: 96.02.11.03
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

objects_callbacks_t objects_callbacks_for_int = 
{
  (objects_hash_func_t) objects_int_hash,
  (objects_compare_func_t) objects_int_compare,
  (objects_is_equal_func_t) objects_int_is_equal,
  (objects_retain_func_t) objects_int_retain,
  (objects_release_func_t) objects_int_release,
  (objects_describe_func_t) objects_int_describe,
  0
};

/**** Function Implementations ***********************************************/

size_t
objects_int_hash(void *i)
{
  return (size_t)((int)i);
}

int
objects_int_compare(void *i, void *j)
{
  return ((int)i) - ((int)j);
}

int
objects_int_is_equal(void *i, void *j)
{
  return ((int)i) == ((int)j);
}

void *
objects_int_retain(void *i)
{
  return i;
}

void
object_int_release(void *i)
{
  return;
}

void *
objects_int_describe(void *i)
{
  /* FIXME: Code this. */
  return 0;
}


