/** Implementation of ObjC runtime for GNUStep
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSObjCRuntime class reference</title>
   $Date$ $Revision$
   */ 

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <mframe.h>
#include <string.h>

NSString *
NSStringFromSelector(SEL aSelector)
{
  if (aSelector != (SEL)0)
    return [NSString stringWithCString: GSNameFromSelector(aSelector)];
  return nil;
}

SEL
NSSelectorFromString(NSString *aSelectorName)
{
  if (aSelectorName != nil)
    return GSSelectorFromName ([aSelectorName lossyCString]);
  return (SEL)0;
}

Class
NSClassFromString(NSString *aClassName)
{
  if (aClassName != nil)
    return GSClassFromName ([aClassName lossyCString]);
  return (Class)0;
}

NSString *
NSStringFromClass(Class aClass)
{
  if (aClass != (Class)0)
    return [NSString stringWithCString: (char*)GSNameFromClass(aClass)];
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
  return typePtr;
}
 
/**
 * This function is used to locate information about the instance
 * variable of obj called name.  It returns YES if the variable
 * was found, NO otherwise.  If it returns YES, then the values
 * pointed to by type, size, and offset will be set (except where
 * they are nul pointers).
 */
BOOL
GSFindInstanceVariable(id obj, const char *name,
  const char **type, unsigned int *size, int *offset)
{
  Class			class;
  struct objc_ivar_list	*ivars;
  struct objc_ivar	*ivar = 0;

  class = [obj class];
  while (class != nil && ivar == 0)
    {
      ivars = class->ivars;
      class = class->super_class;
      if (ivars != 0)
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
      return NO;
    }

  if (type)
    *type = ivar->ivar_type;
  if (size)
    *size = objc_sizeof_type(ivar->ivar_type);
  if (offset)
    *offset = ivar->ivar_offset;
  return YES;
}

/**
 * This function performs no checking ... you should use it only where
 * you are providing information from a call to GSFindInstanceVariable()
 * and you know that the data area provided is the correct size.
 */
void
GSGetVariable(id obj, int offset, unsigned int size, void *data)
{
  memcpy(data, ((void*)obj) + offset, size);
}

/**
 * This function performs no checking ... you should use it only where
 * you are providing information from a call to GSFindInstanceVariable()
 * and you know that the data area provided is the correct size.
 */
void
GSSetVariable(id obj, int offset, unsigned int size, const void *data)
{
  memcpy(((void*)obj) + offset, data, size);
}

/** <deprecated />
 */
BOOL
GSInstanceVariableInfo(id obj, NSString *iVarName,
  const char **type, unsigned *size, unsigned *offset)
{
  const char	*name = [iVarName cString];

  return GSFindInstanceVariable(obj, name, type, size, offset);
}

/** <deprecated />
 */
BOOL
GSGetInstanceVariable(id obj, NSString *iVarName, void *data)
{
  const char	*name = [iVarName cString];
  int		offset;
  unsigned int	size;

  if (GSFindInstanceVariable(obj, name, 0, &size, &offset) == YES)
    {
      GSGetVariable(obj, offset, size, data);
      return YES;
    }
  return NO;
}

/** <deprecated />
 */
BOOL
GSSetInstanceVariable(id obj, NSString *iVarName, const void *data)
{
  const char	*name = [iVarName cString];
  int		offset;
  unsigned int	size;

  if (GSFindInstanceVariable(obj, name, 0, &size, &offset) == YES)
    {
      GSSetVariable(obj, offset, size, data);
      return YES;
    }
  return NO;
}

/* Getting a system error message on a variety of systems */
#ifdef __MINGW__
LPTSTR GetErrorMsg(DWORD msgId)
{
  LPVOID lpMsgBuf;

  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL, msgId,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
    (LPTSTR)&lpMsgBuf, 0, NULL);

  return (LPTSTR)lpMsgBuf;
}
#else
#ifndef HAVE_STRERROR
const char*
strerror(int eno)
{
  extern char*  sys_errlist[];
  extern int    sys_nerr;

  if (eno < 0 || eno >= sys_nerr)
    {
      return("unknown error number");
    }
  return(sys_errlist[eno]);
}
#endif
#endif /* __MINGW__ */

const char *GSLastErrorStr(long error_id)
{
#ifdef __MINGW__
  return GetErrorMsg(GetLastError());
#else
  return strerror(error_id);
#endif
}
