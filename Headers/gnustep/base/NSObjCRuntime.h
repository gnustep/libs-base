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
#  define GS_DECLARE __declspec(dllexport)
#elif libgnustep_base_ISDLL
#  define GS_EXPORT  extern __declspec(dllimport)
#  define GS_DECLARE __declspec(dllimport)
#else
#  define GS_EXPORT extern
#  define GS_DECLARE
#endif

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
GS_EXPORT BOOL GSFindInstanceVariable(id obj, const char *name,
  const char **type, unsigned int *size, int *offset);
GS_EXPORT void GSGetVariable(id obj, int offset, unsigned int size, void *data);
GS_EXPORT void GSSetVariable(id obj, int offset, unsigned int size,
  const void *data);

/*
 * The following three functions are deprecated and will be removed in future
 */
GS_EXPORT BOOL GSInstanceVariableInfo(id obj, NSString *iVarName,
  const char **type, unsigned *size, unsigned *offset);
GS_EXPORT BOOL GSGetInstanceVariable(id obj, NSString *name, void* data);
GS_EXPORT BOOL GSSetInstanceVariable(id obj, NSString *name, const void* data);

#include <base/objc-gnu2next.h>

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

/** <deprecated />
 */
FOUNDATION_STATIC_INLINE const char*
GSObjCName(Class this)
{
  return class_get_class_name(this);
}

/** <deprecated />
 */
FOUNDATION_STATIC_INLINE const char*
GSObjCSelectorName(SEL this)
{
  if (this == 0)
    return 0;
  return sel_get_name(this);
}

/** <deprecated />
 */
FOUNDATION_STATIC_INLINE const char*
GSObjCSelectorTypes(SEL this)
{
  return sel_get_type(this);
}




/**
 * Given a class name, return the corresponding class or
 * a nul pointer if the class cannot be found. <br />
 * If the argument is nil, return a nul pointer.
 */
FOUNDATION_STATIC_INLINE Class
GSClassFromName(const char *name)
{
  if (name == 0)
    return 0;
  return objc_lookup_class(name);
}

/**
 * Return the name of the supplied class, or a nul pointer if no class
 * was supplied.
 */
FOUNDATION_STATIC_INLINE const char*
GSNameFromClass(Class this)
{
  if (this == 0)
    return 0;
  return class_get_class_name(this);
}

/**
 * Return the name of the supplied selector, or a nul pointer if no selector
 * was supplied.
 */
FOUNDATION_STATIC_INLINE const char*
GSNameFromSelector(SEL this)
{
  if (this == 0)
    return 0;
  return sel_get_name(this);
}

/**
 * Return a selector matching the specified name, or nil if no name is
 * supplied.  The returned selector could be any one with the name.<br />
 * If no selector exists, returns nil.
 */
FOUNDATION_STATIC_INLINE SEL
GSSelectorFromName(const char *name)
{
  if (name == 0)
    {
      return 0;
    }
  else
    {
      return sel_get_any_uid(name);
    }
}

/**
 * Return the selector for the specified name and types.  Returns a nul
 * pointer if the name is nul.  Uses any available selector if the types
 * argument is nul. <br />
 * Creates a new selector if necessary.
 */
FOUNDATION_STATIC_INLINE SEL
GSSelectorFromNameAndTypes(const char *name, const char *types)
{
  if (name == 0)
    {
      return 0;
    }
  else
    {
      SEL	s;

      if (types == 0)
	{
	  s = sel_get_any_typed_uid(name);
	}
      else
	{
	  s = sel_get_typed_uid(name, types);
	}
      if (s == 0)
	{
	  if (types == 0)
	    {
	      s = sel_register_name(name);
	    }
	  else
	    {
	      s = sel_register_typed_name(name, types);
	    }
	}
      return s;
    }

}

/**
 * Return the type information from the specified selector.
 * May return a nul pointer if the selector was a nul pointer or if it
 * was not typed.
 */
FOUNDATION_STATIC_INLINE const char*
GSTypesFromSelector(SEL this)
{
  if (this == 0)
    return 0;
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
  return class_get_version(this);
}

/*
 * Return the zone in which an object belongs, without using the zone method
 */
#include	<Foundation/NSZone.h>
GS_EXPORT NSZone *GSObjCZone(NSObject *obj);

/*
 * Quickly return autoreleased data.
 */
void	*_fastMallocBuffer(unsigned size);

/* Getting a system error message on a variety of systems */
GS_EXPORT const char *GSLastErrorStr(long error_id);

#endif

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */
