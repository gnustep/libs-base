/* Some functionality in the GNU runtime that's not in the NeXT runtime
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Author: Kresten Krab Thorup
   Modified by: Andrew McCallum

   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#if ! NeXT_runtime
#error This file only needed if using NeXT runtime
#endif /* ! NeXT_runtime */

#include "objects/gnu4next.h"
#include <objc/objc.h>
#include <objc/objc-api.h>

/* Deal with strrchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define index strchr
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

#define MAX(X, Y)                    \
  ({ typeof(X) __x = (X), __y = (Y); \
     (__x > __y ? __x : __y); })

#define MIN(X, Y)                    \
  ({ typeof(X) __x = (X), __y = (Y); \
     (__x < __y ? __x : __y); })

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })


static inline int
atoi (const char* str)
{
  int res = 0;
  
  while (isdigit (*str))
    res *= 10, res += (*str++ - '0');

  return res;
}

/*
  return the size of an object specified by type 
*/

int
objc_sizeof_type(const char* type)
{
  switch(*type) {
  case _C_ID:
    return sizeof(id);
    break;

  case _C_CLASS:
    return sizeof(Class);
    break;

  case _C_SEL:
    return sizeof(SEL);
    break;

  case _C_CHR:
    return sizeof(char);
    break;
    
  case _C_UCHR:
    return sizeof(unsigned char);
    break;

  case _C_SHT:
    return sizeof(short);
    break;

  case _C_USHT:
    return sizeof(unsigned short);
    break;

  case _C_INT:
    return sizeof(int);
    break;

  case _C_UINT:
    return sizeof(unsigned int);
    break;

  case _C_LNG:
    return sizeof(long);
    break;

  case _C_ULNG:
    return sizeof(unsigned long);
    break;

  case _C_FLT:
    return sizeof(float);
    break;

  case _C_DBL:
    return sizeof(double);
    break;

  case _C_PTR:
  case _C_ATOM:
  case _C_CHARPTR:
    return sizeof(char*);
    break;

  case _C_ARY_B:
    {
      int len = atoi(type+1);
      while (isdigit(*++type));
      return len*objc_aligned_size (type);
    }
    break; 

  case _C_STRUCT_B:
    {
      int acc_size = 0;
      int align;
      while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
      while (*type != _C_STRUCT_E)
	{
	  align = objc_alignof_type (type);       /* padd to alignment */
	  acc_size = ROUND (acc_size, align);
	  acc_size += objc_sizeof_type (type);   /* add component size */
	  type = objc_skip_typespec (type);	         /* skip component */
	}
      return acc_size;
    }

  case _C_UNION_B:
    {
      int max_size = 0;
      while (*type != _C_UNION_E && *type++ != '=') /* do nothing */;
      while (*type != _C_UNION_E)
	{
	  max_size = MAX (max_size, objc_sizeof_type (type));
	  type = objc_skip_typespec (type);
	}
      return max_size;
    }
    
  default:
    abort();
  }
}


/*
  Return the alignment of an object specified by type 
*/

int
objc_alignof_type(const char* type)
{
  switch(*type) {
  case _C_ID:
    return __alignof__(id);
    break;

  case _C_CLASS:
    return __alignof__(Class);
    break;
    
  case _C_SEL:
    return __alignof__(SEL);
    break;

  case _C_CHR:
    return __alignof__(char);
    break;
    
  case _C_UCHR:
    return __alignof__(unsigned char);
    break;

  case _C_SHT:
    return __alignof__(short);
    break;

  case _C_USHT:
    return __alignof__(unsigned short);
    break;

  case _C_INT:
    return __alignof__(int);
    break;

  case _C_UINT:
    return __alignof__(unsigned int);
    break;

  case _C_LNG:
    return __alignof__(long);
    break;

  case _C_ULNG:
    return __alignof__(unsigned long);
    break;

  case _C_FLT:
    return __alignof__(float);
    break;

  case _C_DBL:
    return __alignof__(double);
    break;

  case _C_ATOM:
  case _C_CHARPTR:
    return __alignof__(char*);
    break;

  case _C_ARY_B:
    while (isdigit(*++type)) /* do nothing */;
    return objc_alignof_type (type);
      
  case _C_STRUCT_B:
    {
      struct { int x; double y; } fooalign;
      while(*type != _C_STRUCT_E && *type++ != '=') /* do nothing */;
      if (*type != _C_STRUCT_E)
	return MAX (objc_alignof_type (type), __alignof__ (fooalign));
      else
	return __alignof__ (fooalign);
    }

  case _C_UNION_B:
    {
      int maxalign = 0;
      while (*type != _C_UNION_E && *type++ != '=') /* do nothing */;
      while (*type != _C_UNION_E)
	{
	  maxalign = MAX (maxalign, objc_alignof_type (type));
	  type = objc_skip_typespec (type);
	}
      return maxalign;
    }
    
  default:
    abort();
  }
}

/*
  The aligned size if the size rounded up to the nearest alignment.
*/

int
objc_aligned_size (const char* type)
{
  int size = objc_sizeof_type (type);
  int align = objc_alignof_type (type);
  return ROUND (size, align);
}

/*
  The size rounded up to the nearest integral of the wordsize, taken
  to be the size of a void*.
*/

int 
objc_promoted_size (const char* type)
{
  int size = objc_sizeof_type (type);
  int wordsize = sizeof (void*);

  return ROUND (size, wordsize);
}

/*
  Skip type qualifiers.  These may eventually precede typespecs
  occuring in method prototype encodings.
*/

inline const char*
objc_skip_type_qualifiers (const char* type)
{
  while (*type == _C_CONST
	 || *type == _C_IN 
	 || *type == _C_INOUT
	 || *type == _C_OUT 
	 || *type == _C_BYCOPY
	 || *type == _C_ONEWAY)
    {
      type += 1;
    }
  return type;
}

  
/*
  Skip one typespec element.  If the typespec is prepended by type
  qualifiers, these are skipped as well.
*/

const char* 
objc_skip_typespec (const char* type)
{
  type = objc_skip_type_qualifiers (type);
  
  switch (*type) {

  case _C_ID:
    /* An id may be annotated by the actual type if it is known
       with the @"ClassName" syntax */

    if (*++type != '"')
      return type;
    else
      {
	while (*++type != '"') /* do nothing */;
	return type + 1;
      }

    /* The following are one character type codes */
  case _C_CLASS:
  case _C_SEL:
  case _C_CHR:
  case _C_UCHR:
  case _C_CHARPTR:
  case _C_ATOM:
  case _C_SHT:
  case _C_USHT:
  case _C_INT:
  case _C_UINT:
  case _C_LNG:
  case _C_ULNG:
  case _C_FLT:
  case _C_DBL:
  case _C_VOID:
    return ++type;
    break;

  case _C_ARY_B:
    /* skip digits, typespec and closing ']' */
    
    while(isdigit(*++type));
    type = objc_skip_typespec(type);
    if (*type == _C_ARY_E)
      return ++type;
    else
      abort();

  case _C_STRUCT_B:
    /* skip name, and elements until closing '}'  */
    
    while (*type != _C_STRUCT_E && *type++ != '=');
    while (*type != _C_STRUCT_E) { type = objc_skip_typespec (type); }
    return ++type;

  case _C_UNION_B:
    /* skip name, and elements until closing ')'  */
    
    while (*type != _C_UNION_E && *type++ != '=');
    while (*type != _C_UNION_E) { type = objc_skip_typespec (type); }
    return ++type;

  case _C_PTR:
    /* Just skip the following typespec */
    
    return objc_skip_typespec (++type);
    
  default:
    abort();
  }
}

/*
  Skip an offset as part of a method encoding.  This is prepended by a
  '+' if the argument is passed in registers.
*/
inline const char* 
objc_skip_offset (const char* type)
{
  if (*type == '+') type++;
  while(isdigit(*++type));
  return type;
}

/*
  Skip an argument specification of a method encoding.
*/
const char*
objc_skip_argspec (const char* type)
{
  type = objc_skip_typespec (type);
  type = objc_skip_offset (type);
  return type;
}

unsigned
objc_get_type_qualifiers (const char* type)
{
  unsigned res = 0;
  BOOL flag = YES;

  while (flag)
    switch (*type++)
      {
      case _C_CONST:  res |= _F_CONST; break;
      case _C_IN:     res |= _F_IN; break;
      case _C_INOUT:  res |= _F_INOUT; break;
      case _C_OUT:    res |= _F_OUT; break;
      case _C_BYCOPY: res |= _F_BYCOPY; break;
      case _C_ONEWAY: res |= _F_ONEWAY; break;
      default: flag = NO;
    }

  return res;
}

/* Returns YES iff t1 and t2 have same method types, but we ignore
   the argframe layout */
BOOL
sel_types_match (const char* t1, const char* t2)
{
  if (!t1 || !t2)
    return NO;
  while (*t1 && *t2)
    {
      if (*t1 == '+') t1++;
      if (*t2 == '+') t2++;
      while (isdigit(*t1)) t1++;
      while (isdigit(*t2)) t2++;
      /* xxx Remove these next two lines when qualifiers are put in
	 all selectors, not just Protocol selectors. */
      t1 = objc_skip_type_qualifiers(t1);
      t2 = objc_skip_type_qualifiers(t2);
      if (!*t1 && !*t2)
	return YES;
      if (*t1 != *t2)
	return NO;
      t1++;
      t2++;
    }
  return NO;
}
