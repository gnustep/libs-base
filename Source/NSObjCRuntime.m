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

/**
 * Returns a string object containing the method name for
 * aSelector.  If aSelector is 0, returns nil.
 */
NSString *
NSStringFromSelector(SEL aSelector)
{
  if (aSelector != (SEL)0)
    return [NSString stringWithCString: GSNameFromSelector(aSelector)];
  return nil;
}

/**
 * Returns a selector for the method whose name is supplied in the
 * aSelectorName argument, or 0 if a nil string is supplied.
 */
SEL
NSSelectorFromString(NSString *aSelectorName)
{
  if (aSelectorName != nil)
    return GSSelectorFromName ([aSelectorName lossyCString]);
  return (SEL)0;
}

/**
 * Returns the class whose name is supplied in the
 * aClassName argument, or 0 if a nil string is supplied.
 */
Class
NSClassFromString(NSString *aClassName)
{
  if (aClassName != nil)
    return GSClassFromName ([aClassName lossyCString]);
  return (Class)0;
}

/**
 * Returns an [NSString] object containing the class name for
 * aClass.  If aClass is 0, returns nil.
 */
NSString *
NSStringFromClass(Class aClass)
{
  if (aClass != (Class)0)
    return [NSString stringWithCString: (char*)GSNameFromClass(aClass)];
  return nil;
}

/**
 * When provided with a C string containing encoded type information,
 * this method extracts size and alignment information for the specified
 * type into the buffers pointed to by sizep and alignp.<br />
 * If either sizep or alignp is a nil pointer, the corresponding data is
 * not extracted.<br />
 * The function returns a pointer to the type information C string.
 */
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
 
