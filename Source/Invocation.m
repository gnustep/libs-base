/* Implementation for Objective-C Invocation object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Invocation.h>
#include <Foundation/DistributedObjects.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSException.h>

/* xxx We are currently retaining the return value.
   We shouldn't always do this.  Make is an option. */

/* Deal with strrchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

/* xxx Perhaps make this an ivar. */
#define return_retained 0

@implementation Invocation

- initWithReturnType: (const char *)enc
{
  int l = strlen(enc);
  OBJC_MALLOC(return_type, char, l + 1);
  memcpy(return_type, enc, l);
  return_type[l] = '\0';
  enc = objc_skip_type_qualifiers (return_type);
  if (*enc != 'v')
    {
      /* Work around bug in objc_sizeof_type; it doesn't handle void type */
      return_size = objc_sizeof_type (enc);
      return_value = objc_calloc (1, return_size);
    }
  else
    {
      return_size = 0;
      return_value = NULL;
    }
  return self;
}

- (void) encodeWithCoder: (id <Encoding>)coder
{
  [super encodeWithCoder: coder];
  [coder encodeValueOfCType: @encode(char*)
	 at: &return_type
	 withName: @"Invocation return type"];
  [coder encodeValueOfCType: @encode(unsigned)
	 at: &return_size
	 withName: @"Invocation return size"];
  if (return_size)
    [coder encodeValueOfObjCType: return_type
	   at: return_value
	   withName: @"Invocation return value"];
}

- initWithCoder: (id <Decoding>)coder
{
  self = [super initWithCoder: coder];
  [coder decodeValueOfCType: @encode(char*)
	 at: &return_type
	 withName: NULL];
  [coder decodeValueOfCType: @encode(unsigned)
	 at: &return_size
	 withName: NULL];
  if (return_size)
    {
      return_value = objc_malloc (return_size);
      [coder decodeValueOfObjCType: return_type
	     at: return_value
	     withName: NULL];
    }
  else
    return_value = 0;
  return self;
}

- (Class) classForConnectedCoder: coder
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

/*	Next two methods for OPENSTEP	*/
- (Class) classForPortCoder
{
  return [self class];
}
- replacementObjectForPortCoder: coder
{
  return self;
}

- (void) invoke
{
  [self subclassResponsibility:_cmd];
}

- (void) invokeWithObject: anObj
{
  [self subclassResponsibility:_cmd];
}

- (const char *) returnType
{
  return return_type;
}

- (unsigned) returnSize
{
  return return_size;
}

- (void) getReturnValue: (void *)addr
{
  if (return_value)
    memcpy (addr, return_value, return_size);
  /* xxx what if it hasn't been invoked yet, and there isn't 
     a return value yet. */
}

- (void) setReturnValue: (void*)addr
{
  if (return_value)
    {
      if (return_retained && *return_type == _C_ID)
	{
	  [*(id*)return_value release];
	  *(id*)return_value = *(id*)addr;
	  [*(id*)return_value retain];
	}
      else
	memcpy (return_value, addr, return_size);
    }
}

- objectReturnValue
{
  switch (*return_type)
    {
#define CASE_RETURN(C,T,S) \
    case C: return [NSNumber numberWith ## S: *(T*)return_value]
      CASE_RETURN (_C_LNG, long, Long);
      CASE_RETURN (_C_ULNG, unsigned long, UnsignedLong);
      CASE_RETURN (_C_INT, int, Int);
      CASE_RETURN (_C_UINT, unsigned int, UnsignedInt);
      CASE_RETURN (_C_SHT, short, Short);
      CASE_RETURN (_C_USHT, unsigned short, UnsignedShort);
      CASE_RETURN (_C_CHR, char, Char);
      CASE_RETURN (_C_UCHR, unsigned char, UnsignedChar);
      CASE_RETURN (_C_FLT, float, Float);
      CASE_RETURN (_C_DBL, double, Double);
#undef CASE_RETURN
    case _C_PTR:
      return [NSNumber numberWithUnsignedLong: (long) *(void**)return_value];
    case _C_CHARPTR:
      return [NSString stringWithCString: *(char**)return_value];
    case _C_ID:
      return *(id*)return_value;
    case 'v':
      return nil;
    default:
      [self notImplemented: _cmd];
    }
  return 0;
  [self notImplemented: _cmd];
  return nil;
}

- (int) intReturnValue
{
  switch (*return_type)
    {
#define CASE_RETURN(_C,_T) case _C: return (int) *(_T*)return_value
      CASE_RETURN (_C_LNG, long);
      CASE_RETURN (_C_ULNG, unsigned long);
      CASE_RETURN (_C_INT, int);
      CASE_RETURN (_C_UINT, unsigned int);
      CASE_RETURN (_C_SHT, short);
      CASE_RETURN (_C_USHT, unsigned short);
      CASE_RETURN (_C_CHR, char);
      CASE_RETURN (_C_UCHR, unsigned char);
      CASE_RETURN (_C_CHARPTR, char*);
      CASE_RETURN (_C_FLT, float);
      CASE_RETURN (_C_DBL, double);
      CASE_RETURN (_C_PTR, void*);
#undef CASE_RETURN
    case _C_ID:
      return [*(id*)return_value intValue];
    case 'v':
      return 0;
    default:
      [self notImplemented: _cmd];
    }
  return 0;
}

- (BOOL) returnValueIsTrue
{
  switch (return_size)
    {
    case sizeof(char):
      return (*(char*)return_value != 0);
    case sizeof(short):
      return (*(short*)return_value != 0);
    case sizeof(int):
      return (*(int*)return_value != 0);
    }
  {
    int i;
    for (i = 0; i < return_size; i++)
      if (*((char*)return_value + i) != 0)
	return YES;
    return NO;
  }
}


- (void) dealloc
{
  if (return_retained && *return_type == _C_ID)
    [*(id*)return_value release];
  OBJC_FREE(return_type);
  [super dealloc];
}

@end

static int
types_get_size_of_stack_arguments(const char *types)
{
  const char* type = objc_skip_typespec (types);
  return atoi(type);
}

static int
types_get_size_of_register_arguments(const char *types)
{
  const char* type = strrchr(types, '+');
  if (type)
    return atoi(++type) + sizeof(void*);
  else
    return 0;
}

/* To fix temporary bug in method_get_next_argument() on m68k */
static char*
my_method_get_next_argument (arglist_t argframe,
			          const char **type)
{
  const char *t = objc_skip_argspec (*type);

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

@implementation ArgframeInvocation

- (void) _retainArguments
{
  const char *tmptype;
  void *datum;

  tmptype = return_type;
  while ((datum = my_method_get_next_argument (argframe, &tmptype)))
    {
      tmptype = objc_skip_type_qualifiers (tmptype);
      if (*tmptype == _C_ID)
	[*(id*)datum retain];
    }
}

- (void) _initArgframeFrom: (arglist_t)frame 
		  withType: (const char*)type
                retainArgs: (BOOL)f
{
  int stack_argsize, reg_argsize;

  /* allocate the argframe */
  stack_argsize = types_get_size_of_stack_arguments (type);
  reg_argsize = types_get_size_of_register_arguments(type);
  argframe = (arglist_t) objc_calloc (1 ,sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = objc_calloc (1, stack_argsize);
  else
    argframe->arg_ptr = 0;

  /* copy the frame into the argframe */
  if (frame)
    {
      memcpy((char*)argframe + sizeof(char*), 
	     (char*)frame + sizeof(char*),
	     reg_argsize);
      memcpy(argframe->arg_ptr, frame->arg_ptr, stack_argsize);
      if (f)
	[self _retainArguments];
    }
}

/* This is the designated initializer. */
- initWithArgframe: (arglist_t)frame type: (const char *)type
{
  /* xxx we are just using the return part.  Does this matter? */
  [super initWithReturnType: type];
  [self _initArgframeFrom: frame withType: type retainArgs: NO];

  return self;
}

- (void) encodeWithCoder: (id <Encoding>)coder
{
  const char *tmptype;
  void *datum;

  [super encodeWithCoder: coder];
  tmptype = return_type;
  while ((datum = my_method_get_next_argument(argframe, &tmptype)))
    {
      [coder encodeValueOfObjCType: tmptype
	     at: datum
	     withName: @"Invocation Argframe argument"];
    }
}

- initWithCoder: (id <Decoding>)coder
{
  const char *tmptype;
  void *datum;

  self = [super initWithCoder: coder];
  [self _initArgframeFrom: NULL withType: return_type retainArgs: NO];
  tmptype = return_type;
  while ((datum = my_method_get_next_argument(argframe, &tmptype)))
    {
      [coder decodeValueOfObjCType: tmptype
	     at: datum
	     withName: NULL];
    }
  return self;
}

- initWithType: (const char *)e
{
  [self initWithArgframe:NULL type:e];
  return self;
}

- (void) retainArguments
{
  if (!args_retained)
    {
      if (argframe)
	[self _retainArguments];
      args_retained = YES;
    }
}

- (BOOL) argumentsRetained
{
  return  args_retained;
}

- (const char *) argumentTypeAtIndex: (unsigned)i
{
  const char *tmptype = return_type;

  do 
    {
      tmptype = objc_skip_argspec (tmptype);
    }
  while (i--);
  return tmptype;
}

- (unsigned) argumentSizeAtIndex: (unsigned)i
{
  return objc_sizeof_type ([self argumentTypeAtIndex:i]);
}

- (void) getArgument: (void*)addr atIndex: (unsigned)i
{
  const char *tmptype = return_type;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i-- && datum);
  /* xxx Give error msg for null datum */
  memcpy (addr, datum, objc_sizeof_type(tmptype));
}

- (void) setArgument:(const void *)addr atIndex: (unsigned)i
{
  const char *tmptype = return_type;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i--);
  memcpy (datum, addr, objc_sizeof_type(tmptype));
}

- (void) setArgumentAtIndex: (unsigned)i 
    toValueAt: (const void*)addr
{
  [self setArgument: addr atIndex: i];
}

- (void) _deallocArgframe
{
  if (argframe)
    {
      if (argframe->arg_ptr)
	objc_free (argframe->arg_ptr);
      objc_free (argframe);
    }
}

- (void) dealloc
{
  void *datum;
  const char *tmptype = return_type;
  while ((datum = my_method_get_next_argument(argframe, &tmptype)))
    {
      tmptype = objc_skip_type_qualifiers (tmptype);
      if (args_retained && *tmptype == _C_ID)
	[*(id*)datum release];
    }
  [self _deallocArgframe];
  [super dealloc];
}

#if 0
- resetArgframeWithReturnType: (const char*)encoding
{
  [self _deallocArgframe];
  [self _allocArgframe];
}
#endif

@end

@implementation MethodInvocation

- (void) _initTargetAndSelPointers
{
  const char *tmptype = return_type;
  target_pointer = (id*) my_method_get_next_argument (argframe, &tmptype);
  sel_pointer = (SEL*) my_method_get_next_argument (argframe, &tmptype);
}

/* This is the designated initializer */
- initWithArgframe: (arglist_t)frame type: (const char*)t
{
  [super initWithArgframe: frame type: t];
  [self _initTargetAndSelPointers];
  return self;
}

- initWithArgframe: (arglist_t)frame selector: (SEL)sel
{
  const char *sel_type;

  if (! (sel_type = sel_get_type (sel)) )
    sel_type = sel_get_type ( sel_get_any_typed_uid (sel_get_name (sel)));
  /* xxx Try harder to get this type by looking up the method in the target.
     Hopefully the target can be found in the FRAME. */
  if (!sel_type)
    [NSException raise: @"SelectorWithoutType"
		 format: @"Couldn't find encoding type for selector %s.", 
		 sel_get_name (sel)];
  [self initWithArgframe: frame type: sel_type];
  if (!frame)
    *sel_pointer = sel;
  return self;
}

- initWithCoder: (id <Decoding>)coder
{
  self = [super initWithCoder: coder];
  [self _initTargetAndSelPointers];
  return self;
}

- initWithSelector: (SEL)s
{
  [self initWithArgframe: NULL selector: s];
  *sel_pointer = s;
  return self;
}

- initWithTarget: target selector: (SEL)s, ...
{
  const char *tmptype;
  void *datum;
  va_list ap;

  [self initWithArgframe: NULL selector: s];
  tmptype = return_type;
  datum = my_method_get_next_argument(argframe, &tmptype);
  if (args_retained)
    [target retain];
  *((id*)datum) = target;
  datum = my_method_get_next_argument(argframe, &tmptype);
  *((SEL*)datum) = s;
  datum = my_method_get_next_argument(argframe, &tmptype);
  va_start (ap, s);
  while (datum)
    {
      #define CASE_TYPE(_C,_T) case _C: *(_T*)datum = va_arg (ap, _T); break
      switch (*tmptype)
	{
	case _C_ID:
	  *(id*)datum = va_arg (ap, id);
	  if (args_retained)
	    [*(id*)datum retain];
	  break;

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
	  CASE_TYPE(_C_CHARPTR, char*);
	  CASE_TYPE(_C_PTR, void*);
	default:
	  [self notImplemented: _cmd];
	  // memcpy (datum, va_arg (ap, void*), objc_sizeof_type(tmptype));
	}
      datum = my_method_get_next_argument (argframe, &tmptype);
    }
  return self;
}


- (void) invoke
{
  void *ret;
  IMP imp;
  id target;
  id cl;
  SEL sel;

  /* xxx This could be more efficient by using my_method_get_next_argument
     instead of -target and -selector.  Or, even better, caching the
     memory offsets of the target and selector in the argframe. */

  target = *target_pointer;
  if (target == nil)
    return;

  cl = object_get_class (target);
  sel = *sel_pointer;
  /* xxx Perhaps we could speed things up by making this an ivar,
     and caching it. */
  imp = get_imp (cl, sel);
  assert(imp);
  ret = __builtin_apply((void(*)(void))imp,
			argframe, 
			types_get_size_of_stack_arguments(return_type));
  if (return_size)
    {
      if (*return_type == _C_DBL)
	/* DBL's are stored in a different place relative to RET. */
	memcpy(return_value, (char*)ret + 2*sizeof(void*), return_size);
      else if (*return_type == _C_ID)
	{
	  if (*(id*)return_value != *(id*)ret)
	    {
	      if (return_retained)
		{
		  if (*(id*)return_value)
		    [*(id*)return_value release];
		  [*(id*)ret retain];
		}
	      *(id*)return_value = *(id*)ret;
	    }
	}
      else
	{
	  memcpy(return_value, ret, return_size);
	}
    }
}

- (void) invokeWithTarget: t
{
  [self setTarget: t];
  [self invoke];
}

- (void) invokeWithObject: anObj
{
  [self invokeWithTarget: anObj];
}

- (SEL) selector
{
  return *sel_pointer;
}

- (void) setSelector: (SEL)s
{
  SEL mysel = [self selector];
  if (mysel == (SEL)0)
    /* XXX Type check is needed! (masata-y@is.aist-nara.ac.jp) */
    *sel_pointer = sel_get_any_typed_uid (sel_get_name (s));
  else if (sel_types_match(sel_get_type(mysel), sel_get_type(s)))
    *sel_pointer = s;
  else
    {
      /* We need to reallocate the argframe */
      [self notImplemented:_cmd];
    }
}

- target
{
  return *target_pointer;
}

- (void) setTarget: t
{
  if (*target_pointer != t)
    {
      if (args_retained)
	{
	  [*target_pointer release];
	  [t retain];
	}
      *target_pointer = t;
    }
}

@end

@implementation ObjectMethodInvocation

- (void) _initArgObjectPointer
{
  const char *tmptype;
  void *datum;

  tmptype = return_type;
  my_method_get_next_argument (argframe, &tmptype);
  my_method_get_next_argument (argframe, &tmptype);
  do 
    {
      datum = my_method_get_next_argument (argframe, &tmptype);
      tmptype = objc_skip_type_qualifiers (tmptype);
    }
  while (datum && tmptype && *tmptype != _C_ID);
  if (*tmptype != _C_ID)
    [self error: "This method does not have an object argument."];
  arg_object_pointer = (id*) datum;
}

- initWithArgframe: (arglist_t)frame selector: (SEL)sel
{
  [super initWithArgframe: frame selector: sel];
  [self _initArgObjectPointer];
  return self;
}

- initWithCoder: (id <Decoding>)coder
{
  self = [super initWithCoder: coder];
  [self _initArgObjectPointer];
  return self;
}

- (void) invokeWithObject: anObject
{
  if (*arg_object_pointer != anObject)
    {
      if (args_retained)
	{
	  [*arg_object_pointer release];
	  [anObject retain];
	}
      *arg_object_pointer = anObject;
    }
  [self invoke];
}


@end

@implementation VoidFunctionInvocation

#if 0
- initWithFunction: (void(*)())f
    argframe: (arglist_t)frame type: (const char *)e
{
  [super initWithArgframe: frame type: e];
  function = f;
  return self;
}
#endif

- initWithVoidFunction: (void(*)())f
{
  [super initWithReturnType: "v"];
  function = f;
  return self;
}

/* Encode ourself as a proxies across Connection's; we can't encode
   a function across the wire. */
- classForPortCoder
{
  return [NSDistantObject class];
}

- (void) encodeWithCoder: (id <Encoding>)coder
{
  [self shouldNotImplement: _cmd];
}

- (void) invoke
{
  (*function) ();
}

- (void) invokeWithObject
{
  [self shouldNotImplement: _cmd];
}

@end

@implementation ObjectFunctionInvocation

- initWithObjectFunction: (id(*)(id))f
{
  [super initWithReturnType: "@"];
  function = f;
  return self;
}

/* Encode ourself as a proxies across Connection's; we can't encode
   a function across the wire. */
- classForPortCoder
{
  return [NSDistantObject class];
}

- (void) encodeWithCoder: (id <Encoding>)coder
{
  [self shouldNotImplement: _cmd];
}

- (void) invoke
{
  [self invokeWithObject: nil];
}

- (void) invokeWithObject: anObject
{
  id r;

  r = (*function) (anObject);
  if (*(id*)return_value != r)
    {
      if (return_retained)
	{
	  [*(id*)return_value release];
	  [r retain];
	}
      *(id*)return_value = r;
    }
}

@end

/* Many other kinds of Invocations are possible:
   SchemeInvocation, TclInvocation */

#if 0
@implementation CurriedInvocation
@end

What is this nonsense?
@interface StreamInvocation
@interface LogInvocation
@interface PrintingInvocation
{
  Stream *stream;
  char *format_string;
}
@end
#endif
