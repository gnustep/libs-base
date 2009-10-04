/** Implementation of functions for dissecting/making method calls
   Copyright (C) 1994, 1995, 1996, 1997, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Oct 1994

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

/* These functions can be used for dissecting and making method calls
   for many different situations.  They are used for distributed
   objects; they could also be used to make interfaces between
   Objective C and Scheme, Perl, Tcl, or other languages.

*/

/* Remove `inline' nested functions if they crash your compiler */
//#define inline

#include "config.h"
#include "GNUstepBase/preface.h"
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <mframe.h>

/* Deal with strrchr: */
#if STDC_HEADERS || defined(HAVE_STRING_H)
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && defined(HAVE_MEMORY_H)
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

#include "Foundation/NSObjCRuntime.h"
#include "Foundation/NSData.h"
#include "Foundation/NSException.h"
#include "Foundation/NSDebug.h"



/* For encoding and decoding the method arguments, we have to know where
   to find things in the "argframe" as returned by __builtin_apply_args.

   For some situations this is obvious just from the selector type
   encoding, but structures passed by value cause a problem because some
   architectures actually pass these by reference, i.e. use the
   structure-value-address mentioned in the gcc/config/_/_.h files.

   These differences are not encoded in the selector types.

   Below is my current guess for which architectures do this.
   xxx I really should do this properly by looking at the gcc config values.

   I've also been told that some architectures may pass structures with
   sizef(structure) > sizeof(void*) by reference, but pass smaller ones by
   value.  The code doesn't currently handle that case.
   */


char*
mframe_build_signature(const char *typePtr, int *size, int *narg, char *buf)
{
  MFRAME_ARGS	cum;
  BOOL		doMalloc = NO;
  const		char	*types;
  char		*start;
  char		*dest;
  int		total = 0;
  int		count = 0;

  /*
   *	If we have not been given a buffer - allocate space on the stack for
   *	the largest concievable type encoding.
   */
  if (buf == 0)
    {
      doMalloc = YES;
      buf = alloca((strlen(typePtr)+1)*16);
    }

  /*
   *	Copy the return type info (including qualifiers) into the buffer.
   */
  types = objc_skip_typespec(typePtr);
  strncpy(buf, typePtr, types - typePtr);
  buf[types-typePtr] = '\0';

  /*
   *	Point to the return type, initialise size of stack args, and skip
   *	to the first argument.
   */
  types = objc_skip_type_qualifiers(typePtr);
  MFRAME_INIT_ARGS(cum, types);
  types = objc_skip_typespec(types);
  if (*types == '+')
    {
      types++;
    }
  if (*types == '-')
    {
      types++;
    }
  while (isdigit(*types))
    {
      types++;
    }

  /*
   *	Where to start putting encoding information - leave enough room for
   *	the size of the stack args to be stored after the return type.
   */
  start = &buf[strlen(buf)+10];
  dest = start;

  /*
   *	Now step through all the arguments - copy any type qualifiers, but
   *	let the macro write all the other info into the buffer.
   */
  while (types && *types)
    {
      const char	*qual = types;

      /*
       *	If there are any type qualifiers - copy the through to the
       *	destination.
       */
      types = objc_skip_type_qualifiers(types);
      while (qual < types)
	{
	  *dest++ = *qual++;
	}
      MFRAME_ARG_ENCODING(cum, types, total, dest);
      count++;
    }
  *dest = '\0';

  /*
   *	Write the total size of the stack arguments after the return type,
   *	then copy the remaining type information to fill the gap.
   */
  sprintf(&buf[strlen(buf)], "%d", total);
  dest = &buf[strlen(buf)];
  while (*start)
    {
      *dest++ = *start++;
    }
  *dest = '\0';

  /*
   *	If we have written into a local buffer - we need to allocate memory
   *	in which to return our result.
   */
  if (doMalloc)
    {
      char	*tmp = NSZoneMalloc(NSDefaultMallocZone(), dest - buf + 1);

      strcpy(tmp, buf);
      buf = tmp;
    }

  /*
   *	If the caller wants to know the total size of the stack and/or the
   *	number of arguments, return them in the appropriate variables.
   */
  if (size)
    {
      *size = total;
    }
  if (narg)
    {
      *narg = count;
    }
  return buf;
}


/* Step through method encoding information extracting details.
 * If outTypes is non-nul then we copy the argument type into
 * the buffer as a nul terminated string and use the values in
 * this buffer as the types in info, rather than pointers to
 * positions in typePtr
 */
const char *
mframe_next_arg(const char *typePtr, NSArgumentInfo *info, char *outTypes)
{
  NSArgumentInfo	local;
  BOOL			flag;
  BOOL			negative = NO;

  if (info == 0)
    {
      info = &local;
    }
  /*
   *	Skip past any type qualifiers - if the caller wants them, return them.
   */
  flag = YES;
  info->qual = 0;
  while (flag)
    {
      switch (*typePtr)
	{
	  case _C_CONST:  info->qual |= _F_CONST; break;
	  case _C_IN:     info->qual |= _F_IN; break;
	  case _C_INOUT:  info->qual |= _F_INOUT; break;
	  case _C_OUT:    info->qual |= _F_OUT; break;
	  case _C_BYCOPY: info->qual |= _F_BYCOPY; break;
#ifdef	_C_BYREF
	  case _C_BYREF:  info->qual |= _F_BYREF; break;
#endif
	  case _C_ONEWAY: info->qual |= _F_ONEWAY; break;
#ifdef	_C_GCINVISIBLE
	  case _C_GCINVISIBLE:  info->qual |= _F_GCINVISIBLE; break;
#endif
	  default: flag = NO;
	}
      if (flag)
	{
	  typePtr++;
	}
    }

  info->type = typePtr;

  /*
   *	Scan for size and alignment information.
   */
  switch (*typePtr++)
    {
      case _C_ID:
	info->size = sizeof(id);
	info->align = __alignof__(id);
	break;

      case _C_CLASS:
	info->size = sizeof(Class);
	info->align = __alignof__(Class);
	break;

      case _C_SEL:
	info->size = sizeof(SEL);
	info->align = __alignof__(SEL);
	break;

      case _C_CHR:
	info->size = sizeof(char);
	info->align = __alignof__(char);
	break;

      case _C_UCHR:
	info->size = sizeof(unsigned char);
	info->align = __alignof__(unsigned char);
	break;

      case _C_SHT:
	info->size = sizeof(short);
	info->align = __alignof__(short);
	break;

      case _C_USHT:
	info->size = sizeof(unsigned short);
	info->align = __alignof__(unsigned short);
	break;

      case _C_INT:
	info->size = sizeof(int);
	info->align = __alignof__(int);
	break;

      case _C_UINT:
	info->size = sizeof(unsigned int);
	info->align = __alignof__(unsigned int);
	break;

      case _C_LNG:
	info->size = sizeof(long);
	info->align = __alignof__(long);
	break;

      case _C_ULNG:
	info->size = sizeof(unsigned long);
	info->align = __alignof__(unsigned long);
	break;

      case _C_LNG_LNG:
	info->size = sizeof(long long);
	info->align = __alignof__(long long);
	break;

      case _C_ULNG_LNG:
	info->size = sizeof(unsigned long long);
	info->align = __alignof__(unsigned long long);
	break;

      case _C_FLT:
	info->size = sizeof(float);
	info->align = __alignof__(float);
	break;

      case _C_DBL:
	info->size = sizeof(double);
	info->align = __alignof__(double);
	break;

      case _C_PTR:
	info->size = sizeof(char*);
	info->align = __alignof__(char*);
	if (*typePtr == '?')
	  {
	    typePtr++;
	  }
	else
	  {
	    typePtr = objc_skip_typespec(typePtr);
	  }
	break;

      case _C_ATOM:
      case _C_CHARPTR:
	info->size = sizeof(char*);
	info->align = __alignof__(char*);
	break;

      case _C_ARY_B:
	{
	  int	length = atoi(typePtr);

	  while (isdigit(*typePtr))
	    {
	      typePtr++;
	    }
	  typePtr = mframe_next_arg(typePtr, &local, 0);
	  info->size = length * ROUND(local.size, local.align);
	  info->align = local.align;
	  typePtr++;	/* Skip end-of-array	*/
	}
	break;

      case _C_STRUCT_B:
	{
	  unsigned int acc_size = 0;
	  unsigned int def_align = objc_alignof_type(typePtr-1);
	  unsigned int acc_align = def_align;
	  const char	*ptr = typePtr;

	  /*
	   *	Skip "<name>=" stuff.
	   */
	  while (*ptr != _C_STRUCT_E && *ptr != '=') ptr++;
	  if (*ptr == '=') typePtr = ptr;
	  typePtr++;

	  /*
	   *	Base structure alignment on first element.
	   */
	  if (*typePtr != _C_STRUCT_E)
	    {
	      typePtr = mframe_next_arg(typePtr, &local, 0);
	      if (typePtr == 0)
		{
		  return 0;		/* error	*/
		}
	      acc_size = ROUND(acc_size, local.align);
	      acc_size += local.size;
	      acc_align = MAX(local.align, def_align);
	    }
	  /*
	   *	Continue accumulating structure size
	   *	and adjust alignment if necessary
	   */
	  while (*typePtr != _C_STRUCT_E)
	    {
	      typePtr = mframe_next_arg(typePtr, &local, 0);
	      if (typePtr == 0)
		{
		  return 0;		/* error	*/
		}
	      acc_size = ROUND(acc_size, local.align);
	      acc_size += local.size;
	      acc_align = MAX(local.align, acc_align);
	    }
	  /*
	   * Size must be a multiple of alignment
	   */
	  if (acc_size % acc_align != 0)
	    {
	      acc_size += acc_align - acc_size % acc_align;
	    }
	  info->size = acc_size;
	  info->align = acc_align;
	  typePtr++;	/* Skip end-of-struct	*/
	}
	break;

      case _C_UNION_B:
	{
	  unsigned int	max_size = 0;
	  unsigned int	max_align = 0;

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
	  while (*typePtr != _C_UNION_E)
	    {
	      typePtr = mframe_next_arg(typePtr, &local, 0);
	      if (typePtr == 0)
		{
		  return 0;		/* error	*/
		}
	      max_size = MAX(max_size, local.size);
	      max_align = MAX(max_align, local.align);
	    }
	  info->size = max_size;
	  info->align = max_align;
	  typePtr++;	/* Skip end-of-union	*/
	}
	break;

      case _C_VOID:
	info->size = 0;
	info->align = __alignof__(char*);
	break;

      default:
	return 0;
    }

  if (typePtr == 0)
    {		/* Error condition.	*/
      return 0;
    }

  /* Copy tye type information into the buffer if provided.
   */
  if (outTypes != 0)
    {
      unsigned	len = typePtr - info->type;

      strncpy(outTypes, info->type, len);
      outTypes[len] = '\0';
      info->type = outTypes;
    }

  /*
   *	May tell the caller if the item is stored in a register.
   */
  if (*typePtr == '+')
    {
      typePtr++;
      info->isReg = YES;
    }
  else
    {
      info->isReg = NO;
    }
  /*
   * Cope with negative offsets.
   */
  if (*typePtr == '-')
    {
      typePtr++;
      negative = YES;
    }
  /*
   *	May tell the caller what the stack/register offset is for
   *	this argument.
   */
  info->offset = 0;
  while (isdigit(*typePtr))
    {
      info->offset = info->offset * 10 + (*typePtr++ - '0');
    }
  if (negative == YES)
    {
      info->offset = -info->offset;
    }

  return typePtr;
}


/* Return the number of arguments that the method MTH expects.  Note
   that all methods need two implicit arguments `self' and `_cmd'.  */

int
method_types_get_number_of_arguments (const char *type)
{
  int i = 0;

  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
}


/* Return the size of the argument block needed on the stack to invoke
  the method MTH.  This may be zero, if all arguments are passed in
  registers.  */

int
method_types_get_size_of_stack_arguments (const char *type)
{
  type = objc_skip_typespec (type);
  return atoi (type);
}

int
method_types_get_size_of_register_arguments(const char *types)
{
  const char* type = strrchr(types, '+');

  if (type)
    {
      return atoi(++type) + sizeof(void*);
    }
  else
    {
      return 0;
    }
}

