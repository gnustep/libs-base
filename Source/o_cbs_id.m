/* Callbacks for the Objective-C object type. */
/* Copyright (C) 1996  Free Software Foundation, Inc. */

/* Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 15:55:51 EST 1996
 * Updated: Sun Feb 11 01:42:20 EST 1996
 * Serial: 96.02.11.05
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
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <base/o_cbs.h>

/**** Function Implementations ***********************************************/

/* FIXME: It sure would be nice if we had a way of checking whether
 * or not these objects responded to the messages we're sending them here.
 * We need a way that is independent of whether we have GNUStep objects,
 * NEXTSTEP objects, or GNU objects.  We could certainly just use the
 * same trick that the `respondsToSelector:' method itself uses, but I'd hoped
 * that there was already a built-in call to do this sort of thing. */

size_t
o_id_hash(id obj)
{
  return (size_t)[obj hash];
}

int
o_id_compare(id obj, id jbo)
{
  return (int)[obj compare:jbo];
}

int
o_id_is_equal(id obj, id jbo)
{
  return (int)[obj isEqual:jbo];
}

const void *
o_id_retain(id obj)
{
  return (const void *)[obj retain];
}

void
o_id_release(id obj)
{
  [obj release];
  return;
}

NSString *
o_id_describe(id obj)
{
  return [obj description];
}

