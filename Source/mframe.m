/* Implementation of functions for dissecting/making method calls 
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Oct 1994
   
   This file is part of the Gnustep Base Library.

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

/* These functions can be used for dissecting and making method calls
   for many different situations.  They are used for distributed
   objects; they could also be used to make interfaces between
   Objective C and Scheme, Perl, Tcl, or other languages.

*/


#include <gnustep/base/preface.h>
#include <gnustep/base/objc-malloc.h>
#include <gnustep/base/mframe.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/NSException.h>
#include <stdlib.h>
#include <assert.h>

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

/* Do we need separate _PASSED_BY_REFERENCE and _RETURNED_BY_REFERENCE? */

#if (sparc) || (hppa) || (AM29K)
#define MFRAME_STRUCTURES_PASSED_BY_REFERENCE 1
#else
#define MFRAME_STRUCTURES_PASSED_BY_REFERENCE 0
#endif


/* Float and double return values are stored at retframe + 8 bytes
   by __builtin_return() 

   The retframe consists of 16 bytes.  The first 4 are used for ints, 
   longs, chars, etc.  The last 8 are used for floats and doubles.

   xxx This is disgusting.  I should get this info from the gcc config 
   machine description files. xxx
   */
#define FLT_AND_DBL_RETFRAME_OFFSET 8

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })



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
    return atoi(++type) + sizeof(void*);
  else
    return 0;
}


/* To fix temporary bug in method_get_next_argument() on m68k */
/* xxx Perhaps this isn't working with the NeXT runtime? */

char*
method_types_get_next_argument (arglist_t argf,
				const char **type)
{
  const char *t = objc_skip_argspec (*type);
   union {
     char *arg_ptr;
     char arg_regs[sizeof (char*)];
   } *argframe;

  argframe = (void*)argf;

  if (*t == '\0')
    return 0;

  *type = t;
  t = objc_skip_typespec (t);

  if (*t == '+')
    return argframe->arg_regs + atoi(++t);
  else
    /* xxx What's going on here?  This -8 needed on my 68k NeXT box. */
#if m68k
    return argframe->arg_ptr + (atoi(t) - 8);
#else
    return argframe->arg_ptr + atoi(t);
#endif
}


/* mframe_dissect_call()

   This function encodes the arguments of a method call.

   Call it with an ARGFRAME that was returned by __builtin_args(), and
   a TYPE string that describes the input and return locations,
   i.e. from sel_get_types() or Method->method_types.

   The function ENCODER will be called once with each input argument.

   Returns YES iff there are any outparameters---parameters that for
   which we will have to get new values after the method is run,
   e.g. an argument declared (out char*). */

BOOL
mframe_dissect_call (arglist_t argframe, const char *type,
		     void (*encoder)(int,void*,const char*,int))
{
  unsigned flags;
  char *datum;
  int argnum;
  BOOL out_parameters = NO;

  /* Enumerate all the arguments in ARGFRAME, and call ENCODER for
     each one.  METHOD_TYPES_GET_NEXT_ARGUEMENT() returns 0 when
     there are no more arguments, otherwise it returns a pointer to the
     argument in the ARGFRAME. */

  for (datum = method_types_get_next_argument(argframe, &type), argnum=0;
       datum;
       datum = method_types_get_next_argument(argframe, &type), argnum++)
    {
      /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
      flags = objc_get_type_qualifiers(type);

      /* Skip over the type qualifiers, so now TYPE is pointing directly
	 at the char corresponding to the argument's type, as defined
	 in <objc/objc-api.h> */
      type = objc_skip_type_qualifiers(type);

      /* Decide how, (or whether or not), to encode the argument
	 depending on its FLAGS and TYPE.  Only the first two cases
	 involve parameters that may potentially be passed by
	 reference, and thus only the first two may change the value
	 of OUT_PARAMETERS. */

      switch (*type)
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
             explicity qualified as an OUT parameter, then encode
             it. */
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*encoder) (argnum, datum, type, flags);
	  break;

	case _C_PTR:
	  /* Handle an argument that is a pointer to a non-char.  But
	     (void*) and (anything**) is not allowed. */
	  /* The argument is a pointer to something; increment TYPE
	       so we can see what it is a pointer to. */
	  type++;
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  /* If the pointer's value is qualified as an IN parameter,
             or not explicity qualified as an OUT parameter, then
             encode it. */
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*encoder) (argnum, *(void**)datum, type, flags);
	  break;

	case _C_STRUCT_B:
	case _C_ARY_B:
	  /* Handle struct and array arguments. */
	  /* Whether DATUM points to the data, or points to a pointer
	     that points to the data, depends on the value of
	     MFRAME_STRUCTURES_PASSED_BY_REFERENCE.  Do the right thing
	     so that ENCODER gets a pointer to directly to the data. */
#if MFRAME_STRUCTURES_PASSED_BY_REFERENCE
	  (*encoder) (argnum, *(void**)datum, type, flags);
#else
	  (*encoder) (argnum, datum, type, flags);
#endif
	  break;

	default:
	  /* Handle arguments of all other types. */
	  (*encoder) (argnum, datum, type, flags);
	}
    }

  /* Return a BOOL indicating whether or not there are parameters that
     were passed by reference; we will need to get those values again
     after the method has finished executing because the execution of
     the method may have changed them.*/
  return out_parameters;
}


/* mframe_do_call()

   This function decodes the arguments of method call, builds an
   argframe of type arglist_t, and invokes the method using
   __builtin_apply; then it encodes the return value and any
   pass-by-reference arguments.

   ENCODED_TYPES should be a string that describes the return value
   and arguments.  It's argument types and argument type qualifiers
   should match exactly those that were used when the arguments were
   encoded with mframe_dissect_call()---mframe_do_call() uses
   ENCODED_TYPES to determine which variable types it should decode.

   ENCODED_TYPES is used to get the types and type qualifiers, but not
   to get the register and stack locations---we get that information
   from the selector type of the SEL that is decoded as the second
   argument.  In this way, the ENCODED_TYPES may come from a machine
   of a different architecture.  Having the original ENCODED_TYPES is
   good, just in case the machine running mframe_do_call() has some
   slightly different qualifiers.  Using different qualifiers for
   encoding and decoding could lead to massive confusion.


   DECODER should be a pointer to a function that obtains the method's
   argument values.  For example:

     void my_decoder (int argnum, void *data, const char *type)

     ARGNUM is the number of the argument, beginning at 0.
     DATA is a pointer to the memory where the value should be placed.
     TYPE is a pointer to the type string of this value.

     mframe_do_call() calls this function once for each of the methods
     arguments.  The DECODER function should place the ARGNUM'th
     argument's value at the memory location DATA.

     If DECODER malloc's new memory in the course of doing its
     business, then DECODER is responsible for making sure that the
     memory will get free eventually.  For example, if DECODER uses
     -decodeValueOfCType:at:withName: to decode a char* string, you
     should remember that -decodeValueOfCType:at:withName: malloc's
     new memory to hold the string, and DECODER should autorelease the
     malloc'ed pointer, using the MallocAddress class.


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

     mframe_do_call() calls this function after the method has been
     run---once for the return value, and once for each of the
     pass-by-reference parameters.  The ENCODER function should place
     the value at memory location DATA wherever the user wants to
     record the ARGNUM'th return value.

*/

void
mframe_do_call (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int))
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
  /* The number bytes for holding arguments passed on the stack. */
  int stack_argsize;
  /* The number bytes for holding arguments passed in registers. */
  int reg_argsize;
  /* The structure for holding the arguments to the method. */
#if NeXT_runtime
  union {
    char *arg_ptr;
    char arg_regs[sizeof (char*)];
  } *argframe;
#else
  arglist_t argframe;
#endif
  /* A pointer into the ARGFRAME; points at individual arguments. */
  char *datum;
  /* Type qualifier flags; see <objc/objc-api.h>. */
  unsigned flags;
  /* Which argument number are we processing now? */
  int argnum;
  /* A pointer to the memory holding the return value of the method. */
  void *retframe;
  /* Does the method have any arguments that are passed by reference?
     If so, we need to encode them, since the method may have changed them. */
  BOOL out_parameters = NO;
  /* For extracting a return value of type `float' from RETFRAME. */
  float retframe_float (void *rframe)
    {
      __builtin_return (rframe);
    }
  /* For extracting a return value of type `double' from RETFRAME. */
  double retframe_double (void *rframe)
    {
      __builtin_return (rframe);
    }


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


  /* Allocate an argframe, using memory on the stack */

  /* Calculate the amount of memory needed for storing variables that
     are passed in registers, and the amount of memory for storing
     variables that are passed on the stack. */
  stack_argsize = method_types_get_size_of_stack_arguments (type);
  reg_argsize = method_types_get_size_of_register_arguments (type);
  /* Allocate the space for variables passed in registers. */
  argframe = (arglist_t) alloca(sizeof(char*) + reg_argsize);
  /* Allocate the space for variables passed on the stack. */
  if (stack_argsize)
    argframe->arg_ptr = alloca (stack_argsize);
  else
    argframe->arg_ptr = 0;


  /* Put OBJECT and SELECTOR into the ARGFRAME. */

  /* Initialize our temporary pointers into the method type strings. */
  tmptype = type;
  etmptype = objc_skip_argspec (encoded_types);
  /* Get a pointer into ARGFRAME, pointing to the location where the
     first argument is to be stored. */
  datum = method_types_get_next_argument (argframe, &tmptype);
  NSCParameterAssert (datum);
  NSCParameterAssert (*tmptype == _C_ID);
  /* Put the target object there. */
  *(id*)datum = object;
  /* Get a pionter into ARGFRAME, pointing to the location where the
     second argument is to be stored. */
  etmptype = objc_skip_argspec(etmptype);
  datum = method_types_get_next_argument(argframe, &tmptype);
  NSCParameterAssert (datum);
  NSCParameterAssert (*tmptype == _C_SEL);
  /* Put the selector there. */
  *(SEL*)datum = selector;


  /* Decode arguments after OBJECT and SELECTOR, and put them into the
     ARGFRAME.  Step TMPTYPE and ETMPTYPE in lock-step through their
     method type strings. */

  for (datum = method_types_get_next_argument (argframe, &tmptype),
       etmptype = objc_skip_argspec (etmptype), argnum = 2;
       datum;
       datum = method_types_get_next_argument (argframe, &tmptype),
       etmptype = objc_skip_argspec (etmptype), argnum++)
    {
      /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
      flags = objc_get_type_qualifiers (etmptype);
      /* Skip over the type qualifiers, so now TYPE is pointing directly
	 at the char corresponding to the argument's type, as defined
	 in <objc/objc-api.h> */
      tmptype = objc_skip_type_qualifiers(tmptype);

      /* Decide how, (or whether or not), to decode the argument
	 depending on its FLAGS and TMPTYPE.  Only the first two cases
	 involve parameters that may potentially be passed by
	 reference, and thus only the first two may change the value
	 of OUT_PARAMETERS.  *** Note: This logic must match exactly
	 the code in mframe_dissect_call(); that function should
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
	     autorelease of MallocAddress object). */
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*decoder) (argnum, datum, tmptype);

	  break;

	case _C_PTR:
	  /* Handle an argument that is a pointer to a non-char.  But
	     (void*) and (anything**) is not allowed. */
	  /* The argument is a pointer to something; increment TYPE
	       so we can see what it is a pointer to. */
	  tmptype++;
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
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
	  break;

	case _C_STRUCT_B:
	case _C_ARY_B:
	  /* Handle struct and array arguments. */
	  /* Whether DATUM points to the data, or points to a pointer
	     that points to the data, depends on the value of
	     MFRAME_STRUCTURES_PASSED_BY_REFERENCE.  Do the right thing
	     so that ENCODER gets a pointer to directly to the data. */
#if MFRAME_STRUCTURES_PASSED_BY_REFERENCE
	  /* Allocate some memory to be pointed to, and to hold the
	     data.  Note that it is allocated on the stack, and
	     methods that want to keep the data pointed to, will have
	     to make their own copies. */
	  *(void**)datum = alloca (objc_sizeof_type(tmptype));
	  (*decoder) (argnum, *(void**)datum, tmptype);
#else
	  (*decoder) (argnum, datum, tmptype);
#endif
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


  /* Invoke the method! */

  /* Find the target object's implementation of this selector. */
  method_implementation = objc_msg_lookup (object, selector);
  NSCParameterAssert (method_implementation);
  /* Do it!  Send the message to the target, and get the return value
     in RETFRAME.  The arguments will still be in ARGFRAME, so we can
     get the pass-by-reference info from there. */
  retframe = __builtin_apply((void(*)(void))method_implementation, 
			     argframe, 
			     stack_argsize);


  /* Encode the return value and pass-by-reference values, if there
     are any.  This logic must match exactly that in
     mframe_build_return(). */
  /* OUT_PARAMETERS should be true here in exactly the same
     situations as it was true in mframe_dissect_call(). */

  /* Get the qualifier type of the return value. */
  flags = objc_get_type_qualifiers (encoded_types);
  /* Get the return type; store it our two temporary char*'s. */
  etmptype = objc_skip_type_qualifiers (encoded_types);
  tmptype = objc_skip_type_qualifiers (type);

  /* Only encode return values if there is a non-void return value, or
     if there are values that were passed by reference. */
  /* xxx Are my tests right?  Do we also have to check _F_ONEWAY? */

  /* If there is a return value, encode it. */
  switch (*tmptype)
    {
    case _C_VOID:
      /* No return value to encode; do nothing. */
      break;

    case _C_ID:
      (*encoder) (-1, retframe, @encode(id), flags);
    break;

    case _C_PTR:
      /* The argument is a pointer to something; increment TYPE
	 so we can see what it is a pointer to. */
      tmptype++;
      /* Encode the value that was pointed to. */
      (*encoder) (-1, *(void**)retframe, tmptype, flags);
      break;

    case _C_STRUCT_B:
    case _C_ARY_B:
      /* The argument is a structure or array returned by value.
	 (In C, are array's allowed to be returned by value?) */
      /* xxx Does MFRAME_STRUCTURES_PASSED_BY_REFERENCE have
	 anything to do with how structures are returned?  What about
	 struct's that are smaller than sizeof(void*)?  Are they also
	 returned by reference like this? */
      (*encoder) (-1, *(void**)retframe, tmptype, flags);
      break;

    case _C_FLT:
      {
	float ret = retframe_float (retframe);
	(*encoder) (-1, &ret, tmptype, flags);
	break;
      }

    case _C_DBL:
      {
	double ret = retframe_double (retframe);
	(*encoder) (-1, &ret, tmptype, flags);
	break;
      }

    case _C_SHT:
    case _C_USHT:
      /* For C variable types smaller than int, like short, the
	 RETFRAME doesn't actually point to the beginning of the
	 short, it points to the beginning of an int. */
      (*encoder) (-1, ((char*)retframe) + sizeof(void*)-sizeof(short),
		  tmptype, flags);
      break;

    case _C_CHR:
    case _C_UCHR:
      /* For C variable types smaller than int, like char, the
         RETFRAME doesn't actually point to the beginning of the
         short, it points to the beginning of an int. */
      (*encoder) (-1, ((char*)retframe) + sizeof(void*)-sizeof(char),
		  tmptype, flags);
      break;

    default:
      /* case _C_INT: case _C_UINT: case _C_LNG: case _C_ULNG:
	 case _C_CHARPTR: */
      /* xxx I think this assumes that sizeof(int)==sizeof(void*) */
      (*encoder) (-1, retframe, tmptype, flags);
    }


  /* Encode the values returned by reference.  Note: this logic
     must match exactly the code in mframe_build_return(); that
     function should decode exactly what we encode here. */

  if (out_parameters)
    {
      /* Step through all the arguments, finding the ones that were
	 passed by reference. */
      for (datum = method_types_get_next_argument (argframe, &tmptype), 
	     argnum = 1,
	     etmptype = objc_skip_argspec (etmptype);
	   datum;
	   datum = method_types_get_next_argument (argframe, &tmptype), 
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


/* mframe_build_return()

   This function decodes the values returned from a method call,
   builds a retframe of type retval_t that can be passed to GCC's
   __builtin_return(), and updates the pass-by-reference arguments in
   ARGFRAME.  This function returns a retframe pointer.

   In the function that calls this one, be careful about calling more
   functions after this one.  The memory for the retframe is
   alloca()'ed, not malloc()'ed, and therefore is on the stack and can
   be tromped-on by future function calls.

   xxx Pointer values returned by the method or non-const strings
   passed in will now point to newly malloc'ed memory.  It is your
   responsibility to free it.  This is thoroughly disgusting, and will
   be fixed as soon as we get rid of the -free method and replace it
   with something better.  */

retval_t 
mframe_build_return (arglist_t argframe, 
		     const char *type, 
		     BOOL out_parameters,
		     void(*decoder)(int,void*,const char*,int))
{
  /* A pointer to the memory that will hold the return value. */
  retval_t retframe = NULL;
  /* The size, in bytes, of memory pointed to by RETFRAME. */
  int retsize;
  /* Which argument number are we processing now? */
  int argnum;
  /* Type qualifier flags; see <objc/objc-api.h>. */
  int flags;
  /* A pointer into the TYPE string. */
  const char *tmptype;
  /* A pointer into the ARGFRAME; points at individual arguments. */
  void *datum;

  /* Get the return type qualifier flags, and the return type. */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);

  /* Decode the return value and pass-by-reference values, if there
     are any.  OUT_PARAMETERS should be the value returned by
     mframe_dissect_call(). */
  if (out_parameters || *tmptype != _C_VOID)
    /* xxx What happens with method declared "- (oneway) foo: (out int*)ip;" */
    /* xxx What happens with method declared "- (in char *) bar;" */
    /* xxx Is this right?  Do we also have to check _F_ONEWAY? */
    {
      /* ARGNUM == -1 signifies to DECODER() that this is the return
         value, not an argument. */

      /* If there is a return value, decode it, and put it in retframe. */
      if (*tmptype != _C_VOID)
	{
	  /* Get the size of the returned value. */
	  retsize = objc_sizeof_type (tmptype);
	  /* Allocate memory on the stack to hold the return value.
             It should be at least 4 * sizeof(void*). */
	  /* xxx We need to test retsize's less than 4.  Also note that
	     if we return structures using a structure-value-address, we
	     are potentially alloca'ing much more than we need here. */
	  /* xxx Find out about returning structures by reference
	     on non--structure-value-address machines, and potentially
	     just always alloca(RETFRAME_SIZE == sizeof(void*)*4) */
	  retframe = alloca (MAX(retsize, sizeof(void*)*4));
	  
	  switch (*tmptype)
	    {
	    case _C_PTR:
	      /* We are returning a pointer to something. */
	      /* Increment TYPE so we can see what it is a pointer to. */
	      tmptype++;
	      /* Allocate some memory to hold the value we're pointing to. */
	      *(void**)retframe = 
		(*objc_malloc) (objc_sizeof_type (tmptype));
	      /* We are responsible for making sure this memory gets free'd
		 eventually.  Ask MallocAddress class to autorelease it. */
	      [MallocAddress autoreleaseMallocAddress: *(void**)retframe];
	      /* Decode the return value into the memory we allocated. */
	      (*decoder) (-1, *(void**)retframe, tmptype, flags);
	      break;

	    case _C_STRUCT_B: 
	    case _C_ARY_B:
	      /* The argument is a structure or array returned by value.
		 (In C, are array's allowed to be returned by value?) */
	      /* xxx Does MFRAME_STRUCTURES_PASSED_BY_REFERENCE
		 have anything to do with how structures are returned?
		 What about struct's that are smaller than
		 sizeof(void*)?  Are they also returned by reference
		 like this? */
	      /* Allocate some memory to hold the struct or array. */
	      *(void**)retframe = alloca (objc_sizeof_type (tmptype));
	      /* Decode the return value into the memory we allocated. */
	      (*decoder) (-1, *(void**)retframe, tmptype, flags);
	      break;

	    case _C_FLT: 
	    case _C_DBL:
	      (*decoder) (-1, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET,
			  tmptype, flags);
	      break;

	    default:
	      /* (Among other things, _C_CHARPTR is handled here). */
	      /* Special case BOOL (and other types smaller than int)
		 because retframe doesn't actually point to the char */
	      /* xxx What about structures smaller than int's that
		 are passed by reference on true structure reference-
		 passing architectures? */
	      /* xxx Is this the right test?  Use sizeof(int) instead? */
	      if (retsize < sizeof(void*))
		{
		  *(void**)retframe = 0;
		  (*decoder) (-1, ((char*)retframe)+sizeof(void*)-retsize,
			      tmptype, flags);
		}
	      else
		{
		  (*decoder) (-1, retframe, tmptype, flags);
		}
	    }
	}
      
      /* Decode the values returned by reference.  Note: this logic
	 must match exactly the code in mframe_do_call(); that
	 function should decode exactly what we encode here. */

      if (out_parameters)
	{
	  /* Step through all the arguments, finding the ones that were
	     passed by reference. */
	  for (datum = method_types_get_next_argument(argframe, &tmptype), 
	       argnum=0;
	       datum;
	       (datum = method_types_get_next_argument(argframe, &tmptype)), 
	       argnum++)
	    {
	      /* Get the type qualifiers, like IN, OUT, INOUT, ONEWAY. */
	      flags = objc_get_type_qualifiers(tmptype);
	      /* Skip over the type qualifiers, so now TYPE is
		 pointing directly at the char corresponding to the
		 argument's type, as defined in <objc/objc-api.h> */
	      tmptype = objc_skip_type_qualifiers(tmptype);

	      /* Decide how, (or whether or not), to encode the
		 argument depending on its FLAGS and TMPTYPE. */

	      if (*tmptype == _C_PTR
		  && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  /* The argument is a pointer (to a non-char), and
		     the pointer's value is qualified as an OUT
		     parameter, or it not explicitly qualified as an
		     IN parameter, then it is a pass-by-reference
		     argument.*/
		  /* The argument is a pointer to something; increment
		     TYPE so we can see what it is a pointer to. */
		  tmptype++;
		  /* xxx Note that a (char**) is malloc'ed anew here.
		     Yucky, or worse than yucky.  If the returned string
		     is smaller than the original, we should just put it
		     there; if the returned string is bigger, I don't know
		     what to do. */
		  /* xxx __builtin_return can't return structures by value? */
		  (*decoder) (argnum, *(void**)datum, tmptype, flags);
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
		}
	    }
	}
    }
  else	/* matches `if (out_parameters)' */
    {
      /* We are just returning void, but retframe needs to point to
         something or else we can crash. */
      retframe = alloca (sizeof(void*));
    }

  /* Return the retval_t pointer to the return value. */
  return retframe;
}
