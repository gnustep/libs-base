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
#include <base/preface.h>
#include <base/fast.x>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <mframe.h>

NSString *
NSStringFromSelector(SEL aSelector)
{
  if (aSelector != (SEL)0)
    return [_fastCls._NSGCString stringWithCString:
	(char*)sel_get_name(aSelector)];
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
    return [_fastCls._NSGCString stringWithCString: fastClassName(aClass)];
  return nil;
}

const char *
NSGetSizeAndAlignment(const char *typePtr, unsigned *sizep, unsigned *alignp)
{
  NSArgumentInfo	info;
  typePtr = mframe_next_arg(typePtr, &info);
  if (sizep)
    *sizep = info.size;
  if (alignp)
    *alignp = info.align;
}

BOOL
GSGetInstanceVariable(id obj, NSString *iVarName, void *data)
{
  const char	*name = [iVarName cString];
  Class	class;
  struct objc_ivar_list	*ivars;
  struct objc_ivar	*ivar = 0;
  int		offset;
  const char	*type;
  unsigned int	size;

  class = [obj class];
  while (class != nil && ivar == 0)
    {
      ivars = class->ivars;
      class = class->super_class;
      if (ivars)
	{
	  int	i;

	  for (i = 0; i < ivars->ivar_count; i++)
	    {
	      if (strcmp(ivars->ivar_list[i].ivar_name, name) == 0)
		{
		  ivar = &ivars->ivar_list[i];
		  break;
		}
	    }
	}
    }
  if (ivar == 0)
    {
      NSLog(@"Attempt to get non-existent ivar");
      return NO;
    }

  offset = ivar->ivar_offset;
  type = ivar->ivar_type;
  size = objc_sizeof_type(type);
  memcpy(data, ((void*)obj) + offset, size);
  return YES;
}

BOOL
GSSetInstanceVariable(id obj, NSString *iVarName, const void *data)
{
  const	char	*name = [iVarName cString];
  Class	class;
  struct objc_ivar_list	*ivars;
  struct objc_ivar	*ivar = 0;
  int		offset;
  const char	*type;
  unsigned int	size;

  class = [obj class];
  while (class != nil && ivar == 0)
    {
      ivars = class->ivars;
      class = class->super_class;
      if (ivars)
	{
	  int	i;

	  for (i = 0; i < ivars->ivar_count; i++)
	    {
	      if (strcmp(ivars->ivar_list[i].ivar_name, name) == 0)
		{
		  ivar = &ivars->ivar_list[i];
		  break;
		}
	    }
	}
    }
  if (ivar == 0)
    {
      NSLog(@"Attempt to set non-existent ivar");
      return NO;
    }

  offset = ivar->ivar_offset;
  type = ivar->ivar_type;
  size = objc_sizeof_type(type);
  memcpy(((void*)obj) + offset, data, size);
  return YES;
}
