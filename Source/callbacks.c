/* Handling various types in a uniform manner.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Oct  9 13:14:41 EDT 1994
 * Updated: Sun Feb 11 01:33:41 EST 1996
 * Serial: 96.02.10.07
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

#include <objects/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* WARNING: Don't change this unless you know what you're getting into! */
static objects_callbacks_t ___objects_callbacks_standard =
{
  (objects_hash_func_t) objects_void_p_hash,
  (objects_compare_func_t) objects_void_p_compare,
  (objects_is_equal_func_t) objects_void_p_is_equal,
  (objects_retain_func_t) objects_void_p_retain,
  (objects_release_func_t) objects_void_p_release,
  (objects_describe_func_t) objects_void_p_describe,
  0
};

/**** Function Implementations ***********************************************/

/** Getting the standard callbacks **/

objects_callbacks_t
objects_callbacks_standard(void)
{
  return ___objects_callbacks_standard;
}

/** Standardizing callbacks **/

objects_callbacks_t
objects_callbacks_standardize(objects_callbacks_t callbacks)
{
  if (callbacks.hash == 0)
    callbacks.hash = objects_callbacks_standard().hash;
  if (callbacks.compare == 0 && callbacks.is_equal == 0)
  {
    callbacks.compare = objects_callbacks_standard().compare;
    callbacks.is_equal = objects_callbacks_standard().is_equal;
  }
  if (callbacks.retain == 0)
    callbacks.retain = objects_callbacks_standard().retain;
  if (callbacks.release == 0)
    callbacks.release = objects_callbacks_standard().release;

  return callbacks;
}

/** Using callbacks **/

size_t
objects_hash (objects_callbacks_t callbacks, void *thing, void *user_data)
{
  if (callbacks.hash != 0)
    return callbacks.hash(thing, user_data);
  else
    return objects_callbacks_standard().hash(thing, user_data);
}

int
objects_compare (objects_callbacks_t callbacks,
		 void *thing1,
		 void *thing2,
		 void *user_data)
{
  if (callbacks.compare != 0)
    return callbacks.compare(thing1, thing2, user_data);
  else if (callbacks.is_equal != 0)
    return !(callbacks.is_equal(thing1, thing2, user_data));
  else
    return objects_callbacks_standard().compare(thing1, thing2, user_data);
}

int
objects_is_equal (objects_callbacks_t callbacks,
		  void *thing1,
		  void *thing2,
		  void *user_data)
{
  if (callbacks.is_equal != 0)
    return callbacks.is_equal(thing1, thing2, user_data);
  else if (callbacks.compare != 0)
    return !(callbacks.compare(thing1, thing2, user_data));
  else
    return objects_callbacks_standard().is_equal(thing1, thing2, user_data);
}

void *
objects_retain (objects_callbacks_t callbacks, void *thing, void *user_data)
{
  if (callbacks.retain != 0)
    return callbacks.retain(thing, user_data);
  else
    return objects_callbacks_standard().retain(thing, user_data);
}

void
objects_release (objects_callbacks_t callbacks, void *thing, void *user_data)
{
  if (callbacks.release != 0)
    callbacks.release(thing, user_data);
  else
    objects_callbacks_standard().release(thing, user_data);
  return;
}

void *
objects_describe(objects_callbacks_t callbacks, void *thing, void *user_data)
{
  if (callbacks.release != 0)
    return callbacks.describe(thing, user_data);
  else
    return objects_callbacks_standard().describe(thing, user_data);
}

