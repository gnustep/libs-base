/* Callbacks for `int' (and smaller) things. */
/* Copyright (C) 1996  Free Software Foundation, Inc. */

/* Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Mon Mar 11 00:23:10 EST 1996
 * Serial: 96.03.11.01
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

#include <stdlib.h>
#include <Foundation/NSString.h>
#include <base/o_cbs.h>

/**** Function Implementations ***********************************************/

/* FIXME: We (like OpenStep) make the big assumption here that
 * 'sizeof(int) <= sizeof(void *)'....This is probably not a good thing,
 * but what can I do? */

size_t
o_int_hash(int i)
{
  return (size_t)i;
}

int
o_int_compare(int i, int j)
{
  return i - j;
}

int
o_int_is_equal(int i, int j)
{
  return i == j;
}

const void *
o_int_retain(int i)
{
  return (const void *)i;
}

void
o_int_release(int i)
{
  return;
}

NSString *
o_int_describe(int i)
{
  /* FIXME: Code this. */
  return nil;
}


