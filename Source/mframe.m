/* Implementation of functions for dissecting/making method calls 
   Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Oct 1994
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

/* These functions can be used for dissecting and making method calls
   for many different situations.  They are used for distributed
   objects; they could also be used to make interfaces between
   Objective C and Scheme, Perl, Tcl, or other languages.

*/

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/mframe.h>
#include <Foundation/NSData.h>
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


char*
mframe_build_signature(const char *typePtr, int *size, int *narg, char *buf)
{
    MFRAME_ARGS	cum;
    BOOL	doMalloc = NO;
    const char	*types;
    char	*start;
    char	*dest;
    int		total = 0;
    int		count = 0;

    /*
     *	If we have not been given a buffer - allocate space on the stack for
     *	the largest concievable type encoding.
     */
    if (buf == 0) {
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
    if (*types == '+') {
	types++;
    }
    while (isdigit(*types)) {
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
    while (types && *types) {
	const char	*qual = types;

	/*
	 *	If there are any type qualifiers - copy the through to the
	 *	destination.
	 */
	types = objc_skip_type_qualifiers(types);
	while (qual < types) {
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
    while (*start) {
	*dest++ = *start++;
    }
    *dest = '\0';

    /*
     *	If we have written into a local buffer - we need to allocate memory
     *	in which to return our result.
     */
    if (doMalloc) {
	char	*tmp = objc_malloc(dest - buf + 1);

	strcpy(tmp, buf);
	buf = tmp;
    }

    /*
     *	If the caller wants to know the total size of the stack and/or the
     *	number of arguments, return them in the appropriate variables.
     */
    if (size) {
	*size = total;
    }
    if (narg) {
	*narg = count;
    }
    return buf;
}


/*
 *      Step through method encoding information extracting details.
 */
const char *
mframe_next_arg(const char *typePtr, NSArgumentInfo *info)
{
    NSArgumentInfo	local;
    BOOL	flag;

    if (info == 0) {
	info = &local;
    }
    /*
     *	Skip past any type qualifiers - if the caller wants them, return them.
     */
    flag = YES;
    info->qual = 0;
    while (flag) {
	switch (*typePtr) {
	    case _C_CONST:  info->qual |= _F_CONST; break;
	    case _C_IN:     info->qual |= _F_IN; break;
	    case _C_INOUT:  info->qual |= _F_INOUT; break;
	    case _C_OUT:    info->qual |= _F_OUT; break;
	    case _C_BYCOPY: info->qual |= _F_BYCOPY; break;
#ifdef	_C_BYREF
	    case _C_BYREF:  info->qual |= _F_BYREF; break;
#endif
	    case _C_ONEWAY: info->qual |= _F_ONEWAY; break;
	    default: flag = NO;
	}
	if (flag) {
	    typePtr++;
	}
    }

    info->type = typePtr;

    /*
     *	Scan for size and alignment information.
     */
    switch (*typePtr++) {
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
	    if (*typePtr == '?') {
	      typePtr++;
	    }
	    else {
	      typePtr = mframe_next_arg(typePtr, &local);
	      info->isReg = local.isReg;
	      info->offset = local.offset;
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

		while (isdigit(*typePtr)) {
		    typePtr++;
		}
		typePtr = mframe_next_arg(typePtr, &local);
	        info->size = length * ROUND(local.size, local.align);
		info->align = local.align;
		typePtr++;	/* Skip end-of-array	*/
	    }
	    break; 

	case _C_STRUCT_B:
	    {
		struct { int x; double y; } fooalign;
		int acc_size = 0;
		int acc_align = __alignof__(fooalign);

		/*
		 *	Skip "<name>=" stuff.
		 */
		while (*typePtr != _C_STRUCT_E) {
		    if (*typePtr++ == '=') {
			break;
		    }
		}
		/*
		 *	Base structure alignment on first element.
		 */
		if (*typePtr != _C_STRUCT_E) {
		    typePtr = mframe_next_arg(typePtr, &local);
		    if (typePtr == 0) {
			return 0;		/* error	*/
		    }
		    acc_size = ROUND(acc_size, local.align);
		    acc_size += local.size;
		    acc_align = MAX(local.align, __alignof__(fooalign));
		}
		/*
		 *	Continue accumulating structure size.
		 */
		while (*typePtr != _C_STRUCT_E) {
		    typePtr = mframe_next_arg(typePtr, &local);
		    if (typePtr == 0) {
			return 0;		/* error	*/
		    }
		    acc_size = ROUND(acc_size, local.align);
		    acc_size += local.size;
		}
	        info->size = acc_size;
		info->align = acc_align;
		typePtr++;	/* Skip end-of-struct	*/
	    }
	    break;

	case _C_UNION_B:
	    {
		int	max_size = 0;
		int	max_align = 0;

		/*
		 *	Skip "<name>=" stuff.
		 */
		while (*typePtr != _C_UNION_E) {
		    if (*typePtr++ == '=') {
			break;
		    }
		}
		while (*typePtr != _C_UNION_E) {
		    typePtr = mframe_next_arg(typePtr, &local);
		    if (typePtr == 0) {
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

    if (typePtr == 0) {		/* Error condition.	*/
	return 0;
    }

    /*
     *	If we had a pointer argument, we will already have gathered
     *	(and skipped past) the argframe offset information - so we
     *	don't need to (and can't) do it here.
     */
    if (info->type[0] != _C_PTR || info->type[1] == '?') {
	/*
	 *	May tell the caller if the item is stored in a register.
	 */
	if (*typePtr == '+') {
	    typePtr++;
	    info->isReg = YES;
	}
	else if (info->isReg) {
	    info->isReg = NO;
	}

	/*
	 *	May tell the caller what the stack/register offset is for
	 *	this argument.
	 */
	info->offset = 0;
	while (isdigit(*typePtr)) {
	    info->offset = info->offset * 10 + (*typePtr++ - '0');
	}
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
    return atoi(++type) + sizeof(void*);
  else
    return 0;
}


/* To fix temporary bug in method_get_next_argument() on NeXT boxes */
/* xxx Perhaps this isn't working with the NeXT runtime? */

char*
method_types_get_next_argument (arglist_t argf, const char **type)
{
  const char *t = objc_skip_argspec (*type);
  arglist_t	argframe;

  argframe = (void*)argf;

  if (*t == '\0')
    return 0;

  *type = t;
  t = objc_skip_typespec (t);

  if (*t == '+')
    return argframe->arg_regs + atoi(++t);
  else
    /* xxx What's going on here?  This -8 needed on my 68k NeXT box. */
#if NeXT
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
mframe_dissect_call_opts (arglist_t argframe, const char *type,
		     void (*encoder)(int,void*,const char*,int),
			BOOL pass_pointers)
{
  unsigned flags;
  char *datum;
  int argnum;
  BOOL out_parameters = NO;

  if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) {
    datum = alloca((strlen(type)+1)*10);
    type = mframe_build_signature(type, 0, 0, datum);
  }
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
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  if (pass_pointers) {
	    if ((flags & _F_IN) || !(flags & _F_OUT))
	      (*encoder) (argnum, datum, type, flags);
	  }
	  else {
	    /* Handle an argument that is a pointer to a non-char.  But
	       (void*) and (anything**) is not allowed. */
	    /* The argument is a pointer to something; increment TYPE
		 so we can see what it is a pointer to. */
	    type++;
	    /* If the pointer's value is qualified as an IN parameter,
	       or not explicity qualified as an OUT parameter, then
	       encode it. */
	    if ((flags & _F_IN) || !(flags & _F_OUT))
	      (*encoder) (argnum, *(void**)datum, type, flags);
	  }
	  break;

	case _C_STRUCT_B:
	case _C_UNION_B:
	case _C_ARY_B:
	  /* Handle struct and array arguments. */
	  /* Whether DATUM points to the data, or points to a pointer
	     that points to the data, depends on the value of
	     MFRAME_STRUCT_BYREF.  Do the right thing
	     so that ENCODER gets a pointer to directly to the data. */
#if MFRAME_STRUCT_BYREF
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

BOOL
mframe_dissect_call (arglist_t argframe, const char *type,
		     void (*encoder)(int,void*,const char*,int))
{
    return mframe_dissect_call_opts(argframe, type, encoder, NO);
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
     mframe_do_call() calls this function once with ARGNUM -1, DATA 0,
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

     mframe_do_call() calls this function after the method has been
     run---once for the return value, and once for each of the
     pass-by-reference parameters.  The ENCODER function should place
     the value at memory location DATA wherever the user wants to
     record the ARGNUM'th return value.

  PASS_POINTERS is a flag saying whether pointers should be passed
  as pointers (for local stuff) or should be assumed to point to a
  single data item (for distributed objects).
*/

void
mframe_do_call_opts (const char *encoded_types,
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
  /* The number bytes for holding arguments passed on the stack. */
  int stack_argsize;
  /* The number bytes for holding arguments passed in registers. */
  int reg_argsize;
  /* The structure for holding the arguments to the method. */
  arglist_t argframe;
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
  /* For extracting a return value of type `char' from RETFRAME */
  char retframe_char (void *rframe)
    {
      __builtin_return (rframe);
    }
  /* For extracting a return value of type `short' from RETFRAME */
  short retframe_short (void *rframe)
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

  /*
   *	The compiler/runtime doesn't always seem to get the encoding right
   *	for our purposes - so we generate our own encoding as required by
   *	__builtin_apply().
   */
  if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) {
    tmptype = alloca((strlen(type)+1)*10);
    type = mframe_build_signature(type, 0, 0, (char*)tmptype);
  }

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

  if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) {
      void	*buf;

    /* If we are passing a pointer to return a structure in, we must allocate
       the memory for it and put it in the correct place in the argframe. */
      buf = alloca(objc_sizeof_type(type));
      MFRAME_SET_STRUCT_ADDR(argframe, type, buf);
  }

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
  /* Get a pointer into ARGFRAME, pointing to the location where the
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
	  if (pass_pointers) {
	    if ((flags & _F_IN) || !(flags & _F_OUT))
	      (*decoder) (argnum, datum, tmptype);
	  }
	  else {
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
	  /* Whether DATUM points to the data, or points to a pointer
	     that points to the data, depends on the value of
	     MFRAME_STRUCT_BYREF.  Do the right thing
	     so that ENCODER gets a pointer to directly to the data. */
#if MFRAME_STRUCT_BYREF
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
  (*decoder) (-1, 0, 0);


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
      /* No return value to encode; do nothing. */
      break;

    case _C_PTR:
      if (pass_pointers) {
        (*encoder) (-1, retframe, tmptype, flags);
      }
      else {
	/* The argument is a pointer to something; increment TYPE
	   so we can see what it is a pointer to. */
	tmptype++;
	/* Encode the value that was pointed to. */
	(*encoder) (-1, *(void**)retframe, tmptype, flags);
      }
      break;

    case _C_STRUCT_B:
    case _C_UNION_B:
    case _C_ARY_B:
      /* The argument is a structure or array returned by value.
	 (In C, are array's allowed to be returned by value?) */
      (*encoder)(-1, MFRAME_GET_STRUCT_ADDR(argframe, tmptype), tmptype, flags);
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
      /* On some (but not all) architectures, for C variable types
	 smaller than int, like short, the RETFRAME doesn't actually
	 point to the beginning of the short, it points to the
	 beginning of an int.  So we let RETFRAME_SHORT() take care of
	 it. */
      {
	short ret = retframe_short (retframe);
	(*encoder) (-1, &ret, tmptype, flags);
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      /* On some (but not all) architectures, for C variable types
         smaller than int, like char, the RETFRAME doesn't actually
         point to the beginning of the char, it points to the
         beginning of an int.   So we let RETFRAME_SHORT() take care of
	 it. */
      {
	char ret = retframe_char (retframe);
	(*encoder) (-1, &ret, tmptype, flags);
	break;
      }

    default:
      /* case _C_INT: case _C_UINT: case _C_LNG: case _C_ULNG:
	 case _C_CHARPTR: case: _C_ID: */
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

void
mframe_do_call (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int))
{
    mframe_do_call_opts(encoded_types, decoder, encoder, NO);
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

   The callback function is finally called with the 'type' set to a nul pointer
   to tell it that the return value and all return parameters have been
   dealt with.  This permits the function to do any tidying up necessary.
*/

retval_t 
mframe_build_return_opts (arglist_t argframe, 
		     const char *type, 
		     BOOL out_parameters,
		     void(*decoder)(int,void*,const char*,int),
		     BOOL pass_pointers)
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
  const char *rettype;
  /* For returning strucutres etc */
  typedef struct { id many[8];} __big;
  __big return_block (void* data)
    {
      return *(__big*)data;
    }
  /* For returning a char (or unsigned char) */
  char return_char (char data)
    {
      return data;
    }
  /* For returning a double */
  double return_double (double data)
    {
      return data;
    }
  /* For returning a float */
  float return_float (float data)
    {
      return data;
    }
  /* For returning a short (or unsigned short) */
  short return_short (short data)
    {
      return data;
    }
  retval_t apply_block(void* data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_block, args, sizeof(void*));
    }
  retval_t apply_char(char data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_char, args, sizeof(void*));
    }
  retval_t apply_float(float data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_float, args, sizeof(float));
    }
  retval_t apply_double(double data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_double, args, sizeof(double));
    }
  retval_t apply_short(short data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_short, args, sizeof(void*));
    }

  if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) {
    tmptype = alloca((strlen(type)+1)*10);
    type = mframe_build_signature(type, 0, 0, (char*)tmptype);
  }
  /* Get the return type qualifier flags, and the return type. */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);
  rettype = tmptype;

  /* Decode the return value and pass-by-reference values, if there
     are any.  OUT_PARAMETERS should be the value returned by
     mframe_dissect_call(). */
  if (out_parameters || *tmptype != _C_VOID || (flags & _F_ONEWAY) == 0)
    /* xxx What happens with method declared "- (oneway) foo: (out int*)ip;" */
    /* xxx What happens with method declared "- (in char *) bar;" */
    /* xxx Is this right?  Do we also have to check _F_ONEWAY? */
    {
      /* ARGNUM == -1 signifies to DECODER() that this is the return
         value, not an argument. */

      /* If there is a return value, decode it, and put it in retframe. */
      if (*tmptype != _C_VOID || (flags & _F_ONEWAY) == 0)
	{
	  /* Get the size of the returned value. */
          if (*tmptype == _C_VOID)
	    retsize = sizeof(void*);
	  else
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
	      if (pass_pointers) {
		(*decoder) (-1, retframe, tmptype, flags);
	      }
	      else {
		unsigned retLength;

		/* We are returning a pointer to something. */
		/* Increment TYPE so we can see what it is a pointer to. */
		tmptype++;
		retLength = objc_sizeof_type(tmptype);
		/* Allocate some memory to hold the value we're pointing to. */
		*(void**)retframe = 
		  objc_malloc (retLength);
		/* We are responsible for making sure this memory gets free'd
		   eventually.  Ask NSData class to autorelease it. */
		[NSData dataWithBytesNoCopy: *(void**)retframe
				     length: retLength];
		/* Decode the return value into the memory we allocated. */
		(*decoder) (-1, *(void**)retframe, tmptype, flags);
	      }
	      break;

	    case _C_STRUCT_B: 
	    case _C_UNION_B:
	    case _C_ARY_B:
	      /* The argument is a structure or array returned by value.
		 (In C, are array's allowed to be returned by value?) */
	      *(void**)retframe = MFRAME_GET_STRUCT_ADDR(argframe, tmptype);
	      /* Decode the return value into the memory we allocated. */
	      (*decoder) (-1, *(void**)retframe, tmptype, flags);
	      break;

	    case _C_FLT: 
	    case _C_DBL:
	      (*decoder) (-1, ((char*)retframe), tmptype, flags);
	      break;

	    case _C_VOID:
		{
		  (*decoder) (-1, retframe, @encode(int), 0);
		}
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
#if 1
		  /* Frith-Macdonald said this worked better 21 Nov 96. */
		  (*decoder) (-1, retframe, tmptype, flags);
#else
		  *(void**)retframe = 0;
		  (*decoder) (-1, ((char*)retframe)+sizeof(void*)-retsize,
			      tmptype, flags);
#endif
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
      (*decoder) (0, 0, 0, 0);	/* Tell it we have finished.	*/
    }
  else	/* matches `if (out_parameters)' */
    {
      /* We are just returning void, but retframe needs to point to
         something or else we can crash. */
      retframe = alloca (sizeof(void*));
    }

  switch (*rettype) {
    case _C_CHR:
    case _C_UCHR:
	return apply_char(*(char*)retframe);
    case _C_DBL:
	return apply_double(*(double*)retframe);
    case _C_FLT:
	return apply_float(*(float*)retframe);
    case _C_SHT:
    case _C_USHT:
	return apply_short(*(short*)retframe);
#if 0
    case _C_ARY_B:
    case _C_UNION_B:
    case _C_STRUCT_B:
	if (objc_sizeof_type(rettype) > 8) {
	    return apply_block(*(void**)retframe);
	}
#endif
  }

  /* Return the retval_t pointer to the return value. */
  return retframe;
}

retval_t 
mframe_build_return (arglist_t argframe, 
		     const char *type, 
		     BOOL out_parameters,
		     void(*decoder)(int,void*,const char*,int))
{
    return mframe_build_return_opts(argframe,type,out_parameters,decoder,NO);
}



arglist_t
mframe_create_argframe(const char *types, void** retbuf)
{
    arglist_t	argframe = objc_calloc(MFRAME_ARGS_SIZE, 1);
    const char*	rtype = objc_skip_type_qualifiers(types);
    int	stack_argsize = atoi(objc_skip_typespec(rtype));

    /*
     *	Allocate the space for variables passed on the stack.
     */
    if (stack_argsize) {
	argframe->arg_ptr = objc_calloc(stack_argsize, 1);
    }
    else {
	argframe->arg_ptr = 0;
    }
    if (*rtype == _C_STRUCT_B || *rtype == _C_UNION_B || *rtype == _C_ARY_B) {
	/*
	 *	If we haven't been passed a pointer to the location in which
	 *	to store a returned structure - allocate space and return
	 *	the address of the allocated space.
	 */
	if (*retbuf == 0) {
	    *retbuf = objc_calloc(objc_sizeof_type(rtype), 1);
	}
	MFRAME_SET_STRUCT_ADDR(argframe, rtype, *retbuf);
    }
    return argframe;
}

void
mframe_destroy_argframe(const char *types, arglist_t argframe)
{
    const char*	rtype = objc_skip_type_qualifiers(types);
    int	stack_argsize = atoi(objc_skip_typespec(rtype));

    if (stack_argsize) {
	objc_free(argframe->arg_ptr);
    }
    objc_free(argframe);
}



BOOL
mframe_decode_return (const char *type, void* buffer, void* retframe)
{
  int	size = 0;

  type = objc_skip_type_qualifiers(type);
  NSGetSizeAndAlignment(type, &size, 0);

  switch (*type)
    {
    case _C_ID:
      {
	inline id retframe_id(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(id*)buffer = retframe_id(retframe);
	break;
      }

    case _C_CLASS:
      {
	inline Class retframe_Class(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(Class*)buffer = retframe_Class(retframe);
	break;
      }

    case _C_SEL:
      {
	inline SEL retframe_SEL(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(SEL*)buffer = retframe_SEL(retframe);
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      {
	inline unsigned char retframe_char(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(unsigned char*)buffer = retframe_char(retframe);
	break;
      }

    case _C_SHT:
    case _C_USHT:
      {
	inline unsigned short retframe_short(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(unsigned short*)buffer = retframe_short(retframe);
	break;
      }

    case _C_INT:
    case _C_UINT:
      {
	inline unsigned int retframe_int(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(unsigned int*)buffer = retframe_int(retframe);
	break;
      }

    case _C_LNG:
    case _C_ULNG:
      {
	inline unsigned long retframe_long(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(unsigned long*)buffer = retframe_long(retframe);
	break;
      }

    case _C_FLT:
      {
	inline float retframe_float(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(float*)buffer = retframe_float(retframe);
	break;
      }

    case _C_DBL:
      {
	inline double retframe_double(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(double*)buffer = retframe_double(retframe);
	break;
      }

    case _C_PTR:
    case _C_ATOM:
    case _C_CHARPTR:
      {
	inline char* retframe_pointer(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(char**)buffer = retframe_pointer(retframe);
	break;
      }

    case _C_ARY_B:
    case _C_STRUCT_B:
    case _C_UNION_B:
      {
	typedef struct {
	  char	val[size];
	} block;
	inline block retframe_block(void *rframe)
	{
	  __builtin_return (rframe);
	}
	*(block*)buffer = retframe_block(retframe);
	break;
      }

    case _C_VOID:
      break;

    default:
      return NO;		/* Unknown type.	*/
    }
  return YES;
}



void*
mframe_handle_return(const char* type, void* retval, arglist_t argframe)
{
    retval_t	retframe;
    typedef struct { id many[8];} __big;
    __big return_block (void* data)
    {
      return *(__big*)data;
    }
    /* For returning a char (or unsigned char) */
    char return_char (char data)
    {
      return data;
    }
    /* For returning a double */
    double return_double (double data)
    {
      return data;
    }
    /* For returning a float */
    float return_float (float data)
    {
      return data;
    }
    /* For returning a short (or unsigned short) */
    short return_short (short data)
    {
      return data;
    }
    retval_t apply_block(void* data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_block, args, sizeof(void*));
    }
    retval_t apply_char(char data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_char, args, sizeof(void*));
    }
    retval_t apply_float(float data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_float, args, sizeof(float));
    }
    retval_t apply_double(double data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_double, args, sizeof(double));
    }
    retval_t apply_short(short data)
    {
      void* args = __builtin_apply_args();
      return __builtin_apply((apply_t)return_short, args, sizeof(void*));
    }

    retframe = alloca(MFRAME_RESULT_SIZE);

    switch (*type) {
	case _C_VOID:
	    break;
	case _C_CHR:
	case _C_UCHR:
	    return apply_char(*(char*)retval);
	case _C_DBL:
	    return apply_double(*(double*)retval);
	case _C_FLT:
	    return apply_float(*(float*)retval);
	case _C_SHT:
	case _C_USHT:
	    return apply_short(*(short*)retval);
	case _C_ARY_B:
	case _C_UNION_B:
	case _C_STRUCT_B:
	    {
		int    size = objc_sizeof_type(type);
#if 1
		void	*dest;

		dest = MFRAME_GET_STRUCT_ADDR(argframe, type);
		memcpy(dest, retval, size);
#else
		if (size > 8) {
		    return apply_block(*(void**)retval);
		}
		else {
		    memcpy(retframe, retval, size);
		}
#endif
	    }
	    break;
	default:
	    memcpy(retframe, retval, objc_sizeof_type(type));
	    break;
    }

    return retframe;
}

