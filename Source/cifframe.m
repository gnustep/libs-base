/* cifframe.m - Wrapper/Objective-C interface for ffi function interface

   Copyright (C) 1999, Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@gnu.org>
   Created: Dec 1999
   
   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <config.h>
#include <stdlib.h>
#include "cifframe.h"
#include <Foundation/NSException.h>

#if defined(ALPHA) || (defined(MIPS) && (_MIPS_SIM == _ABIN32))
typedef long long smallret_t;
#else
typedef int smallret_t;
#endif

/* Return the number of arguments that the method MTH expects.  Note
   that all methods need two implicit arguments `self' and `_cmd'.  
   From mframe.m */
extern int method_types_get_number_of_arguments (const char *type);

extern BOOL sel_types_match(const char* t1, const char* t2);

const char *cifframe_next_arg(const char *typePtr, ffi_type **ftype_ret);

cifframe_t *
cifframe_from_sig (const char *typePtr, void **retval)
{
  int i;
  cifframe_t *cframe;

  cframe = malloc(sizeof(cifframe_t));
  cframe->nargs = method_types_get_number_of_arguments(typePtr);
  cframe->args = malloc(cframe->nargs * sizeof(ffi_type));

  typePtr = cifframe_next_arg(typePtr, &cframe->rtype);
  for (i = 0; i < cframe->nargs; i++)
    typePtr = cifframe_next_arg(typePtr, &cframe->args[i]);

  if (ffi_prep_cif(&cframe->cif, FFI_DEFAULT_ABI, cframe->nargs,
		   cframe->rtype, cframe->args) != FFI_OK)
    {
      free(cframe->args);
      free(cframe);
      cframe = NULL;
    }

  if (cframe)
    {
      cframe->values = malloc(cframe->nargs * sizeof(void *));
      for (i = 0; i < cframe->nargs; i++)
	cframe->values[i] = malloc(cframe->args[i]->size);
    }

  if (retval)
    {
      *retval = NSZoneMalloc(NSDefaultMallocZone(), 
			    MAX(cframe->rtype->size, sizeof(smallret_t)) );
    }
  return cframe;
}

void
cifframe_free(cifframe_t *cframe)
{
  int i;
  if (cframe->rtype->type == FFI_TYPE_STRUCT)
    free(cframe->rtype->elements);
  for (i = 0; i < cframe->nargs; i++)
    {
      free(cframe->values[i]);
      cframe->values[i] = 0;
      if (cframe->args[i]->type == FFI_TYPE_STRUCT)
	free(cframe->rtype->elements);
    }

  cframe->nargs = 0;
  free(cframe->args);
  free(cframe->values);
  free(cframe);
}

void
cifframe_set_arg(cifframe_t *cframe, int index, void *buffer)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(cframe->values[index], buffer, cframe->args[index]->size);
}

void
cifframe_get_arg(cifframe_t *cframe, int index, void *buffer)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(buffer, cframe->values[index], cframe->args[index]->size);
}

void *
cifframe_arg_addr(cifframe_t *cframe, int index)
{
  if (index < 0 || index >= cframe->nargs)
     return NULL;
  return cframe->values[index];
}

/*
 *      Step through method encoding information extracting details.
 */
const char *
cifframe_next_arg(const char *typePtr, ffi_type **ftype_ret)
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
      case _C_SHT: ftype = &ffi_type_sshort;
	break;
      case _C_USHT: ftype = &ffi_type_ushort;
	break;
      case _C_INT: ftype = &ffi_type_sint;
	break;
      case _C_UINT: ftype = &ffi_type_uint;
	break;
      case _C_LNG: ftype = &ffi_type_slong;
	break;
      case _C_ULNG: ftype = &ffi_type_ulong;
	break;
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG: ftype = 0;
	NSCAssert(ftype, @"long long encoding not implemented");
	break;
      case _C_ULNG_LNG: ftype = 0;
	NSCAssert(ftype, @"long long encoding not implemented");
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
	    ffi_type *local;
	    typePtr = cifframe_next_arg(typePtr, &local);
	  }
	break;

      case _C_ATOM:
      case _C_CHARPTR:
	ftype = &ffi_type_pointer;
	break;

      case _C_ARY_B:
	{
	  ffi_type *local;
	  ftype = &ffi_type_pointer;

	  while (isdigit(*typePtr))
	    {
	      typePtr++;
	    }
	  typePtr = cifframe_next_arg(typePtr, &local);
	  typePtr++;	/* Skip end-of-array	*/
	}
	break; 

      case _C_STRUCT_B:
	{
	  int types, maxtypes;
	  ffi_type *local;

	  ftype = malloc(sizeof(ffi_type));
	  ftype->size = 0;
	  ftype->alignment = 0;
	  ftype->type = FFI_TYPE_STRUCT;
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
	  types = 0;
	  maxtypes = 4;
	  ftype->elements = malloc(maxtypes*sizeof(ffi_type));
	  /*
	   *	Continue accumulating structure size.
	   */
	  while (*typePtr != _C_STRUCT_E)
	    {
	      typePtr = cifframe_next_arg(typePtr, &local);
	      NSCAssert(typePtr, @"End of signature while parsing");
	      ftype->elements[types++] = local;
	      if (types >= maxtypes)
		{
		  maxtypes *=2;
		  ftype->elements = realloc(ftype->elements, 
					    maxtypes*sizeof(ffi_type));
		}
	    }
	  ftype->elements[types] = NULL;
	  typePtr++;	/* Skip end-of-struct	*/
	}
	break;

      case _C_UNION_B:
	{
	  ffi_type *local;
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
	      int align = objc_alignof_type(typePtr);
	      typePtr = cifframe_next_arg(typePtr, &local);
	      NSCAssert(typePtr, @"End of signature while parsing");
	      if (align > max_align)
		{
		  if (ftype && ftype->type == FFI_TYPE_STRUCT)
		    free(ftype->elements);
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

  NSCAssert(typePtr, @"Unfinished signature");
  *ftype_ret = ftype;
  return typePtr;
}

/* Some return types actually get coded differently. We need to convert 
   back to the expected return type */
BOOL
cifframe_decode_return (const char *type, void* buffer)
{
  int	size = 0;

  type = objc_skip_type_qualifiers(type);
  NSGetSizeAndAlignment(type, &size, 0);

  switch (*type)
    {
    case _C_ID:
      break;
    case _C_CLASS:
      break;
    case _C_SEL:
      break;
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

    case _C_LNG:
    case _C_ULNG:
      break;

    case _C_LNG_LNG:
    case _C_ULNG_LNG:
      break;

    case _C_FLT:
      break;

    case _C_DBL:
      break;

    case _C_PTR:
    case _C_ATOM:
    case _C_CHARPTR:
      break;

    case _C_ARY_B:
    case _C_STRUCT_B:
    case _C_UNION_B:
      break;

    case _C_VOID:
      break;

    default:
      return NO;		/* Unknown type.	*/
    }
  return YES;
}


/*-------------------------------------------------------------------------*/
/* Functions for handling sending and receiving messages accross a 
   connection
*/

/* cifframe_do_call()

   This function decodes the arguments of method call, builds an
   argframe of type arglist_t, and invokes the method using
   __builtin_apply; then it encodes the return value and any
   pass-by-reference arguments.

   ENCODED_TYPES should be a string that describes the return value
   and arguments.  It's argument types and argument type qualifiers
   should match exactly those that were used when the arguments were
   encoded with cifframe_dissect_call()---cifframe_do_call() uses
   ENCODED_TYPES to determine which variable types it should decode.

   ENCODED_TYPES is used to get the types and type qualifiers, but not
   to get the register and stack locations---we get that information
   from the selector type of the SEL that is decoded as the second
   argument.  In this way, the ENCODED_TYPES may come from a machine
   of a different architecture.  Having the original ENCODED_TYPES is
   good, just in case the machine running cifframe_do_call() has some
   slightly different qualifiers.  Using different qualifiers for
   encoding and decoding could lead to massive confusion.


   DECODER should be a pointer to a function that obtains the method's
   argument values.  For example:

     void my_decoder (int argnum, void *data, const char *type)

     ARGNUM is the number of the argument, beginning at 0.
     DATA is a pointer to the memory where the value should be placed.
     TYPE is a pointer to the type string of this value.

     cifframe_do_call() calls this function once for each of the methods
     arguments.  The DECODER function should place the ARGNUM'th
     argument's value at the memory location DATA.
     cifframe_do_call() calls this function once with ARGNUM -1, DATA 0,
     and TYPE 0 to denote completion of decoding.


     If DECODER malloc's new memory in the course of doing its
     business, then DECODER is responsible for making sure that the
     memory will get free eventually.  For example, if DECODER uses
     -decodeValueOfCType:at:withName: to decode a char* string, you
     should remember that -decodeValueOfCType:at:withName: malloc's
     new memory to hold the string, and DECODER should autorelease the
     malloc'ed pointer, using the NSData class.


   ENCODER should be a pointer to a function that records the method's
   return value and pass-by-reference values.  For example:

     void my_encoder (int argnum, void *data, const char *type, int flags)

     ARGNUM is the number of the argument; this will be -1 for the
       return value, and the argument index for the pass-by-reference
       values; the indices start at 0.
     DATA is a pointer to the memory where the value can be found.
     TYPE is a pointer to the type string of this value.
     FLAGS is a copy of the type qualifier flags for this argument; 
       (see <objc/objc-api.h>).

     cifframe_do_call() calls this function after the method has been
     run---once for the return value, and once for each of the
     pass-by-reference parameters.  The ENCODER function should place
     the value at memory location DATA wherever the user wants to
     record the ARGNUM'th return value.

  PASS_POINTERS is a flag saying whether pointers should be passed
  as pointers (for local stuff) or should be assumed to point to a
  single data item (for distributed objects).
*/

void
cifframe_do_call_opts (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int),
		BOOL pass_pointers)
{
  /* The method type string obtained from the target's OBJC_METHOD 
     structure for the selector we're sending. */
  const char *type;
  /* A pointer into the local variable TYPE string. */
  const char *tmptype;
  /* A pointer into the argument ENCODED_TYPES string. */
  const char *etmptype;
  /* The target object that will receive the message. */
  id object;
  /* The selector for the message we're sending to the TARGET. */
  SEL selector;
  /* The OBJECT's implementation of the SELECTOR. */
  IMP method_implementation;
  /* A pointer into the ARGFRAME; points at individual arguments. */
  char *datum;
  /* Type qualifier flags; see <objc/objc-api.h>. */
  unsigned flags;
  /* Which argument number are we processing now? */
  int argnum;
  /* A pointer to the memory holding the return value of the method. */
  void *retval;
  /* The cif information for calling the method */
  cifframe_t *cframe;
  /* Does the method have any arguments that are passed by reference?
     If so, we need to encode them, since the method may have changed them. */
  BOOL out_parameters = NO;

  /* Decode the object, (which is always the first argument to a method),
     into the local variable OBJECT. */
  (*decoder) (0, &object, @encode(id));
  NSCParameterAssert (object);

  /* Decode the selector, (which is always the second argument to a
     method), into the local variable SELECTOR. */
  /* xxx @encode(SEL) produces "^v" in gcc 2.5.8.  It should be ":" */
  (*decoder) (1, &selector, ":");
  NSCParameterAssert (selector);

  /* Get the "selector type" for this method.  The "selector type" is
     a string that lists the return and argument types, and also
     indicates in which registers and where on the stack the arguments
     should be placed before the method call.  The selector type
     string we get here should have the same argument and return types
     as the ENCODED_TYPES string, but it will have different register
     and stack locations if the ENCODED_TYPES came from a machine of a
     different architecture. */
#if NeXT_runtime
  {
    Method m;
    m = class_getInstanceMethod(object->isa, selector);
    if (!m) 
      abort();
    type = m->method_types;
  }
#elif 0
  {
    Method_t m;
    m = class_get_instance_method (object->class_pointer,
				   selector);
    NSCParameterAssert (m);
    type = m->method_types;
  }
#else
  type = sel_get_type (selector);
#endif /* NeXT_runtime */

  /* Make sure we successfully got the method type, and that its
     types match the ENCODED_TYPES. */
  NSCParameterAssert (type);
  NSCParameterAssert (sel_types_match(encoded_types, type));

  /* Build the cif frame */
  cframe = cifframe_from_sig(type, &retval);

  /* Put OBJECT and SELECTOR into the ARGFRAME. */

  /* Initialize our temporary pointers into the method type strings. */
  tmptype = objc_skip_argspec (type);
  etmptype = objc_skip_argspec (encoded_types);
  NSCParameterAssert (*tmptype == _C_ID);
  /* Put the target object there. */
  cifframe_set_arg(cframe, 0, &object);
  /* Get a pointer into ARGFRAME, pointing to the location where the
     second argument is to be stored. */
  tmptype = objc_skip_argspec (tmptype);
  etmptype = objc_skip_argspec(etmptype);
  NSCParameterAssert (*tmptype == _C_SEL);
  /* Put the selector there. */
  cifframe_set_arg(cframe, 1, &selector);


  /* Decode arguments after OBJECT and SELECTOR, and put them into the
     ARGFRAME.  Step TMPTYPE and ETMPTYPE in lock-step through their
     method type strings. */

  for (tmptype = objc_skip_argspec (tmptype),
       etmptype = objc_skip_argspec (etmptype), argnum = 2;
       *tmptype != '\0';
       tmptype = objc_skip_argspec (tmptype),
       etmptype = objc_skip_argspec (etmptype), argnum++)
    {
      /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
      flags = objc_get_type_qualifiers (etmptype);
      /* Skip over the type qualifiers, so now TYPE is pointing directly
	 at the char corresponding to the argument's type, as defined
	 in <objc/objc-api.h> */
      tmptype = objc_skip_type_qualifiers(tmptype);

      datum = cifframe_arg_addr(cframe, argnum);

      /* Decide how, (or whether or not), to decode the argument
	 depending on its FLAGS and TMPTYPE.  Only the first two cases
	 involve parameters that may potentially be passed by
	 reference, and thus only the first two may change the value
	 of OUT_PARAMETERS.  *** Note: This logic must match exactly
	 the code in cifframe_dissect_call(); that function should
	 encode exactly what we decode here. *** */

      switch (*tmptype)
	{

	case _C_CHARPTR:
	  /* Handle a (char*) argument. */
	  /* If the char* is qualified as an OUT parameter, or if it
	     not explicitly qualified as an IN parameter, then we will
	     have to get this char* again after the method is run,
	     because the method may have changed it.  Set
	     OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  /* If the char* is qualified as an IN parameter, or not
	     explicity qualified as an OUT parameter, then decode it.
	     Note: the decoder allocates memory for holding the
	     string, and it is also responsible for making sure that
	     the memory gets freed eventually, (usually through the
	     autorelease of NSData object). */
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*decoder) (argnum, datum, tmptype);

	  break;

	case _C_PTR:
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  if (pass_pointers)
	    {
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*decoder) (argnum, datum, tmptype);
	    }
	  else
	    {
	      /* Handle an argument that is a pointer to a non-char.  But
		 (void*) and (anything**) is not allowed. */
	      /* The argument is a pointer to something; increment TYPE
		   so we can see what it is a pointer to. */
	      tmptype++;
	      /* Allocate some memory to be pointed to, and to hold the
		 value.  Note that it is allocated on the stack, and
		 methods that want to keep the data pointed to, will have
		 to make their own copies. */
	      *(void**)datum = alloca (objc_sizeof_type (tmptype));
	      /* If the pointer's value is qualified as an IN parameter,
		 or not explicity qualified as an OUT parameter, then
		 decode it. */
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*decoder) (argnum, *(void**)datum, tmptype);
	    }
	  break;

	case _C_STRUCT_B:
	case _C_UNION_B:
	case _C_ARY_B:
	  /* Handle struct and array arguments. */
	  (*decoder) (argnum, datum, tmptype);
	  break;

	default:
	  /* Handle arguments of all other types. */
	  /* NOTE FOR OBJECTS: Unlike [Decoder decodeObjectAt:..],
	     this function does not generate a reference to the
	     object; the object may be autoreleased; if the method
	     wants to keep a reference to the object, it will have to
	     -retain it. */
	  (*decoder) (argnum, datum, tmptype);
	}
    }
  /* End of the for() loop that enumerates the method's arguments. */
  (*decoder) (-1, 0, 0);


  /* Invoke the method! */

  /* Find the target object's implementation of this selector. */
  method_implementation = objc_msg_lookup (object, selector);
  NSCParameterAssert (method_implementation);
  /* Do it!  Send the message to the target, and get the return value
     in retval.  We need to rencode any pass-by-reference info */
  ffi_call(&(cframe->cif), FFI_FN(method_implementation), retval,
	   cframe->values);

  /* Encode the return value and pass-by-reference values, if there
     are any.  This logic must match exactly that in
     cifframe_build_return(). */
  /* OUT_PARAMETERS should be true here in exactly the same
     situations as it was true in cifframe_dissect_call(). */

  /* Get the qualifier type of the return value. */
  flags = objc_get_type_qualifiers (encoded_types);
  /* Get the return type; store it our two temporary char*'s. */
  etmptype = objc_skip_type_qualifiers (encoded_types);
  tmptype = objc_skip_type_qualifiers (type);

  /* Only encode return values if there is a non-void return value,
     a non-oneway void return value, or if there are values that were
     passed by reference. */

  /* If there is a return value, encode it. */
  cifframe_decode_return(tmptype, retval);
  switch (*tmptype)
    {
    case _C_VOID:
      if ((flags & _F_ONEWAY) == 0)
	{
	   int	dummy = 0;
          (*encoder) (-1, (void*)&dummy, @encode(int), 0);
	}
      /* No return value to encode; do nothing. */
      break;

    case _C_PTR:
      if (pass_pointers)
	{
	  (*encoder) (-1, retval, tmptype, flags);
	}
      else
	{
	  /* The argument is a pointer to something; increment TYPE
	     so we can see what it is a pointer to. */
	  tmptype++;
	  /* Encode the value that was pointed to. */
	  (*encoder) (-1, *(void**)retval, tmptype, flags);
	}
      break;

    case _C_STRUCT_B:
    case _C_UNION_B:
    case _C_ARY_B:
      /* The argument is a structure or array returned by value.
	 (In C, are array's allowed to be returned by value?) */
      (*encoder)(-1, retval, tmptype, flags);
      break;

    case _C_FLT:
      {
	(*encoder) (-1, retval, tmptype, flags);
	break;
      }

    case _C_DBL:
      {
	(*encoder) (-1, retval, tmptype, flags);
	break;
      }

    case _C_SHT:
    case _C_USHT:
      {
	(*encoder) (-1, retval, tmptype, flags);
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      {
	(*encoder) (-1, retval, tmptype, flags);
	break;
      }

    default:
      /* case _C_INT: case _C_UINT: case _C_LNG: case _C_ULNG:
	 case _C_CHARPTR: case: _C_ID: */
      /* xxx I think this assumes that sizeof(int)==sizeof(void*) */
      (*encoder) (-1, retval, tmptype, flags);
    }


  /* Encode the values returned by reference.  Note: this logic
     must match exactly the code in cifframe_build_return(); that
     function should decode exactly what we encode here. */

  if (out_parameters)
    {
      /* Step through all the arguments, finding the ones that were
	 passed by reference. */
      for (tmptype = objc_skip_argspec (tmptype),
	     argnum = 0,
	     etmptype = objc_skip_argspec (etmptype);
	   *tmptype != '\0';
	   tmptype = objc_skip_argspec (tmptype),
	     argnum++,
	     etmptype = objc_skip_argspec (etmptype))
	{
	  /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
	  flags = objc_get_type_qualifiers(etmptype);
	  /* Skip over the type qualifiers, so now TYPE is pointing directly
	     at the char corresponding to the argument's type, as defined
	     in <objc/objc-api.h> */
	  tmptype = objc_skip_type_qualifiers (tmptype);

	  /* Decide how, (or whether or not), to encode the argument
	     depending on its FLAGS and TMPTYPE. */
	  datum = cifframe_arg_addr(cframe, argnum);

	  if ((*tmptype == _C_PTR) 
	      && ((flags & _F_OUT) || !(flags & _F_IN)))
	    {
	      /* The argument is a pointer (to a non-char), and the
		 pointer's value is qualified as an OUT parameter, or
		 it not explicitly qualified as an IN parameter, then
		 it is a pass-by-reference argument.*/
	      /* The argument is a pointer to something; increment TYPE
		 so we can see what it is a pointer to. */
	      tmptype++;
	      /* Encode it. */
	      (*encoder) (argnum, *(void**)datum, tmptype, flags);
	    }
	  else if (*tmptype == _C_CHARPTR
		   && ((flags & _F_OUT) || !(flags & _F_IN)))
	    {
	      /* The argument is a pointer char string, and the
		 pointer's value is qualified as an OUT parameter, or
		 it not explicitly qualified as an IN parameter, then
		 it is a pass-by-reference argument.  Encode it.*/
	      /* xxx Perhaps we could save time and space by saving
		 a copy of the string before the method call, and then
		 comparing it to this string; if it didn't change, don't
		 bother to send it back again. */
	      (*encoder) (argnum, datum, tmptype, flags);
	    }
	}
    }

  return;
}

void
cifframe_do_call (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int))
{
  cifframe_do_call_opts(encoded_types, decoder, encoder, NO);
}
