/* Implementation of ObjC runtime for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: Aug 1995
   
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
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

NSString *
NSStringFromSelector(SEL aSelector)
{
  if (aSelector != (SEL)0)
    return [NSString stringWithCString: (char*)sel_get_name(aSelector)];
  return nil;
}

SEL
NSSelectorFromString(NSString *aSelectorName)
{
  if (aSelectorName != nil)
    return sel_get_any_uid ([aSelectorName cString]);
  return (SEL)0;
}

Class
NSClassFromString(NSString *aClassName)
{
  if (aClassName != nil)
    return objc_lookup_class ([aClassName cString]);
  return (Class)0;
}

NSString *
NSStringFromClass(Class aClass)
{
  if (aClass != (Class)0)
    return [NSString stringWithCString: (char*)class_get_class_name(aClass)];
  return nil;
}

#ifdef	MAX
#undef	MAX
#endif
#define MAX(X, Y)                    \
  ({ typeof(X) __x = (X), __y = (Y); \
     (__x > __y ? __x : __y); })

#ifdef	ROUND
#undef	ROUND
#endif
#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

/* This function was built by copying and modifying code from the objc runtime
 * rather than calling the objc runtime functions directly.  I did this for
 * efficiency, and because the existing runtime can't cope with 'void'.
 */
const char *
NSGetSizeAndAlignment(const char *typePtr, unsigned *sizep, unsigned *alignp)
{
  unsigned int	size;
  unsigned int	align;

  /* Skip any leading type qualifiers */
  while (*typePtr == _C_CONST
         || *typePtr == _C_IN
         || *typePtr == _C_INOUT
         || *typePtr == _C_OUT
         || *typePtr == _C_BYCOPY
#ifdef	_C_BYREF
         || *typePtr == _C_BYREF
#endif
         || *typePtr == _C_ONEWAY)
    {
      typePtr++;
    }

  switch(*typePtr++)
    {
    case _C_ID:
      size = sizeof(id);
      align = __alignof__(id);
      break;

    case _C_CLASS:
      size = sizeof(Class);
      align = __alignof__(Class);
      break;

    case _C_SEL:
      size = sizeof(SEL);
      align = __alignof__(SEL);
      break;

    case _C_CHR:
      size = sizeof(char);
      align = __alignof__(char);
      break;
      
    case _C_UCHR:
      size = sizeof(unsigned char);
      align = __alignof__(unsigned char);
      break;

    case _C_SHT:
      size = sizeof(short);
      align = __alignof__(short);
      break;

    case _C_USHT:
      size = sizeof(unsigned short);
      align = __alignof__(unsigned short);
      break;

    case _C_INT:
      size = sizeof(int);
      align = __alignof__(int);
      break;

    case _C_UINT:
      size = sizeof(unsigned int);
      align = __alignof__(unsigned int);
      break;

    case _C_LNG:
      size = sizeof(long);
      align = __alignof__(long);
      break;

    case _C_ULNG:
      size = sizeof(unsigned long);
      align = __alignof__(unsigned long);
      break;

    case _C_FLT:
      size = sizeof(float);
      align = __alignof__(float);
      break;

    case _C_DBL:
      size = sizeof(double);
      align = __alignof__(double);
      break;

    case _C_PTR:
    case _C_ATOM:
    case _C_CHARPTR:
      size = sizeof(char*);
      align = __alignof__(char*);
      break;

    case _C_ARY_B:
      {
	int len = atoi(typePtr);
	while (isdigit(*typePtr))
	  typePtr++;
	typePtr = NSGetSizeAndAlignment(typePtr, &size, &align);
	size *= len;
      }
      break; 

    case _C_STRUCT_B:
      {
	struct { int x; double y; } fooalign;
	int a;
	int s;

	align = __alignof__(fooalign);
	size = 0;
	while (*typePtr != _C_STRUCT_E && *typePtr++ != '=');
	while (*typePtr != _C_STRUCT_E)
	  {
	    typePtr = NSGetSizeAndAlignment(typePtr, &s, &a);
	    align = MAX (align, a);
	    size = ROUND (size, a);
	    size += s;	/* add component size */
	  }
	typePtr++;
      }

    case _C_UNION_B:
      {
	int a;
	int s;

	align = 0;
	size = 0;
	while (*typePtr != _C_STRUCT_E && *typePtr++ != '=');
	while (*typePtr != _C_STRUCT_E)
	  {
	    typePtr = NSGetSizeAndAlignment(typePtr, &s, &a);
	    align = MAX (align, a);
	    size = MAX (size, s);
	  }
	typePtr++;
      }
      
    case _C_VOID:
      size = 0;
      align = 1;
      break;

    default:
      return 0;		/* Unknown type.	*/
  }
  if (alignp)
    *alignp = align;
  if (sizep)
    *sizep = size;
  return typePtr;
}

