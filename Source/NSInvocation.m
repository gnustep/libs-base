
/* Implementation of NSInvocation for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written:     Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1998
   Based on code by: Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   
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

#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSInvocation.h>
#include <include/fast.x>
#include <config.h>
#include <mframe.h>

@implementation NSInvocation

+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)signature
{
  return AUTORELEASE([[NSInvocation alloc] initWithMethodSignature: signature]);
}

- (void) dealloc
{
  if (argsRetained)
    {
      RELEASE(target);
      argsRetained = NO;
      if (argframe && sig)
	{
	  int	i;

	  for (i = 3; i <= numArgs; i++)
	    {
	      if (*info[i].type == _C_CHARPTR)
		{
		  char	*str;

		  mframe_get_arg(argframe, &info[i], &str);
		  objc_free(str);
		}
	      else if (*info[i].type == _C_ID)
		{
		  id	obj;

		  mframe_get_arg(argframe, &info[i], &obj);
		  RELEASE(obj);
		}
	    }
	}
    }
  if (argframe)
    {
      mframe_destroy_argframe([sig methodType], argframe);
    }
  if (retval)
    {
      objc_free(retval);
    }
  RELEASE(sig);
  [super dealloc];
}

/*
 *      Accessing message elements.
 */

- (void) getArgument: (void*)buffer
	     atIndex: (int)index
{
  if ((unsigned)index >= numArgs)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"bad invocation argument index"];
    }
  if (index == 0)
    {
      *(id*)buffer = target;
    }
  else if (index == 1)
    {
      *(SEL*)buffer = selector;
    }
  else
    {
      index++;	/* Allow offset for return type info.	*/
      mframe_get_arg(argframe, &info[index], buffer);
    }		
}

- (void) getReturnValue: (void*)buffer
{
  const char	*type;

  if (validReturn == NO)
    {
      [NSException raise: NSGenericException
		  format: @"getReturnValue with no value set"];
    }

  type = [sig methodReturnType];

  if (*info[0].type != _C_VOID)
    {
      int	length = info[0].size;
#if WORDS_BIGENDIAN
      if (length < sizeof(void*))
	length = sizeof(void*);
#endif
      memcpy(buffer, retval, length);
    }
}

- (SEL) selector
{
  return selector;
}

- (void) setArgument: (void*)buffer
	     atIndex: (int)index
{
  if ((unsigned)index >= numArgs)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"bad invocation argument index"];
    }
  if (index == 0)
    {
      [self setTarget: *(id*)buffer];
    }
  else if (index == 1)
    {
      [self setSelector: *(SEL*)buffer];
    }
  else
    {
      int		i = index+1;	/* Allow for return type in 'info' */
      const char	*type = info[i].type;

      if (argsRetained && (*type == _C_ID || *type == _C_CHARPTR))
	{
	  if (*type == _C_ID)
	    {
	      id	old;

	      mframe_get_arg(argframe, &info[i], &old);
	      mframe_set_arg(argframe, &info[i], buffer);
	      RETAIN(*(id*)buffer);
	      if (old != nil)
		{
		  RELEASE(old);
		}
	    }
	  else
	    {
	      char	*oldstr;
	      char	*newstr = *(char**)buffer;

	      mframe_get_arg(argframe, &info[i], &oldstr);
	      if (newstr == 0)
		{
		  mframe_set_arg(argframe, &info[i], buffer);
		}
	      else
		{
		  char	*tmp = objc_malloc(strlen(newstr)+1);

		  strcpy(tmp, newstr);
		  mframe_set_arg(argframe, &info[i], tmp);
		}
	      if (oldstr != 0)
		{
		  objc_free(oldstr);
		}
	    }
	}
      else
	{
	  mframe_set_arg(argframe, &info[i], buffer);
	}
    }		
}

- (void) setReturnValue: (void*)buffer
{
  const char	*type;

  type = info[0].type;

  if (*type != _C_VOID)
    {
      int	length = info[0].size;

#if WORDS_BIGENDIAN
      if (length < sizeof(void*))
	length = sizeof(void*);
#endif
      memcpy(retval, buffer, length);
    }
  validReturn = YES;
}

- (void) setSelector: (SEL)aSelector
{
  selector = aSelector;
}

- (void) setTarget: (id)anObject
{
  if (argsRetained)
    {
      ASSIGN(target, anObject);
    }
  target = anObject;
}

- (id) target
{
  return target;
}

/*
 *      Managing arguments.
 */

- (BOOL) argumentsRetained
{
  return argsRetained;
}

- (void)retainArguments
{
  if (argsRetained)
    {
      return;
    }
  else
    {
      int	i;

      argsRetained = YES;
      RETAIN(target);
      if (argframe == 0)
	{
	  return;
	}
      for (i = 3; i <= numArgs; i++)
	{
	  if (*info[i].type == _C_ID || *info[i].type == _C_CHARPTR)
	    {
	      if (*info[i].type == _C_ID)
		{
		  id	old;

		  mframe_get_arg(argframe, &info[i], &old);
		  if (old != nil)
		    {
		      RETAIN(old);
		    }
		}
	      else
		{
		  char	*str;

		  mframe_get_arg(argframe, &info[i], &str);
		  if (str != 0)
		    {
		      char	*tmp = objc_malloc(strlen(str)+1);

		      strcpy(tmp, str);
		      mframe_set_arg(argframe, &info[i], &tmp);
		    }
		}
	    }
	}
    }		
}

/*
 *      Dispatching an Invocation.
 */

- (void) invoke
{
  [self invokeWithTarget: target];
}

- (void) invokeWithTarget:(id)anObject
{
  id		old_target;
  retval_t	returned;
  IMP		imp;
  int		stack_argsize;

  /*
   *	A message to a nil object returns nil.
   */
  if (anObject == nil)
    {
      memset(retval, '\0', info[0].size);	/* Clear return value */
      return;
    }

  NSAssert(selector != 0, @"you must set the selector before invoking");

  /*
   *	Temporarily set new target and copy it (and the selector) into the
   *	argframe.
   */
  old_target = RETAIN(target);
  [self setTarget: anObject];

  mframe_set_arg(argframe, &info[1], &target);

  mframe_set_arg(argframe, &info[2], &selector);

  imp = method_get_imp(object_is_instance(target) ?
	      class_get_instance_method(
		    ((struct objc_class*)target)->class_pointer, selector)
	    : class_get_class_method(
		    ((struct objc_class*)target)->class_pointer, selector));
  /*
   *	If fast lookup failed, we may be forwarding or something ...
   */
  if (imp == 0)
    imp = objc_msg_lookup(target, selector);

  [self setTarget: old_target];
  RELEASE(old_target);

  stack_argsize = [sig frameLength];

  returned = __builtin_apply((void(*)(void))imp, argframe, stack_argsize);
  if (info[0].size)
    {
      mframe_decode_return(info[0].type, retval, returned);
    }
  validReturn = YES;
}

/*
 *      Getting the method signature.
 */

- (NSMethodSignature*) methodSignature
{
  return sig;
}

- (NSString*)description
{
  /*
   *	Don't use -[NSString stringWithFormat:] method because it can cause
   *	infinite recursion.
   */
  char buffer[1024];

  sprintf (buffer, "<%s %p selector: %s target: %s>", \
                (char*)object_get_class_name(self), \
                self, \
                selector ? [NSStringFromSelector(selector) cString] : "nil", \
                target ? [NSStringFromClass([target class]) cString] : "nil" \
                );

  return [NSString stringWithCString:buffer];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  const char	*types = [sig methodType];
  int		i;

  [aCoder encodeValueOfObjCType: @encode(char*)
			     at: &types];

  [aCoder encodeObject: target];

  [aCoder encodeValueOfObjCType: info[2].type
			     at: &selector];

  for (i = 3; i <= numArgs; i++)
    {
      const char	*type = info[i].type;
      void		*datum;

      datum = mframe_arg_addr(argframe, &info[i]);

      if (*type == _C_ID)
	{
	  [aCoder encodeObject: *(id*)datum];
	}
#if     MFRAME_STRUCT_BYREF
      else if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B)
        {
	  [aCoder encodeValueOfObjCType: type at: *(void**)datum];
        }
#endif
      else
	{
	  [aCoder encodeValueOfObjCType: type at: datum];
	}
    }
  if (*info[0].type != _C_VOID)
    {
      [aCoder encodeValueOfObjCType: @encode(BOOL) at: &validReturn];
      if (validReturn)
	{
	  [aCoder encodeValueOfObjCType: info[0].type at: retval];
	}
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSMethodSignature	*newSig;
  const char		*types;
  void			*datum;
  int			i;

  [aCoder decodeValueOfObjCType: @encode(char*) at: &types];
  newSig = [NSMethodSignature signatureWithObjCTypes: types];
  self = [self initWithMethodSignature: newSig];
 
  [aCoder decodeValueOfObjCType: @encode(id) at: &target];

  [aCoder decodeValueOfObjCType: @encode(SEL) at: &selector];

  for (i = 3; i <= numArgs; i++)
    {
      datum = mframe_arg_addr(argframe, &info[i]);
#if     MFRAME_STRUCT_BYREF
      {
        const char      *t = info[i].type;
        if (*t == _C_STRUCT_B || *t == _C_UNION_B || *t == _C_ARY_B)
          {
	    *(void**)datum = _fastMallocBuffer(info[i].size);
            datum = *(void**)datum;
          }
      }
#endif
      [aCoder decodeValueOfObjCType: info[i].type at: datum];
    }
  argsRetained = YES;
  if (*info[0].type != _C_VOID)
    {
      [aCoder decodeValueOfObjCType: @encode(BOOL) at: &validReturn];
      if (validReturn)
	{
	  [aCoder decodeValueOfObjCType: info[0].type at: retval];
	}
    }
  return self;
}



@end

@implementation NSInvocation (GNUstep)

- initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
{
  const char		*types;
  NSMethodSignature	*newSig;

  types = sel_get_type(aSelector);
  if (types == 0)
    {
      types = sel_get_type(sel_get_any_typed_uid(sel_get_name(aSelector)));
    }
  if (types == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Couldn't find encoding type for selector %s.",
			 sel_get_name(aSelector)];
    }
  newSig = [NSMethodSignature signatureWithObjCTypes: types];
  self = [self initWithMethodSignature: newSig];
  if (self)
    {
      [self setSelector: aSelector];
      /*
       *	Copy the argframe we were given.
       */
      if (frame)
	{
	  int	i;

	  mframe_get_arg(frame, &info[1], &target);
	  for (i = 1; i <= numArgs; i++)
	    {
	      mframe_cpy_arg(argframe, frame, &info[i]);
	    }
	}
    }
  return self;
}

/*
 *	This is the designated initialiser.
 */
- initWithMethodSignature: (NSMethodSignature*)aSignature
{
  sig = RETAIN(aSignature);
  numArgs = [aSignature numberOfArguments];
  info = [aSignature methodInfo];
  argframe = mframe_create_argframe([sig methodType], &retval);
  if (retval == 0 && info[0].size > 0)
    {
      retval = objc_malloc(info[0].size);
    }
  return self;
}

- initWithSelector: (SEL)aSelector
{
  return [self initWithArgframe: 0 selector: aSelector];
}

- initWithTarget: anObject selector: (SEL)aSelector, ...
{
  va_list	ap;

  self = [self initWithArgframe: 0 selector: aSelector];
  if (self)
    {
      int	i;

      [self setTarget: anObject];
      va_start (ap, aSelector);
      for (i = 3; i <= numArgs; i++)
	{
	  const char	*type = info[i].type;
	  unsigned	size = info[i].size;
	  void		*datum;

	  datum = mframe_arg_addr(argframe, &info[i]);

#define CASE_TYPE(_C,_T) case _C: *(_T*)datum = va_arg (ap, _T); break
	  switch (*type)
	    {
	      case _C_ID:
		*(id*)datum = va_arg (ap, id);
		if (argsRetained)
		  {
		    RETAIN(*(id*)datum);
		  }
		break;
	      case _C_CHARPTR:
		*(char**)datum = va_arg (ap, char*);
		if (argsRetained)
		  {
		    char	*old = *(char**)datum;

		    if (old != 0)
		      {
			char	*tmp = objc_malloc(strlen(old)+1);

			strcpy(tmp, old);
			*(char**)datum = tmp;
		      }
		  }
		break;
	      CASE_TYPE(_C_CLASS, Class);
	      CASE_TYPE(_C_SEL, SEL);
	      CASE_TYPE(_C_LNG, long);
	      CASE_TYPE(_C_ULNG, unsigned long);
	      CASE_TYPE(_C_INT, int);
	      CASE_TYPE(_C_UINT, unsigned int);
	      CASE_TYPE(_C_SHT, short);
	      CASE_TYPE(_C_USHT, unsigned short);
	      CASE_TYPE(_C_CHR, char);
	      CASE_TYPE(_C_UCHR, unsigned char);
	      CASE_TYPE(_C_FLT, float);
	      CASE_TYPE(_C_DBL, double);
	      CASE_TYPE(_C_PTR, void*);
	      default:
		{
		  memcpy(datum, va_arg(ap, typeof(char[size])), size);
		} /* default */
	    }
	}
    }
  return self;
}

- (void*) returnFrame: (arglist_t)argFrame
{
  return mframe_handle_return(info[0].type, retval, argFrame);
}
@end

@implementation NSInvocation (BackwardCompatibility)

- (void) invokeWithObject: (id)obj
{
  [self invokeWithTarget: (id)obj];
}

@end

