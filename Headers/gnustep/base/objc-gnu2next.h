/* Definitions to allow compilation of GNU objc code with NeXT runtime
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

/* This file is by no means complete. */

#ifndef __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE
#define __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE

#if NeXT_RUNTIME

#include <objc/objc-class.h>
#include <objc/objc-runtime.h>
#include <stddef.h>
#include <ctype.h>
#include <stdio.h>

/* Disable builtin functions for gcc < 3.x since it triggers a bad bug (even some 3.x versions may have this
   bug) */
#if __GNUC__ < 3
#define __builtin_apply(a,b,c) 0
#define __builtin_apply_args() 0
#define __builtin_return(a)  0
#endif

typedef union {
  char *arg_ptr;
  char arg_regs[sizeof (char*)];
} *arglist_t;                   /* argument frame */
//#define arglist_t marg_list
#define retval_t void*
typedef void(*apply_t)(void);   /* function pointer */
#define TypedStream void*

#define METHOD_NULL  (struct objc_method *)0

#define class_pointer isa
typedef struct objc_super Super;

#define class_create_instance(CLASS)	class_createInstance(CLASS, 0)
#define class_get_instance_method	class_getInstanceMethod
#define class_get_class_method 		class_getClassMethod
#define class_add_method_list		class_addMethods
#define class_set_version		class_setVersion
#define class_get_version		class_getVersion
#define class_pose_as			class_poseAs
#define method_get_sizeof_arguments	method_getSizeOfArguments
#define objc_lookup_class		objc_lookUpClass
#define objc_get_class			objc_getClass

#define sel_register_name		sel_registerName
#define sel_is_mapped			sel_isMapped
#define sel_get_name			sel_getName
#define sel_get_any_uid			sel_getUid
#define sel_get_uid			sel_getUid
#define sel_eq(s1, s2) 			(s1 == s2)

/* There's no support for typed sels in NeXT. These may not work */
#define sel_get_typed_uid(_s, _t)	sel_getUid(_s)
#define sel_get_any_typed_uid		sel_getUid
#define sel_register_typed_name(_s, _t)	sel_registerName(_s)
#define sel_get_type(_s)		(NULL)

#define class_get_class_name(CLASSPOINTER) \
     (((struct objc_class*)(CLASSPOINTER))->name)
#define object_get_class(OBJECT) \
    (((struct objc_class*)(OBJECT))->isa)
#define class_get_super_class(CLASSPOINTER) \
    (((struct objc_class*)(CLASSPOINTER))->super_class)
#define object_get_super_class(OBJECT) \
    (((struct objc_class*)(object_get_class(OBJECT)))->super_class)
#define object_get_class_name(OBJECT) \
     (((struct objc_class*)(object_get_class(OBJECT)))->name)

#define __objc_responds_to(OBJECT,SEL) \
    (class_getInstanceMethod(object_get_class(OBJECT), SEL) != METHOD_NULL)
#define CLS_ISCLASS(CLASSPOINTER) \
    ((((struct objc_class*)(CLASSPOINTER))->info) & CLS_CLASS)
#define CLS_ISMETA(CLASSPOINTER) \
    ((((struct objc_class*)(CLASSPOINTER))->info) & CLS_META)
#define objc_msg_lookup(OBJ,SEL) \
    (class_getInstanceMethod(object_get_class(OBJ), SEL)->method_imp)
#define objc_msg_lookup_super(OBJ,SEL) \
    (class_getInstanceMethod(object_get_class(OBJ), SEL)->method_imp)

#define objc_msg_sendv                  next_objc_msg_sendv

extern id next_objc_msg_sendv(id self, SEL op, void* arg_frame);

#define OBJC_READONLY 1
#define OBJC_WRITEONLY 2

/*
** Standard functions for memory allocation and disposal.
** Users should use these functions in their ObjC programs so
** that they work properly with garbage collectors as well as
** can take advantage of the exception/error handling available.
*/
void *
objc_malloc(size_t size);

void *
objc_atomic_malloc(size_t size);

void *
objc_valloc(size_t size);

void *
objc_realloc(void *mem, size_t size);

void *
objc_calloc(size_t nelem, size_t size);

void
objc_free(void *mem);

static inline BOOL
class_is_class(Class class)
{
  return CLS_ISCLASS(class);
}

static inline BOOL
object_is_class(id object)
{
  return CLS_ISCLASS((Class)object);
}

static inline long
class_get_instance_size(Class class)
{
  return CLS_ISCLASS(class)?class->instance_size:0;
}

static inline IMP
method_get_imp(Method method)
{
  return (method!=0)?method->method_imp:(IMP)0;
}

static inline IMP
get_imp(Class class, SEL aSel)
{
  return method_get_imp(class_getInstanceMethod(class, aSel));
}

static inline BOOL
object_is_instance(id object)
{
  return (object!=nil)&&CLS_ISCLASS(object->class_pointer);
}

/*
** Hook functions for memory allocation and disposal.
** This makes it easy to substitute garbage collection systems
** such as Boehm's GC by assigning these function pointers
** to the GC's allocation routines.  By default these point
** to the ANSI standard malloc, realloc, free, etc.
**
** Users should call the normal objc routines above for
** memory allocation and disposal within their programs.
*/
extern void *(*_objc_malloc)(size_t);
extern void *(*_objc_atomic_malloc)(size_t);
extern void *(*_objc_valloc)(size_t);
extern void *(*_objc_realloc)(void *, size_t);
extern void *(*_objc_calloc)(size_t, size_t);
extern void (*_objc_free)(void *);

/* encoding functions */
extern int objc_sizeof_type(const char* type);
extern int objc_alignof_type(const char* type);
extern int objc_aligned_size (const char* type);
extern int objc_promoted_size (const char* type);
extern const char *objc_skip_type_qualifiers (const char* type);
extern const char *objc_skip_typespec (const char* type);
extern const char *objc_skip_argspec (const char* type);
extern unsigned objc_get_type_qualifiers (const char* type);
extern BOOL sel_types_match (const char* t1, const char* t2);

/* Error handling */
extern void objc_error(id object, int code, const char* fmt, ...);
extern void objc_verror(id object, int code, const char* fmt, va_list ap);
typedef BOOL (*objc_error_handler)(id, int code, const char *fmt, va_list ap);
objc_error_handler objc_set_error_handler(objc_error_handler func);

/*
** Error codes
** These are used by the runtime library, and your
** error handling may use them to determine if the error is
** hard or soft thus whether execution can continue or abort.
*/
#define OBJC_ERR_UNKNOWN 0             /* Generic error */

#define OBJC_ERR_OBJC_VERSION 1        /* Incorrect runtime version */
#define OBJC_ERR_GCC_VERSION 2         /* Incorrect compiler version */
#define OBJC_ERR_MODULE_SIZE 3         /* Bad module size */
#define OBJC_ERR_PROTOCOL_VERSION 4    /* Incorrect protocol version */

#define OBJC_ERR_MEMORY 10             /* Out of memory */

#define OBJC_ERR_RECURSE_ROOT 20       /* Attempt to archive the root
                                          object more than once. */
#define OBJC_ERR_BAD_DATA 21           /* Didn't read expected data */
#define OBJC_ERR_BAD_KEY 22            /* Bad key for object */
#define OBJC_ERR_BAD_CLASS 23          /* Unknown class */
#define OBJC_ERR_BAD_TYPE 24           /* Bad type specification */
#define OBJC_ERR_NO_READ 25            /* Cannot read stream */
#define OBJC_ERR_NO_WRITE 26           /* Cannot write stream */
#define OBJC_ERR_STREAM_VERSION 27     /* Incorrect stream version */
#define OBJC_ERR_BAD_OPCODE 28         /* Bad opcode */

#define OBJC_ERR_UNIMPLEMENTED 30      /* Method is not implemented */

#define OBJC_ERR_BAD_STATE 40          /* Bad thread state */
#endif /* NeXT_RUNTIME */

#endif /* __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE */
