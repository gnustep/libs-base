/*
    objc-load.h - Dynamically load in Obj-C modules (Classes, Categories)

    Copyright (C) 1993, Adam Fedor.
    
*/

#ifndef __objc_load_h_INCLUDE
#define __objc_load_h_INCLUDE

#include <stdio.h>
#include <objc/objc-api.h>
#include <Foundation/NSString.h>

#if HAVE_DLADDR
#define LINKER_GETSYMBOL 1
#else
#define LINKER_GETSYMBOL 0
#endif

extern long objc_load_module(
	const char *filename,
	FILE *errorStream,
	void (*loadCallback)(Class, Category*),
        void **header,
        char *debugFilename);

extern long objc_unload_module(
	FILE *errorStream,
	void (*unloadCallback)(Class, Category*));

extern long objc_load_modules(
	char *files[],
	FILE *errorStream,
        void (*callback)(Class,Category*),
        void **header,
        char *debugFilename);

extern long objc_unload_modules(
	FILE *errorStream,
	void (*unloadCallback)(Class, Category*));

extern NSString *objc_get_symbol_path(
	Class theClass,
	Category *theCategory);

#endif /* __objc_load_h_INCLUDE */
