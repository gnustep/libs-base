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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSInvocation.h>
#include <base/GSInvocation.h>
#include <config.h>
#include <mframe.h>
#if defined(USE_LIBFFI)
#include "cifframe.h"
#elif defined(USE_FFCALL)
#include "callframe.h"
#endif


static Class   NSInvocation_abstract_class;
static Class   NSInvocation_concrete_class;

@implementation NSInvocation

#ifdef USE_LIBFFI
static inline void
_get_arg(NSInvocation *inv, int index, void *buffer)
{
  cifframe_get_arg((cifframe_t *)inv->_cframe, index, buffer);
}

static inline void
_set_arg(NSInvocation *inv, int index, void *buffer)
{
  cifframe_set_arg((cifframe_t *)inv->_cframe, index, buffer);
}

static inline void *
_arg_addr(NSInvocation *inv, int index)
{
  return cifframe_arg_addr((cifframe_t *)inv->_cframe, index);
}

#elif defined(USE_FFCALL)
static inline void
_get_arg(NSInvocation *inv, int index, void *buffer)
{
  callframe_get_arg((callframe_t *)inv->_cframe, index, buffer,
		    inv->_info[index+1].size);
}

static inline void
_set_arg(NSInvocation *inv, int index, void *buffer)
{
  callframe_set_arg((callframe_t *)inv->_cframe, index, buffer,
		    inv->_info[index+1].size);
}

static inline void *
_arg_addr(NSInvocation *inv, int index)
{
  return callframe_arg_addr((callframe_t *)inv->_cframe, index);
}

#else
_get_arg(NSInvocation *inv, int index, void *buffer)
{
  mframe_get_arg(inv->_argframe, &inv->_info[index+1], &buffer);
}

static inline void
_set_arg(NSInvocation *inv, int index, void *buffer)
{
  mframe_set_arg(inv->_argframe, &inv->_info[index+1], buffer);
}

static inline void *
_arg_addr(NSInvocation *inv, int index)
{
  return mframe_arg_addr(inv->_argframe, &inv->_info[index+1]);
}

#endif

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == NSInvocation_abstract_class)
    {
      return NSAllocateObject(NSInvocation_concrete_class, 0, aZone);
    }
  else
    {
      return NSAllocateObject(self, 0, aZone);
    }
}

+ (void) initialize
{
  if (self == [NSInvocation class])
    {
      NSInvocation_abstract_class = self;
#if defined(USE_LIBFFI)
      NSInvocation_concrete_class = [GSFFIInvocation class];
#elif defined(USE_FFCALL)
      NSInvocation_concrete_class = [GSFFCallInvocation class];
#else
      NSInvocation_concrete_class = [GSFrameInvocation class];
#endif
    }
}

+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)_signature
{
  return AUTORELEASE([[NSInvocation_concrete_class alloc]
    initWithMethodSignature: _signature]);
}

- (void) dealloc
{
  if (_argsRetained)
    {
      RELEASE(_target);
      _argsRetained = NO;
      if (_argframe && _sig)
	{
	  int	i;

	  for (i = 3; i <= _numArgs; i++)
	    {
	      if (*_info[i].type == _C_CHARPTR)
		{
		  char	*str;

		  _get_arg(self, i-1, &str);
		  NSZoneFree(NSDefaultMallocZone(), str);
		}
	      else if (*_info[i].type == _C_ID)
		{
		  id	obj;

		  _get_arg(self, i-1, &obj);
		  RELEASE(obj);
		}
	    }
	}
    }
#ifdef USE_LIBFFI
  if (_cframe)
    cifframe_free((cifframe_t *)_cframe);
#else
#ifdef USE_FFCALL
  if (_cframe)
    callframe_free((callframe_t *)_cframe);
#endif
#endif
  if (_argframe)
    {
      mframe_destroy_argframe([_sig methodType], _argframe);
    }
  if (_retval)
    {
      NSZoneFree(NSDefaultMallocZone(), _retval);
    }
  RELEASE(_sig);
  [super dealloc];
}

/*
 *      Accessing message elements.
 */

- (void) getArgument: (void*)buffer
	     atIndex: (int)index
{
  if ((unsigned)index >= _numArgs)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"bad invocation argument index"];
    }
  if (index == 0)
    {
      *(id*)buffer = _target;
    }
  else if (index == 1)
    {
      *(SEL*)buffer = _selector;
    }
  else
    {
      _get_arg(self, index, buffer);
    }		
}

- (void) getReturnValue: (void*)buffer
{
  const char	*type;

  if (_validReturn == NO)
    {
      [NSException raise: NSGenericException
		  format: @"getReturnValue with no value set"];
    }

  type = [_sig methodReturnType];

  if (*_info[0].type != _C_VOID)
    {
      int	length = _info[0].size;
#if WORDS_BIGENDIAN
      if (length < sizeof(void*))
	length = sizeof(void*);
#endif
      memcpy(buffer, _retval, length);
    }
}

- (SEL) selector
{
  return _selector;
}

- (void) setArgument: (void*)buffer
	     atIndex: (int)index
{
  if ((unsigned)index >= _numArgs)
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
      int		i = index+1;	/* Allow for return type in '_info' */
      const char	*type = _info[i].type;

      if (_argsRetained && (*type == _C_ID || *type == _C_CHARPTR))
	{
	  if (*type == _C_ID)
	    {
	      id	old;

	      _get_arg(self, index, &old);
	      _set_arg(self, index, buffer);
	      IF_NO_GC(RETAIN(*(id*)buffer));
	      if (old != nil)
		{
		  RELEASE(old);
		}
	    }
	  else
	    {
	      char	*oldstr;
	      char	*newstr = *(char**)buffer;

	      _get_arg(self, index, &oldstr);
	      if (newstr == 0)
		{
		  _set_arg(self, index, buffer);
		}
	      else
		{
		  char	*tmp;

		  tmp = NSZoneMalloc(NSDefaultMallocZone(), strlen(newstr)+1);
		  strcpy(tmp, newstr);
		  _set_arg(self, index, tmp);
		}
	      if (oldstr != 0)
		{
		  NSZoneFree(NSDefaultMallocZone(), oldstr);
		}
	    }
	}
      else
	{
	  _set_arg(self, index, buffer);
	}
    }		
}

- (void) setReturnValue: (void*)buffer
{
  const char	*type;

  type = _info[0].type;

  if (*type != _C_VOID)
    {
      int	length = _info[0].size;

#if WORDS_BIGENDIAN
      if (length < sizeof(void*))
	length = sizeof(void*);
#endif
      memcpy(_retval, buffer, length);
    }
  _validReturn = YES;
}

- (void) setSelector: (SEL)aSelector
{
  _selector = aSelector;
}

- (void) setTarget: (id)anObject
{
  if (_argsRetained)
    {
      ASSIGN(_target, anObject);
    }
  _target = anObject;
}

- (id) target
{
  return _target;
}

/*
 *      Managing arguments.
 */

- (BOOL) argumentsRetained
{
  return _argsRetained;
}

- (void) retainArguments
{
  if (_argsRetained)
    {
      return;
    }
  else
    {
      int	i;

      _argsRetained = YES;
      IF_NO_GC(RETAIN(_target));
      if (_argframe == 0)
	{
	  return;
	}
      for (i = 3; i <= _numArgs; i++)
	{
	  if (*_info[i].type == _C_ID || *_info[i].type == _C_CHARPTR)
	    {
	      if (*_info[i].type == _C_ID)
		{
		  id	old;

		  _get_arg(self, i-1, &old);
		  if (old != nil)
		    {
		      IF_NO_GC(RETAIN(old));
		    }
		}
	      else
		{
		  char	*str;

		  _get_arg(self, i-1, &str);
		  if (str != 0)
		    {
		      char	*tmp;

		      tmp = NSZoneMalloc(NSDefaultMallocZone(), strlen(str)+1);
		      strcpy(tmp, str);
		      _set_arg(self, i-1, &tmp);
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
  [self invokeWithTarget: _target];
}

- (void) invokeWithTarget: (id)anObject
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
      memset(_retval, '\0', _info[0].size);	/* Clear return value */
      return;
    }

  NSAssert(_selector != 0, @"you must set the selector before invoking");

  /*
   *	Temporarily set new target and copy it (and the selector) into the
   *	_argframe.
   */
  old_target = RETAIN(_target);
  [self setTarget: anObject];

  _set_arg(self, 0, &_target);
  _set_arg(self, 1, &_selector);

  imp = method_get_imp(object_is_instance(_target) ?
	      class_get_instance_method(
		    ((struct objc_class*)_target)->class_pointer, _selector)
	    : class_get_class_method(
		    ((struct objc_class*)_target)->class_pointer, _selector));
  /*
   *	If fast lookup failed, we may be forwarding or something ...
   */
  if (imp == 0)
    imp = objc_msg_lookup(_target, _selector);

  [self setTarget: old_target];
  RELEASE(old_target);

  stack_argsize = [_sig frameLength];

#ifdef USE_LIBFFI
  ffi_call(&((cifframe_t *)_cframe)->cif, (void(*)(void))imp, _retval,
	   ((cifframe_t *)_cframe)->values);
  if (_info[0].size)
    {
      cifframe_decode_return(_info[0].type, _retval);
    }
#else
  returned = __builtin_apply((void(*)(void))imp, _argframe, stack_argsize);
  if (_info[0].size)
    {
      mframe_decode_return(_info[0].type, _retval, returned);
    }
#endif
  _validReturn = YES;
}

/*
 *      Getting the method _signature.
 */

- (NSMethodSignature*) methodSignature
{
  return _sig;
}

- (NSString*) description
{
  /*
   *	Don't use -[NSString stringWithFormat:] method because it can cause
   *	infinite recursion.
   */
  char buffer[1024];

  sprintf (buffer, "<%s %p selector: %s target: %s>", \
                (char*)object_get_class_name(self), \
                self, \
                _selector ? [NSStringFromSelector(_selector) cString] : "nil", \
                _target ? [NSStringFromClass([_target class]) cString] : "nil" \
                );

  return [NSString stringWithCString:buffer];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  const char	*types = [_sig methodType];
  int		i;

  [aCoder encodeValueOfObjCType: @encode(char*)
			     at: &types];

  [aCoder encodeObject: _target];

  [aCoder encodeValueOfObjCType: _info[2].type
			     at: &_selector];

  for (i = 3; i <= _numArgs; i++)
    {
      const char	*type = _info[i].type;
      void		*datum;

      datum = _arg_addr(self, i-1);

      if (*type == _C_ID)
	{
	  [aCoder encodeObject: *(id*)datum];
	}
#if !defined(USE_LIBFFI) && !defined(USE_FFCALL)
#if     MFRAME_STRUCT_BYREF
      else if (*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B)
        {
	  [aCoder encodeValueOfObjCType: type at: *(void**)datum];
        }
#endif
#endif
      else
	{
	  [aCoder encodeValueOfObjCType: type at: datum];
	}
    }
  if (*_info[0].type != _C_VOID)
    {
      [aCoder encodeValueOfObjCType: @encode(BOOL) at: &_validReturn];
      if (_validReturn)
	{
	  [aCoder encodeValueOfObjCType: _info[0].type at: _retval];
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
  NSZoneFree(NSDefaultMallocZone(), (void*)types);

  RELEASE(self);
  self  = [NSInvocation invocationWithMethodSignature: newSig];
  RETAIN(self);
 
  [aCoder decodeValueOfObjCType: @encode(id) at: &_target];

  [aCoder decodeValueOfObjCType: @encode(SEL) at: &_selector];

  for (i = 3; i <= _numArgs; i++)
    {
      datum = _arg_addr(self, i-1);
#if !defined(USE_LIBFFI) && !defined(USE_FFCALL)
#if     MFRAME_STRUCT_BYREF
      {
        const char      *t = _info[i].type;
        if (*t == _C_STRUCT_B || *t == _C_UNION_B || *t == _C_ARY_B)
          {
	    *(void**)datum = _fastMallocBuffer(_info[i].size);
            datum = *(void**)datum;
          }
      }
#endif
#endif
      [aCoder decodeValueOfObjCType: _info[i].type at: datum];
    }
  _argsRetained = YES;
  if (*_info[0].type != _C_VOID)
    {
      [aCoder decodeValueOfObjCType: @encode(BOOL) at: &_validReturn];
      if (_validReturn)
	{
	  [aCoder decodeValueOfObjCType: _info[0].type at: _retval];
	}
    }
  return self;
}

@end

@implementation NSInvocation (GNUstep)

- (id) initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/*
 *	This is the de_signated initialiser.
 */
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithSelector: (SEL)aSelector
{
  return [self initWithArgframe: 0 selector: aSelector];
}

- (id) initWithTarget: anObject selector: (SEL)aSelector, ...
{
  va_list	ap;

  self = [self initWithArgframe: 0 selector: aSelector];
  if (self)
    {
      int	i;

      [self setTarget: anObject];
      va_start (ap, aSelector);
      for (i = 3; i <= _numArgs; i++)
	{
	  const char	*type = _info[i].type;
	  unsigned	size = _info[i].size;
	  void		*datum;

#ifdef USE_LIBFFI
	  size = ((cifframe_t *)_cframe)->args[i-1]->size;
#endif
	  datum = _arg_addr(self, i-1);

#define CASE_TYPE(_C,_T) case _C: *(_T*)datum = va_arg (ap, _T); break
	  switch (*type)
	    {
	      case _C_ID:
		*(id*)datum = va_arg (ap, id);
		if (_argsRetained)
		  {
		    IF_NO_GC(RETAIN(*(id*)datum));
		  }
		break;
	      case _C_CHARPTR:
		*(char**)datum = va_arg (ap, char*);
		if (_argsRetained)
		  {
		    char	*old = *(char**)datum;

		    if (old != 0)
		      {
			char	*tmp;

			tmp = NSZoneMalloc(NSDefaultMallocZone(),strlen(old)+1);
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
	      case _C_SHT:
		*(short*)datum = (short)va_arg(ap, int);
		break;
	      case _C_USHT:
		*(unsigned short*)datum = (unsigned short)va_arg(ap, int);
		break;
	      case _C_CHR:
		*(char*)datum = (char)va_arg(ap, int);
		break;
	      case _C_UCHR:
		*(unsigned char*)datum = (unsigned char)va_arg(ap, int);
		break;
	      case _C_FLT:
		*(float*)datum = (float)va_arg(ap, double);
		break;
	      CASE_TYPE(_C_DBL, double);
	      CASE_TYPE(_C_PTR, void*);
	      case _C_STRUCT_B:
	      default:
#if !defined(USE_LIBFFI) && !defined(USE_FFCALL)
#if defined(sparc) || defined(powerpc)
		/* FIXME: This only appears on sparc and ppc machines so far.
		structures appear to be aligned on word boundaries. 
		Hopefully there is a more general way to figure this out */
		size = (size<sizeof(int))?4:size;
#endif
#endif
	      NSLog(@"Unsafe handling of type of %d argument.", i-1);
	      memcpy(datum, ap, size);
	      {
		struct {
		  char	x[size];
		} dummy;
		dummy = va_arg(ap, typeof(dummy));
	      }
	      break;
	    }
	}
    }
  return self;
}

- (void*) returnFrame: (arglist_t)argFrame
{
  [self subclassResponsibility: _cmd];
  return NULL;
}
@end

@implementation NSInvocation (BackwardCompatibility)

- (void) invokeWithObject: (id)obj
{
  [self invokeWithTarget: (id)obj];
}

@end

@implementation GSFrameInvocation

- (id) initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
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
       *	Copy the _argframe we were given.
       */
      if (frame)
	{
	  int	i;

	  mframe_get_arg(frame, &_info[1], &_target);
	  for (i = 1; i <= _numArgs; i++)
	    {
	      mframe_cpy_arg(_argframe, frame, &_info[i]);
	    }
	}
    }
  return self;
}

/*
 *	This is the de_signated initialiser.
 */
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature
{
  _sig = RETAIN(aSignature);
  _numArgs = [aSignature numberOfArguments];
  _info = [aSignature methodInfo];
  _argframe = mframe_create_argframe([_sig methodType], &_retval);
  if (_retval == 0 && _info[0].size > 0)
    {
      _retval = NSZoneMalloc(NSDefaultMallocZone(), _info[0].size);
    }
  return self;
}

- (void*) returnFrame: (arglist_t)argFrame
{
  return mframe_handle_return(_info[0].type, _retval, argFrame);
}
@end
