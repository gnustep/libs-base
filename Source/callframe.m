/* callframe.m - Wrapper/Objective-C interface for ffcall function interface

   Copyright (C) 2000, Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@gnu.org>
   Created: Nov 2000
   
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
#include "callframe.h"
#include <Foundation/NSException.h>
#include <Foundation/NSData.h>
#include <base/GSInvocation.h>

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

callframe_t *
callframe_from_info (NSArgumentInfo *info, int numargs, void **retval)
{
  int i;
  callframe_t *cframe;

  cframe = malloc(sizeof(callframe_t));
  cframe->nargs = numargs;
  if (cframe)
    {
      cframe->args = malloc(cframe->nargs * sizeof(void *));
      for (i = 0; i < cframe->nargs; i++)
	cframe->args[i] = malloc(info[i+1].size);
    }

  if (retval)
    {
      *retval = NSZoneMalloc(NSDefaultMallocZone(), 
			    MAX(info[0].size, sizeof(smallret_t)) );
    }
  return cframe;
}

void
callframe_free(callframe_t *cframe)
{
  int i;
  for (i = 0; i < cframe->nargs; i++)
    {
      free(cframe->args[i]);
      cframe->args[i] = 0;
    }

  cframe->nargs = 0;
  free(cframe->args);
  free(cframe);
}

void
callframe_set_arg(callframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(cframe->args[index], buffer, size);
}

void
callframe_get_arg(callframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(buffer, cframe->args[index], size);
}

void *
callframe_arg_addr(callframe_t *cframe, int index)
{
  if (index < 0 || index >= cframe->nargs)
     return NULL;
  return cframe->args[index];
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

/* callframe_do_call()

   This function decodes the arguments of method call, builds an
   argframe of type arglist_t, and invokes the method using
   __builtin_apply; then it encodes the return value and any
   pass-by-reference arguments.

   ENCODED_TYPES should be a string that describes the return value
   and arguments.  It's argument types and argument type qualifiers
   should match exactly those that were used when the arguments were
   encoded with callframe_dissect_call()---callframe_do_call() uses
   ENCODED_TYPES to determine which variable types it should decode.

   ENCODED_TYPES is used to get the types and type qualifiers, but not
   to get the register and stack locations---we get that information
   from the selector type of the SEL that is decoded as the second
   argument.  In this way, the ENCODED_TYPES may come from a machine
   of a different architecture.  Having the original ENCODED_TYPES is
   good, just in case the machine running callframe_do_call() has some
   slightly different qualifiers.  Using different qualifiers for
   encoding and decoding could lead to massive confusion.


   DECODER should be a pointer to a function that obtains the method's
   argument values.  For example:

     void my_decoder (int argnum, void *data, const char *type)

     ARGNUM is the number of the argument, beginning at 0.
     DATA is a pointer to the memory where the value should be placed.
     TYPE is a pointer to the type string of this value.

     callframe_do_call() calls this function once for each of the methods
     arguments.  The DECODER function should place the ARGNUM'th
     argument's value at the memory location DATA.
     callframe_do_call() calls this function once with ARGNUM -1, DATA 0,
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

     callframe_do_call() calls this function after the method has been
     run---once for the return value, and once for each of the
     pass-by-reference parameters.  The ENCODER function should place
     the value at memory location DATA wherever the user wants to
     record the ARGNUM'th return value.

  PASS_POINTERS is a flag saying whether pointers should be passed
  as pointers (for local stuff) or should be assumed to point to a
  single data item (for distributed objects).
*/

void
callframe_do_call_opts (const char *encoded_types,
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
  callframe_t *cframe;
  /* Does the method have any arguments that are passed by reference?
     If so, we need to encode them, since the method may have changed them. */
  BOOL out_parameters = NO;
  BOOL one_way = NO;
  /* A dummy invocation to pass to the function that invokes our method */
  NSInvocation_t *inv;
  /* Signature information */
  NSMethodSignature *sig;

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
  cframe = callframe_from_info([sig methodInfo], [sig numberOfArguments], 
			       &retval);

  /* Put OBJECT and SELECTOR into the ARGFRAME. */

  /* Initialize our temporary pointers into the method type strings. */
  tmptype = objc_skip_argspec (type);
  etmptype = objc_skip_argspec (encoded_types);
  NSCParameterAssert (*tmptype == _C_ID);
  /* Put the target object there. */
  callframe_set_arg(cframe, 0, &object, sizeof(id));
  /* Get a pointer into ARGFRAME, pointing to the location where the
     second argument is to be stored. */
  tmptype = objc_skip_argspec (tmptype);
  etmptype = objc_skip_argspec(etmptype);
  NSCParameterAssert (*tmptype == _C_SEL);
  /* Put the selector there. */
  callframe_set_arg(cframe, 1, &selector, sizeof(SEL));


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

      datum = callframe_arg_addr(cframe, argnum);

      /* Decide how, (or whether or not), to decode the argument
	 depending on its FLAGS and TMPTYPE.  Only the first two cases
	 involve parameters that may potentially be passed by
	 reference, and thus only the first two may change the value
	 of OUT_PARAMETERS.  *** Note: This logic must match exactly
	 the code in callframe_dissect_call(); that function should
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
  inv = (NSInvocation_t *)NSAllocateObject([NSInvocation class], 0, 
					   NSDefaultMallocZone());
  inv->_retval = retval;
  inv->_selector = selector;
  inv->_cframe = cframe;
  inv->_info = [sig methodInfo];
  inv->_numArgs = [sig numberOfArguments];
  GSFFCallInvokeWithTargetAndImp((NSInvocation *)inv, object, 
				 method_implementation);
  NSDeallocateObject((NSInvocation *)inv);

  /* Encode the return value and pass-by-reference values, if there
     are any.  This logic must match exactly that in
     callframe_build_return(). */
  /* OUT_PARAMETERS should be true here in exactly the same
     situations as it was true in callframe_dissect_call(). */

  /* Get the qualifier type of the return value. */
  flags = objc_get_type_qualifiers (encoded_types);
  /* Get the return type; store it our two temporary char*'s. */
  etmptype = objc_skip_type_qualifiers (encoded_types);
  tmptype = objc_skip_type_qualifiers (type);

  /* Only encode return values if there is a non-void return value,
     a non-oneway void return value, or if there are values that were
     passed by reference. */

  /* If there is a return value, encode it. */
  switch (*tmptype)
    {
    case _C_VOID:
      if ((flags & _F_ONEWAY) == 0)
	{
	   int	dummy = 0;
          (*encoder) (-1, (void*)&dummy, @encode(int), 0);
	}
      else
	{
	  one_way = YES;
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
     must match exactly the code in callframe_build_return(); that
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
	  datum = callframe_arg_addr(cframe, argnum);

	  if ((*tmptype == _C_PTR) 
	      && ((flags & _F_OUT) || !(flags & _F_IN)))
	    {
	      /* The argument is a pointer (to a non-char), and the
		 pointer's value is qualified as an OUT parameter, or
		 it not explicitly qualified as an IN parameter, then
		 it is a pass-by-reference argument.*/
	      /* Encode it. */
	      (*encoder) (argnum, datum, tmptype, flags);
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
callframe_do_call (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int))
{
  callframe_do_call_opts(encoded_types, decoder, encoder, YES);
}

/* callframe_build_return()

   This function decodes the values returned from a method call, 
   sets up the invocation with the return value, and updates the
   pass-by-reference arguments.  

   The callback function is finally called with the 'type' set to a nul pointer
   to tell it that the return value and all return parameters have been
   dealt with.  This permits the function to do any tidying up necessary.  */

void
callframe_build_return_opts (NSInvocation *inv,
		     const char *type, 
		     BOOL out_parameters,
		     void(*decoder)(int,void*,const char*,int),
		     BOOL pass_pointers)
{
  /* The size, in bytes, of memory pointed to by RETFRAME. */
  int retsize;
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
  callframe_t *cframe;
  /* Signature information */
  NSMethodSignature *sig;

  /* Build the call frame */
  sig = [NSMethodSignature signatureWithObjCTypes: type];
  cframe = callframe_from_info([sig methodInfo], [sig numberOfArguments], 
			       &retval);

  /* Get the return type qualifier flags, and the return type. */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);
  rettype = tmptype;

  /* Decode the return value and pass-by-reference values, if there
     are any.  OUT_PARAMETERS should be the value returned by
     callframe_dissect_call(). */
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
	  switch (*tmptype)
	    {
	    case _C_PTR:
	      if (pass_pointers)
		{
		  (*decoder) (-1, retval, tmptype, flags);
		}
	      else
		{
		  unsigned retLength;

		  /* We are returning a pointer to something. */
		  /* Increment TYPE so we can see what it is a pointer to. */
		  tmptype++;
		  retLength = objc_sizeof_type(tmptype);
		  /* Allocate memory to hold the value we're pointing to. */
		  *(void**)retval = 
		    NSZoneMalloc(NSDefaultMallocZone(), retLength);
		  /* We are responsible for making sure this memory gets free'd
		     eventually.  Ask NSData class to autorelease it. */
		  [NSData dataWithBytesNoCopy: *(void**)retval
				       length: retLength];
		  /* Decode the return value into the memory we allocated. */
		  (*decoder) (-1, *(void**)retval, tmptype, flags);
		}
	      break;

	    case _C_STRUCT_B: 
	    case _C_UNION_B:
	    case _C_ARY_B:
	      /* Decode the return value into the memory we allocated. */
	      (*decoder) (-1, retval, tmptype, flags);
	      break;

	    case _C_FLT: 
	    case _C_DBL:
	      (*decoder) (-1, ((char*)retval), tmptype, flags);
	      break;

	    case _C_VOID:
		{
		  (*decoder) (-1, retval, @encode(int), 0);
		}
		break;

	    default:
	      /* (Among other things, _C_CHARPTR is handled here). */
	      /* Special case BOOL (and other types smaller than int)
		 because retval doesn't actually point to the char */
	      /* xxx What about structures smaller than int's that
		 are passed by reference on true structure reference-
		 passing architectures? */
	      /* xxx Is this the right test?  Use sizeof(int) instead? */
	      if (retsize < sizeof(void*))
		{
#if 1
		  /* Frith-Macdonald said this worked better 21 Nov 96. */
		  (*decoder) (-1, retval, tmptype, flags);
#else
		  *(void**)retval = 0;
		  (*decoder) (-1, ((char*)retval)+sizeof(void*)-retsize,
			      tmptype, flags);
#endif
		}
	      else
		{
		  (*decoder) (-1, retval, tmptype, flags);
		}
	    }
	}
      [inv setReturnValue: retval];

      /* Decode the values returned by reference.  Note: this logic
	 must match exactly the code in callframe_do_call(); that
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
	      datum = callframe_arg_addr(cframe, argnum);

	      if (*tmptype == _C_PTR
		  && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  void *ptr;
		  /* The argument is a pointer (to a non-char), and
		     the pointer's value is qualified as an OUT
		     parameter, or it not explicitly qualified as an
		     IN parameter, then it is a pass-by-reference
		     argument.*/
		  (*decoder) (argnum, datum, tmptype, flags);
		  /* Copy the pointed-to data back to the original
		     pointer */
		  [inv getArgument: &ptr atIndex: argnum];
		  memcpy(ptr, *(void **)datum, objc_sizeof_type(tmptype+1));
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
		  (*decoder) (argnum, datum, tmptype, flags);
		  [inv setArgument: datum atIndex: argnum];
		}
	    }
	}
      (*decoder) (0, 0, 0, 0);	/* Tell it we have finished.	*/
    }
  callframe_free(cframe);
}

void
callframe_build_return (NSInvocation *inv,
			const char *type, 
			BOOL out_parameters,
			void(*decoder)(int,void*,const char*,int))
{
  callframe_build_return_opts(inv, type, out_parameters, decoder, YES);
}
