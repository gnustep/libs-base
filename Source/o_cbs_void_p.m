/* Callbacks for pointers to `void'.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 22:04:38 EST 1996
 * Updated: Mon Mar 11 02:03:13 EST 1996
 * Serial: 96.03.11.04
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include "config.h"
#include <Foundation/NSString.h>
#include <base/o_cbs.h>

/**** Function Implementations ***********************************************/

size_t
o_non_owned_void_p_hash(register const void *cptr)
{
  return ((size_t) cptr)/4;
}

int
o_non_owned_void_p_compare(register const void *cptr,
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
o_non_owned_void_p_is_equal(register const void *cptr,
                                  register const void *dptr)
{
  return (cptr == dptr);
}

const void *
o_non_owned_void_p_retain(const void *cptr)
{
  return cptr;
}

void
o_non_owned_void_p_release(void *cptr)
{
  /* We don't own CPTR, so we don't release it. */
  return;
}

NSString *
o_non_owned_void_p_describe(const void *cptr)
{
  /* FIXME: Code this. */
  return nil;
}

size_t
o_owned_void_p_hash(register const void *cptr)
{
  /* We divide by 4 because many machines align
   * memory on word boundaries. */
  return ((size_t) cptr)/4;
}

int
o_owned_void_p_compare(register const void *cptr,
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
o_owned_void_p_is_equal(register const void *cptr, 
			      register const void *dptr)
{
  return (cptr == dptr);
}

const void *
o_owned_void_p_retain(const void *cptr)
{
  return cptr;
}

void
o_owned_void_p_release(void *cptr)
{
  free((void *)cptr);
  return;
}

NSString *
o_owned_void_p_describe(const void *obj)
{
  /* FIXME: Code this. */
  return nil;
}

