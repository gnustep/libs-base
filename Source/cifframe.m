/** cifframe.m - Wrapper/Objective-C interface for ffi function interface

   Copyright (C) 1999, Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Dec 1999, rewritten Apr 2002

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#include "config.h"
#include <stdlib.h>
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

#include "cifframe.h"
#include "Foundation/NSException.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDebug.h"
#include "GSInvocation.h"

#if defined(ALPHA) || (defined(MIPS) && (_MIPS_SIM == _ABIN32))
typedef long long smallret_t;
#else
typedef int smallret_t;
#endif

/* ffi defines types in a very odd way that doesn't map to the
   normal objective-c type (see ffi.h). Here we make up for that */
#if GS_SIZEOF_SHORT == 2
#define gsffi_type_ushort ffi_type_uint16
#define gsffi_type_sshort ffi_type_sint16
#elif GS_SIZEOF_SHORT == 4
#define gsffi_type_ushort ffi_type_uint32
#define gsffi_type_sshort ffi_type_sint32
#else
#error FFI Sizeof SHORT case not handled
#endif

#if GS_SIZEOF_INT == 2
#define gsffi_type_uint ffi_type_uint16
#define gsffi_type_sint ffi_type_sint16
#elif GS_SIZEOF_INT == 4
#define gsffi_type_uint ffi_type_uint32
#define gsffi_type_sint ffi_type_sint32
#elif GS_SIZEOF_INT == 8
#define gsffi_type_uint ffi_type_uint64
#define gsffi_type_sint ffi_type_sint64
#else
#error FFI Sizeof INT case not handled
#endif

#if GS_SIZEOF_LONG == 2
#define gsffi_type_ulong ffi_type_uint16
#define gsffi_type_slong ffi_type_sint16
#elif GS_SIZEOF_LONG == 4
#define gsffi_type_ulong ffi_type_uint32
#define gsffi_type_slong ffi_type_sint32
#elif GS_SIZEOF_LONG == 8
#define gsffi_type_ulong ffi_type_uint64
#define gsffi_type_slong ffi_type_sint64
#else
#error FFI Sizeof LONG case not handled
#endif

#ifdef	_C_LNG_LNG
#if GS_SIZEOF_LONG_LONG == 8
#define gsffi_type_ulong_long ffi_type_uint64
#define gsffi_type_slong_long ffi_type_sint64
#else
#error FFI Sizeof LONG LONG case not handled
#endif
#endif

ffi_type *cifframe_type(const char *typePtr, const char **advance);

/* Best guess at the space needed for a structure, since we don't know
   for sure until it's calculated in ffi_prep_cif, which is too late */
int
cifframe_guess_struct_size(ffi_type *stype)
{
  int      i, size;
  unsigned align = __alignof(double);

  if (stype->elements == NULL)
    return stype->size;

  size = 0;
  i = 0;
  while (stype->elements[i])
    {
      if (stype->elements[i]->elements)
	size += cifframe_guess_struct_size(stype->elements[i]);
      else
	size += stype->elements[i]->size;

      if (size % align != 0)
	{
	  size += (align - size % align);
	}
      i++;
    }
  return size;
}


cifframe_t *
cifframe_from_info (NSArgumentInfo *info, int numargs, void **retval)
{
  unsigned      size = sizeof(cifframe_t);
  unsigned      align = __alignof(double);
  unsigned      type_offset = 0;
  unsigned      offset = 0;
  void          *buf;
  int           i;
  ffi_type      *rtype;
  ffi_type      *arg_types[numargs];
  cifframe_t    *cframe;

  /* FIXME: in cifframe_type, return values/arguments that are structures
     have custom ffi_types with are allocated separately. We should allocate
     them in our cifframe so we don't leak memory. Or maybe we could
     cache structure types? */
  rtype = cifframe_type(info[0].type, NULL);
  for (i = 0; i < numargs; i++)
    {
      arg_types[i] = cifframe_type(info[i+1].type, NULL);
    }

  if (numargs > 0)
    {
      if (size % align != 0)
        {
          size += align - (size % align);
        }
      type_offset = size;
      /* Make room to copy the arg_types */
      size += sizeof(ffi_type *) * numargs;
      if (size % align != 0)
        {
          size += align - (size % align);
        }
      offset = size;
      size += numargs * sizeof(void*);
      if (size % align != 0)
        {
          size += (align - (size % align));
        }
      for (i = 0; i < numargs; i++)
        {
	  if (arg_types[i]->elements)
	    size += cifframe_guess_struct_size(arg_types[i]);
	  else
	    size += arg_types[i]->size;

          if (size % align != 0)
            {
              size += (align - size % align);
            }
        }
    }

  /*
   * If we need space allocated to store a return value,
   * make room for it at the end of the cifframe so we
   * only need to do a single malloc.
   */
  if (rtype && (rtype->size > 0 || rtype->elements != NULL))
    {
      unsigned	full = size;
      unsigned	pos;

      if (full % align != 0)
	{
	  full += (align - full % align);
	}
      pos = full;
      if (rtype->elements)
	full += cifframe_guess_struct_size(rtype);
      else
	full += MAX(rtype->size, sizeof(smallret_t));
      /* HACK ... not sure why, but on my 64bit intel system adding a bit
       * more to the buffer size prevents writing outside the allocated
       * memory by the ffi stuff.
       */
      full += 64;
#if	GS_WITH_GC
      cframe = buf = NSAllocateCollectable(full, NSScannedOption);
#else
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), full, 1);
#endif
      if (cframe && retval)
	{
	  *retval = buf + pos;
	}
    }
  else
    {
#if	GS_WITH_GC
      cframe = buf = NSAllocateCollectable(size, NSScannedOption);
#else
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), size, 1);
#endif
    }

  if (cframe)
    {
      cframe->nargs = numargs;
      cframe->arg_types = buf + type_offset;
      memcpy(cframe->arg_types, arg_types, sizeof(ffi_type *) * numargs);
      cframe->values = buf + offset;
    }

  if (ffi_prep_cif (&cframe->cif, FFI_DEFAULT_ABI, cframe->nargs,
		   rtype, cframe->arg_types) != FFI_OK)
    {
      objc_free(cframe);
      cframe = NULL;
    }

  if (cframe)
    {
      /* Set values locations. This must be done after ffi_prep_cif so
         that any structure sizes get calculated first. */
      offset += numargs * sizeof(void*);
      if (offset % align != 0)
        {
          offset += align - (offset % align);
        }
      for (i = 0; i < cframe->nargs; i++)
        {
          cframe->values[i] = buf + offset;

          offset += arg_types[i]->size;

          if (offset % align != 0)
            {
              offset += (align - offset % align);
            }
        }
    }

  return cframe;
}

void
cifframe_set_arg(cifframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(cframe->values[index], buffer, size);
}

void
cifframe_get_arg(cifframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(buffer, cframe->values[index], size);
}

void *
cifframe_arg_addr(cifframe_t *cframe, int index)
{
  if (index < 0 || index >= cframe->nargs)
     return NULL;
  return cframe->values[index];
}

/*
 * Get the ffi_type for this type
 */
ffi_type *
cifframe_type(const char *typePtr, const char **advance)
{
  BOOL flag;
  const char *type;
  ffi_type *ftype;

  /*
   *	Skip past any type qualifiers
   */
  flag = YES;
  while (flag)
    {
      switch (*typePtr)
	{
	case _C_CONST:
	case _C_IN:
	case _C_INOUT:
	case _C_OUT:
	case _C_BYCOPY:
#ifdef	_C_BYREF
	case _C_BYREF:
#endif
	case _C_ONEWAY:
#ifdef	_C_GCINVISIBLE
	case _C_GCINVISIBLE:
#endif
	  break;
	default: flag = NO;
	}
      if (flag)
	{
	  typePtr++;
	}
    }

  type = typePtr;

  /*
   *	Scan for size and alignment information.
   */
  switch (*typePtr++)
    {
    case _C_ID: ftype = &ffi_type_pointer;
      break;
    case _C_CLASS: ftype = &ffi_type_pointer;
      break;
    case _C_SEL: ftype = &ffi_type_pointer;
      break;
    case _C_CHR: ftype = &ffi_type_schar;
      break;
    case _C_UCHR: ftype = &ffi_type_uchar;
      break;
    case _C_SHT: ftype = &gsffi_type_sshort;
      break;
    case _C_USHT: ftype = &gsffi_type_ushort;
      break;
    case _C_INT: ftype = &gsffi_type_sint;
      break;
    case _C_UINT: ftype = &gsffi_type_uint;
      break;
    case _C_LNG: ftype = &gsffi_type_slong;
      break;
    case _C_ULNG: ftype = &gsffi_type_ulong;
      break;
#ifdef	_C_LNG_LNG
    case _C_LNG_LNG: ftype = &gsffi_type_slong_long;
      break;
    case _C_ULNG_LNG: ftype = &gsffi_type_ulong_long;
      break;
#endif
    case _C_FLT: ftype = &ffi_type_float;
      break;
    case _C_DBL: ftype = &ffi_type_double;
      break;
    case _C_PTR:
      ftype = &ffi_type_pointer;
      if (*typePtr == '?')
	{
	  typePtr++;
	}
      else
	{
	  const char *adv;
	  cifframe_type(typePtr, &adv);
	  typePtr = adv;
	}
      break;

    case _C_ATOM:
    case _C_CHARPTR:
      ftype = &ffi_type_pointer;
      break;

    case _C_ARY_B:
      {
	const char *adv;
	ftype = &ffi_type_pointer;

	while (isdigit(*typePtr))
	  {
	    typePtr++;
	  }
	cifframe_type(typePtr, &adv);
	typePtr = adv;
	typePtr++;	/* Skip end-of-array	*/
      }
      break;

    case _C_STRUCT_B:
      {
	int types, maxtypes, size;
	ffi_type *local;
	const char *adv;
	unsigned   align = __alignof(double);

	types = 0;
	maxtypes = 4;
	size = sizeof(ffi_type);
	if (size % align != 0)
	  {
	    size += (align - (size % align));
	  }
	ftype = objc_malloc(size + (maxtypes+1)*sizeof(ffi_type));
	ftype->size = 0;
	ftype->alignment = 0;
	ftype->type = FFI_TYPE_STRUCT;
	ftype->elements = (void*)ftype + size;
	/*
	 *	Skip "<name>=" stuff.
	 */
	while (*typePtr != _C_STRUCT_E)
	  {
	    if (*typePtr++ == '=')
	      {
		break;
	      }
	  }
	/*
	 *	Continue accumulating structure size.
	 */
	while (*typePtr != _C_STRUCT_E)
	  {
	    local = cifframe_type(typePtr, &adv);
	    typePtr = adv;
	    NSCAssert(typePtr, @"End of signature while parsing");
	    ftype->elements[types++] = local;
	    if (types >= maxtypes)
	      {
		maxtypes *=2;
		ftype = objc_realloc(ftype,
                  size + (maxtypes+1)*sizeof(ffi_type));
	        ftype->elements = (void*)ftype + size;
	      }
	  }
	ftype->elements[types] = NULL;
	typePtr++;	/* Skip end-of-struct	*/
      }
      break;

    case _C_UNION_B:
      {
	const char *adv;
	int	max_align = 0;

	/*
	 *	Skip "<name>=" stuff.
	 */
	while (*typePtr != _C_UNION_E)
	  {
	    if (*typePtr++ == '=')
	      {
		break;
	      }
	  }
	ftype = NULL;
	while (*typePtr != _C_UNION_E)
	  {
	    ffi_type *local;
	    int align = objc_alignof_type(typePtr);
	    local = cifframe_type(typePtr, &adv);
	    typePtr = adv;
	    NSCAssert(typePtr, @"End of signature while parsing");
	    if (align > max_align)
	      {
		if (ftype && ftype->type == FFI_TYPE_STRUCT)
		  objc_free(ftype);
		ftype = local;
		max_align = align;
	      }
	  }
	typePtr++;	/* Skip end-of-union	*/
      }
      break;

    case _C_VOID: ftype = &ffi_type_void;
      break;
    default:
      ftype = &ffi_type_void;
      NSCAssert(0, @"Unknown type in sig");
    }

  /* Skip past any offset information, if there is any */
  if (*type != _C_PTR || *type == '?')
    {
      if (*typePtr == '+')
	typePtr++;
      if (*typePtr == '-')
	typePtr++;
      while (isdigit(*typePtr))
	typePtr++;
    }
  if (advance)
    *advance = typePtr;

  return ftype;
}

/*-------------------------------------------------------------------------*/
/* Functions for handling sending and receiving messages accross a
   connection
*/

/* Some return types actually get coded differently. We need to convert
   back to the expected return type */
BOOL
cifframe_decode_arg (const char *type, void* buffer)
{
  switch (*type)
    {
    case _C_CHR:
    case _C_UCHR:
      {
	*(unsigned char*)buffer = (unsigned char)(*((smallret_t *)buffer));
	break;
      }
    case _C_SHT:
    case _C_USHT:
      {
	*(unsigned short*)buffer = (unsigned short)(*((smallret_t *)buffer));
	break;
      }
    case _C_INT:
    case _C_UINT:
      {
	*(unsigned int*)buffer = (unsigned int)(*((smallret_t *)buffer));
	break;
      }
    default:
      return NO;
    }
  return YES;
}

BOOL
cifframe_encode_arg (const char *type, void* buffer)
{
  switch (*type)
    {
    case _C_CHR:
    case _C_UCHR:
      {
	*(smallret_t *)buffer = (smallret_t)(*((unsigned char *)buffer));
	break;
      }
    case _C_SHT:
    case _C_USHT:
      {
	*(smallret_t *)buffer = (smallret_t)(*((unsigned short *)buffer));
	break;
      }
    case _C_INT:
    case _C_UINT:
      {
	*(smallret_t *)buffer = (smallret_t)(*((unsigned int *)buffer));
	break;
      }
    default:
      return NO;
    }
  return YES;
}

