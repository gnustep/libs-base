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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

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
  int len;
  NSMethodSignature *newMs = [NSMethodSignature alloc];
#if 0
  len = strlen(t);
#else
  len = strlen(t) + 1;		// For the last '\0'
#endif
  OBJC_MALLOC(newMs->types, char, len);
  memcpy(newMs->types, t, len);
#if 0
  len = strlen(t);	                                 /* xxx */
#else
  {
    char * endof_ret_encoding = strrchr(t, '0');
    len = endof_ret_encoding - t + 1;		// +2?
  }
#endif
  OBJC_MALLOC(newMs->returnTypes, char, len);
  memcpy(newMs->returnTypes, t, len);
  newMs->returnTypes[len-1] = '\0'; // ???
  newMs->argFrameLength = types_get_size_of_arguments(t);
  newMs->returnFrameLength = objc_sizeof_type(t);
  newMs->numArgs = types_get_number_of_arguments(t);
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
  return (NSArgumentInfo){offset, size, result_type};
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
  OBJC_FREE(types);
  OBJC_FREE(returnTypes);
  [super dealloc];
}

@end

@implementation NSMethodSignature(GNU)
- (char*) methodType
{
  return types;
}
@end
