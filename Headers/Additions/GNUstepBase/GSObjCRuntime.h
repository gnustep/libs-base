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
#include <GNUstepBase/GSConfig.h>

#include <stdio.h>
#include <objc/objc.h>
#include <objc/objc-api.h>

#if	OBJC2RUNTIME
/* We have a real ObjC2 runtime.
 */
#include <objc/runtime.h>
#else
/* We emulate an ObjC2 runtime.
 */
#include <ObjectiveC2/runtime.h>
#endif

#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
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

#if	!defined(_C_CONST)
#define _C_CONST        'r'
#endif
#if	!defined(_C_IN)
#define _C_IN           'n'
#endif
#if	!defined(_C_INOUT)
#define _C_INOUT        'N'
#endif
#if	!defined(_C_OUT)
#define _C_OUT          'o'
#endif
#if	!defined(_C_BYCOPY)
#define _C_BYCOPY       'O'
#endif
#if	!defined(_C_BYREF)
#define _C_BYREF        'R'
#endif
#if	!defined(_C_ONEWAY)
#define _C_ONEWAY       'V'
#endif
#if	!defined(_C_GCINVISIBLE)
#define _C_GCINVISIBLE  '!'
#endif

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
GSObjCMethodNames(id obj, BOOL recurse);

GS_EXPORT NSArray *
GSObjCVariableNames(id obj, BOOL recurse);

/**
 * <p>A Behavior can be seen as a "Protocol with an implementation" or a
 * "Class without any instance variables".  A key feature of behaviors
 * is that they give a degree of multiple inheritance.
 * </p>
 * <p>Behavior methods, when added to a class, override the class's
 * superclass methods, but not the class's methods.
 * </p>
 * <p>Whan a behavior class is added to a receiver class, not only are the
 * methods defined in the behavior class added, but the methods from the
 * behavior's class hierarchy are also added (unless already present).
 * </p>
 * <p>It's not the case that a class adding behaviors from another class
 * must have "no instance vars".  The receiver class just has to have the
 * same layout as the behavior class (optionally with some additional
 * ivars after those of the behavior class).
 * </p>
 * <p>This function provides Behaviors without adding any new syntax to
 * the Objective C language.  Simply define a class with the methods you
 * want to add, then call this function with that class as the behavior
 * argument.
 * </p>
 * <p>This function should be called in the +initialize method of the receiver.
 * </p>
 * <p>If you add several behaviors to a class, be aware that the order of
 * the additions is significant.
 * </p>
 */
GS_EXPORT void
GSObjCAddClassBehavior(Class receiver, Class behavior);

/**
 * <p>An Override can be seen as a "category implemented as a separate class
 * and manually added to the receiver class under program control, rather
 * than automatically added by the compiler/runtime.
 * </p>
 * <p>Override methods, when added to a receiver class, replace the class's
 * class's methods of the same name (or are added if the class did not define
 * methods with that name).
 * </p>
 * <p>It's not the case that a class adding overrides from another class
 * must have "no instance vars".  The receiver class just has to have the
 * same layout as the override class (optionally with some additional
 * ivars after those of the override class).
 * </p>
 * <p>This function provides overrides without adding any new syntax to
 * the Objective C language.  Simply define a class with the methods you
 * want to add, then call this function with that class as the override
 * argument.
 * </p>
 * <p>This function should usually be called in the +initialize method
 * of the receiver.
 * </p>
 * <p>If you add several overrides to a class, be aware that the order of
 * the additions is significant.
 * </p>
 */
GS_EXPORT void
GSObjCAddClassOverride(Class receiver, Class override);

GS_EXPORT NSValue *
GSObjCMakeClass(NSString *name, NSString *superName, NSDictionary *iVars);

GS_EXPORT void
GSObjCAddClasses(NSArray *classes);

/**
 * Given a NULL terminated list of methods, add them to the class.<br />
 * If the method already exists in a superclass, the new version overrides
 * that one, but if the method already exists in the class itsself, the
 * new one is quietly ignored (replace==NO) or replaced with the new
 * version (if replace==YES).<br />
 * To add class methods, cls should be the metaclass of the class to
 * which the methods are being added.
 */
GS_EXPORT void
GSObjCAddMethods(Class cls, Method *list, BOOL replace);

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

/**
 * Deprecated ... use objc_getClassList()
 */
GS_EXPORT unsigned int
GSClassList(Class *buffer, unsigned int max, BOOL clearCache);

/**
 * GSObjCClass() is deprecated ... use object_getClass()
 */
GS_EXPORT Class GSObjCClass(id obj);

/**
 * GSObjCSuper() is deprecated ... use class_getSuperclass()
 */
GS_EXPORT Class GSObjCSuper(Class cls);

/**
 * GSObjCIsInstance() is deprecated ... use object_getClass()
 * in conjunction with class_isMetaClass()
 */
GS_EXPORT BOOL GSObjCIsInstance(id obj);

/**
 * GSObjCIsClass() is deprecated ... use object_getClass()
 * in conjunction with class_isMetaClass()
 */
GS_EXPORT BOOL GSObjCIsClass(Class cls);

/**
 * Test to see if class inherits from another class
 * The argument to this function must NOT be nil.
 */
GS_EXPORT BOOL GSObjCIsKindOf(Class cls, Class other);

/**
 * GSClassFromName() is deprecated ... use objc_lookUpClass()
 */
GS_EXPORT Class GSClassFromName(const char *name);

/**
 * GSNameFromClass() is deprecated ... use class_getName()
 */
GS_EXPORT const char *GSNameFromClass(Class cls);

/**
 * GSClassNameFromObject() is deprecated ... use object_getClass()
 * in conjunction with class_getName()
 */
GS_EXPORT const char *GSClassNameFromObject(id obj);

/**
 * GSNameFromSelector() is deprecated ... use sel_getName()
 */
GS_EXPORT const char *GSNameFromSelector(SEL sel);

/**
 * GSSelectorFromName() is deprecated ... use sel_getUid()
 */
GS_EXPORT SEL
GSSelectorFromName(const char *name);

/**
 * Return the selector for the specified name and types.  Returns a nul
 * pointer if the name is nul.  Uses any available selector if the types
 * argument is nul. <br />
 * Creates a new selector if necessary.
 */
GS_EXPORT SEL
GSSelectorFromNameAndTypes(const char *name, const char *types);

/**
 * Return the type information from the specified selector.
 * May return a nul pointer if the selector was a nul pointer or if it
 * was not typed.
 */
GS_EXPORT const char *
GSTypesFromSelector(SEL sel);

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
typedef Method	GSMethod;
typedef Ivar	GSIVar;

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
 * Deprecated .. does nothing.
 */
GS_EXPORT void
GSFlushMethodCacheForClass (Class cls);

/**
 * Deprecated .. use class_getInstanceVariable()
 */
GS_EXPORT GSIVar
GSCGetInstanceVariableDefinition(Class cls, const char *name);

/**
 * Deprecated .. use class_getInstanceVariable()
 */
GS_EXPORT GSIVar
GSObjCGetInstanceVariableDefinition(Class cls, NSString *name);

/**
 * GSObjCVersion() is deprecated ... use class_getVersion()
 */
GS_EXPORT int GSObjCVersion(Class cls);

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


#ifdef __cplusplus
}
#endif

#endif /* __GSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */
