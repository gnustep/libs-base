/** Interface to ObjC runtime for GNUStep
   Copyright (C) 1995, 1997, 2000, 2002 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2002
   
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

    AutogsdocSource: Additions/GSObjCRuntime.m

   */ 

#ifndef __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>
#include <objc/objc-api.h>
#include <stdarg.h>

#ifdef GNUSTEP_WITH_DLL
 
#if BUILD_libgnustep_base_DLL
#  define GS_EXPORT  __declspec(dllexport)
#  define GS_DECLARE __declspec(dllexport)
#else
#  define GS_EXPORT  extern __declspec(dllimport)
#  define GS_DECLARE __declspec(dllimport)
#endif
 
#else /* GNUSTEP_WITH[OUT]_DLL */

#  define GS_EXPORT extern
#  define GS_DECLARE 

#endif

@class	NSArray;
@class	NSDictionary;
@class	NSObject;
@class	NSString;
@class	NSValue;

#ifndef YES
#define YES		1
#endif
#ifndef NO
#define NO		0
#endif
#ifndef nil
#define nil		0
#endif

#ifndef	NO_GNUSTEP
/*
 * Functions for accessing instance variables directly -
 * We can copy an ivar into arbitrary data,
 * Get the type encoding for a named ivar,
 * and copy a value into an ivar.
 */
GS_EXPORT BOOL GSObjCFindVariable(id obj, const char *name,
  const char **type, unsigned int *size, int *offset);
GS_EXPORT void GSObjCGetVariable(id obj, int offset, unsigned int size,
  void *data);
GS_EXPORT void GSObjCSetVariable(id obj, int offset, unsigned int size,
  const void *data);
GS_EXPORT NSArray* GSObjCMethodNames(id obj);
GS_EXPORT NSArray* GSObjCVariableNames(id obj);

GS_EXPORT void GSObjCAddClassBehavior(Class receiver, Class behavior);
GS_EXPORT IMP GSObjCGetMethod(Class class, SEL sel);
GS_EXPORT IMP GSObjCReplaceMethod(Class class, SEL sel, IMP imp);

GS_EXPORT NSValue*
GSObjCMakeClass(NSString *name, NSString *superName, NSDictionary *iVars);
GS_EXPORT void GSObjCAddClasses(NSArray *classes);

/*
 * Functions for key-value encoding ... they access values in an object
 * either by selector or directly, but do so using NSNumber for the
 * scalar types of data.
 */
GS_EXPORT id GSObjCGetValue(NSObject *self, NSString *key, SEL sel,
  const char *type, unsigned size, int offset);
GS_EXPORT void GSObjCSetValue(NSObject *self, NSString *key, id val, SEL sel,
  const char *type, unsigned size, int offset);

/*
 * The next five are old (deprecated) names for the same thing.
 */
GS_EXPORT BOOL GSFindInstanceVariable(id obj, const char *name,
  const char **type, unsigned int *size, int *offset);
GS_EXPORT void GSGetVariable(id obj, int offset, unsigned int size,
  void *data);
GS_EXPORT void GSSetVariable(id obj, int offset, unsigned int size,
  const void *data);
GS_EXPORT id GSGetValue(NSObject *self, NSString *key, SEL sel,
  const char *type, unsigned size, int offset);
GS_EXPORT void GSSetValue(NSObject *self, NSString *key, id val, SEL sel,
  const char *type, unsigned size, int offset);

#include <gnustep/base/objc-gnu2next.h>

#define GS_STATIC_INLINE static inline

/*
 * GSObjCClass() return the class of an instance.
 * The argument to this function must NOT be nil.
 */
GS_STATIC_INLINE Class
GSObjCClass(id obj)
{
  return obj->class_pointer;
}

/*
 * GSObjCIsInstance() tests to see if an id is an instance.
 * The argument to this function must NOT be nil.
 */
GS_STATIC_INLINE BOOL
GSObjCIsInstance(id obj)
{
  return CLS_ISCLASS(obj->class_pointer);
}

/*
 * GSObjCIsKindOf() tests to see if a class inherits from another class
 * The argument to this function must NOT be nil.
 */
GS_STATIC_INLINE BOOL
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

/** ## deprecated ##
 */
GS_STATIC_INLINE const char*
GSObjCName(Class this)
{
  return class_get_class_name(this);
}

/** ## deprecated ##
 */
GS_STATIC_INLINE const char*
GSObjCSelectorName(SEL this)
{
  if (this == 0)
    return 0;
  return sel_get_name(this);
}

/** ## deprecated ##
 */
GS_STATIC_INLINE const char*
GSObjCSelectorTypes(SEL this)
{
  return sel_get_type(this);
}

/**
 * Given a class name, return the corresponding class or
 * a nul pointer if the class cannot be found. <br />
 * If the argument is nil, return a nul pointer.
 */
GS_STATIC_INLINE Class
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
GS_STATIC_INLINE const char*
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
GS_STATIC_INLINE const char*
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
GS_STATIC_INLINE SEL
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
GS_STATIC_INLINE SEL
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
GS_STATIC_INLINE const char*
GSTypesFromSelector(SEL this)
{
  if (this == 0)
    return 0;
  return sel_get_type(this);
}


GS_STATIC_INLINE Class
GSObjCSuper(Class this)
{
  return class_get_super_class(this);
}

GS_STATIC_INLINE int
GSObjCVersion(Class this)
{
  return class_get_version(this);
}

/*
 * Return the zone in which an object belongs, without using the zone method
 */
#ifndef NeXT_Foundation_LIBRARY
#include	<Foundation/NSZone.h>
#else
#include <Foundation/Foundation.h>
#endif

GS_EXPORT NSZone *GSObjCZone(NSObject *obj);

/**
 * Quickly return autoreleased data storage area.
 */
GS_EXPORT void	*GSAutoreleasedBuffer(unsigned size);

/* Getting a system error message on a variety of systems */
GS_EXPORT const char *GSLastErrorStr(long error_id);



#ifndef	GS_MAX_OBJECTS_FROM_STACK
/**
 * The number of objects to try to get from varargs into an array on
 * the stack ... if there are more than this, use the heap.
 * NB. This MUST be a multiple of 2
 */
#define	GS_MAX_OBJECTS_FROM_STACK	128
#endif

/**
 * <p>This is a macro designed to minimise the use of memory allocation and
 * deallocation when you need to work with a vararg list of objects.<br />
 * The objects are unpacked from the vararg list into two 'C' arrays and
 * then a code fragment you specify is able to make use of them before
 * that 'C' array is destroyed. 
 * </p>
 * <p>The firstObject argument is the name of the formal parameter in your
 * method or function which precedes the ', ...' denoting variable args.
 * </p>
 * <p>The code argument is a piece of objective-c code to be executed to
 * make use of the objects stored in the 'C' arrays.<br />
 * When this code is called the unsigned integer '__count' will contain the
 * number of objects unpacked, the pointer '__objects' will point to
 * the first object in each pair, and the pointer '__pairs' will point
 * to an array containing the second halves of the pairs of objects
 * whose first halves are in '__objects'.<br />
 * This lets you pack a list of the form 'key, value, key, value, ...'
 * into an array of keys and an array of values.
 * </p>
 */
#define GS_USEIDPAIRLIST(firstObject, code...) ({\
  va_list	__ap; \
  unsigned int	__max = GS_MAX_OBJECTS_FROM_STACK; \
  unsigned int	__count = 0; \
  id		__buf[__max]; \
  id		*__objects = __buf; \
  id		*__pairs = &__objects[__max/2]; \
  id		__obj = firstObject; \
  va_start(__ap, firstObject); \
  while (__obj != nil && __count < __max) \
    { \
      if ((__count % 2) == 0) \
	{ \
	  __objects[__count/2] = __obj; \
	} \
      else \
	{ \
	  __pairs[__count/2] = __obj; \
	} \
      __obj = va_arg(__ap, id); \
      if (++__count == __max) \
	{ \
	  while (__obj != nil) \
	    { \
	      __count++; \
	      __obj = va_arg(__ap, id); \
	    } \
	} \
    } \
  if ((__count % 2) == 1) \
    { \
      __pairs[__count/2] = nil; \
      __count++; \
    } \
  va_end(__ap); \
  if (__count > __max) \
    { \
      unsigned int	__tmp; \
      __objects = (id*)objc_malloc(__count*sizeof(id)); \
      __pairs = &__objects[__count/2]; \
      __objects[0] = firstObject; \
      va_start(__ap, firstObject); \
      for (__tmp = 1; __tmp < __count; __tmp++) \
	{ \
	  if ((__tmp % 2) == 0) \
	    { \
	      __objects[__tmp/2] = va_arg(__ap, id); \
	    } \
	  else \
	    { \
	      __pairs[__tmp/2] = va_arg(__ap, id); \
	    } \
	} \
      va_end(__ap); \
    } \
  code; \
  if (__objects != __buf) objc_free(__objects); \
})

/**
 * <p>This is a macro designed to minimise the use of memory allocation and
 * deallocation when you need to work with a vararg list of objects.<br />
 * The objects are unpacked from the vararg list into a 'C' array and
 * then a code fragment you specify is able to make use of them before
 * that 'C' array is destroyed. 
 * </p>
 * <p>The firstObject argument is the name of the formal parameter in your
 * method or function which precedes the ', ...' denoting variable args.
 * </p>
 * <p>The code argument is a piece of objective-c code to be executed to
 * make use of the objects stored in the 'C' array.<br />
 * When this code is called the unsigned integer '__count' will contain the
 * number of objects unpacked, and the pointer '__objects' will point to
 * the unpacked objects, ie. firstObject followed by the vararg arguments
 * up to (but not including) the first nil.
 * </p>
 */
#define GS_USEIDLIST(firstObject, code...) ({\
  va_list	__ap; \
  unsigned int	__max = GS_MAX_OBJECTS_FROM_STACK; \
  unsigned int	__count = 0; \
  id		__buf[__max]; \
  id		*__objects = __buf; \
  id		__obj = firstObject; \
  va_start(__ap, firstObject); \
  while (__obj != nil && __count < __max) \
    { \
      __objects[__count] = __obj; \
      __obj = va_arg(__ap, id); \
      if (++__count == __max) \
	{ \
	  while (__obj != nil) \
	    { \
	      __count++; \
	      __obj = va_arg(__ap, id); \
	    } \
	} \
    } \
  va_end(__ap); \
  if (__count > __max) \
    { \
      unsigned int	__tmp; \
      __objects = (id*)objc_malloc(__count*sizeof(id)); \
      va_start(__ap, firstObject); \
      __objects[0] = firstObject; \
      for (__tmp = 1; __tmp < __count; __tmp++) \
	{ \
	  __objects[__tmp] = va_arg(__ap, id); \
	} \
      va_end(__ap); \
    } \
  code; \
  if (__objects != __buf) objc_free(__objects); \
})


#endif

#endif /* __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */
