/* Callbacks for strings of `char'.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 22:04:38 EST 1996
 * Updated: Sun Feb 11 01:40:09 EST 1996
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

/**** Type, Constant, and Macro Definitions **********************************/

objects_callbacks_t objects_callbacks_for_char_p = 
{
  (objects_hash_func_t) objects_char_p_hash,
  (objects_compare_func_t) objects_char_p_compare,
  (objects_is_equal_func_t) objects_char_p_is_equal,
  (objects_retain_func_t) objects_char_p_retain,
  (objects_release_func_t) objects_char_p_release,
  (objects_describe_func_t) objects_char_p_describe,
  0
};

/**** Function Implementations ***********************************************/

size_t
objects_char_p_hash (const void *cptr)
{
  register char *s = (char *) cptr;
  register size_t h = 0;
  register size_t c = 0;

  while (*s != '\0')
    h ^= *(s++) << (c++);

  return h;
}

int
objects_char_p_compare (const void *cptr, const void *dptr)
{
  register char *s = (char *) cptr;
  register char *t = (char *) dptr;

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
objects_char_p_is_equal (register const void *cptr, register const void *dptr)
{
  register char *s = (char *) cptr;
  register char *t = (char *) dptr;

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
objects_char_p_retain (const void *cptr)
{
  return cptr;
}

void
objects_char_p_release (const void *cptr)
{
  return;
}

const void *
objects_char_p_describe (const void *cptr)
{
  /* FIXME: Code this.  But first, figure out what it should do, OK? */
  return 0;
}

