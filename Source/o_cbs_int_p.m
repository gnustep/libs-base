/* Callbacks for pointers to `int'.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Sun Feb 11 01:49:55 EST 1996
 * Serial: 96.02.11.04
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA. */ 

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSString.h>
#include <base/o_cbs.h>

/**** Function Implementations ***********************************************/

size_t
o_int_p_hash(const int *iptr)
{
  return (size_t)(iptr) / 4;
}

int
o_int_p_compare(const int *iptr, const int *jptr)
{
  if (iptr < jptr)
    return -1;
  else if (iptr > jptr)
    return 1;
  else /* (iptr == jptr) */
    return 0;
}

int
o_int_p_is_equal(const int *iptr, const int *jptr)
{
  /* FIXME: Is this right?  If not, what else could it be? */
  return iptr == jptr;
}

const void *
o_int_p_retain(const int *iptr)
{
  return (const void *)iptr;
}

void
o_int_p_release(int *iptr)
{
  return;
}

NSString *
o_int_p_describe(const int *iptr)
{
  /* FIXME: Code this. */
  return nil;
}


