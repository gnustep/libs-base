/* Implementation for Objective-C Invocation object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <objects/stdobjects.h>
#include <objects/Invocation.h>

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


/* 
   Put something like this in Collecting:
   - withObjectsAtArgumentIndex: (unsigned)index
       invoke: (Invocation*)invocation;
   - putObjectsAtArgumentIndex: (unsigned)index
       andInvoke: (Invocation*)invocation;
   - invoke: (Invocation*)invocation
       withObjectsAtArgumentIndex: (unsigned)index
*/

@implementation Invocation

- initWithReturnType: (const char *)enc
{
  int l = strlen(enc);
  OBJC_MALLOC(encoding, char, l + 1);
  memcpy(encoding, enc, l);
  encoding[l] = '\0';
  enc = objc_skip_type_qualifiers (encoding);
  if (*enc != 'v')
    {
      /* Work around bug in objc_sizeof_type; it doesn't handle void type */
      return_size = objc_sizeof_type (enc);
      return_value = (*objc_malloc) (return_size);
    }
  else
    {
      return_size = 0;
      return_value = NULL;
    }
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
  return encoding;
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

- objectReturnValue
{
  [self notImplemented: _cmd];
  return nil;
}

- (int) intReturnValue
{
  [self notImplemented: _cmd];
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
    case sizeof(long):
      return (*(long*)return_value != 0);
    }
  [self notImplemented: _cmd];
}


- (void) dealloc
{
  OBJC_FREE(encoding);
  [super dealloc];
}

@end

#if 0
@implementation CurriedInvocation

@end
#endif

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

/* This is the designated initializer. */
- initWithArgframe: (arglist_t)frame type: (const char *)type
{
  int stack_argsize, reg_argsize;

  /* xxx we could just use the return part.  Does this matter? */
  [super initWithReturnType:type];

  /* allocate the argframe */
  stack_argsize = types_get_size_of_stack_arguments(type);
  reg_argsize = types_get_size_of_register_arguments(type);
  argframe = (arglist_t) (*objc_calloc)(1 ,sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = (*objc_calloc)(1, stack_argsize);
  else
    argframe->arg_ptr = 0;

  /* copy the frame into the argframe */
  if (frame)
    {
      memcpy((char*)argframe + sizeof(char*), 
	     (char*)frame + sizeof(char*),
	     reg_argsize);
      memcpy(argframe->arg_ptr, frame->arg_ptr, stack_argsize);
    }

  return self;
}

- initWithType: (const char *)e
{
  [self initWithArgframe:NULL type:e];
  return self;
}

- (const char *) argumentTypeAtIndex: (unsigned)i
{
  const char *tmptype = encoding;

  do 
    {
      tmptype = objc_skip_argspec(objc_skip_typespec(tmptype));
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
  const char *tmptype = encoding;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i--);
  memcpy (addr, datum, objc_sizeof_type(tmptype));
}

- (void) setArgumentAtIndex: (unsigned)i 
    toValueAt: (const void*)addr
{
  const char *tmptype = encoding;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i--);
  memcpy (datum, addr, objc_sizeof_type(tmptype));
}

@end

@implementation MethodInvocation

- initWithArgframe: (arglist_t)frame selector: (SEL)sel
{
  const char *sel_type;
  if (! (sel_type = sel_get_type (sel)) )
    sel_type = sel_get_type ( sel_get_any_typed_uid (sel_get_name (sel)));
  [self initWithArgframe: frame type: sel_type];
  return self;
}

- initWithSelector: (SEL)s
{
  [self initWithArgframe: NULL selector: s];
  [self setArgumentAtIndex: 1 toValueAt: &s];
  return self;
}

- initWithTarget: target selector: (SEL)s, ...
{
  const char *tmptype;
  void *datum;
  void *arg_datum;
  va_list ap;

  [self initWithSelector:s];
  tmptype = encoding;
  datum = my_method_get_next_argument(argframe, &tmptype);
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
	  CASE_TYPE(_C_ID, id);
	  CASE_TYPE(_C_LNG, long);
	  CASE_TYPE(_C_ULNG, unsigned long);
	  CASE_TYPE(_C_INT, int);
	  CASE_TYPE(_C_UINT, unsigned int);
	  CASE_TYPE(_C_SHT, short);
	  CASE_TYPE(_C_USHT, unsigned short);
	  CASE_TYPE(_C_CHR, char);
	  CASE_TYPE(_C_UCHR, unsigned char);
	  CASE_TYPE(_C_CHARPTR, char*);
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

  target = [self target];
  if (target == nil)
    return;

  cl = object_get_class (target);
  sel = [self selector];
  imp = get_imp (cl, sel);
  assert(imp);
  ret = __builtin_apply((void(*)(void))imp,
			argframe, 
			types_get_size_of_stack_arguments(encoding));
  if (return_value)
    {
      if (*encoding == 'd')
	memcpy(return_value, (char*)ret + 2*sizeof(void*), return_size);
      else
	memcpy(return_value, ret, return_size);
    }
}

- (void) invokeWithTarget: t
{
  /* xxx Could be more efficient. */
  [self setArgumentAtIndex:0 toValueAt:&t];
  [self invoke];
}

- (void) invokeWithObject: anObj
{
  [self invokeWithTarget: anObj];
}

- (SEL) selector
{
  SEL s;
  [self getArgument:&s atIndex:1];
  return s;
}

- (void) setSelector: (SEL)s
{
  [self setArgumentAtIndex:1 toValueAt:&s];
  if (sel_types_match(sel_get_type([self selector]), sel_get_type(s)))
    [self setArgumentAtIndex:1 toValueAt:&s];
  else
    {
      [self notImplemented:_cmd];
      /* We will need to reallocate the argframe */
    }
}

- target
{
  id t;
  [self getArgument:&t atIndex:0];
  return t;
}

- (void) setTarget: t
{
  [self setArgumentAtIndex:0 toValueAt:&t];
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

- initWithFunction: (void(*)())f
{
  [super initWithReturnType: "v"];
  function = f;
}

@end


/* Many other kinds of Invocations are possible:
   SchemeInvocation, TclInvocation */

#if 0
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
