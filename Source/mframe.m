/* Implementation of functions for dissecting/making method calls 
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: Oct 1994
   
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

/* These functions can be used for dissecting and making method calls
   for many different situations.  They are used for distributed
   objects; they could also be used to make interfaces between
   Objective C and Scheme, Perl, Tcl, whatever...  I need to
   generalize this stuff a little more to make it useable for an
   Invocation class also. */

#include <objects/stdobjects.h>
#include <objects/stdobjects.h>
#include <objects/objc-malloc.h>
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
#define CONNECTION_STRUCTURES_PASSED_BY_REFERENCE 1
#else
#define CONNECTION_STRUCTURES_PASSED_BY_REFERENCE 0
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


/*
  Return the number of arguments that the method MTH expects.
  Note that all methods need two implicit arguments `self' and
  `_cmd'. 
*/
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

/*
  Return the size of the argument block needed on the stack to invoke
  the method MTH.  This may be zero, if all arguments are passed in
  registers.
*/

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


/* Returns YES iff there are any outparameters */
BOOL
dissect_method_call(arglist_t argframe, const char *type,
		    void (*f)(int,void*,const char*,int))
{
  const char *tmptype;
  unsigned flags;
  char *datum;
  int argnum;
  BOOL out_parameters = NO;

  tmptype = type;
  for (datum = method_types_get_next_argument(argframe, &tmptype), argnum=0;
       datum;
       datum = method_types_get_next_argument(argframe, &tmptype), argnum++)
    {
      flags = objc_get_type_qualifiers(tmptype);
      tmptype = objc_skip_type_qualifiers(tmptype);
      if (*tmptype == _C_CHARPTR)
	{
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*f)(argnum, datum, tmptype, flags);
	}
      else if (*tmptype == _C_PTR)
	{
	  tmptype++;
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  /* xxx These two cases currently the same */
	  if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	    {
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*f)(argnum, *(void**)datum, tmptype, flags);
	    }
	  else
	    {
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*f)(argnum, *(void**)datum, tmptype, flags);
	    }
	}
      else if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	{
#if CONNECTION_STRUCTURES_PASSED_BY_REFERENCE
	  (*f)(argnum, *(void**)datum, tmptype, flags);
#else
	  (*f)(argnum, datum, tmptype, flags);
#endif
	}
      else
	{
	  (*f)(argnum, datum, tmptype, flags);
	}
    }
  return out_parameters;
}


void
make_method_call(const char *forward_type,
		 void(*fd)(int,void*,const char*),
		 void(*fe)(int,void*,const char*,int))
{
  const char *type, *tmptype;
  const char *ftmptype;
  id object;
  SEL selector;
  IMP imp;
  void *retframe;
#if NeXT_runtime
  union {
    char *arg_ptr;
    char arg_regs[sizeof (char*)];
  } *argframe;
#else
  arglist_t argframe;
#endif
  int stack_argsize;
  int reg_argsize;
  char *datum;
  unsigned flags;
  BOOL out_parameters = NO;
  int argnum;

  /* get object and selector */
  (*fd)(0, &object, @encode(id));
  assert(object);

  /* @encode(SEL) produces "^v" in gcc 2.5.8.  It should be ":" */
  (*fd)(1, &selector, ":");
  assert(selector);

#if NeXT_runtime
  {
    Method m;
    m = (class_getInstanceMethod(object->isa, selector));
    if (!m) 
      abort();
    type = m->method_types;
  }
#else
  type = sel_get_type(selector);
#endif /* NeXT_runtime */
  assert(type);
  assert(sel_types_match(forward_type, type));

  /* Set up argframe */
  stack_argsize = method_types_get_size_of_stack_arguments(type);
  reg_argsize = method_types_get_size_of_register_arguments(type);
  argframe = (arglist_t) alloca(sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = alloca(stack_argsize);
  else
    argframe->arg_ptr = 0;

  /* decode rest of arguments */
  tmptype = type;
  ftmptype = objc_skip_argspec(forward_type);
  datum = method_types_get_next_argument(argframe, &tmptype);
  assert(datum);
  assert(*tmptype == _C_ID);
  *(id*)datum = object;
  assert(object);
  ftmptype = objc_skip_argspec(ftmptype);
  datum = method_types_get_next_argument(argframe, &tmptype);
  assert(datum);
  assert(*tmptype == _C_SEL);
  *(SEL*)datum = selector;
  assert(selector);
  for (datum = method_types_get_next_argument(argframe, &tmptype),
       ftmptype = objc_skip_argspec(ftmptype), argnum = 2;
       datum;
       datum = method_types_get_next_argument(argframe, &tmptype),
       ftmptype = objc_skip_argspec(ftmptype), argnum++)
    {
      flags = objc_get_type_qualifiers(ftmptype);
      tmptype = objc_skip_type_qualifiers(tmptype);
      if (*tmptype == _C_CHARPTR)
	{
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  if ((flags & _F_IN) || !(flags & _F_OUT))
	    (*fd)(argnum, datum, tmptype);
	}
      else if (*tmptype == _C_PTR)
	{
	  tmptype++;
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  /* xxx These two cases currently the same */
	  if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	    {
	      /* *(void**)datum = alloca(sizeof(void*)); */
	      /* xxx or should this be alloca?!  
		 What about inout params?  Where do they get freed? */
	      *(void**)datum = 
		(*objc_malloc)(objc_sizeof_type(tmptype));
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*fd)(argnum, *(void**)datum, tmptype);
	    }
	  else
	    {
	      /* xxx or should this be alloca?!  
		 What about inout params?  Where dothey get freed? */
	      *(char**)datum = 
		(*objc_malloc)(objc_sizeof_type(tmptype));
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		(*fd)(argnum, *(void**)datum, tmptype);
	    }
	}
      else if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	{
#if CONNECTION_STRUCTURES_PASSED_BY_REFERENCE
	  *(void**)datum = alloca(objc_sizeof_type(tmptype));
	  (*fd)(argnum, *(void**)datum, tmptype);
#else
	  (*fd)(argnum, datum, tmptype);
#endif
	}
      else
	{
	  (*fd)(argnum, datum, tmptype);
	}
    }

  /* Call the method */
  imp = objc_msg_lookup(object, selector);
  assert(imp);
  retframe = __builtin_apply((void(*)(void))imp, 
			     argframe, 
			     stack_argsize);

  /* Return results, if necessary */
  flags = objc_get_type_qualifiers(forward_type);
  ftmptype = objc_skip_type_qualifiers(forward_type);
  tmptype = objc_skip_type_qualifiers(type);
  /* Is this right?  Do we also have to check _F_ONEWAY? */
  if (out_parameters || *tmptype != _C_VOID)
    {
      if (*tmptype != _C_VOID)
	{
	  /* encode return value */
	  /* xxx Change this to switch(*tmptype) */
	  if (*tmptype == _C_ID)
	    {
	      (*fe)(-1, retframe, @encode(id), flags);
	    }
	  else if (*tmptype == _C_PTR)
	    {
	      tmptype++;
	      /* xxx These two cases currently the same */
	      if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
		(*fe)(-1, *(void**)retframe, tmptype, flags);
	      else
		(*fe)(-1, *(void**)retframe, tmptype, flags);
	    }
	  else if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	    {
	      /* xxx these two cases currently the same? */
#if CONNECTION_STRUCTURES_PASSED_BY_REFERENCE
	      (*fe)(-1, *(void**)retframe, tmptype, flags);
#else
	      (*fe)(-1, *(void**)retframe, tmptype, flags);
#endif
	    }
	  else if (*tmptype == _C_FLT || *tmptype == _C_DBL)
	    {
	      /* xxx For floats on MIPS, it seems I should add 4 more in
		 addition to the FLT_AND_DBL_RETFRAME_OFFSET while working
		 on guileobjc.
		 Look into this for Distributed Objects. */
	      /* xxx Yipes!  Perhaps this change is needed on other
		 architectures too. */
#if __mips__
	      if (*tmptype == _C_FLT)
		(*fe)(-1, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET + 4,
		      tmptype, flags);
	      else
		(*fe)(-1, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET,
		      tmptype, flags);
#else
	      (*fe)(-1, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET,
		    tmptype, flags);
#endif
	    }
	  else /* Among other types, _C_CHARPTR is handled here */
	    {
	      int retsize = objc_sizeof_type(tmptype);
	      /* Special case BOOL (and other types smaller than int)
		 because retframe doesn't actually point to the char */
	      /* xxx What about structures smaller than int's that
		 are passed by reference on true structure reference-
		 passing architectures? */
	      /* xxx Is this the right test?  Use sizeof(int*) instead? */
	      if (retsize < sizeof(void*))
		{
		  (*fe)(-1, ((char*)retframe)+sizeof(void*)-retsize,
			tmptype, flags);
		}
	      else
		{
		  (*fe)(-1, retframe, tmptype, flags);
		}
	    }
	}

      /* encode values returned by reference */
      if (out_parameters)
	{
	  for (datum = method_types_get_next_argument(argframe,&tmptype), 
	       argnum = 1,
	       ftmptype = objc_skip_argspec(ftmptype);
	       datum;
	       datum = method_types_get_next_argument(argframe,&tmptype), 
	       argnum++,
	       ftmptype = objc_skip_argspec(ftmptype))
	    {
	      flags = objc_get_type_qualifiers(ftmptype);
	      tmptype = objc_skip_type_qualifiers(tmptype);
	      if ((*tmptype == _C_PTR) 
		  && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  tmptype++;
		  /* xxx These two cases currently the same */
		  if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
		    {
		      (*fe)(argnum, *(void**)datum, tmptype, flags);
		    }
		  else
		    {
		      (*fe)(argnum, *(void**)datum, tmptype, flags);
		    }
		}
	      else if (*tmptype == _C_CHARPTR
		       && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  (*fe)(argnum, datum, tmptype, flags);
		}
	    }
	}
    }
  return;
}


/* In the function that calls this one, be careful about calling more
   functions after this one.  The memory for the retval_t is alloca'ed.

   Pointer values returned by the method or non-const strings passed
   in will now point to newly malloc'ed memory.  It is your
   responsibility to free it.  This is thoroughly disgusting, and will
   be fixed as soon as we get rid of the -free method and replace it
   with something better.
 */

retval_t 
dissect_method_return(arglist_t argframe, const char *type, 
		      BOOL out_parameters,
		      void(*f)(int,void*,const char*,int))
{
  retval_t retframe;
  int argnum;
  int retsize;
  int flags;
  const char *tmptype;
  void *datum;

  /* get return values, if necessary */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);
  /* xxx What happens with method declared "- (oneway) foo: (out int*)ip;" */
  /* xxx What happens with method declared "- (in char *) bar;" */
  /* Is this right?  Do we also have to check _F_ONEWAY? */
  if (out_parameters || *tmptype != _C_VOID)
    {
      argnum = -1;
      if (*tmptype != _C_VOID)
	{
	  /* decode return value */
	  retsize = objc_sizeof_type(tmptype);
	  /* xxx We need to test retsize's less than 4.  Also note that
	     if we return structures using a structure-value-address, we
	     are potentially alloca'ing much more than we need here. */
	  /* xxx Find out about returning structures by reference
	     on non--structure-value-address machines, and potentially
	     just always alloca(RETFRAME_SIZE == sizeof(void*)*4) */
	  retframe = alloca(MAX(retsize, sizeof(void*)*4));
	  /* xxx change this to a switch (*tmptype) */
	  if (*tmptype == _C_PTR)
	    {
	      tmptype++;
	      /* xxx these two cases are the same */
	      if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
		{
		  *(void**)retframe = 
		    (*objc_malloc)(objc_sizeof_type(tmptype));
		  (*f)(argnum, *(void**)retframe, tmptype, flags);
		}
	      else
		{
		  *(void**)retframe = 
		    (*objc_malloc)(objc_sizeof_type(tmptype));
		  (*f)(argnum, *(void**)retframe, tmptype, flags);
		}
	    }
	  else if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
	    {
	      /* xxx These two cases currently the same */
#if CONNECTION_STRUCTURES_PASSED_BY_REFERENCE
		*(void**)retframe = alloca(objc_sizeof_type(tmptype));
	      (*f)(argnum, *(void**)retframe, tmptype, flags);
#else
	      *(void**)retframe = alloca(objc_sizeof_type(tmptype));
	      (*f)(argnum, *(void**)retframe, tmptype, flags);
#endif
	    }
	  else if (*tmptype == _C_FLT || *tmptype == _C_DBL)
	    {
	      (*f)(argnum, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET,
		   tmptype, flags);
	    }
	  else			/* Among other things, _C_CHARPTR is handled here */
	    {
	      /* int typesize;  xxx Use retsize instead! */
	      /* xxx was: (typesize = objc_sizeof_type(tmptype)) */
	      /* Special case BOOL (and other types smaller than int)
		 because retframe doesn't actually point to the char */
	      /* xxx What about structures smaller than int's that
		 are passed by reference on true structure reference-
		 passing architectures? */
	      /* xxx Is this the right test?  Use sizeof(int*) instead? */
	      if (retsize < sizeof(void*))
		{
		  *(void**)retframe = 0;
		  (*f)(argnum, ((char*)retframe)+sizeof(void*)-retsize,
		       tmptype, flags);
		}
	      else
		{
		  (*f)(argnum, retframe, tmptype, flags);
		}
	    }
	}
      
      /* decode values returned by reference */
      if (out_parameters)
	{
	  for (datum = method_types_get_next_argument(argframe, &tmptype), 
	       argnum=0;
	       datum;
	       (datum = method_types_get_next_argument(argframe, &tmptype)), 
	       argnum++)
	    {
	      flags = objc_get_type_qualifiers(tmptype);
	      tmptype = objc_skip_type_qualifiers(tmptype);
	      if (*tmptype == _C_PTR
		  && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  tmptype++;
		  /* xxx Note that a (char**) is malloc'ed anew here.
		     Yucky, or worse than yucky.  If the returned string
		     is smaller than the original, we should just put it
		     there; if the returned string is bigger, I don't know
		     what to do. */
		  /* xxx These two cases are the same */
		  if (*tmptype == _C_STRUCT_B || *tmptype == _C_ARY_B)
		    {
		      (*f)(argnum, *(void**)datum, tmptype, flags);
		    }
		  else
		    {
		      (*f)(argnum, *(void**)datum, tmptype, flags);
		    }
		}
	      /* __builtin_return can't return structures by value */
	      else if (*tmptype == _C_CHARPTR
		       && ((flags & _F_OUT) || !(flags & _F_IN)))
		{
		  (*f)(argnum, datum, tmptype, flags);
		}
	    }
	}
    }
  else	/* void return value */
    {
      retframe = alloca(sizeof(void*));
    }
  return retframe;
}
