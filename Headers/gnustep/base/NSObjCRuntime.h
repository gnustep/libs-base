/* Interface to ObjC runtime for GNUStep
   Copyright (C) 1995, 1997, 2000 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

#ifndef __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>
#include <objc/objc-api.h>
#include <stdarg.h>

#if BUILD_libgnustep_base_DLL
#  define GS_EXPORT  __declspec(dllexport)
#elif libgnustep_base_ISDLL
#  define GS_EXPORT  extern __declspec(dllimport)
#else
#  define GS_EXPORT extern
#endif
#define GS_DECLARE

@class	NSObject;
@class	NSString;

GS_EXPORT NSString	*NSStringFromSelector(SEL aSelector);
GS_EXPORT SEL		NSSelectorFromString(NSString *aSelectorName);
GS_EXPORT Class		NSClassFromString(NSString *aClassName);
GS_EXPORT NSString	*NSStringFromClass(Class aClass);
GS_EXPORT const char	*NSGetSizeAndAlignment(const char *typePtr,
  unsigned int *sizep, unsigned int *alignp);

/* Logging */
/* OpenStep spec states that log messages go to stderr, but just in case
   someone wants them to go somewhere else, they can implement a function
   like this */
typedef void NSLog_printf_handler (NSString* message);
GS_EXPORT NSLog_printf_handler	*_NSLog_printf_handler;

GS_EXPORT void			NSLog (NSString* format, ...);
GS_EXPORT void			NSLogv (NSString* format, va_list args);

#ifndef YES
#define YES		1
#endif
#ifndef NO
#define NO		0
#endif
#ifndef nil
#define nil		0
#endif

#define FOUNDATION_EXPORT
#define FOUNDATION_STATIC_INLINE static inline

#ifndef	NO_GNUSTEP
/*
 * Functions for accessing instance variables directly -
 * We can copy an ivar into arbitrary data,
 * Get the type encoding for a named ivar,
 * and copy a value into an ivar.
 */
GS_EXPORT BOOL GSInstanceVariableInfo(id obj, NSString *iVarName,
  const char **type, unsigned *size, unsigned *offset);
GS_EXPORT BOOL GSGetInstanceVariable(id obj, NSString *name, void* data);
GS_EXPORT BOOL GSSetInstanceVariable(id obj, NSString *name, const void* data);

/*
 * GSObjCClass() return the class of an instance.
 * The argument to this function must NOT be nil.
 */
FOUNDATION_STATIC_INLINE Class
GSObjCClass(id obj)
{
  return obj->class_pointer;
}

/*
 * GSObjCIsInstance() tests to see if an id is an instance.
 * The argument to this function must NOT be nil.
 */
FOUNDATION_STATIC_INLINE BOOL
GSObjCIsInstance(id obj)
{
  return CLS_ISCLASS(obj->class_pointer);
}

/*
 * GSObjCIsKindOf() tests to see if a class inherits from another class
 * The argument to this function must NOT be nil.
 */
FOUNDATION_STATIC_INLINE BOOL
GSObjCIsKindOf(Class this, Class other)
{
  while (this != Nil)
    {
      if (this == other)
	{
	  return YES;
	}
      this = class_get_super_class(this);
    }
  return NO;
}

FOUNDATION_STATIC_INLINE const char*
GSObjCName(Class this)
{
  return this->name;
}

FOUNDATION_STATIC_INLINE const char*
GSObjCSelectorName(SEL this)
{
  return sel_get_name(this);
}

FOUNDATION_STATIC_INLINE const char*
GSObjCSelectorTypes(SEL this)
{
  return sel_get_type(this);
}

FOUNDATION_STATIC_INLINE Class
GSObjCSuper(Class this)
{
  return class_get_super_class(this);
}

FOUNDATION_STATIC_INLINE int
GSObjCVersion(Class this)
{
  return this->version;
}

/*
 * Return the zone in which an object belongs, without using the zone method
 */
#include	<Foundation/NSZone.h>
NSZone	*GSObjCZone(NSObject *obj);

/*
 * Quickly return autoreleased data.
 */
void	*_fastMallocBuffer(unsigned size);

#endif

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */
