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
  OBJC_MALLOC(encoding, char, l);
  memcpy(encoding, enc, l);
  return_size = objc_sizeof_type(encoding);
  return_value = NULL;
  return self;
}
- (void) invoke
{
  [self subclassResponsibility:_cmd];
}

- (void) invokeWithObject: anObj
{
  [self invoke];
}

- (void) invokeWithElement: (elt)anElt
{
  [self invoke];
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
  memcpy(addr, return_value, return_size);
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
  argframe = (arglist_t) (*objc_malloc)(sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = (*objc_malloc)(stack_argsize);
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
  return objc_sizeof_type([self argumentTypeAtIndex:i]);
}

- (void) getArgument: (void*)addr atIndex: (unsigned)i
{
  const char *tmptype = encoding;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i--);
  memcpy(addr, datum, objc_sizeof_type(tmptype));
}

- (void) setArgumentAtIndex: (unsigned)i 
    toValueAt: (const void*)addr
{
  const char *tmptype = encoding;
  void *datum;

  do
    datum = my_method_get_next_argument(argframe, &tmptype);
  while (i--);
  memcpy(datum, addr, objc_sizeof_type(tmptype));
}

@end

@implementation MethodInvocation

- initWithArgframe: (arglist_t)frame selector: (SEL)sel
{
  [self initWithArgframe:frame type:sel_get_type(sel)];
  return self;
}

- initWithSelector: (SEL)s
{
  [self initWithArgframe:NULL selector:s];
  return self;
}

- initWithSelector: (SEL)s arguments: receiver, ...
{
  [self initWithSelector:s];
  [self notImplemented:_cmd];
  return self;
}


- (void) invoke
{
  void *ret;
  IMP imp;

  imp = get_imp([self target], [self selector]);
  assert(imp);
  ret = __builtin_apply((void(*)(void))imp,
			argframe, 
			types_get_size_of_stack_arguments(encoding));
  if (*encoding == 'd')
    memcpy(return_value, (char*)ret + 2*sizeof(void*), return_size);
  else
    memcpy(return_value, ret, return_size);
}

- (void) invokeWithTarget: t
{
  [self setArgumentAtIndex:0 toValueAt:&t];
  [self invoke];
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
  [self getArgument:&t atIndex:1];
  return t;
}

- (void) setTarget: t
{
  [self setArgumentAtIndex:0 toValueAt:&t];
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
