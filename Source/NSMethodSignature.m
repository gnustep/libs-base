/* Implementation of NSMethodSignature for GNUStep
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
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

/* Deal with memchr: */
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

#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>


/*
 *	These macros incorporated from libFoundation by R. Frith-Macdonald
 *	are subject to the following copyright rather than the LGPL -
 *
 *  Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
 *  All rights reserved.
 *
 *   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
 *
 *   This file is part of libFoundation.
 *
 *   Permission to use, copy, modify, and distribute this software and its
 *   documentation for any purpose and without fee is hereby granted, provided
 *   that the above copyright notice appear in all copies and that both that
 *   copyright notice and this permission notice appear in supporting
 *   documentation.
 *
 *   We disclaim all warranties with regard to this software, including all
 *   implied warranties of merchantability and fitness, in no event shall
 *   we be liable for any special, indirect or consequential damages or any
 *   damages whatsoever resulting from loss of use, data or profits, whether in
 *   an action of contract, negligence or other tortious action, arising out of
 *   or in connection with the use or performance of this software.
 */

#ifndef ROUND
#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })
#endif


#if	defined(alpha) && defined(linux)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

#define CUMULATIVE_ARGS int

#define INIT_CUMULATIVE_ARGS(CUM)	((CUM) = 0)

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
\
	(CUM) = ROUND((CUM), align); \
	encoding = [NSString stringWithFormat:@"%@%d", \
				    (TYPE), \
				    (CUM) + OBJC_FORWARDING_STACK_OFFSET]; \
	(STACK_ARGSIZE) = (CUM) + type_size; \
	(CUM) += ROUND(type_size, sizeof(void*)); \
	encoding; })


#endif	/* i386 linux	*/

#if	defined(hppa)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

#define CUMULATIVE_ARGS int

#define INIT_CUMULATIVE_ARGS(CUM)  ((CUM) = 0)

#define FUNCTION_ARG_SIZE(TYPESIZE)	\
    ((TYPESIZE + 3) / 4)

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	int align = objc_alignof_type([(TYPE) cString]); \
	int type_size = objc_sizeof_type([(TYPE) cString]); \
	const char* type = [(TYPE) cString]; \
\
	(CUM) = ROUND((CUM), align); \
	encoding = [NSString stringWithFormat:@"%@%d", \
				    (TYPE), \
				    (CUM) + OBJC_FORWARDING_STACK_OFFSET]; \
	if((*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B)) \
	    (STACK_ARGSIZE) = (CUM) + ROUND(type_size, align); \
	else (STACK_ARGSIZE) = (CUM) + type_size; \
\
	/* Compute the new value of cumulative args */ \
	((((CUM) & 01) && FUNCTION_ARG_SIZE(type_size) > 1) && (CUM)++); \
	(CUM) += FUNCTION_ARG_SIZE(type_size); \
	encoding; })

#endif /* hppa */

#if	defined(i386) && defined(linux)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

#define CUMULATIVE_ARGS int

#define INIT_CUMULATIVE_ARGS(CUM)	((CUM) = 0)

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
\
	(CUM) = ROUND((CUM), align); \
	encoding = [NSString stringWithFormat:@"%@%d", \
				    (TYPE), \
				    (CUM) + OBJC_FORWARDING_STACK_OFFSET]; \
	if((*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) \
		&& type_size > 2) \
	    (STACK_ARGSIZE) = (CUM) + ROUND(type_size, align); \
	else (STACK_ARGSIZE) = (CUM) + type_size; \
	(CUM) += ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* i386 linux */

#if	defined(m68k)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

#define CUMULATIVE_ARGS int

#define INIT_CUMULATIVE_ARGS(CUM)	((CUM) = 0)

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
\
	(CUM) = ROUND((CUM), align); \
	if(type_size < sizeof(int)) \
	    (CUM) += sizeof(int) - ROUND(type_size, align); \
	encoding = [NSString stringWithFormat:@"%@%d", \
				    (TYPE), \
				    (CUM) + OBJC_FORWARDING_STACK_OFFSET]; \
	if((*type == _C_STRUCT_B || *type == _C_UNION_B || *type == _C_ARY_B) \
		&& type_size > 2) \
	    (STACK_ARGSIZE) = (CUM) + ROUND(type_size, align); \
	else (STACK_ARGSIZE) = (CUM) + ROUND(type_size, align); \
	(CUM) += type_size < sizeof(int) \
		? ROUND(type_size, align) \
		: ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* m68k */

#if	defined(sparc) && defined(solaris)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

/* From config/sparc/sparc.h in the GCC sources:

   On SPARC the first six args are normally in registers
   and the rest are pushed.  Any arg that starts within the first 6 words
   is at least partially passed in a register unless its data type forbids.
   For v9, the first 6 int args are passed in regs and the first N
   float args are passed in regs (where N is such that %f0-15 are filled).
   The rest are pushed.  Any arg that starts within the first 6 words
   is at least partially passed in a register unless its data type forbids.

   ...

   The SPARC ABI stipulates passing struct arguments (of any size) and
   (!v9) quad-precision floats by invisible reference.
*/

enum sparc_arg_location { IN_REGS = 0, ON_STACK = 1 };

struct sparc_args {
    int offsets[2];   /* 0 for args in regs, 1 for the rest of args on stack */
    int onStack;
};

#define CUMULATIVE_ARGS struct sparc_args

/* Initialize a variable of type CUMULATIVE_ARGS. This macro is called before
   processing the first argument of a method. */

#define INIT_CUMULATIVE_ARGS(CUM) \
    ({  (CUM).offsets[0] = 8; /* encoding in regs starts from 8 */ \
	(CUM).offsets[1] = 20; /* encoding in regs starts from 20 or 24 */ \
	(CUM).onStack = NO; })

#define GET_SPARC_ARG_LOCATION(CUM, CSTRING_TYPE, TYPESIZE) \
    ((CUM).onStack \
	? ON_STACK \
	: ((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 8 \
	    ? (((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 4 \
		? 0 : ((CUM).offsets[ON_STACK] += 4)),\
	      IN_REGS) \
	    : ((CUM).onStack = YES, ON_STACK)))

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
	int arg_location = GET_SPARC_ARG_LOCATION(CUM, type, type_size); \
\
	(CUM).offsets[arg_location] \
		= ROUND((CUM).offsets[arg_location], align); \
	if(type_size < sizeof(int)) \
	    (CUM).offsets[arg_location] += sizeof(int) - ROUND(type_size, align); \
	encoding = [NSString stringWithFormat: \
				(arg_location == IN_REGS ? @"%@+%d" : @"%@%d"), \
				(TYPE), \
				(arg_location == IN_REGS \
				    ? ((CUM).offsets[arg_location] \
					    + OBJC_FORWARDING_STACK_OFFSET) \
				    : (CUM).offsets[arg_location])]; \
	if(arg_location == ON_STACK) { \
	    if((*type == _C_STRUCT_B || *type == _C_UNION_B \
		    || *type == _C_ARY_B)) \
		(STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + ROUND(type_size, align); \
	    else (STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + type_size; \
	} \
	(CUM).offsets[arg_location] += \
	    type_size < sizeof(int) \
		? ROUND(type_size, align) \
		: ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* sparc solaris */

#if	defined(sparc) && defined(linux)

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

enum sparc_arg_location { IN_REGS = 0, ON_STACK = 1 };

struct sparc_args {
    int offsets[2];   /* 0 for args in regs, 1 for the rest of args on stack */
    int onStack;
};

#define CUMULATIVE_ARGS struct sparc_args

#define INIT_CUMULATIVE_ARGS(CUM) \
    ({  (CUM).offsets[0] = 8; /* encoding in regs starts from 8 */ \
	(CUM).offsets[1] = 20; /* encoding in regs starts from 20 or 24 */ \
	(CUM).onStack = NO; })

#define GET_SPARC_ARG_LOCATION(CUM, CSTRING_TYPE, TYPESIZE) \
    ((CUM).onStack \
	? ON_STACK \
	: ((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 8 \
	    ? (((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 4 \
		? 0 : ((CUM).offsets[ON_STACK] += 4)),\
	      IN_REGS) \
	    : ((CUM).onStack = YES, ON_STACK)))

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
	int arg_location = GET_SPARC_ARG_LOCATION(CUM, type, type_size); \
\
	(CUM).offsets[arg_location] \
		= ROUND((CUM).offsets[arg_location], align); \
	if(type_size < sizeof(int)) \
	    (CUM).offsets[arg_location] += sizeof(int) - ROUND(type_size, align); \
	encoding = [NSString stringWithFormat: \
				(arg_location == IN_REGS ? @"%@+%d" : @"%@%d"), \
				(TYPE), \
				(arg_location == IN_REGS \
				    ? ((CUM).offsets[arg_location] \
					    + OBJC_FORWARDING_STACK_OFFSET) \
				    : (CUM).offsets[arg_location])]; \
	if(arg_location == ON_STACK) { \
	    if((*type == _C_STRUCT_B || *type == _C_UNION_B \
		    || *type == _C_ARY_B)) \
		(STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + ROUND(type_size, align); \
	    else (STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + type_size; \
	} \
	(CUM).offsets[arg_location] += \
	    type_size < sizeof(int) \
		? ROUND(type_size, align) \
		: ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* sparc linux */



#ifndef		FUNCTION_ARG_ENCODING

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

#define CUMULATIVE_ARGS int

#define INIT_CUMULATIVE_ARGS(CUM)	((CUM) = 0)

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
\
	(CUM) = ROUND((CUM), align); \
	encoding = [NSString stringWithFormat:@"%@%d", \
				    (TYPE), \
				    (CUM) + OBJC_FORWARDING_STACK_OFFSET]; \
	(STACK_ARGSIZE) = (CUM) + type_size; \
	(CUM) += ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* generic */

/*
 *	End of libFoundation macros.
 */


static NSString*
isolate_type(const char* types)
{
    const char* p = objc_skip_typespec(types);
    return [NSString stringWithCString:types length:(unsigned)(p - types)];
}

static int
types_get_size_of_arguments(const char *types)
{
  const char* type = objc_skip_typespec (types);
  return atoi (type);
}

static int
types_get_number_of_arguments (const char *types)
{
  int i = 0;
  const char* type = types;
  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
}

static BOOL
rtn_type_is_oneway(const char * types)
{
  char * oneway_pos = strrchr(types, _C_ONEWAY);
  if (oneway_pos != (char *)0)
    return YES;
  else
    return NO;
}

@implementation NSMethodSignature

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)t
{
  NSMethodSignature *newMs = [[NSMethodSignature alloc] autorelease];
  const char *positionOfSizeInfo;
  const char *positionOfFirstParam;
  int len;

  positionOfSizeInfo = objc_skip_typespec(t);

  if (!isdigit(*positionOfSizeInfo))
    {
      CUMULATIVE_ARGS cumulative_args;
      int stack_argsize = 0;
      id encoding = [[NSMutableString new] autorelease];
      const char* retval = t;

      /* Skip returned value. */
      t = objc_skip_typespec(t);

      newMs->numArgs = 0;

      INIT_CUMULATIVE_ARGS(cumulative_args);
      while(*t) {
	  [encoding appendString:
		  FUNCTION_ARG_ENCODING(cumulative_args,
				      isolate_type(t),
				      stack_argsize)];
	  t = objc_skip_typespec(t);
	  newMs->numArgs++;
      }
      encoding = [NSString stringWithFormat:@"%@%d%@",
			      isolate_type(retval), stack_argsize, encoding];
      newMs->types = objc_malloc([encoding cStringLength]+1);
      [encoding getCString: newMs->types];
    }
  else
    {
      newMs->types = objc_malloc(strlen(t) + 1);
      strcpy(newMs->types, t);
      newMs->numArgs = types_get_number_of_arguments(newMs->types);
    }
  positionOfFirstParam = objc_skip_typespec(newMs->types);
  len = positionOfFirstParam - newMs->types;
  newMs->returnTypes = objc_malloc(len + 1);
  memcpy(newMs->returnTypes, newMs->types, len);
  newMs->returnTypes[len] = '\0';
  newMs->argFrameLength = types_get_size_of_arguments(newMs->types);
  if (*newMs->types == _C_VOID)
    newMs->returnFrameLength = 0;
  else
    newMs->returnFrameLength = objc_sizeof_type(newMs->types);
  return newMs;
}

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index
{
  /*   0  1   2   3       position
    "C0@+8:+12C+19C+23"   types    
       ^  ^   ^   ^
       (index == 0) tmptype->0, pretmptype->0
       (index == 1) tmptype->1, pretmptype->0
       (index == 2) tmptype->2, pretmptype->1
       (index == 3) tmptype->3, pretmptype->2
       and so on... */
  const char *tmptype = types;
  const char *pretmptype = NULL;
  int offset, preoffset, size;
  const char * result_type;

  if (index >= numArgs)
    [NSException raise:NSInvalidArgumentException
		 format:@"Index too high."];

  do 
    {
      pretmptype = tmptype;
      tmptype = objc_skip_argspec (tmptype);
    }
  while (index--);

  result_type = tmptype;  

  if (pretmptype == types)	// index == 0
    {

      tmptype = objc_skip_typespec(tmptype);
      if (*tmptype == '+')
	offset = atoi(tmptype + 1);
      else
#if m68k
	  offset = (atoi(tmptype) - 8);
#else 
	  offset = atoi(tmptype);
#endif // m68k
      size = offset;
    }
  else				// index != 0
    {
      tmptype = objc_skip_typespec(tmptype);
      pretmptype = objc_skip_typespec(pretmptype);

      if (*tmptype == '+')
	offset = atoi(tmptype + 1);
      else
#if m68k
	  offset = (atoi(tmptype) - 8);
#else 
	  offset = atoi(tmptype);
#endif // m68k

      if (*pretmptype == '+')
	preoffset = atoi(pretmptype + 1);
      else
#if m68k
	  preoffset = (atoi(pretmptype) - 8);
#else 
	  preoffset = atoi(pretmptype);

      size = offset - preoffset;
    }
#endif // m68k
  return (NSArgumentInfo){offset, size, (char*)result_type};
}

- (unsigned) frameLength
{
  return argFrameLength;
}

- (BOOL) isOneway
{
  return rtn_type_is_oneway(returnTypes);
}

- (unsigned) methodReturnLength
{
  return returnFrameLength;
}

- (char*) methodReturnType
{
  return returnTypes;
}

- (unsigned) numberOfArguments
{
  return numArgs;
}

- (void) dealloc
{
  objc_free(types);
  objc_free(returnTypes);
  [super dealloc];
}

@end

@implementation NSMethodSignature(GNU)
- (char*) methodType
{
  return types;
}
@end
