/* GNUStep callback functions.  Implicitly required by the standard.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Feb 13 23:10:29 EST 1996
 * Updated: Wed Mar 20 19:53:48 EST 1996
 * Serial: 96.03.20.02
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

#include <NSCallBacks.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

/**** Type, Constant, and Macro Definitions **********************************/

/**** Function Implementations ***********************************************/

/** For `int's **/

unsigned int
_NS_int_hash (void *table, int i)
{
  return (unsigned int) i;
}

BOOL
_NS_int_is_equal (void *table, int i, int j)
{
  return (i == j) ? YES : NO;
}

void
_NS_int_retain (void *table, int i)
{
  return;
}

void
_NS_int_release (void *table, int i)
{
  return;
}

NSString *
_NS_int_describe (void *table, int i)
{
  return [NSString stringWithFormat:@"%d", i];
}

/** For owned `void *' **/

unsigned int
_NS_owned_void_p_hash (void *table, void *p)
{
  /* P may be aligned, so we need to compensate. */
  return ((unsigned int)p)/4;
}

BOOL
_NS_owned_void_p_is_equal (void *table, void *p, void *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_owned_void_p_retain (void *table, void *p)
{
  return;
}

void
_NS_owned_void_p_release (void *table, void *p)
{
  if (p != 0)
    free(p);
  return;
}

NSString *
_NS_owned_void_p_describe (void *table, void *p)
{
  return [NSString stringWithFormat:@"%#x", p];
}

/** For non-retained Objective-C objects **/

unsigned int
_NS_non_retained_id_hash (void *table, id <NSObject> o)
{
  return [o hash];
}

BOOL
_NS_non_retained_id_is_equal (void *table, id <NSObject> o, id <NSObject> p)
{
  return [o isEqual:p];
}

void
_NS_non_retained_id_retain (void *table, id <NSObject> o)
{
  return;
}

void
_NS_non_retained_id_release (void *table, id <NSObject> o)
{
  return;
}

NSString *
_NS_non_retained_id_describe (void *table, id <NSObject> o)
{
  return [o description];
}

/** For (retainable) objects **/

unsigned int
_NS_id_hash (void *table, id <NSObject> o)
{
  return [o hash];
}

BOOL
_NS_id_is_equal (void *table, id <NSObject> o, id <NSObject> p)
{
  return [o isEqual:p];
}

void
_NS_id_retain (void *table, id <NSObject> o)
{
  [o retain];
  return;
}

void
_NS_id_release (void *table, id <NSObject> o)
{
  [o release];
  return;
}

NSString *
_NS_id_describe (void *table, id <NSObject> o)
{
  return [o description];
}


/** For (non-owned) `void *' **/

unsigned int
_NS_non_owned_void_p_hash (void *table, void *p)
{
  return ((unsigned int)p)/4;
}

BOOL
_NS_non_owned_void_p_is_equal (void *table, void *p, void *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_non_owned_void_p_retain (void *table, void *p)
{
  return;
}

void
_NS_non_owned_void_p_release (void *table, void *p)
{
  return;
}

NSString *
_NS_non_owned_void_p_describe (void *table, void *p)
{
  return [NSString stringWithFormat:@"%0x", p];
}

/** For pointers to structures and `int *' **/

unsigned int
_NS_int_p_hash (void *table, int *p)
{
  return ((unsigned int)p)/4;
}

BOOL
_NS_int_p_is_equal (void *table, int *p, int *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_int_p_retain (void *table, int *p)
{
  return;
}

void
_NS_int_p_release (void *table, int *p)
{
  return;
}

NSString *
_NS_int_p_describe (void *table, int *p)
{
  /* Is this useful? */
  return [NSString stringWithFormat:@"%d (%#x)", *p, p];
}
