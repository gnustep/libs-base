/* objc-load - Dynamically load in Obj-C modules (Classes, Categories)

   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor, Pedja Bogdanovich
   
   This file is part of the Gnustep Base Library.

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

/*
    CAVEATS:
	- unloading modules not implemented
	- would like to raise exceptions without having to turn this into
	  a .m file (right now NSBundle does this for us, ok?)
    
*/

#include <stdio.h>
#include <stdlib.h>
#include <objc/objc-api.h>
#include <objc/objc-list.h>
#include <Foundation/objc-load.h>

/* include the interface to the dynamic linker */
#include "dynamic-load.h"

/* From the objc runtime -- needed when invalidating the dtable */
extern void __objc_install_premature_dtable(Class);
extern void sarray_free(struct sarray*);
extern struct sarray *__objc_uninstalled_dtable;

/* Declaration from NSBundle.m */
const char *objc_executable_location( void );

/* This is the GNU name for the CTOR list */
#define CTOR_LIST       "___CTOR_LIST__"

/* dynamic_loaded is YES if the dynamic loader was sucessfully initialized. */
static BOOL	dynamic_loaded;

/* Our current callback function */
void (*_objc_load_load_callback)(Class, Category*) = 0;

/* List of modules we have loaded (by handle) */
static struct objc_list *dynamic_handles = NULL;

/* Check to see if there are any undefined symbols. Print them out.
*/
static int
objc_check_undefineds(FILE *errorStream)
{
    int count = __objc_dynamic_undefined_symbol_count();

    if (count != 0) {
        int  i;
        char **undefs;
        undefs = __objc_dynamic_list_undefined_symbols();
        if (errorStream)
	    fprintf(errorStream, "Undefined symbols:\n");
        for (i=0; i < count; i++)
            if (errorStream)
		fprintf(errorStream, "  %s\n", undefs[i]);
	return 1;
    }
    return 0;
}

/* Invalidate the dtable so it will be rebuild when a message is sent to
   the object */
static void
objc_invalidate_dtable(Class class)
{
    Class s;

    if (class->dtable == __objc_uninstalled_dtable) 
	return;
    sarray_free(class->dtable);
    __objc_install_premature_dtable(class);
    for (s=class->subclass_list; s; s=s->sibling_class) 
	objc_invalidate_dtable(s);
}

/* Initialize for dynamic loading */
static int 
objc_initialize_loading(FILE *errorStream)
{
    const char *path;

    dynamic_loaded = NO;
    path   = objc_executable_location();
#ifdef DEBUG
    printf("Debug (objc-load): initializing dynamic loader for %s\n", path);
#endif
    if (__objc_dynamic_init(path)) {
	if (errorStream)
	    __objc_dynamic_error(errorStream, "Error (objc-load): Cannot initialize dynamic linker");
	return 1;
    } else
	dynamic_loaded = YES;

    return 0;
}

/* A callback received from the Object initializer (_objc_exec_class).
   Do what we need to do and call our own callback.
*/
static void 
objc_load_callback(Class class, Category* category)
{
    /* Invalidate the dtable, so it will be rebuilt correctly */
    if (class != 0 && category != 0) {
	objc_invalidate_dtable(class);
	objc_invalidate_dtable(class->class_pointer);
    }

    if (_objc_load_load_callback)
	_objc_load_load_callback(class, category);
}

long
objc_load_module(
	const char *filename,
	FILE *errorStream,
	void (*loadCallback)(Class, Category*),
	void **header,
	char *debugFilename)

{
    typedef void (*void_fn)();
    dl_handle_t handle;
#if !defined(__ELF__) && !defined(CON_AUTOLOAD)
    void_fn *ctor_list;
    int i;
#endif

    if (!dynamic_loaded)
        if (objc_initialize_loading(errorStream))
            return 1;

    _objc_load_load_callback = loadCallback;
    _objc_load_callback = objc_load_callback;

    /* Link in the object file */
#ifdef DEBUG
    printf("Debug (objc-load): Linking file %s\n", filename);
#endif
    handle = __objc_dynamic_link(filename, 1, debugFilename);
    if (handle == 0) {
	if (errorStream)
	    __objc_dynamic_error(errorStream, "Error (objc-load)");
	return 1;
    }
    dynamic_handles = list_cons(handle, dynamic_handles);

    /* If there are any undefined symbols, we can't load the bundle */
    if (objc_check_undefineds(errorStream)) {
	__objc_dynamic_unlink(handle);
	return 1;
    }

#if !defined(__ELF__) && !defined(CON_AUTOLOAD)
    /* Get the constructor list and load in the objects */
    ctor_list = (void_fn *)__objc_dynamic_find_symbol(handle, CTOR_LIST);
    if (!ctor_list) {
	if (errorStream)
	    fprintf(errorStream, "Error (objc-load): Cannot load objects (no CTOR list)\n");
	return 1;
    }

#ifdef DEBUG
    printf("Debug (objc-load): %d modules\n", (int)ctor_list[0]);
#endif
    for (i=1; ctor_list[i]; i++) {
#ifdef DEBUG
	printf("Debug (objc-load): Invoking CTOR %p\n", ctor_list[i]);
#endif
	ctor_list[i]();
    }
#endif /* not __ELF__ */

    _objc_load_callback = 0;
    _objc_load_load_callback = 0;
    return 0;
}

long 
objc_unload_module(
	FILE *errorStream,
	void (*unloadCallback)(Class, Category*))
{
    if (!dynamic_loaded)
        return 1;

    if (errorStream)
        fprintf(errorStream, "Warning: unloading modules not implemented\n");
    return 0;
}

long objc_loadModules(char *files[],FILE *errorStream,
	void (*callback)(Class,Category*),
	void **header,
	char *debugFilename)
{
    while (*files) {
	if (objc_load_module(*files, errorStream, callback, 
		(void *)header, debugFilename)) 
	    return 1;
	files++;
    }
    return 0;
}

long 
objc_unloadModules(
	FILE *errorStream,
	void (*unloadCallback)(Class, Category*))
{
    if (!dynamic_loaded)
        return 1;

    if (errorStream)
        fprintf(errorStream, "Warning: unloading modules not implemented\n");
    return 0;
}
