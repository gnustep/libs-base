/* Implementation of GSFFCallInvocation for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written: Adam Fedor <fedor@gnu.org>
   Date: Nov 2000
   
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
#include <Foundation/NSDistantObject.h>
#include <base/GSInvocation.h>
#include <config.h>
#include <objc/objc-api.h>
#include <avcall.h>
#include <callback.h>
#include "callframe.h"

typedef struct _NSInvocation_t {
  @defs(NSInvocation)
} NSInvocation_t;

void
GSInvocationCallback(void *callback_data, va_alist args);

/* Callback for forwarding methods */
static void *ff_callback;

/* Callback data (which will hold the selector) */
static SEL callback_sel;

/* Recursively calculate the offset using the offset of the previous
   sub-type */
static int
gs_offset(const char *type, int index)
{
  int offset;
  const char *subtype;
  
  if (index == 0)
    return 0;
  subtype = type;
  while (*subtype != _C_STRUCT_E && *subtype++ != '='); /* skip "<name>=" */

  offset = (gs_offset(type, index-1) + objc_sizeof_type(&subtype[index-1])
    + objc_alignof_type(&subtype[index]) - 1)
    & -(long)objc_alignof_type(&subtype[index]);
  return offset;
}

/* Determines if the structure type can be returned entirely in registers.
   See the avcall or vacall man pages for more info. FIXME: I'm betting
   this won't work if a structure contains another structure */
int
gs_splittable(const char *type)
{
  int i, numtypes;
  const char *subtype;
  int  result;
  
  subtype = type;
  while (*subtype != _C_STRUCT_E && *subtype++ != '='); /* skip "<name>=" */
  numtypes = 0;
  while (*subtype != _C_STRUCT_E)
    {
      numtypes++;
      subtype = objc_skip_typespec (subtype);
    }
  subtype = type;
  while (*subtype != _C_STRUCT_E && *subtype++ != '='); /* skip "<name>=" */

  result = 1;
  for (i = 0; i < numtypes; i++)
    {
      result = result 
	&& (gs_offset(type, i)/sizeof(__avword) 
	    == (gs_offset(type, i)+objc_sizeof_type(&subtype[i])-1)
	       / sizeof(__avword));
    }
  //printf("Splittable for %s is %d\n", type, result);
  return result;
}

@implementation GSFFCallInvocation

static IMP gs_objc_msg_forward (SEL sel)
{
  callback_sel = sel;
  return ff_callback;
}

static void gs_free_callback(void)
{
  if (ff_callback)
    {
      free_callback(ff_callback);
      ff_callback = NULL;
    }
}

+ (void)load
{
  ff_callback = alloc_callback(&GSInvocationCallback, &callback_sel);

  __objc_msg_forward = gs_objc_msg_forward;
}

- (id) initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
{
  /* We should never get here */
  NSDeallocateObject(self);
  [NSException raise: NSInternalInconsistencyException
	       format: @"Runtime incorrectly configured to pass argframes"];
  return nil;
}

/*
 *	This is the de-signated initialiser.
 */
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature
{
  _sig = RETAIN(aSignature);
  _numArgs = [aSignature numberOfArguments];
  _info = [aSignature methodInfo];
  _cframe = callframe_from_info(_info, _numArgs, &_retval);
  if (_retval == 0 && _info[0].size > 0)
    {
      _retval = NSZoneMalloc(NSDefaultMallocZone(), _info[0].size);
    }
  return self;
}

/* This is implemented as a function so it can be used by other
   routines (like the DO forwarding)
*/
void
GSFFCallInvokeWithTargetAndImp(NSInvocation *_inv, id anObject, IMP imp)
{
  int      i;
  av_alist alist;
  NSInvocation_t *inv = (NSInvocation_t*)_inv;
  void *retval = inv->_retval;

  /* Do an av call starting with the return type */
#undef CASE_TYPE
#define CASE_TYPE(_T, _V, _F)				\
	case _T:					\
	  _F(alist, imp, retval);	       		\
          break;

  switch (*inv->_info[0].type)
    {
    case _C_ID:
      av_start_ptr(alist, imp, id, retval);
      break;
    case _C_CLASS:
      av_start_ptr(alist, imp, Class, retval);
      break;
    case _C_SEL:
      av_start_ptr(alist, imp, SEL, retval);
      break;
    case _C_PTR:
      av_start_ptr(alist, imp, void *, retval);
      break;
    case _C_CHARPTR:
      av_start_ptr(alist, imp, char *, retval);
      break;
	
      CASE_TYPE(_C_CHR,  char, av_start_char)
      CASE_TYPE(_C_UCHR, unsigned char, av_start_uchar)
      CASE_TYPE(_C_SHT,  short, av_start_short)
      CASE_TYPE(_C_USHT, unsigned short, av_start_ushort)
      CASE_TYPE(_C_INT,  int, av_start_int)
      CASE_TYPE(_C_UINT, unsigned int, av_start_uint)
      CASE_TYPE(_C_LNG,  long, av_start_long)
      CASE_TYPE(_C_ULNG, unsigned long, av_start_ulong)
      CASE_TYPE(_C_LNG_LNG,  long long, av_start_longlong)
      CASE_TYPE(_C_ULNG_LNG, unsigned long long, av_start_ulonglong)
      CASE_TYPE(_C_FLT,  float, av_start_float)
      CASE_TYPE(_C_DBL,  double, av_start_double)

    case _C_STRUCT_B:
      {
	int split = 0;
	if (inv->_info[0].size > sizeof(long) && inv->_info[0].size <= 2*sizeof(long))
	  split = gs_splittable(inv->_info[0].type);
	_av_start_struct(alist, imp, inv->_info[0].size, split, retval);
	break;
      }
    case _C_VOID:
      av_start_void(alist, imp);
      break;
    default:
      NSCAssert1(0, @"GSFFCallInvocation: Return Type '%s' not implemented", 
		 inv->_info[0].type);
      break;
    }

  /* Set target and selector */
  av_ptr(alist, id, anObject);
  av_ptr(alist, SEL, inv->_selector);

  /* Set the rest of the arguments */
  for (i = 2; i < inv->_numArgs; i++)
    {
      const char *type = inv->_info[i+1].type;
      unsigned	 size = inv->_info[i+1].size;
      void              *datum;

      datum = callframe_arg_addr((callframe_t *)inv->_cframe, i);

#undef CASE_TYPE
#define CASE_TYPE(_T, _V, _F)				\
	case _T:					\
	  {						\
	    _V c;          				\
            memcpy(&c, datum, size);                    \
            _F(alist, c);                               \
	    break;					\
	  }

      switch (*type)
	{
	case _C_ID:
	  {
	    id obj;
	    memcpy(&obj, datum, size);
	    av_ptr(alist, id, obj);
	    break;
	  }
	case _C_CLASS:
	  {
	    Class obj;
	    memcpy(&obj, datum, size);
	    av_ptr(alist, Class, obj);
	    break;
	  }
	case _C_SEL:
	  {
	    SEL sel;
	    memcpy(&sel, datum, size);
	    av_ptr(alist, SEL, sel);
	    break;
	  }
	case _C_PTR:
	  {
	    void *ptr;
	    memcpy(&ptr, datum, size);
	    av_ptr(alist, void *, ptr);
	    break;
	  }
	case _C_CHARPTR:
	  {
	    char *ptr;
	    memcpy(&ptr, datum, size);
	    av_ptr(alist, char *, ptr);
	    break;
	  }
	  
	  CASE_TYPE(_C_CHR,  char, av_char)
	  CASE_TYPE(_C_UCHR, unsigned char, av_uchar)
	  CASE_TYPE(_C_SHT,  short, av_short)
	  CASE_TYPE(_C_USHT, unsigned short, av_ushort)
	  CASE_TYPE(_C_INT,  int, av_int)
	  CASE_TYPE(_C_UINT, unsigned int, av_uint)
	  CASE_TYPE(_C_LNG,  long, av_long)
	  CASE_TYPE(_C_ULNG, unsigned long, av_ulong)
	  CASE_TYPE(_C_LNG_LNG,  long long, av_longlong)
	  CASE_TYPE(_C_ULNG_LNG, unsigned long long, av_ulonglong)
	  CASE_TYPE(_C_FLT,  float, av_float)
	  CASE_TYPE(_C_DBL,  double, av_double)
	  
	case _C_STRUCT_B:
	  _av_struct(alist, size, inv->_info[i+1].align, datum);
	  break;
	default:
	  NSCAssert1(0, @"GSFFCallInvocation: Type '%s' not implemented", type);
	  break;
	}
    }

  /* Do it */
  av_call(alist);
}

- (void) invokeWithTarget: (id)anObject
{
  id		old_target;
  IMP		imp;

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

  callframe_set_arg((callframe_t *)_cframe, 0, &_target, _info[1].size);
  callframe_set_arg((callframe_t *)_cframe, 1, &_selector, _info[2].size);

  if (_sendToSuper == YES)
    {
      Super	s;

      s.self = _target;
      if (GSObjCIsInstance(_target))
	s.class = class_get_super_class(GSObjCClass(_target));
      else
	s.class = class_get_super_class((Class)_target);
      imp = objc_msg_lookup_super(&s, _selector);
    }
  else
    {
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
    }

  [self setTarget: old_target];
  RELEASE(old_target);
  
  GSFFCallInvokeWithTargetAndImp(self, anObject, imp);
  _validReturn = YES;
}

- (void*) returnFrame: (arglist_t)argFrame
{
  return _retval;
}
@end

void GSInvocationCallback(void *callback_data, va_alist args)
{
  id obj;
  SEL callback_sel, selector;
  int i, num_args;
  void *retval;
  const char *callback_type;
  NSArgumentInfo *info;
  GSFFCallInvocation *invocation;
  NSMethodSignature *sig;
  
  callback_sel = *(SEL *)callback_data;
  callback_type = sel_get_type(callback_sel);

  /*
   * Make a guess at what the type signature might be by asking the
   * runtime for a selector with the same name as the untyped one we
   * were given.
   */
  if (callback_type == NULL)
    {
      const char *name = sel_get_name(callback_sel);

      if (name != NULL)
	{
	  SEL	sel = sel_get_any_typed_uid(name);

	  if (sel != NULL)
	    {
	      callback_sel = sel;
	      callback_type = sel_get_type(callback_sel);
	    }
	}
    }

  if (callback_type == NULL)
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid selector %s (no type information)",
		sel_get_name(callback_sel)];

  callback_type = objc_skip_type_qualifiers(callback_type);

#undef CASE_TYPE
#define CASE_TYPE(_T, _V, _F)				\
	case _T:					\
	  _F(args);       		                \
          break;

  switch (*callback_type)
    {
    case _C_ID:
      va_start_ptr(args, id);
      break;
    case _C_CLASS:
      va_start_ptr(args, Class);
      break;
    case _C_SEL:
      va_start_ptr(args, SEL);
      break;
    case _C_PTR:
      va_start_ptr(args, void *);
      break;
    case _C_CHARPTR:
      va_start_ptr(args, char *);
      break;
	
      CASE_TYPE(_C_CHR,  char, va_start_char)
      CASE_TYPE(_C_UCHR, unsigned char, va_start_uchar)
      CASE_TYPE(_C_SHT,  short, va_start_short)
      CASE_TYPE(_C_USHT, unsigned short, va_start_ushort)
      CASE_TYPE(_C_INT,  int, va_start_int)
      CASE_TYPE(_C_UINT, unsigned int, va_start_uint)
      CASE_TYPE(_C_LNG,  long, va_start_long)
      CASE_TYPE(_C_ULNG, unsigned long, va_start_ulong)
      CASE_TYPE(_C_LNG_LNG,  long long, va_start_longlong)
      CASE_TYPE(_C_ULNG_LNG, unsigned long long, va_start_ulonglong)
      CASE_TYPE(_C_FLT,  float, va_start_float)
      CASE_TYPE(_C_DBL,  double, va_start_double)

    case _C_STRUCT_B:
      {
	int split, ssize;
	ssize = objc_sizeof_type(callback_type);
	if (ssize > sizeof(long) && ssize <= 2*sizeof(long))
	  split = gs_splittable(callback_type);
	_va_start_struct(args, ssize, objc_alignof_type(callback_type), split);
	break;
      }
    case _C_VOID:
      va_start_void(args);
      break;
    default:
      NSCAssert1(0, @"GSFFCallInvocation: Return Type '%s' not implemented", 
		 callback_type);
      break;
    }

  obj      = va_arg_ptr(args, id);
  selector = va_arg_ptr(args, SEL);
  /* Invoking a NSDistantObject method is likely to cause infinite recursion.
     So make sure we really can't find the selector locally .*/
  sig = nil;
  if ([obj isKindOfClass: [NSDistantObject class]])
    {
      const char *type = sel_get_type(selector);
      if (type)
	sig = [NSMethodSignature signatureWithObjCTypes: type];
    }
  if (!sig)
    {
      //NSLog(@"looking up sel %@", NSStringFromSelector(selector));
      sig = [obj methodSignatureForSelector: selector];
    }
  NSCAssert1(sig, @"No signature for selector %@", 
	     NSStringFromSelector(selector));


  invocation = [[GSFFCallInvocation alloc] initWithMethodSignature: sig];
  AUTORELEASE(invocation);
  [invocation setTarget: obj];
  [invocation setSelector: selector];

  /* Set the rest of the arguments */
  num_args = [sig numberOfArguments];
  info = [sig methodInfo]; 
  for (i = 2; i < num_args; i++)
    {
      const char	*type = info[i+1].type;
      unsigned	size = info[i+1].size;

#undef CASE_TYPE
#define CASE_TYPE(_T, _V, _F)				\
	case _T:					\
	  {						\
	    _V c = _F(args);				\
	    [invocation setArgument: &c atIndex: i];	\
	    break;					\
	  }

      switch (*type)
	{
	case _C_ID:
	  {
	    id obj = va_arg_ptr (args, id);
	    [invocation setArgument: &obj atIndex: i];
	    break;
	  }
	case _C_CLASS:
	  {
	    Class obj = va_arg_ptr (args, Class);
	    [invocation setArgument: &obj atIndex: i];
	    break;
	  }
	case _C_SEL:
	  {
	    SEL sel = va_arg_ptr (args, SEL);
	    [invocation setArgument: &sel atIndex: i];
	    break;
	  }
	case _C_PTR:
	  {
	    void *ptr = va_arg_ptr (args, void *);
	    [invocation setArgument: &ptr atIndex: i];
	    break;
	  }
	case _C_CHARPTR:
	  {
	    char *ptr = va_arg_ptr (args, char *);
	    [invocation setArgument: &ptr atIndex: i];
	    break;
	  }
	  
	  CASE_TYPE(_C_CHR,  char, va_arg_char)
	  CASE_TYPE(_C_UCHR, unsigned char, va_arg_uchar)
	  CASE_TYPE(_C_SHT,  short, va_arg_short)
	  CASE_TYPE(_C_USHT, unsigned short, va_arg_ushort)
	  CASE_TYPE(_C_INT,  int, va_arg_int)
	  CASE_TYPE(_C_UINT, unsigned int, va_arg_uint)
	  CASE_TYPE(_C_LNG,  long, va_arg_long)
	  CASE_TYPE(_C_ULNG, unsigned long, va_arg_ulong)
	  CASE_TYPE(_C_LNG_LNG,  long long, va_arg_longlong)
	  CASE_TYPE(_C_ULNG_LNG, unsigned long long, va_arg_ulonglong)
	  CASE_TYPE(_C_FLT,  float, va_arg_float)
	  CASE_TYPE(_C_DBL,  double, va_arg_double)
	  
	case _C_STRUCT_B:
	  {
	    /* Here we actually get a ptr to the struct */
	    void *ptr = _va_arg_struct(args, size, info[i+1].align);
	    [invocation setArgument: ptr atIndex: i];
	    break;
	  }
	default:
	  NSCAssert1(0, @"GSFFCallInvocation: Type '%s' not implemented", type);
	  break;
	}
    }
  
  /* Now do it */
  [obj forwardInvocation: invocation];

  /* Return the proper type */
  retval = [invocation returnFrame: NULL];

#undef CASE_TYPE
#define CASE_TYPE(_T, _V, _F)				\
	case _T:					\
	  _F(args, *(_V *)retval);       		\
          break;

  switch (*info[0].type)
    {
    case _C_ID:
      va_return_ptr(args, id, *(id *)retval);
      break;
    case _C_CLASS:
      va_return_ptr(args, Class, *(Class *)retval);
      break;
    case _C_SEL:
      va_return_ptr(args, SEL, *(SEL *)retval);
      break;
    case _C_PTR:
      va_return_ptr(args, void *, *(void **)retval);
      break;
    case _C_CHARPTR:
      va_return_ptr(args, char *, *(char **)retval);
      break;
	
      CASE_TYPE(_C_CHR,  char, va_return_char)
      CASE_TYPE(_C_UCHR, unsigned char, va_return_uchar)
      CASE_TYPE(_C_SHT,  short, va_return_short)
      CASE_TYPE(_C_USHT, unsigned short, va_return_ushort)
      CASE_TYPE(_C_INT,  int, va_return_int)
      CASE_TYPE(_C_UINT, unsigned int, va_return_uint)
      CASE_TYPE(_C_LNG,  long, va_return_long)
      CASE_TYPE(_C_ULNG, unsigned long, va_return_ulong)
      CASE_TYPE(_C_LNG_LNG,  long long, va_return_longlong)
      CASE_TYPE(_C_ULNG_LNG, unsigned long long, va_return_ulonglong)
      CASE_TYPE(_C_FLT,  float, va_return_float)
      CASE_TYPE(_C_DBL,  double, va_return_double)

    case _C_STRUCT_B:
      _va_return_struct(args, info[0].size, info[0].align, retval);
      break;
    case _C_VOID:
      va_return_void(args);
      break;
    default:
      NSCAssert1(0, @"GSFFCallInvocation: Return Type '%s' not implemented", info[0].type);
      break;
    }
}

@implementation NSInvocation (DistantCoding)

/* An internal method used to help NSConnections code invocations
   to send over the wire */
- (BOOL) encodeWithDistantCoder: (NSCoder*)coder passPointers: (BOOL)passp
{
  int i;
  BOOL out_parameters = NO;
  const char *type = [_sig methodType];

  [coder encodeValueOfObjCType: @encode(char*) at: &type];

  for (i = 0; i < _numArgs; i++)
    {
      int flags = _info[i+1].qual;
      const char *type = _info[i+1].type;
      void *datum;
      
      if (i == 0)
	datum = &_target;
      else if (i == 1)
	datum = &_selector;
      else
        datum = callframe_arg_addr((callframe_t *)_cframe, i);

      /* Decide how, (or whether or not), to encode the argument
	 depending on its FLAGS and TYPE.  Only the first two cases
	 involve parameters that may potentially be passed by
	 reference, and thus only the first two may change the value
	 of OUT_PARAMETERS. */

      switch (*type)
	{
	case _C_ID: 
	  if (flags & _F_BYCOPY)
	    [coder encodeBycopyObject: *(id*)datum];
#ifdef	_F_BYREF
	  else if (flags & _F_BYREF)
	    [coder encodeByrefObject: *(id*)datum];
#endif
	  else
	    [coder encodeObject: *(id*)datum];
	  break;
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
	    [coder encodeValueOfObjCType: type at: datum];
	  break;

	case _C_PTR:
	  /* If the pointer's value is qualified as an OUT parameter,
	     or if it not explicitly qualified as an IN parameter,
	     then we will have to get the value pointed to again after
	     the method is run, because the method may have changed
	     it.  Set OUT_PARAMETERS accordingly. */
	  if ((flags & _F_OUT) || !(flags & _F_IN))
	    out_parameters = YES;
	  if (passp) 
	    {
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		[coder encodeValueOfObjCType: type at: datum];
	    }
	  else 
	    {
	      /* Handle an argument that is a pointer to a non-char.  But
		 (void*) and (anything**) is not allowed. */
	      /* The argument is a pointer to something; increment TYPE
		 so we can see what it is a pointer to. */
	      type++;
	      /* If the pointer's value is qualified as an IN parameter,
		 or not explicity qualified as an OUT parameter, then
		 encode it. */
	      if ((flags & _F_IN) || !(flags & _F_OUT))
		[coder encodeValueOfObjCType: type at: *(void**)datum];
	    }
	  break;

	case _C_STRUCT_B:
	case _C_UNION_B:
	case _C_ARY_B:
	  /* Handle struct and array arguments. */
	  /* Whether DATUM points to the data, or points to a pointer
	     that points to the data, depends on the value of
	     CALLFRAME_STRUCT_BYREF.  Do the right thing
	     so that ENCODER gets a pointer to directly to the data. */
	  [coder encodeValueOfObjCType: type at: datum];
	  break;

	default:
	  /* Handle arguments of all other types. */
	  [coder encodeValueOfObjCType: type at: datum];
	}
    }

  /* Return a BOOL indicating whether or not there are parameters that
     were passed by reference; we will need to get those values again
     after the method has finished executing because the execution of
     the method may have changed them.*/
  return out_parameters;
}

