/* Callbacks for (NUL-terminated) arrays of `char'.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 22:04:38 EST 1996
 * Updated: Mon Mar 11 03:09:33 EST 1996
 * Serial: 96.03.11.06
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
#include <gnustep/base/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_A_CHAR_P_MARKER (const void *)(-1)

const void *objects_not_a_char_p_marker = _OBJECTS_NOT_A_CHAR_P_MARKER;

objects_callbacks_t objects_callbacks_for_char_p = 
{
  (objects_hash_func_t) objects_char_p_hash,
  (objects_compare_func_t) objects_char_p_compare,
  (objects_is_equal_func_t) objects_char_p_is_equal,
  (objects_retain_func_t) objects_char_p_retain,
  (objects_release_func_t) objects_char_p_release,
  (objects_describe_func_t) objects_char_p_describe,
  _OBJECTS_NOT_A_CHAR_P_MARKER
};

/**** Function Implementations ***********************************************/

size_t
objects_char_p_hash(const char *cptr)
{
  register const char *s = cptr;
  register size_t h = 0;
  register size_t c = 0;

  while (*s != '\0')
    h ^= *(s++) << (c++);

  return h;
}

int
objects_char_p_compare(const char *cptr, const char *dptr)
{
  register const char *s = (char *) cptr;
  register const char *t = (char *) dptr;

  if (s == t)
  {
    return 0;
  }
  else
  {
    register char c;
    register char d;

    while ((c = *(s++)) == (d = *(s++)))
      if (c == '\0')
        return 0;
    
    return (c - d);
  }
}

/* Determines whether or not CPTR is the same (`NUL'-terminated)
 * character string as DPTR.  Returns true if CPTR and DPTR are the same,
 * and false otherwise.  Note that we are performing no
 * internationalization here.  CPTR and DPTR are taken to be C strings
 * in the default (seven or) eight bit character encoding. */
int
objects_char_p_is_equal(const char *cptr, const char *dptr)
{
  register const char *s = cptr;
  register const char *t = dptr;

  if (s == t)
  {
    return 1;
  }
  else
  {
    register char c;
    register char d;

    while ((c = *(s++)) == (d = *(t++)))
      if (c == '\0')
        return 1;
    
    return 0;
  }
}

const void *
objects_char_p_retain(const char *cptr)
{
  return (const void *)cptr;
}

void
objects_char_p_release(char *cptr)
{
  return;
}

NSString *
objects_char_p_describe(const char *cptr)
{
  /* FIXME: Code this. */
  return nil;
}

