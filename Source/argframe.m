#include <objc/encoding.h>
#include <objc/objc-api.h>
#include <assert.h>

/* These functions can be used for dissecting and making method calls
   for many different situations.  They are used for distributed
   objects, they could also be used to make interfaces between
   Objective C and Scheme, Perl, Tcl, whatever...  I need to
   generalize this stuff a little more to make it useable for an
   Invocation class also. */

/* Returns YES iff there are any outparameters */
BOOL
dissect_method_call(arglist_t frame, const char *type,
		    void (*f)(int,void*,const char*,int))
{
  const char *tmptype;
  unsigned flags;
  char *datum;
  int argnum;

  tmptype = type;
  for (datum = my_method_get_next_argument(argframe, &tmptype), argnum=0;
       datum;
       datum = my_method_get_next_argument(argframe, &tmptype), argnum++)
    {
      flags = objc_get_type_qualifiers(tmptype);
      tmptype = objc_skip_type_qualifiers(tmptype);
      if (*tmptype == _C_ID)
	{
	  (*f)(argnum, datum, tmptype, flags);
	}
      else if (*tmptype == _C_CHARPTR)
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
  arglist_t argframe;
  int stack_argsize;
  int reg_argsize;
  char *datum;
  id op;
  unsigned flags;
  BOOL out_parameters = NO;
  int argnum;

  /* get object and selector */
  (*fd)(0, &object, @encode(id));

  /* @encode(SEL) produces "^v" in gcc 2.5.8.  It should be ":" */
  (*fd)(1, &selector, ":");
  assert(selector);

  type = sel_get_type(selector);
  assert(type);

  /* Set up argframe */
  stack_argsize = types_get_size_of_stack_arguments(type);
  reg_argsize = types_get_size_of_register_arguments(type);
  argframe = (arglist_t) alloca(sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = alloca(stack_argsize);
  else
    argframe->arg_ptr = 0;

  /* decode rest of arguments */
  tmptype = type;
  ftmptype = objc_skip_argspec(forward_type);
  datum = my_method_get_next_argument(argframe, &tmptype);
  assert(datum);
  assert(*tmptype == _C_ID);
  *(id*)datum = object;
  assert(object);
  ftmptype = objc_skip_argspec(ftmptype);
  datum = my_method_get_next_argument(argframe, &tmptype);
  assert(datum);
  assert(*tmptype == _C_SEL);
  *(SEL*)datum = selector;
  assert(selector);
  for (datum = my_method_get_next_argument(argframe, &tmptype),
       ftmptype = objc_skip_argspec(ftmptype), argnum = 2;
       datum;
       datum = my_method_get_next_argument(argframe, &tmptype),
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
  retframe = __builtin_apply((apply_t)imp, 
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
	      (*fe)(-1, ((char*)retframe) + FLT_AND_DBL_RETFRAME_OFFSET
		    tmptype, flags);
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
		  (*fe)(-1, ((char*)retframe)+sizeof(void*)-retsize
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
	  for (datum = my_method_get_next_argument(argframe,&tmptype), 
	       argnum = 1,
	       ftmptype = objc_skip_argspec(ftmptype);
	       datum;
	       datum = my_method_get_next_argument(argframe,&tmptype), 
	       argnum++,
	       ftmptype = objc_skip_argspec(ftmptype))
	    {
	      flags = objc_get_type_qualifiers(ftmptype);
	      tmptype = objc_skip_type_qualifiers(tmptype);
	      sprintf(argname, "arg%d", argnum); /* too expensive? */
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
  return self;
}


void f_decode_rets (int argnum, void *datum, const char *type)
{
  [ip decodeValueOfObjCType:type
      at:datum
      withName:NULL];
}

/* In the function that calls this one, be careful about calling more
   functions after this one.  The memory for the retval_t is alloca'ed */
retval_t dissect_method_return(arglist_t frame, const char *type, 
			       BOOL out_parameters,
			       void(*f)(int,void*,const char*,int))
{
  retval_t retframe;
  int argnum;
  int flags;
  const char *tmptype;

  /* get return values, if necessary */
  flags = objc_get_type_qualifiers(type);
  tmptype = objc_skip_type_qualifiers(type);
  /* xxx What happens with method declared "- (oneway) foo: (out int*)ip;" */
  /* xxx What happens with method declared "- (in char *) bar;" */
  /* Is this right?  Do we also have to check _F_ONEWAY? */
  if (out_parameters || *tmptype != _C_VOID)
    {
      argnum = -1
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
		xxx wwoooooo, we have to alloca in the frame above
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
	    else		/* Among other things, _C_CHARPTR is handled here */
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
	  for (datum = my_method_get_next_argument(argframe, &tmptype), argnum=0;
	       datum;
	       (datum = my_method_get_next_argument(argframe, &tmptype)), argnum++)
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
}
