/* Handling various types in a uniform manner.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Oct  9 13:14:41 EDT 1994
 * Updated: Mon Mar 11 02:17:32 EST 1996
 * Serial: 96.03.11.08
 * 
 * This file is part of the GNUstep Base Library.
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

#include <Foundation/NSString.h>
#include <gnustep/base/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* WARNING: Don't change this unless you know what you're getting into! */
static o_callbacks_t ___o_callbacks_standard =
{
  (o_hash_func_t) o_non_owned_void_p_hash,
  (o_compare_func_t) o_non_owned_void_p_compare,
  (o_is_equal_func_t) o_non_owned_void_p_is_equal,
  (o_retain_func_t) o_non_owned_void_p_retain,
  (o_release_func_t) o_non_owned_void_p_release,
  (o_describe_func_t) o_non_owned_void_p_describe,
  0
};

/**** Function Implementations ***********************************************/

/** Getting the standard callbacks... **/

o_callbacks_t
o_callbacks_standard(void)
{
  return ___o_callbacks_standard;
}

/** Standardizing callbacks... **/

o_callbacks_t
o_callbacks_standardize(o_callbacks_t callbacks)
{
  if (callbacks.hash == 0)
    callbacks.hash = o_callbacks_standard().hash;

  if (callbacks.compare == 0 && callbacks.is_equal == 0)
  {
    callbacks.compare = o_callbacks_standard().compare;
    callbacks.is_equal = o_callbacks_standard().is_equal;
  }

  if (callbacks.retain == 0)
    callbacks.retain = o_callbacks_standard().retain;

  if (callbacks.release == 0)
    callbacks.release = o_callbacks_standard().release;

  return callbacks;
}

/** Using callbacks... **/

size_t
o_hash(o_callbacks_t callbacks, 
             const void *thing,
             void *user_data)
{
  if (callbacks.hash != 0)
    return callbacks.hash(thing, user_data);
  else
    return o_callbacks_standard().hash(thing, user_data);
}

int
o_compare(o_callbacks_t callbacks,
                const void *thing1,
                const void *thing2,
                void *user_data)
{
  if (callbacks.compare != 0)
    return callbacks.compare(thing1, thing2, user_data);
  else if (callbacks.is_equal != 0)
    return !(callbacks.is_equal(thing1, thing2, user_data));
  else
    return o_callbacks_standard().compare(thing1, thing2, user_data);
}

int
o_is_equal(o_callbacks_t callbacks,
                 const void *thing1,
                 const void *thing2,
                 void *user_data)
{
  if (callbacks.is_equal != 0)
    return callbacks.is_equal(thing1, thing2, user_data);
  else if (callbacks.compare != 0)
    return !(callbacks.compare(thing1, thing2, user_data));
  else
    return o_callbacks_standard().is_equal(thing1, thing2, user_data);
}

const void *
o_retain(o_callbacks_t callbacks, 
               const void *thing,
               void *user_data)
{
  if (callbacks.retain != 0)
    return callbacks.retain(thing, user_data);
  else
    return o_callbacks_standard().retain(thing, user_data);
}

void
o_release(o_callbacks_t callbacks, 
		void *thing,
                void *user_data)
{
  if (callbacks.release != 0)
    callbacks.release (thing, user_data);
  else
    o_callbacks_standard().release(thing, user_data);
  return;
}

NSString *
o_describe(o_callbacks_t callbacks, 
		 const void *thing,
                 void *user_data)
{
  if (callbacks.release != 0)
    return callbacks.describe(thing, user_data);
  else
    return o_callbacks_standard().describe(thing, user_data);
}

