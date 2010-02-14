/** Interface to ObjC runtime for GNUStep
   Copyright (C) 1995, 1997, 2000, 2002, 2003 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2002
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

    AutogsdocSource: Additions/GSObjCRuntime.m

   */ 

#ifndef __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <GNUstepBase/GSVersionMacros.h>

#include <objc/objc.h>
#include <objc/objc-api.h>

#if	defined(HAVE__OBJC_RUNTIME_H)
#include <objc/runtime.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include <stdarg.h>

#ifdef GNUSTEP_WITH_DLL
 
#if BUILD_libgnustep_base_DLL
#
# if defined(__MINGW32__)
  /* On Mingw, the compiler will export all symbols automatically, so
   * __declspec(dllexport) is not needed.
   */
#  define GS_EXPORT  extern
#  define GS_DECLARE 
# else
#  define GS_EXPORT  __declspec(dllexport)
#  define GS_DECLARE __declspec(dllexport)
# endif
#else
#  define GS_EXPORT  extern __declspec(dllimport)
#  define GS_DECLARE __declspec(dllimport)
#endif
 
#else /* GNUSTEP_WITH[OUT]_DLL */

#  define GS_EXPORT extern
#  define GS_DECLARE 

#endif

#if (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 1))
#define GS_ATTRIB_DEPRECATED __attribute__ ((deprecated))
#else
#define GS_ATTRIB_DEPRECATED
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

#if	defined(NeXT_RUNTIME)

#define _C_CONST        'r'
#define _C_IN           'n'
#define _C_INOUT        'N'
#define _C_OUT          'o'
#define _C_BYCOPY       'O'
#define _C_BYREF        'R'
#define _C_ONEWAY       'V'
#define _C_GCINVISIBLE  '!'

#elif	defined(__GNUSTEP_RUNTIME__)

#define	class_nextMethodList(aClass,anIterator) (({\
  if (*(anIterator) == 0) \
    *((struct objc_method_list**)(anIterator)) = (aClass)->methods; \
  else \
    *(anIterator) = (*((struct objc_method_list**)(anIterator)))->method_next; \
}), *(anIterator))

#else	/* Old GNU runtime */

#define	class_getInstanceSize(C) class_get_instance_size(C)

#define	class_nextMethodList(aClass,anIterator) (({\
  if (*(anIterator) == 0) \
    *((struct objc_method_list**)(anIterator)) = (aClass)->methods; \
  else \
    *(anIterator) = (*((struct objc_method_list**)(anIterator)))->method_next; \
}), *(anIterator))

#define	object_getClass(O) ((Class)*(Class*)O)
#define	object_setClass(O,C) (*((Class*)O) = C)

#endif


#ifndef	NO_GNUSTEP
/*
 * Functions for accessing instance variables directly -
 * We can copy an ivar into arbitrary data,
 * Get the type encoding for a named ivar,
 * and copy a value into an ivar.
 */
GS_EXPORT BOOL
GSObjCFindVariable(id obj, const char *name,
		   const char **type, unsigned int *size, int *offset);

GS_EXPORT void
GSObjCGetVariable(id obj, int offset, unsigned int size, void *data);

GS_EXPORT void
GSObjCSetVariable(id obj, int offset, unsigned int size, const void *data);

GS_EXPORT NSArray *
GSObjCMethodNames(id obj);

GS_EXPORT NSArray *
GSObjCVariableNames(id obj);

GS_EXPORT void
GSObjCAddClassBehavior(Class receiver, Class behavior);

GS_EXPORT NSValue *
GSObjCMakeClass(NSString *name, NSString *superName, NSDictionary *iVars);

GS_EXPORT void
GSObjCAddClasses(NSArray *classes);

/*
 * Functions for key-value encoding ... they access values in an object
 * either by selector or directly, but do so using NSNumber for the
 * scalar types of data.
 */
GS_EXPORT id
GSObjCGetVal(NSObject *self, const char *key, SEL sel,
  const char *type, unsigned size, int offset);

GS_EXPORT void
GSObjCSetVal(NSObject *self, const char *key, id val, SEL sel,
  const char *type, unsigned size, int offset);

/*
 * This section includes runtime functions
 * to query and manipulate the ObjC runtime structures.
 * These functions take care to not use ObjC code so
 * that they can safely be used in +(void)load implementations
 * where applicable.
 */

#define GS_STATIC_INLINE static inline

/**
 * Fills a nil terminated array of Class objects referenced by buffer
 * with max number of classes registered with the objc runtime.  
 * The provided buffer must be large enough to hold max + 1 Class objects.
 * If buffer is nil, the function returns the number of Class
 * objects that would be inserted if the buffer is large enough.
 * Otherwise returns the number of Class objects that did not fit
 * into the provided buffer.  This function keeps a cache of the class
 * list for future invocations when used with the GNU runtime.  If
 * clearCache is YES, this cache will be invalidated and rebuild.  The
 * flag has no effect for the NeXT runtime.
 * This function is provided as consistent API to both runtimes.  
 * In the case of the GNU runtime it is likely more efficient to use
 * objc_next_class() to iterate over the classes.
 */
GS_EXPORT unsigned int
GSClassList(Class *buffer, unsigned int max, BOOL clearCache);

/**
 * GSObjCClass() return the class of an instance.
 * Returns a nul pointer if the argument is nil.
 */
GS_STATIC_INLINE Class
GSObjCClass(id obj)
{
  if (obj == nil)
    return 0;
  return obj->class_pointer;
}

/**
 * Returns the superclass of this.
 */
GS_STATIC_INLINE Class
GSObjCSuper(Class cls)
{
#ifndef NeXT_RUNTIME
  if (cls != 0 && CLS_ISRESOLV (cls) == NO)
    {
      const char *name;
      name = (const char *)cls->super_class;
      if (name == NULL)
	{
	  return 0;
	}
      return objc_lookup_class (name);
    }
#endif
  return class_get_super_class(cls);
}

/**
 * GSObjCIsInstance() tests to see if an id is an instance.
 * Returns NO if the argument is nil.
 */
GS_STATIC_INLINE BOOL
GSObjCIsInstance(id obj)
{
  if (obj == nil)
    return NO;
  return object_is_instance(obj);
}

/**
 * GSObjCIsClass() tests to see if an id is a class.
 * Returns NO if the argument is nil.
 */
GS_STATIC_INLINE BOOL
GSObjCIsClass(Class cls)
{
  if (cls == nil)
    return NO;
  return object_is_class(cls);
}

/**
 * GSObjCIsKindOf() tests to see if a class inherits from another class
 * The argument to this function must NOT be nil.
 */
GS_STATIC_INLINE BOOL
GSObjCIsKindOf(Class cls, Class other)
{
  while (cls != Nil)
    {
      if (cls == other)
	{
	  return YES;
	}
      cls = GSObjCSuper(cls);
    }
  return NO;
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
GS_STATIC_INLINE const char *
GSNameFromClass(Class cls)
{
  if (cls == 0)
    return 0;
  return class_get_class_name(cls);
}

/**
 * Return the name of the object's class, or a nul pointer if no object
 * was supplied.
 */
GS_STATIC_INLINE const char *
GSClassNameFromObject(id obj)
{
  if (obj == 0)
    return 0;
  return object_get_class_name(obj);
}

/**
 * Return the name of the supplied selector, or a nul pointer if no selector
 * was supplied.
 */
GS_STATIC_INLINE const char *
GSNameFromSelector(SEL sel)
{
  if (sel == 0)
    return 0;
  return sel_get_name(sel);
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
      return sel_get_uid(name);
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
      SEL s;

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
GS_STATIC_INLINE const char *
GSTypesFromSelector(SEL sel)
{
  if (sel == 0)
    return 0;
  return sel_get_type(sel);
}

/**
 * Compare only the type information ignoring qualifiers, the frame layout
 * and register markers.  Unlike sel_types_match, this function also
 * handles comparisons of types with and without any layout information.
 */
GS_EXPORT BOOL
GSSelectorTypesMatch(const char *types1, const char *types2);

/**
 * Returns a protocol object with the corresponding name.
 * This function searches the registered classes for any protocol
 * with the supplied name.  If one is found, it is cached in
 * for future requests.  If efficiency is a factor then use
 * GSRegisterProtocol() to insert a protocol explicitly into the cache
 * used by this function.  If no protocol is found this function returns
 * nil.
 */
GS_EXPORT Protocol *
GSProtocolFromName(const char *name);

/**
 * Registers proto in the cache used by GSProtocolFromName().
 */
GS_EXPORT void
GSRegisterProtocol(Protocol *proto);


/*
 * Unfortunately the definition of the symbols
 * 'Method(_t)', 'MethodList(_t)'  and 'IVar(_t)'
 * are incompatible between the GNU and NeXT/Apple runtimes.
 * We introduce GSMethod, GSMethodList and GSIVar to allow portability.
 */
typedef struct objc_method      *GSMethod;
typedef struct objc_method_list *GSMethodList;
typedef struct objc_ivar        *GSIVar;

/**
 * Returns the pointer to the method structure
 * for the selector in the specified class.
 * Depending on searchInstanceMethods, this function searches
 * either instance or class methods.
 * Depending on searchSuperClassesm this function searches
 * either the specified class only or also its superclasses.<br/>
 * To obtain the implementation pointer IMP use returnValue->method_imp
 * which should be safe across all runtimes.<br/>
 * It should be safe to use this function in +load implementations.<br/>
 * This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.
 */
GS_EXPORT GSMethod
GSGetMethod(Class cls, SEL sel,
	    BOOL searchInstanceMethods,
	    BOOL searchSuperClasses);

/**
 * Flushes the cached method dispatch table for the class.
 * Call this function after any manipulations in the method structures.<br/>
 * It should be safe to use this function in +load implementations.<br/>
 * This function should currently (June 2003) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.
 */
GS_STATIC_INLINE void
GSFlushMethodCacheForClass (Class cls)
{
  extern void __objc_update_dispatch_table_for_class (Class);
  __objc_update_dispatch_table_for_class (cls);
}

/**
 * Returns the pointer to the instance variable structure
 * for the instance variable name in the specified class.
 * This function searches the specified class and its superclasses.<br/>
 * It should be safe to use this function in +load implementations.<br/>
 * This function should currently (June 2003) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.
 */
GS_EXPORT GSIVar
GSCGetInstanceVariableDefinition(Class cls, const char *name);

/**
 * Returns the pointer to the instance variable structure
 * for the instance variable name in the specified class.
 * This function searches the specified class and its superclasses.<br/>
 * It is not necessarily safe to use this function
 * in +load implementations.<br/>
 * This function should currently (June 2003) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.
 */
GS_EXPORT GSIVar
GSObjCGetInstanceVariableDefinition(Class cls, NSString *name);

/**
 * <p>Returns a pointer to objc_malloc'ed memory large enough
 * to hold a struct objc_method_list with 'count' number of
 * struct objc_method entries.  The memory returned is
 * initialized with 0, including the method count and
 * next method list fields.  </p>
 * <p> This function is intended for use in conjunction with
 * GSAppendMethodToList() to fill the memory and GSAddMethodList()
 * to activate the method list.  </p>
 * <p>After method list manipulation you should call
 * GSFlushMethodCacheForClass() for the changes to take effect.</p>
 * <p><em>WARNING:</em> Manipulating the runtime structures
 * can be hazardous!</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
GSMethodList
GSAllocMethodList (unsigned int count);

/**
 * <p>Inserts the method described by sel, types and imp
 * into the slot of the list's method_count incremented by 1.
 * This function does not and cannot check whether
 * the list provided has the necessary capacity.</p>
 * <p>The GNU runtime makes a difference between method lists
 * that are "free standing" and those that "attached" to classes.
 * For "free standing" method lists (e.g. created with GSAllocMethodList()
 * that have not been added to a class or those which have been removed
 * via GSRemoveMethodList()) isFree must be passed YES.
 * When manipulating "attached" method lists, specify NO.</p>
 * <p>This function is intended for use in conjunction with
 * GSAllocMethodList() to allocate the list and GSAddMethodList()
 * to activate the method list. </p>
 * <p>After method list manipulation you should call
 * GSFlushMethodCacheForClass() for the changes to take effect.</p>
 * <p><em>WARNING:</em> Manipulating the runtime structures
 * can be hazardous!</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
void
GSAppendMethodToList (GSMethodList list,
		      SEL sel,
		      const char *types,
		      IMP imp,
		      BOOL isFree);

/**
 * <p>Removes the method identified by sel
 * from the method list moving the following methods up in the list,
 * leaving the last entry blank.  After this call, all references
 * of previous GSMethodFromList() calls with this list should be
 * considered invalid.  If the values they referenced are needed, they
 * must be copied to external buffers before this function is called.</p>
 * <p>Returns YES if the a matching method was found a removed,
 * NO otherwise.</p>
 * <p>The GNU runtime makes a difference between method lists
 * that are "free standing" and those that "attached" to classes.
 * For "free standing" method lists (e.g. created with GSAllocMethodList()
 * that have not been added to a class or those which have been removed
 * via GSRemoveMethodList()) isFree must be passed YES.
 * When manipulating "attached" method lists, specify NO.</p>
 * <p>After method list manipulation you should call
 * GSFlushMethodCacheForClass() for the changes to take effect.</p>
 * <p><em>WARNING:</em> Manipulating the runtime structures
 * can be hazardous!</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
BOOL
GSRemoveMethodFromList (GSMethodList list,
			SEL sel,
			BOOL isFree);

/**
 * <p>Returns a method list of the class that contains the selector.
 * Depending on searchInstanceMethods either instance or class methods
 * are searched.
 * Returns NULL if none are found.
 * This function does not search the superclasses method lists.
 * Call this method with the address of a <code>void *</code>
 * pointing to NULL to obtain the first (active) method list
 * containing the selector.
 * Subsequent calls will return further method lists which contain the
 * selector.  If none are found, it returns NULL.
 * You may instead pass NULL as the iterator in which case the first
 * method list containing the selector will be returned.
 * Do not call it with an uninitialized iterator.
 * If either class or selector are NULL the function returns NULL.
 * If subsequent calls to this function with the same non-NULL iterator yet
 * different searchInstanceMethods value are called, the behavior
 * is undefined.</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
GSMethodList
GSMethodListForSelector(Class cls,
			SEL selector,
			void **iterator,
			BOOL searchInstanceMethods);

/**
 * <p>Returns the (first) GSMethod contained in the supplied list
 * that corresponds to sel.
 * Returns NULL if none is found.</p>
 * <p>The GNU runtime makes a difference between method lists
 * that are "free standing" and those that "attached" to classes.
 * For "free standing" method lists (e.g. created with GSAllocMethodList()
 * that have not been added to a class or those which have been removed
 * via GSRemoveMethodList()) isFree must be passed YES.
 * When manipulating "attached" method lists, specify NO.</p>
 */
GSMethod
GSMethodFromList(GSMethodList list,
		 SEL sel,
		 BOOL isFree);

/**
 * <p>Add the method list to the class as the first list to be
 * searched during method invocation for the given class.
 * Depending on toInstanceMethods, this list will be added as 
 * an instance or a class method list.
 * If the list is in use by another class, behavior is undefined.
 * Create a new list with GSAllocMethodList() or use GSRemoveMethodList()
 * to remove a list before inserting it in a class.</p>
 * <p>After method list manipulation you should call
 * GSFlushMethodCacheForClass() for the changes to take effect.</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
void
GSAddMethodList(Class cls,
		GSMethodList list,
		BOOL toInstanceMethods);

/**
 * <p>Removes the method list from the classes instance or class method
 * lists depending on fromInstanceMethods.
 * If the list is not part of the class, behavior is undefined.</p>
 * <p>After method list manipulation you should call
 * GSFlushMethodCacheForClass() for the changes to take effect.</p>
 * <p>This function should currently (June 2004) be considered WIP.
 * Please follow potential changes (Name, parameters, ...) closely until
 * it stabilizes.</p>
 */
void
GSRemoveMethodList(Class cls,
		   GSMethodList list,
		   BOOL fromInstanceMethods);


/**
 * Returns the version number of this.
 */
GS_STATIC_INLINE int
GSObjCVersion(Class cls)
{
  return class_get_version(cls);
}

#ifndef NeXT_Foundation_LIBRARY
#include	<Foundation/NSZone.h>
#else
#include <Foundation/Foundation.h>
#endif

/**
 * Return the zone in which an object belongs, without using the zone method
 */
GS_EXPORT NSZone *
GSObjCZone(NSObject *obj);

/**
 * Quickly return autoreleased data storage area.
 */
GS_EXPORT void *
GSAutoreleasedBuffer(unsigned size);

/**
 * <p>Prints a message to fptr using the format string provided and any
 * additional arguments.  The format string is interpreted as by
 * the NSString formatted initialisers, and understands the '%@' syntax
 * for printing an object.
 * </p>
 * <p>The data is written to the file pointer in the default CString
 * encoding if possible, as a UTF8 string otherwise.
 * </p>
 * <p>This function is recommended for printing general log messages.
 * For debug messages use NSDebugLog() and friends.  For error logging
 * use NSLog(), and for warnings you might consider NSWarnLog().
 * </p>
 */
GS_EXPORT BOOL
GSPrintf (FILE *fptr, NSString *format, ...);



GS_EXPORT NSArray *
GSObjCAllSubclassesOfClass(Class cls);

GS_EXPORT NSArray *
GSObjCDirectSubclassesOfClass(Class cls);

#if GS_API_VERSION(GS_API_ANY,011500)

GS_EXPORT const char *
GSLastErrorStr(long error_id) GS_ATTRIB_DEPRECATED;

#endif



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


#endif /* NO_GNUSTEP */

#ifdef __cplusplus
}
#endif

#endif /* __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */
