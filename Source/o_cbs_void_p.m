/* Callbacks for pointers to `void'.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 22:04:38 EST 1996
 * Updated: Mon Mar 11 02:03:13 EST 1996
 * Serial: 96.03.11.04
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
#define _OBJECTS_NOT_A_VOID_P_MARKER (const void *)(-1)

const void *objects_not_a_void_p_marker = _OBJECTS_NOT_A_VOID_P_MARKER;

objects_callbacks_t objects_callbacks_for_non_owned_void_p = 
{
  (objects_hash_func_t) objects_non_owned_void_p_hash,
  (objects_compare_func_t) objects_non_owned_void_p_compare,
  (objects_is_equal_func_t) objects_non_owned_void_p_is_equal,
  (objects_retain_func_t) objects_non_owned_void_p_retain,
  (objects_release_func_t) objects_non_owned_void_p_release,
  _OBJECTS_NOT_A_VOID_P_MARKER
};

objects_callbacks_t objects_callbacks_for_owned_void_p = 
{
  (objects_hash_func_t) objects_owned_void_p_hash,
  (objects_compare_func_t) objects_owned_void_p_compare,
  (objects_is_equal_func_t) objects_owned_void_p_is_equal,
  (objects_retain_func_t) objects_owned_void_p_retain,
  (objects_release_func_t) objects_owned_void_p_release,
  _OBJECTS_NOT_A_VOID_P_MARKER
};

/**** Function Implementations ***********************************************/

size_t
objects_non_owned_void_p_hash(register const void *cptr)
{
  return ((size_t) cptr)/4;
}

int
objects_non_owned_void_p_compare(register const void *cptr,
                                 register const void *dptr)
{
  if (cptr == dptr)
    return 0;
  else if (cptr < dptr)
    return -1;
  else /* if (cptr > dptr) */
    return 1;
}

int
objects_non_owned_void_p_is_equal(register const void *cptr,
                                  register const void *dptr)
{
  return (cptr == dptr);
}

const void *
objects_non_owned_void_p_retain(const void *cptr)
{
  return cptr;
}

void
objects_non_owned_void_p_release(void *cptr)
{
  /* We don't own CPTR, so we don't release it. */
  return;
}

NSString *
objects_non_owned_void_p_describe(const void *cptr)
{
  /* FIXME: Code this. */
  return nil;
}

size_t
objects_owned_void_p_hash(register const void *cptr)
{
  /* We divide by 4 because many machines align
   * memory on word boundaries. */
  return ((size_t) cptr)/4;
}

int
objects_owned_void_p_compare(register const void *cptr,
                             register const void *dptr)
{
  if (cptr == dptr)
    return 0;
  else if (cptr < dptr)
    return -1;
  else /* if (cptr > dptr) */
    return 1;
}

int
objects_owned_void_p_is_equal(register const void *cptr, 
			      register const void *dptr)
{
  return (cptr == dptr);
}

const void *
objects_owned_void_p_retain(const void *cptr)
{
  return cptr;
}

void
objects_owned_void_p_release(void *cptr)
{
  free((void *)cptr);
  return;
}

NSString *
objects_owned_void_p_describe(const void *obj)
{
  /* FIXME: Code this. */
  return nil;
}

