/** cifframe.m - Wrapper/Objective-C interface for ffi function interface

   Copyright (C) 1999, Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Dec 1999, rewritten Apr 2002
   
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
#include <Foundation/NSData.h>
#include <base/GSInvocation.h>

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
extern BOOL sel_types_match(const char* t1, const char* t2);

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
  if (rtype && rtype->size > 0)
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
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), full, 1);
      if (cframe && retval)
	{
	  *retval = buf + pos;
	}
    }
  else
    {
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), size, 1);
    }

  if (cframe)
    {
      cframe->nargs = numargs;
      cframe->arg_types = buf + type_offset;
      memcpy(cframe->arg_types, arg_types, sizeof(ffi_type *) * numargs);
      cframe->values = buf + offset;
    }

  if (ffi_prep_cif(&cframe->cif, FFI_DEFAULT_ABI, cframe->nargs,
		   rtype, cframe->arg_types) != FFI_OK)
    {
      free(cframe);
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
	ftype = malloc(size + maxtypes*sizeof(ffi_type));
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
		ftype = realloc(ftype, size + maxtypes*sizeof(ffi_type));
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
		  free(ftype);
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
  if (advance)
    *advance = typePtr;

  return ftype;
}


/* Ugly hack to make it easier to invoke a method from outside
   an NSInvocation class. Hopefully simplication of NSConnection
   could remove this hack */
typedef struct _NSInvocation_t {
  @defs(NSInvocation)
} NSInvocation_t;

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

/* cifframe_do_call()

   This function decodes the arguments of method call, builds a
   cifframe, and invokes the method using GSFFIInvokeWithTargetAndImp
   then it encodes the return value and any pass-by-reference arguments.

   An entry, ctxt->type should be a string that describes the return value
   and arguments.  It's argument types and argument type qualifiers
   should match exactly those that were used when the arguments were
   encoded. cifframe_do_call() uses this information to determine
   which variable types it should decode.

   The type info is used to get the types and type qualifiers, but not
   to get the register and stack locations---we get that information
   from the selector type of the SEL that is decoded as the second
   argument.  In this way, the type info may come from a machine
   of a different architecture.  Having the original type info is
   good, just in case the machine running cifframe_do_call() has some
   slightly different qualifiers.  Using different qualifiers for
   encoding and decoding could lead to massive confusion.


   DECODER should be a pointer to a function that obtains the method's
   argument values.  For example:

     void my_decoder (DOContext *ctxt)

     CTXT contains the context information for the item to decode.

     cifframe_do_call() calls this function once for each of the methods
     arguments.  The DECODER function should place the ARGNUM'th
     argument's value at the memory location ctxt->datum.
     cifframe_do_call() calls this function once with ctxt->datum 0,
     and ctxt->type 0 to denote completion of decoding.


     If DECODER malloc's new memory in the course of doing its
     business, then DECODER is responsible for making sure that the
     memory will get free eventually.  For example, if DECODER uses
     -decodeValueOfCType:at:withName: to decode a char* string, you
     should remember that -decodeValueOfCType:at:withName: malloc's
     new memory to hold the string, and DECODER should autorelease the
     malloc'ed pointer, using the NSData class.


   ENCODER should be a pointer to a function that records the method's
   return value and pass-by-reference values.  For example:

     void my_encoder (DOContext *ctxt)

     CTXT contains the context information for the item to encode.

     cifframe_do_call() calls this function after the method has been
     run---once for the return value, and once for each of the
     pass-by-reference parameters.  The ENCODER function should place
     the value at memory location ctxt->datum wherever the user wants to
     record the ARGNUM'th return value.

*/

void
cifframe_do_call (DOContext *ctxt,
		void(*decoder)(DOContext*),
		void(*encoder)(DOContext*))
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
  /* Type qualifier flags; see <objc/objc-api.h>. */
  unsigned flags;
  /* Which argument number are we processing now? */
  int argnum;
  /* The cif information for calling the method */
  cifframe_t *cframe;
  /* Does the method have any arguments that are passed by reference?
     If so, we need to encode them, since the method may have changed them. */
  BOOL out_parameters = NO;
  /* A dummy invocation to pass to the function that invokes our method */
  NSInvocation_t *inv;
  /* Signature information */
  NSMethodSignature *sig;
  void	*retval;
  const char *encoded_types = ctxt->type;

  /* Decode the object, (which is always the first argument to a method),
     into the local variable OBJECT. */
  ctxt->type = @encode(id);
  ctxt->datum = &object;
  (*decoder) (ctxt);
  NSCParameterAssert (object);

  /* Decode the selector, (which is always the second argument to a
     method), into the local variable SELECTOR. */
  /* xxx @encode(SEL) produces "^v" in gcc 2.5.8.  It should be ":" */
  ctxt->type = @encode(SEL);
  ctxt->datum = &selector;
  (*decoder) (ctxt);
  NSCParameterAssert (selector);

  /* Get the "selector type" for this method.  The "selector type" is
     a string that lists the return and argument types, and also
     indicates in which registers and where on the stack the arguments
     should be placed before the method call.  The selector type
     string we get here should have the same argument and return types
     as the ENCODED_TYPES string, but it will have different register
     and stack locations if the ENCODED_TYPES came from a machine of a
     different architecture. */
#if NeXT_RUNTIME
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
  sig = [NSMethodSignature signatureWithObjCTypes: type];
  cframe = cifframe_from_info([sig methodInfo], [sig numberOfArguments], 
			       &retval);
  ctxt->datToFree = cframe;

  /* Put OBJECT and SELECTOR into the ARGFRAME. */

  /* Initialize our temporary pointers into the method type strings. */
  tmptype = objc_skip_argspec (type);
  etmptype = objc_skip_argspec (encoded_types);
  NSCParameterAssert (*tmptype == _C_ID);
  /* Put the target object there. */
  cifframe_set_arg(cframe, 0, &object, sizeof(id));
  /* Get a pointer into ARGFRAME, pointing to the location where the
     second argument is to be stored. */
  tmptype = objc_skip_argspec (tmptype);
  etmptype = objc_skip_argspec(etmptype);
  NSCParameterAssert (*tmptype == _C_SEL);
  /* Put the selector there. */
  cifframe_set_arg(cframe, 1, &selector, sizeof(SEL));


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

      /*
       * Setup information in context.
       */
      ctxt->datum = cifframe_arg_addr(cframe, argnum);
      ctxt->type = tmptype;
      ctxt->flags = flags;

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
	    (*decoder) (ctxt);

	  break;

	case _C_PTR:
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;

	  /* Handle an argument that is a pointer to a non-char.  But
	     (void*) and (anything**) is not allowed. */
	  /* The argument is a pointer to something; increment TYPE
	       so we can see what it is a pointer to. */
	  tmptype++;
	  ctxt->type = tmptype;
	  /* Allocate some memory to be pointed to, and to hold the
	     value.  Note that it is allocated on the stack, and
	     methods that want to keep the data pointed to, will have
	     to make their own copies. */
	  *(void**)ctxt->datum = alloca (objc_sizeof_type (tmptype));
	  ctxt->datum = *(void**)ctxt->datum;
	  /* If the pointer's value is qualified as an IN parameter,
	     or not explicity qualified as an OUT parameter, then
	     decode it. */
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*decoder) (ctxt);
	  break;

	default:
	  /* Handle arguments of all other types. */
	  /* NOTE FOR OBJECTS: Unlike [Decoder decodeObjectAt:..],
	     this function does not generate a reference to the
	     object; the object may be autoreleased; if the method
	     wants to keep a reference to the object, it will have to
	     -retain it. */
	  (*decoder) (ctxt);
	}
    }
  /* End of the for() loop that enumerates the method's arguments. */
  ctxt->type = 0;
  ctxt->datum = 0;
  (*decoder) (ctxt);


  /* Invoke the method! */

  /* Find the target object's implementation of this selector. */
  method_implementation = objc_msg_lookup (object, selector);
  NSCParameterAssert (method_implementation);
  /* Do it!  Send the message to the target, and get the return value
     in retval.  We need to encode any pass-by-reference info */
  inv = (NSInvocation_t *)NSAllocateObject([NSInvocation class], 0, 
					   NSDefaultMallocZone());
  inv->_retval = retval;
  inv->_selector = selector;
  inv->_cframe = cframe;
  inv->_info = [sig methodInfo];
  inv->_numArgs = [sig numberOfArguments];
  ctxt->objToFree = (id)inv;
  GSFFIInvokeWithTargetAndImp((NSInvocation *)inv, object, 
				 method_implementation);
  ctxt->objToFree = nil;
  NSDeallocateObject((NSInvocation *)inv);

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

  ctxt->flags = flags;

  /* If there is a return value, encode it. */
  if (*tmptype == _C_VOID)
    {
      if ((flags & _F_ONEWAY) == 0)
	{
	  int	dummy = 0;

	  ctxt->type = @encode(int);
	  ctxt->datum = (void*)&dummy;
	  (*encoder) (ctxt);
	}
      /* No return value to encode; do nothing. */
    }
  else
    {
      if (*tmptype == _C_PTR)
	{
	  /* The argument is a pointer to something; increment TYPE
	     so we can see what it is a pointer to. */
	  tmptype++;
	  ctxt->type = tmptype;
	  ctxt->datum = *(void**)ctxt->datum;
	}
      else
	{
	  cifframe_decode_arg(tmptype, retval);
	  ctxt->type = tmptype;
	  ctxt->datum = retval;
	}
      /* Encode the value that was pointed to. */
      (*encoder) (ctxt);
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
	  if (((flags & _F_OUT) || !(flags & _F_IN))
	    && (*tmptype == _C_PTR || *tmptype == _C_CHARPTR))
	    {
	      ctxt->flags = flags;
	      ctxt->datum = cifframe_arg_addr(cframe, argnum);

	      if (*tmptype == _C_PTR) 
		{
		  /* The argument is a pointer (to a non-char), and the
		     pointer's value is qualified as an OUT parameter, or
		     it not explicitly qualified as an IN parameter, then
		     it is a pass-by-reference argument.*/
		  ctxt->type = ++tmptype;
		  ctxt->datum = *(void**)ctxt->datum;
		}
	      else if (*tmptype == _C_CHARPTR)
		{
		  ctxt->type = tmptype;
		  /* The argument is a pointer char string, and the
		     pointer's value is qualified as an OUT parameter, or
		     it not explicitly qualified as an IN parameter, then
		     it is a pass-by-reference argument. */
		}
	      (*encoder) (ctxt);
	    }
	}
    }

  NSZoneFree(NSDefaultMallocZone(), ctxt->datToFree);
  ctxt->datToFree = 0;

  return;
}

/* cifframe_build_return()

   This function decodes the values returned from a method call, 
   sets up the invocation with the return value, and updates the
   pass-by-reference arguments.  

   The callback function is finally called with the 'type' set to a null pointer
   to tell it that the return value and all return parameters have been
   dealt with.  This permits the function to do any tidying up necessary.  */

void
cifframe_build_return (NSInvocation *inv,
		     const char *type, 
		     BOOL out_parameters,
		     void(*decoder)(DOContext *ctxt),
		     DOContext *ctxt)
{
  /* Which argument number are we processing now? */
  int argnum;
  /* Type qualifier flags; see <objc/objc-api.h>. */
  int flags;
  /* A pointer into the TYPE string. */
  const char *tmptype;
  /* Points at individual arguments. */
  void *datum;
  const char *rettype;
  /* A pointer to the memory holding the return value of the method. */
  void *retval;
  /* Storage for the argument information */
  cifframe_t *cframe;
  /* Signature information */
  NSMethodSignature *sig;

  /* Build the cif frame */
  sig = [NSMethodSignature signatureWithObjCTypes: type];
  cframe = cifframe_from_info([sig methodInfo], [sig numberOfArguments], 
			       &retval);
  ctxt->datToFree = cframe;

  /* Get the return type qualifier flags, and the return type. */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);
  rettype = tmptype;

  /* Decode the return value and pass-by-reference values, if there
     are any.  OUT_PARAMETERS should be the value returned by
     cifframe_dissect_call(). */
  if (out_parameters || *tmptype != _C_VOID || (flags & _F_ONEWAY) == 0)
    /* xxx What happens with method declared "- (oneway) foo: (out int*)ip;" */
    /* xxx What happens with method declared "- (in char *) bar;" */
    /* xxx Is this right?  Do we also have to check _F_ONEWAY? */
    {
      /* ARGNUM == -1 signifies to DECODER() that this is the return
         value, not an argument. */

      /* If there is a return value, decode it, and put it in retval. */
      if (*tmptype != _C_VOID || (flags & _F_ONEWAY) == 0)
	{	  
	  ctxt->type = tmptype;
	  ctxt->datum = retval;
	  ctxt->flags = flags;

	  switch (*tmptype)
	    {
	    case _C_PTR:
	      {
		unsigned retLength;

		/* We are returning a pointer to something. */
		/* Increment TYPE so we can see what it is a pointer to. */
		tmptype++;
		retLength = objc_sizeof_type(tmptype);
		/* Allocate memory to hold the value we're pointing to. */
		*(void**)retval = 
		  NSZoneCalloc(NSDefaultMallocZone(), retLength, 1);
		/* We are responsible for making sure this memory gets free'd
		   eventually.  Ask NSData class to autorelease it. */
		[NSData dataWithBytesNoCopy: *(void**)retval
				     length: retLength];
		ctxt->type = tmptype;
		ctxt->datum = *(void**)retval;
		/* Decode the return value into the memory we allocated. */
		(*decoder) (ctxt);
	      }
	      break;

	    case _C_STRUCT_B: 
	    case _C_UNION_B:
	    case _C_ARY_B:
	      /* Decode the return value into the memory we allocated. */
	      (*decoder) (ctxt);
	      break;

	    case _C_FLT: 
	    case _C_DBL:
	      (*decoder) (ctxt);
	      break;

	    case _C_VOID:
		{
		  ctxt->type = @encode(int);
		  ctxt->flags = 0;
		  (*decoder) (ctxt);
		}
		break;

	    default:
		(*decoder) (ctxt);
	    }
	}
      [inv setReturnValue: retval];

      /* Decode the values returned by reference.  Note: this logic
	 must match exactly the code in cifframe_do_call(); that
	 function should decode exactly what we encode here. */

      if (out_parameters)
	{
	  /* Step through all the arguments, finding the ones that were
	     passed by reference. */
      for (tmptype = objc_skip_argspec (tmptype), argnum = 0;
	   *tmptype != '\0';
	   tmptype = objc_skip_argspec (tmptype), argnum++)
	    {
	      /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
	      flags = objc_get_type_qualifiers(tmptype);
	      /* Skip over the type qualifiers, so now TYPE is
		 pointing directly at the char corresponding to the
		 argument's type, as defined in <objc/objc-api.h> */
	      tmptype = objc_skip_type_qualifiers(tmptype);

	      /* Decide how, (or whether or not), to encode the
		 argument depending on its FLAGS and TMPTYPE. */
	      datum = cifframe_arg_addr(cframe, argnum);

	      ctxt->type = tmptype;
	      ctxt->datum = datum;
	      ctxt->flags = flags;

	      if (*tmptype == _C_PTR
		  && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  void *ptr;
		  /* The argument is a pointer (to a non-char), and
		     the pointer's value is qualified as an OUT
		     parameter, or it not explicitly qualified as an
		     IN parameter, then it is a pass-by-reference
		     argument.*/
		  tmptype++;
		  ctxt->type = tmptype;

		  (*decoder) (ctxt);
		  /* Copy the pointed-to data back to the original
		     pointer */
		  [inv getArgument: &ptr atIndex: argnum];
		  memcpy(ptr, datum, objc_sizeof_type(tmptype));
		}
	      else if (*tmptype == _C_CHARPTR
		&& ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  /* The argument is a pointer char string, and the
		     pointer's value is qualified as an OUT parameter,
		     or it not explicitly qualified as an IN
		     parameter, then it is a pass-by-reference
		     argument.  Encode it.*/
		  /* xxx Perhaps we could save time and space by
		     saving a copy of the string before the method
		     call, and then comparing it to this string; if it
		     didn't change, don't bother to send it back
		     again. */
		  (*decoder) (ctxt);
		  [inv setArgument: datum atIndex: argnum];
		}
	    }
	}
      ctxt->type = 0;
      ctxt->datum = 0;
      (*decoder) (ctxt);	/* Tell it we have finished.	*/
    }

  if (ctxt->datToFree != 0)
    {
      NSZoneFree(NSDefaultMallocZone(), ctxt->datToFree);
      ctxt->datToFree = 0;
    }

  return;
}

