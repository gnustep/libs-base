/* Functions for dealing with elt unions
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <gnustep/base/prefix.h>
#include <gnustep/base/eltfuncs.h>
#include <gnustep/base/collhash.h>
#include <gnustep/base/Stream.h>

/* Is there a better (shorter) way to specify all this junk? */

unsigned int
elt_hash_int (elt key)
{
  return (key.int_u);
}

int
elt_compare_ints (elt k1, elt k2)
{
  if (k1.int_u == k2.int_u)
    return 0;
  else if (k1.int_u > k2.int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_unsigned_int (elt key)
{
  return (key.unsigned_int_u);
}

int
elt_compare_unsigned_ints (elt k1, elt k2)
{
  if (k1.unsigned_int_u == k2.unsigned_int_u)
    return 0;
  else if (k1.unsigned_int_u > k2.unsigned_int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_long_int (elt key)
{
  return ((unsigned int)key.long_int_u);
}

int
elt_compare_long_ints (elt k1, elt k2)
{
  if (k1.long_int_u == k2.long_int_u)
    return 0;
  else if (k1.long_int_u > k2.long_int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_unsigned_long_int (elt key)
{
  return ((unsigned int)key.unsigned_long_int_u);
}

int
elt_compare_unsigned_long_ints (elt k1, elt k2)
{
  if (k1.unsigned_long_int_u == k2.unsigned_long_int_u)
    return 0;
  else if (k1.unsigned_long_int_u > k2.unsigned_long_int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_char (elt key)
{
  return ((unsigned int)key.char_u);
}

int
elt_compare_chars (elt k1, elt k2)
{
  if (k1.char_u == k2.char_u)
    return 0;
  else if (k1.char_u > k2.char_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_unsigned_char (elt key)
{
  return ((unsigned int)key.unsigned_char_u);
}

int
elt_compare_unsigned_chars (elt k1, elt k2)
{
  if (k1.unsigned_char_u == k2.unsigned_char_u)
    return 0;
  else if (k1.unsigned_char_u > k2.unsigned_char_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_short (elt key)
{
  return ((unsigned int)key.short_int_u);
}

int
elt_compare_shorts (elt k1, elt k2)
{
  if (k1.short_int_u == k2.short_int_u)
    return 0;
  else if (k1.short_int_u > k2.short_int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_unsigned_short (elt key)
{
  return ((unsigned int)key.unsigned_short_int_u);
}

int
elt_compare_unsigned_shorts (elt k1, elt k2)
{
  if (k1.unsigned_short_int_u == k2.unsigned_short_int_u)
    return 0;
  else if (k1.unsigned_short_int_u > k2.unsigned_short_int_u)
    return 1;
  else
    return -1;
}

unsigned int
elt_hash_float (elt key)
{
  /* There must be a better hash function for floats than this */
  return ((unsigned int)key.float_u);
}

int
elt_compare_floats (elt k1, elt k2)
{
  float diff = k1.float_u - k2.float_u;
  if (diff == 0)
    return 0;
  else if (diff > 0)
    return 1;
  else
    return -1;
}

#if (ELT_INCLUDES_DOUBLE)
unsigned int
elt_hash_double (elt key)
{
  /* There must be a better hash function for doubles than this.
     Fix this nonsense: */
  return ((unsigned int)key.double_u);
}

int
elt_compare_doubles (elt k1, elt k2)
{
  double diff = k1.double_u - k2.double_u;
  if (diff == 0)
    return 0;
  else if (diff > 0)
    return 1;
  else
    return -1;
}
#endif

int 
elt_compare_strings (elt k1, elt k2)
{
  return strcmp (k1.char_ptr_u, k2.char_ptr_u);
}

unsigned int 
elt_hash_string (elt key)
{
  unsigned int ret = 0;
  unsigned int ctr = 0;
        
  while (*key.char_ptr_u) {
    ret ^= *key.char_ptr_u++ << ctr;
    ctr = (ctr + 1) % sizeof (void *);
  }
  return ret;
}

int 
elt_compare_void_ptrs (elt k1, elt k2)
{
  if (k1.void_ptr_u == k2.void_ptr_u)
    return 0;
  else if (k1.void_ptr_u > k2.void_ptr_u)
    return 1;
  else
    return -1;
}

unsigned int 
elt_hash_void_ptr (elt key)
{
  return ((unsigned)key.void_ptr_u) / sizeof(void *);
}

unsigned int
elt_hash_object (elt key)
{
  return [key.id_u hash];
}

int
elt_compare_objects (elt k1, elt k2)
{
  return [k1.id_u compare:k2.id_u];
}

int
(*(elt_get_comparison_function(const char *encoding)))(elt,elt)
{
  switch (*encoding) 
    {
    case _C_CHARPTR: 
    case _C_ATOM: 
      return elt_compare_strings;
      
    case _C_ID: 
    case _C_CLASS:              /* isEqual: on classes works well? */
      return elt_compare_objects;
      
    case _C_PTR: 
      return elt_compare_void_ptrs;
      
    case _C_INT: 
      return elt_compare_ints;

    case _C_SEL:                /* is this where this belongs? */
    case _C_UINT: 
      return elt_compare_unsigned_ints;

    case _C_FLT:
      return elt_compare_floats;

#if ELT_INCLUDES_DOUBLE
    case _C_DBL:
      return elt_compare_doubles;
#endif

    case _C_LNG: 
      return elt_compare_long_ints;

    case _C_ULNG: 
      return elt_compare_unsigned_long_ints;

    case _C_CHR:
      return elt_compare_chars;
      
    case _C_UCHR:
      return elt_compare_unsigned_chars;
      
    case _C_SHT:
      return elt_compare_shorts;

    case _C_USHT:
      return elt_compare_unsigned_shorts;
      
    default : 
      return 0;
    }
}

unsigned int
(*(elt_get_hash_function(const char *encoding)))(elt)
{
  switch (*encoding) 
    {
    case _C_CHARPTR: 
    case _C_ATOM: 
      return elt_hash_string;
      
    case _C_ID: 
    case _C_CLASS:              /* I can send classes isEqual:? */
      return elt_hash_object;
      
    case _C_PTR: 
      return elt_hash_void_ptr;
      
    case _C_INT: 
      return elt_hash_int;

    case _C_SEL:                /* is this where this belongs? */
    case _C_UINT: 
      return elt_hash_unsigned_int;

    case _C_FLT:
      return elt_hash_float;

#if ELT_INCLUDES_DOUBLE
    case _C_DBL:
      return elt_hash_double;
#endif
    case _C_LNG: 
      return elt_hash_long_int;

    case _C_ULNG: 
      return elt_hash_unsigned_long_int;
      
    case _C_CHR:
      return elt_hash_char;
      
    case _C_UCHR:
      return elt_hash_unsigned_char;
      
    case _C_SHT:
      return elt_hash_short;

    case _C_USHT:
      return elt_hash_unsigned_short;
      
    default : 
      return 0;
    }
}


static coll_cache_ptr __comp_func_hashtable = 0;
#define INIT_COMP_FUNC_HASHTABLE_SIZE 32

static inline void
__init_comp_func_hashtable()
{
  __comp_func_hashtable = 
    coll_hash_new(INIT_COMP_FUNC_HASHTABLE_SIZE, 
		  (coll_hash_func_type)elt_hash_void_ptr, 
		  (coll_compare_func_type)elt_compare_void_ptrs);
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_ints,
		@encode(int));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_unsigned_ints,
		@encode(unsigned int));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_long_ints,
		@encode(long int));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_unsigned_long_ints,
		@encode(unsigned long int));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_chars,
		@encode(char));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_unsigned_chars,
		@encode(unsigned char));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_shorts,
		@encode(short));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_unsigned_shorts,
		@encode(unsigned short));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_floats,
		@encode(float));
#if (ELT_INCLUDES_DOUBLE)
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_doubles,
		@encode(double));
#endif
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_strings,
		@encode(char*));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_void_ptrs,
		@encode(void*));
  coll_hash_add(&__comp_func_hashtable, 
		(void*)elt_compare_objects,
		@encode(id));
}

const char *
elt_get_encoding(int(*comparison_function)(elt,elt))
{
  if (!__comp_func_hashtable)
    __init_comp_func_hashtable();

  return (const char *) 
    coll_hash_value_for_key(__comp_func_hashtable, 
			    (void*)comparison_function).char_ptr_u;
}


/* Is this really necessary?  Can I count on element members always 
   starting at the beginning? */

extern void *elt_get_ptr_to_member(const char *encoding, elt *anElement)
{
  switch (*encoding) 
    {
    case _C_CHARPTR: 
    case _C_ATOM: 
      return &(anElement->char_ptr_u);
      
    case _C_ID: 
    case _C_CLASS:
      return &(anElement->id_u);
      
    case _C_PTR: 
      return &(anElement->void_ptr_u);
      
    case _C_SEL:
      return &(anElement->SEL_u);

    case _C_CHR:
      return &(anElement->char_u);

    case _C_UCHR:
      return &(anElement->unsigned_char_u);
      
    case _C_SHT:
      return &(anElement->short_int_u);

    case _C_USHT:
      return &(anElement->unsigned_short_int_u);
      break;
      
    case _C_INT: 
      return &(anElement->int_u);

    case _C_UINT: 
      return &(anElement->unsigned_int_u);

    case _C_LNG: 
      return &(anElement->long_int_u);

    case _C_ULNG: 
      return &(anElement->unsigned_long_int_u);

    case _C_FLT:
      return &(anElement->float_u);
      
#if (ELT_INCLUDES_DOUBLE)
    case _C_DBL:
      return &(anElement->double_u);
#endif
      
    default : 
      return 0;
    }
}

void
elt_fprintf_elt(FILE *fp, const char *encoding, elt anElement)
{
  switch (*encoding)
    {
    case _C_CHARPTR: 
    case _C_ATOM: 
      fprintf(fp, "\"%s\"", anElement.char_ptr_u);
      break;
      
    case _C_ID: 
    case _C_CLASS:
      fprintf(fp, "%s:0x%x", [anElement.id_u name], anElement.unsigned_int_u);
      break;
      
    case _C_PTR: 
      fprintf(fp, "0x%x", anElement.unsigned_int_u);
      break;
      
    case _C_SEL:
      fprintf(fp, "%s", sel_get_name(anElement.SEL_u));
      break;

    case _C_CHR:
      fprintf(fp, "%c", anElement.char_u);
      break;

    case _C_UCHR:
      fprintf(fp, "%c", anElement.unsigned_char_u);
      break;
      
    case _C_SHT:
      fprintf(fp, "%d", anElement.short_int_u);
      break;

    case _C_USHT:
      fprintf(fp, "%d", anElement.unsigned_short_int_u);
      break;
      
    case _C_INT: 
      fprintf(fp, "%d", anElement.int_u);
      break;

    case _C_UINT: 
      fprintf(fp, "%d", anElement.unsigned_int_u);
      break;

    case _C_LNG: 
      fprintf(fp, "%ld", anElement.long_int_u);
      break;

    case _C_ULNG: 
      fprintf(fp, "%lu", anElement.unsigned_long_int_u);
      break;

    case _C_FLT:
      fprintf(fp, "%g", anElement.float_u);
      break;
      
#if (ELT_INCLUDES_DOUBLE)
    case _C_DBL:
      fprintf(fp, "%g", anElement.double_u);
      break;
#endif
      
    default : 
      fprintf(fp, "unknown?");
    }
}
