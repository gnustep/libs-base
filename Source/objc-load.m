/* objc-load - Dynamically load in Obj-C modules (Classes, Categories)

   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor, Pedja Bogdanovich
   
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

/*
    CAVEATS:
	- unloading modules not implemented
	- would like to raise exceptions without having to turn this into
	  a .m file (right now NSBundle does this for us, ok?)
    
*/

#include <config.h>

#ifdef HAVE_DLADDR
/* Define _GNU_SOURCE because that is required with GNU libc in order
 * to have dladdr() available.  */
# define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <objc/objc-api.h>
#ifndef NeXT_RUNTIME
# include <objc/objc-list.h>
#else
# include <objc/objc-load.h>
#endif

#include <Foundation/objc-load.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>

/* include the interface to the dynamic linker */
#include "dynamic-load.h"

/* From the objc runtime -- needed when invalidating the dtable */
#ifndef NeXT_RUNTIME
extern void __objc_install_premature_dtable(Class);
extern void sarray_free(struct sarray*);
#ifndef HAVE_OBJC_GET_UNINSTALLED_DTABLE
#ifndef objc_EXPORT
#define objc_EXPORT export
#endif
objc_EXPORT void *__objc_uninstalled_dtable;
static void *
objc_get_uninstalled_dtable()
{
  return __objc_uninstalled_dtable;
}
#endif
#endif /* ! NeXT */

/* Declaration from NSBundle.m */
const char *objc_executable_location (void);

/* dynamic_loaded is YES if the dynamic loader was sucessfully initialized. */
static BOOL	dynamic_loaded;

/* Our current callback function */
void (*_objc_load_load_callback)(Class, struct objc_category *) = 0;

/* List of modules we have loaded (by handle) */
#ifndef NeXT_RUNTIME
static struct objc_list *dynamic_handles = NULL;
#endif

/* Check to see if there are any undefined symbols. Print them out.
*/
static int
objc_check_undefineds(FILE *errorStream)
{
  int count = __objc_dynamic_undefined_symbol_count();
  
  if (count != 0) 
    {
      int  i;
      char **undefs;

      undefs = __objc_dynamic_list_undefined_symbols();
      if (errorStream)
	{
	  fprintf(errorStream, "Undefined symbols:\n");
	}
      for (i = 0; i < count; i++)
	{
	  if (errorStream)
	    {
	      fprintf(errorStream, "  %s\n", undefs[i]);
	    }
	}
      return 1;
    }
  return 0;
}

/* Invalidate the dtable so it will be rebuild when a message is sent to
   the object */
static void
objc_invalidate_dtable(Class class)
{
#ifndef NeXT_RUNTIME
  Class s;
  
  if (class->dtable == objc_get_uninstalled_dtable()) 
    {
      return;
    }
  
  sarray_free(class->dtable);
  __objc_install_premature_dtable(class);
  for (s = class->subclass_list; s; s = s->sibling_class) 
    {
      objc_invalidate_dtable(s);
    }
#endif
}

/* Initialize for dynamic loading */
static int 
objc_initialize_loading(FILE *errorStream)
{
  const char *path;
  
  dynamic_loaded = NO;
  path   = objc_executable_location();
  
  NSDebugFLLog(@"NSBundle", 
	       @"Debug (objc-load): initializing dynamic loader for %s", 
	       path);
  
  if (__objc_dynamic_init(path)) 
    {
      if (errorStream)
	{
	  __objc_dynamic_error(errorStream, 
			       "Error (objc-load): Cannot initialize dynamic linker");
	}
      return 1;
    } 
  else
    {
      dynamic_loaded = YES;
    }
  
  return 0;
}

/* A callback received from the Object initializer (_objc_exec_class).
   Do what we need to do and call our own callback.
*/
static void 
objc_load_callback(Class class, struct objc_category * category)
{
  /* Invalidate the dtable, so it will be rebuilt correctly */
  if (class != 0 && category != 0) 
    {
      objc_invalidate_dtable(class);
      objc_invalidate_dtable(class->class_pointer);
    }

  if (_objc_load_load_callback)
    {
      _objc_load_load_callback(class, category);
    }
}

long
objc_load_module (const char *filename,
		  FILE *errorStream,
		  void (*loadCallback)(Class, struct objc_category *),
		  void **header,
		  char *debugFilename)
{
#ifdef NeXT_RUNTIME
  int errcode;
  dynamic_loaded = YES;
  return objc_loadModule(filename, loadCallback, &errcode);
#else
  typedef void (*void_fn)();
  dl_handle_t handle;
#if !defined(__ELF__) && !defined(CON_AUTOLOAD)
  void_fn *ctor_list;
  int i;
#endif
  
  if (!dynamic_loaded)
    {
      if (objc_initialize_loading(errorStream))
	{
	  return 1;
	}
    }
  
  _objc_load_load_callback = loadCallback;
  _objc_load_callback = objc_load_callback;
  
  /* Link in the object file */
  NSDebugFLLog(@"NSBundle",
	       @"Debug (objc-load): Linking file %s\n", filename);
  handle = __objc_dynamic_link(filename, 1, debugFilename);
  if (handle == 0) 
    {
      if (errorStream)
	{
	  __objc_dynamic_error(errorStream, "Error (objc-load)");
	}
      _objc_load_load_callback = 0;
      _objc_load_callback = 0;
      return 1;
    }
  dynamic_handles = list_cons(handle, dynamic_handles);
  
  /* If there are any undefined symbols, we can't load the bundle */
  if (objc_check_undefineds(errorStream)) 
    {
      __objc_dynamic_unlink(handle);
      _objc_load_load_callback = 0;
      _objc_load_callback = 0;
      return 1;
    }
  
#if !defined(__ELF__) && !defined(CON_AUTOLOAD)
  /* Get the constructor list and load in the objects */
  ctor_list = (void_fn *)__objc_dynamic_find_symbol(handle, CTOR_LIST);
  if (!ctor_list) 
    {
      if (errorStream)
	{
	  fprintf(errorStream, 
		  "Error (objc-load): Cannot load objects (no CTOR list)\n");
	}
      _objc_load_load_callback = 0;
      _objc_load_callback = 0;
      return 1;
    }
  
  NSDebugFLLog(@"NSBundle",
	       @"Debug (objc-load): %d modules\n", (int)ctor_list[0]);
  for (i = 1; ctor_list[i]; i++) 
    {
      NSDebugFLLog(@"NSBundle",
		   @"Debug (objc-load): Invoking CTOR %p\n", ctor_list[i]);
      ctor_list[i]();
    }
#endif /* not __ELF__ */
  
  _objc_load_callback = 0;
  _objc_load_load_callback = 0;
  return 0;
#endif
}

long 
objc_unload_module(FILE *errorStream,
		   void (*unloadCallback)(Class, struct objc_category *))
{
  if (!dynamic_loaded)
    {
      return 1;
    }
  
  if (errorStream)
    {
      fprintf(errorStream, "Warning: unloading modules not implemented\n");
    }
  return 0;
}

long objc_load_modules(char *files[],FILE *errorStream,
		       void (*callback)(Class,struct objc_category *),
		       void **header,
		       char *debugFilename)
{
    while (*files) 
      {
	if (objc_load_module(*files, errorStream, callback, 
			     (void *)header, debugFilename)) 
	  {
	    return 1;
	  }
	files++;
      }
    return 0;
}

long 
objc_unload_modules(FILE *errorStream,
		    void (*unloadCallback)(Class, struct objc_category *))
{
  if (!dynamic_loaded)
    {
      return 1;
    }
  
  if (errorStream)
    {
      fprintf(errorStream, "Warning: unloading modules not implemented\n");
    }
  
  return 0;
}

NSString *
objc_get_symbol_path(Class theClass, Category *theCategory)
{
  const char *ret;
  char        buf[125], *p = buf;
  int         len = strlen(theClass->name);
  
  if (theCategory == NULL)
    {
      if (len + sizeof(char)*19 > sizeof(buf))
	{
	  p = malloc(len + sizeof(char)*19);

	  if (p == NULL)
	    {
	      fprintf(stderr, "Unable to allocate memory !!");
	      return nil;
	    }
	}

      memcpy(p, "__objc_class_name_", sizeof(char)*18);
      memcpy(&p[18*sizeof(char)], theClass->name,
	     strlen(theClass->name) + 1);
    }
  else
    {
      len += strlen(theCategory->category_name);

      if (len + sizeof(char)*23 > sizeof(buf))
	{
	  p = malloc(len + sizeof(char)*23);

	  if (p == NULL)
	    {
	      fprintf(stderr, "Unable to allocate memory !!");
	      return nil;
	    }
	}

      memcpy(p, "__objc_category_name_", sizeof(char)*21);
      memcpy(&p[21*sizeof(char)], theCategory->class_name,
	     strlen(theCategory->class_name) + 1);
      memcpy(&p[strlen(p)], "_", 2*sizeof(char));
      memcpy(&p[strlen(p)], theCategory->category_name,
	     strlen(theCategory->category_name) + 1);
    }

  ret = __objc_dynamic_get_symbol_path(0, p);

  if (p != buf)
    {
      free(p);
    }
  
  if (ret)
    {
      return [NSString stringWithCString: ret];
    }
  
  return nil;
}
