/* Behaviors for Objective-C, "for Protocols with implementations".
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

   This file is part of the GNU Objective C Class Library.

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

/* A Behavior can be seen as a "Protocol with an implementation" or a
   "Class without any instance variables".  A key feature of behaviors
   is that they give a degree of multiple inheritance.

   Behavior methods override the class's superclass methods, but not 
   the class's methods.

   xxx not necessarily on the "no instance vars".  The behavior just has 
   to have the same layout as the class.

   The following function is a sneaky hack way that provides Behaviors
   without adding any new syntax to the Objective C language.  Simply
   define a class with the methods you want in the behavior, then call
   this function with that class as the BEHAVIOR argument.

   This function should be called in CLASS's +initialize method.

   If you add several behaviors to a class, be aware that the order of 
   the additions is significant.

   McCallum talking to himself:
   "Yipes.  Be careful with [super ...] calls.
   BEHAVIOR methods running in CLASS will now have a different super class.
   No; wrong.  See objc-api.h; typedef struct objc_super."

   */

#include <objc/objc.h>
#include <objc/objc-api.h>
#include <objc/sarray.h>
#include <objects/objc-malloc.h>
#include <assert.h>

static int behavior_debug = 0;

static Method_t search_for_method_in_list (MethodList_t list, SEL op);
static void __objc_send_initialize(Class class);
#if 0
static void __objc_init_protocols (struct objc_protocol_list* protos);
static void __objc_class_add_protocols (Class class,
                                        struct objc_protocol_list* protos);
#endif
static BOOL class_is_kind_of(Class self, Class class);
static void check_class_methods(Class class);

void class_add_methods_if_not_there(Class class, Class behavior);

/* The uninstalled dispatch table, declared in gcc/objc/sendmsg.c. */
extern struct sarray* __objc_uninstalled_dtable;

/* xxx consider using sendmsg.c:__objc_update_dispatch_table_for_class,
   but, I think it will be slower than the current method. */

void
set_behavior_debug(int i)
{
  behavior_debug = i;
}

void
class_add_behavior (Class class, Class behavior)
{
  Class behavior_super_class = class_get_super_class(behavior);

  assert(CLS_ISCLASS(class));
  assert(CLS_ISCLASS(behavior));

  __objc_send_initialize(class);
  __objc_send_initialize(behavior);

#if 0
  /* xxx Do protocols */
  if (behavior->protocols)
    {
      /* xxx Make sure they are not already there before adding. */
      __objc_init_protocols (behavior->protocols);
      __objc_class_add_protocols (class, behavior->protocols);
    }
#endif

  /* Add instance methods */
  if (behavior_debug)
    {
      fprintf(stderr, "Adding instance methods from %s\n",
	      behavior->name);
    }
  class_add_methods_if_not_there(class, behavior);

  /* Add class methods */
  if (behavior_debug)
    {
      fprintf(stderr, "Adding class methods from %s\n",
	      behavior->class_pointer->name);
    }
  class_add_methods_if_not_there(class->class_pointer, 
				 behavior->class_pointer);

  /* Add behavior's superclass, if not already there. */
  {
    if (!class_is_kind_of(class, behavior_super_class))
      class_add_behavior(class, behavior_super_class);
  }

  return;
}

void
class_add_methods_if_not_there(Class class, Class behavior)
{
  static SEL initialize_sel = 0;
  MethodList_t mlist;

  if (!initialize_sel)
    initialize_sel = sel_register_name ("initialize");

  /* Add methods to class->dtable and class->methods */
  for (mlist = behavior->methods; mlist; mlist = mlist->method_next)
    {
      int counter;
      MethodList_t new_list;

      counter = mlist->method_count - 1;

      /* xxx This is a little wasteful of memory, since not necessarily 
	 all methods will go in here. */
      new_list = (MethodList_t)
	(*objc_malloc)
	  (sizeof(MethodList) + sizeof(struct objc_method[counter+1]));
      new_list->method_count = 0;

      while (counter >= 0)
        {
          Method_t method = &(mlist->method_list[counter]);

	  if (behavior_debug)
	    fprintf(stderr, "   processing method [%s]\n", 
		    sel_get_name(method->method_name));

	  if (!search_for_method_in_list(class->methods, method->method_name)
	      && method->method_name->sel_id != initialize_sel->sel_id)
	    {
	      /* As long as the method isn't defined in the CLASS,
		 put the BEHAVIOR method in there.  Thus, behavior
		 methods override the superclasses' methods. */

	      /* If dtable is already installed, go ahead and put it in 
		 the dtable sarray, but if it isn't, let 
		 __objc_install_dispatch_table_for_class do it. */

	      if (class->dtable != __objc_uninstalled_dtable)
		{
		  sarray_at_put_safe (class->dtable,
				      (sidx) method->method_name->sel_id,
				      method->method_imp);
		  if (behavior_debug)
		    fprintf(stderr, "\tinstalled method\n");
		}
	      else
		{
		  if (behavior_debug)
		    fprintf(stderr, "\tappended method\n");
		}
	      new_list->method_list[new_list->method_count] = *method;
	      (new_list->method_count)++;
	    }
          counter -= 1;
        }
      if (new_list->method_count)
	{
	  new_list->method_next = class->methods;
	  class->methods = new_list;
	}
      else
	{
	  OBJC_FREE(new_list);
	}
    }
}

/* Should implement this too:
class_add_behavior_category(), 
and perhaps something like:
class_add_methods_if_not_there_or_inherited() */

#if 0
/* This is like class_add_method_list(), except is doesn't balk at 
   duplicates; it simply ignores them.  Thus, a method implemented 
   in CLASS overrides a method implemented in BEHAVIOR. */

void
class_add_behavior_method_list (Class class, MethodList_t list)
{
  int i;
  static SEL initialize_sel = 0;
  if (!initialize_sel)
    initialize_sel = sel_register_name ("initialize");

  /* Passing of a linked list is not allowed.  Do multiple calls.  */
  assert (!list->method_next);

  /* Check for duplicates.  */
  for (i = 0; i < list->method_count; ++i)
    {
      Method_t method = &list->method_list[i];

      if (method->method_name)  /* Sometimes these are NULL */
	{
	  if (search_for_method_in_list (class->methods, method->method_name)
	      && method->method_name->sel_id != initialize_sel->sel_id)
	    {
	      /* Duplication. Print a error message an change the method name
		 to NULL. */
	      fprintf (stderr, "attempt to add a existing method: %s\n",
		       sel_get_name(method->method_name));
	      method->method_name = 0;
	    }
	  else
	    {
	      /* Behavior method not implemented in class.  Add it. */
	      sarray_at_put_safe (class->dtable,
				  (sidx) method->method_name->sel_id,
				  method->method_imp);
	    }
	}
    }

  /* Add the methods to the class's method list.  */
  list->method_next = class->methods;
  class->methods = list;
}
#endif

/* Given a linked list of method and a method's name.  Search for the named
   method's method structure.  Return a pointer to the method's method
   structure if found.  NULL otherwise. */
static Method_t
search_for_method_in_list (MethodList_t list, SEL op)
{
  MethodList_t method_list = list;

  if (! sel_is_mapped (op))
    return NULL;

  /* If not found then we'll search the list.  */
  while (method_list)
    {
      int i;

      /* Search the method list.  */
      for (i = 0; i < method_list->method_count; ++i)
        {
          Method_t method = &method_list->method_list[i];

          if (method->method_name)
            if (method->method_name->sel_id == op->sel_id)
              return method;
        }

      /* The method wasn't found.  Follow the link to the next list of
         methods.  */
      method_list = method_list->method_next;
    }

  return NULL;
}

/* Send +initialize to class if not already done */
static void __objc_send_initialize(Class class)
{
  /* This *must* be a class object */
  assert(CLS_ISCLASS(class));
  assert(!CLS_ISMETA(class));

  if (!CLS_ISINITIALIZED(class))
    {
      CLS_SETINITIALIZED(class);
      CLS_SETINITIALIZED(class->class_pointer);

      if(class->super_class)
        __objc_send_initialize(class->super_class);

      {
        MethodList_t method_list = class->class_pointer->methods;
        SEL op = sel_register_name ("initialize");

        /* If not found then we'll search the list.  */
        while (method_list)
          {
            int i;

            /* Search the method list.  */
            for (i = 0; i < method_list->method_count; ++i)
              {
                Method_t method = &method_list->method_list[i];


                if (method->method_name->sel_id == op->sel_id)
                  (*method->method_imp)((id) class, op);
              }

            /* The method wasn't found.  Follow the link to the next list of
               methods.  */
            method_list = method_list->method_next;
          }
      }
    }
}

#if 0
static void
__objc_init_protocols (struct objc_protocol_list* protos)
{
  int i;
  static Class proto_class = 0;

  if (! protos)
    return;

  if (!proto_class)
    proto_class = objc_lookup_class("Protocol");

  if (!proto_class)
    {
      unclaimed_proto_list = list_cons (protos, unclaimed_proto_list);
      return;
    }

#if 0
  assert (protos->next == 0);   /* only single ones allowed */
#endif

  for(i = 0; i < protos->count; i++)
    {
      struct objc_protocol* aProto = protos->list[i];
      if (((size_t)aProto->class_pointer) == PROTOCOL_VERSION)
        {
          /* assign class pointer */
          aProto->class_pointer = proto_class;

          /* init super protocols */
          __objc_init_protocols (aProto->protocol_list);
        }
      else if (protos->list[i]->class_pointer != proto_class)
        {
          fprintf (stderr,
                   "Version %d doesn't match runtime protocol version %d\n",
                   (int)((char*)protos->list[i]->class_pointer-(char*)0),
                   PROTOCOL_VERSION);
          abort ();
        }
    }
}

static void __objc_class_add_protocols (Class class,
                                        struct objc_protocol_list* protos)
{
  /* Well... */
  if (! protos)
    return;

  /* Add it... */
  protos->next = class->protocols;
  class->protocols = protos;
}
#endif /* 0 */

static BOOL class_is_kind_of(Class self, Class aClassObject)
{
  Class class;

  for (class = self; class!=Nil; class = class_get_super_class(class))
    if (class==aClassObject)
      return YES;
  return NO;
}

void
check_class_methods(Class class)
{
  int counter;
  MethodList_t mlist;

  if (class->dtable == __objc_uninstalled_dtable)
    return;

  for (mlist = class->methods; mlist; mlist = mlist->method_next)
    {
      counter = mlist->method_count - 1;
      while (counter >= 0)
        {
          Method_t method = &(mlist->method_list[counter]);
	  IMP imp = sarray_get(class->dtable, 
			       (size_t)method->method_name->sel_id);
	  assert((imp == method->method_imp));
	  sarray_at_put_safe (class->dtable,
			      (sidx) method->method_name->sel_id,
			      method->method_imp);
          counter -= 1;
        }
    }
  if (class->super_class)
    check_class_methods(class->super_class);

  (void) &check_class_methods;	/* to prevent compiler warning about unused */
}

