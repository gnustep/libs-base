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
#include <stddef.h>

#define arglist_t marg_list
#define retval_t void*
#define TypedStream NXTypedStream

#define objc_write_type(STREAM, TYPE, VAR) \
     NXWriteType(STREAM, TYPE, VAR)
#define objc_write_types(STREAM, TYPE, args...) \
     NXWriteTypes(STREAM, TYPE, args)
#define objc_write_object(STREAM, VAR) \
     NXWriteObject(STREAM, VAR)
#define objc_write_object_reference(STREAM, VAR) \
     NXWriteObjectReference(STREAM, VAR)
#define objc_read_type(STREAM, TYPE, VAR) \
     NXReadType(STREAM, TYPE, VAR)
#define objc_read_types(STREAM, TYPE, args...) \
     NXReadTypes(STREAM, TYPE, args)
#define objc_read_object(STREAM, VAR) \
     do { (*(VAR)) = NXReadObject(STREAM); } while (0)
#define objc_write_root_object \
     NXWriteRootObject
#define objc_open_typed_stream_for_file \
    NXOpenTypedStreamForFile
#define objc_close_typed_stream NXCloseTypedStream

#define class_create_instance(CLASS) class_createInstance(CLASS, 0)
#define sel_get_name(ASEL) sel_getName(ASEL)
#define sel_get_uid(METHODNAME) sel_getUid(METHODNAME)

/* FIXME: Any equivalent for this ? */
#define sel_get_type(SELECTOR) \
     (NULL)
     
#define class_get_instance_method(CLASSPOINTER, SEL) \
     class_getInstanceMethod(CLASSPOINTER, SEL)
#define class_get_class_method(CLASSPOINTER, SEL) \
     class_getClassMethod(CLASSPOINTER, SEL)
#define class_get_class_name(CLASSPOINTER) \
     (((struct objc_class*)(CLASSPOINTER))->name)
#define method_get_sizeof_arguments(METHOD) \
     method_getSizeOfArguments(METHOD)
#define objc_lookup_class(CLASSNAME) \
     objc_lookUpClass(CLASSNAME)
#define sel_get_any_uid(SELNAME) \
     sel_getUid(SELNAME)
#define object_get_class(OBJECT) \
    (((struct objc_class*)(OBJECT))->isa)
#define class_get_super_class(CLASSPOINTER) \
    (((struct objc_class*)(CLASSPOINTER))->super_class)
#define objc_get_class(CLASSNAME) \
    objc_lookUpClass(CLASSNAME)	/* not exactly right */
#define class_get_version(CLASSPOINTER) \
    (((struct objc_class*)(CLASSPOINTER))->version)
#define __objc_responds_to(OBJECT,SEL) \
    class_getInstanceMethod(object_get_class(OBJECT), SEL)
#define CLS_ISCLASS(CLASSPOINTER) \
    ((((struct objc_class*)(CLASSPOINTER))->info) & CLS_CLASS)
#define CLS_ISMETA(CLASSPOINTER) \
    ((((struct objc_class*)(CLASSPOINTER))->info) & CLS_META)
#define objc_msg_lookup(OBJ,SEL) \
    (class_getInstanceMethod(object_get_class(OBJ), SEL)->method_imp)

#define OBJC_READONLY 1
#define OBJC_WRITEONLY 2

#endif /* NeXT_RUNTIME */

#endif /* __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE */
