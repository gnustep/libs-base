/* Callbacks for the Objective-C object type.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Sun Feb 11 01:42:20 EST 1996
 * Serial: 96.02.11.05
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
#include <objects/stdobjects.h>

/**** Type, Constant, and Macro Definitions **********************************/

objects_callbacks_t objects_callbacks_for_id = 
{
  (objects_hash_func_t) objects_id_hash,
  (objects_compare_func_t) objects_id_compare,
  (objects_is_equal_func_t) objects_id_is_equal,
  (objects_retain_func_t) objects_id_retain,
  (objects_release_func_t) objects_id_release,
  (objects_describe_func_t) objects_id_describe,
  0
};

/**** Function Implementations ***********************************************/

/* FIXME: It sure would be nice if we had a way of checking whether
 * or not these objects responded to the messages we're sending them here.
 * We need a way that is independent of whether we have GNUStep objects,
 * NEXTSTEP objects, or GNU objects.  We could certainly just use the
 * same trick that the `respondsToSelector:' method uses, but I'd hoped
 * that there was already a built-in call to do this sort of thing. */

size_t
objects_id_hash(const void *obj)
{
  return (size_t)[(id)obj hash];
}

int
objects_id_compare(const void *obj, const void *jbo)
{
  return (int)[(id)obj compare:(id)jbo];
}

int
objects_id_is_equal(const void *obj, const void *jbo)
{
  return (int)[(id)obj isEqual:(id)jbo];
}

const void *
objects_id_retain(const void *obj)
{
  return [(id)obj retain];
}

void
objects_id_release(const void *obj)
{
  [(id)obj release];
  return;
}

const void *
objects_id_describe (const void *obj)
{
  /* FIXME: Harrumph.  Make all of these describe functions live
   * in harmony.  Please. */
#if 0
  return [(id)obj describe];
#else
  return 0;
#endif
}

