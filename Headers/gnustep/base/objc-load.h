/* 
   objc-load.h - Dynamically load in Obj-C modules (Classes, Categories)
   
   Copyright (C) 1993, 2002 Free Software Foundation, Inc.

   Author: Adam Fedor
   Date: 1993
   
   This file is part of the GNUstep Objective-C Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __objc_load_h_INCLUDE
#define __objc_load_h_INCLUDE

#include <stdio.h>
#include <objc/objc-api.h>
#include <Foundation/NSString.h>

#ifdef HAVE_DLADDR
#define LINKER_GETSYMBOL 1
#else
#define LINKER_GETSYMBOL 0
#endif

extern long objc_load_module(
	const char *filename,
	FILE *errorStream,
	void (*loadCallback)(Class, struct objc_category *),
        void **header,
        char *debugFilename);

extern long objc_unload_module(
	FILE *errorStream,
	void (*unloadCallback)(Class, struct objc_category *));

extern long objc_load_modules(
	char *files[],
	FILE *errorStream,
        void (*callback)(Class,struct objc_category *),
        void **header,
        char *debugFilename);

extern long objc_unload_modules(
	FILE *errorStream,
	void (*unloadCallback)(Class, struct objc_category *));

/*
 * objc_get_symbol_path() returns the path to the object file from
 * which a certain class was loaded.
 *
 * If the class was loaded from a shared library, this returns the
 * filesystem path to the shared library; if it was loaded from a
 * dynamical object (such as a bundle or framework dynamically
 * loaded), it returns the filesystem path to the object file; if the
 * class was loaded from the main executable, it returns the
 * filesystem path to the main executable path.
 *
 * This function is implemented by using the available features of
 * the dynamic linker on the specific platform we are running on.
 *
 * On some platforms, the dynamic linker does not provide enough
 * facilities to support the objc_get_symbol_path() function at all;
 * in this case, objc_get_symbol_path() always returns nil.
 *
 * On my platform (a Debian GNU Linux), it seems the dynamic linker
 * always returns the filesystem path that was used to load the
 * module.  So it returns the full filesystem path for shared libraries
 * and bundles (which is very nice), but unfortunately it returns 
 * argv[0] (which might be something as horrible as './obj/test')
 * for classes in the main executable.
 *
 * If theCategory argument is not NULL, objc_get_symbol_path() will return
 * the filesystem path to the module from which the category theCategory
 * of the class theClass was loaded.
 *
 * Currently, the function will return nil if any of the following
 * conditions is satisfied:
 *  - the required functionality is not available on the platform we are
 *    running on;
 *  - memory allocation fails;
 *  - the symbol for that class/category could not be found.
 *
 * In general, if the function returns nil, it means something serious
 * went wrong in the system preventing it from getting the symbol path.
 * If your code is to be portable, you (unfortunately) have to be prepared
 * to work around it in some way when this happens.
 *
 * It seems that this function has no corresponding function in the NeXT
 * runtime ... as far as I know.
 */
extern 
NSString *objc_get_symbol_path (Class theClass, Category *theCategory);

#endif /* __objc_load_h_INCLUDE */
