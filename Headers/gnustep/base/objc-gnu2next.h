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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

/* This file is by no means complete. */

#ifndef __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE
#define __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

#if NeXT_runtime

#include <objc/objc-class.h>

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

#if 1
volatile void objc_fatal(const char* msg);
#else
#define objc_fatal(FMT, args...) \
 do { fprintf (stderr, (FMT), ##args); abort(); } while (0)
#endif

#define OBJC_READONLY 1
#define OBJC_WRITEONLY 2


/* Methods defined by the GNU runtime, which libobjects will provide
   if the GNU runtime isn't being used. */

int objc_sizeof_type(const char* type);
int objc_alignof_type(const char* type);
int objc_aligned_size (const char* type);
int objc_promoted_size (const char* type);
inline const char* objc_skip_type_qualifiers (const char* type);
const char* objc_skip_typespec (const char* type);
inline const char* objc_skip_offset (const char* type);
const char* objc_skip_argspec (const char* type);
unsigned objc_get_type_qualifiers (const char* type);

/* The following from GNU's objc/objc-api.h */

/* For functions which return Method_t */
#define METHOD_NULL	(Method_t)0

static inline BOOL
class_is_class(Class* class)
{
  return CLS_ISCLASS(class);
}

static inline BOOL
class_is_meta_class(Class* class)
{
  return CLS_ISMETA(class);
}

static inline BOOL
object_is_class(id object)
{
  return CLS_ISCLASS((Class*)object);
}

static inline BOOL
object_is_instance(id object)
{
  return (object!=nil)&&CLS_ISCLASS(object_get_class(object));
}

static inline BOOL
object_is_meta_class(id object)
{
  return CLS_ISMETA((Class*)object);
}


/* The following from GNU's objc/list.h */

#include <stdio.h>
#include <gnustep/base/objc-malloc.h>

struct objc_list {
  void *head;
  struct objc_list *tail;
};

/* Return a cons cell produced from (head . tail) */

static inline struct objc_list* 
list_cons(void* head, struct objc_list* tail)
{
  struct objc_list* cell;

  cell = (struct objc_list*)(*objc_malloc)(sizeof(struct objc_list));
  cell->head = head;
  cell->tail = tail;
  return cell;
}

/* Return the length of a list, list_length(NULL) returns zero */

static inline int
list_length(struct objc_list* list)
{
  int i = 0;
  while(list)
    {
      i += 1;
      list = list->tail;
    }
  return i;
}

/* Return the Nth element of LIST, where N count from zero.  If N 
   larger than the list length, NULL is returned  */

static inline void*
list_nth(int index, struct objc_list* list)
{
  while(index-- != 0)
    {
      if(list->tail)
	list = list->tail;
      else
	return 0;
    }
  return list->head;
}

/* Remove the element at the head by replacing it by its successor */

static inline void
list_remove_head(struct objc_list** list)
{
  if ((*list)->tail)
    {
      struct objc_list* tail = (*list)->tail; /* fetch next */
      *(*list) = *tail;/* copy next to list head */
      (*objc_free)(tail);/* free next */
    }
  else/* only one element in list */
    {
      (*objc_free)(*list);
      (*list) = 0;
    }
}


/* Remove the element with `car' set to ELEMENT */

static inline void
list_remove_elem(struct objc_list** list, void* elem)
{
  while (*list) {
    if ((*list)->head == elem)
      list_remove_head(list);
    list = &((*list)->tail);
  }
}

/* Map FUNCTION over all elements in LIST */

static inline void
list_mapcar(struct objc_list* list, void(*function)(void*))
{
  while(list)
    {
      (*function)(list->head);
      list = list->tail;
    }
}

/* Return element that has ELEM as car */

static inline struct objc_list**
list_find(struct objc_list** list, void* elem)
{
  while(*list)
    {
    if ((*list)->head == elem)
      return list;
    list = &((*list)->tail);
  }
  return NULL;
}

/* Free list (backwards recursive) */

static void
list_free(struct objc_list* list)
{
  if(list)
    {
      list_free(list->tail);
      (*objc_free)(list);
    }
}

#endif /* NeXT_runtime */

#endif /* __objc_gnu2next_h_GNUSTEP_BASE_INCLUDE */
