/*
    simple-load - Definitions and translations for dynamic loading with 
	the simple dynamic liading library (dl).

    Copyright (C) 1995, Adam Fedor.

    BUGS:
	- In SunOS 4.1, dlopen will only resolve references into the main
	module and not into other modules loaded earlier. dlopen will exit
	if there are undefined symbols. Later versions (e.g. 5.3) fix this
	with RTLD_GLOBAL.

    $Id$
*/

#ifndef __sunos_load_h_INCLUDE
#define __sunos_load_h_INCLUDE

#include <dlfcn.h>

#ifndef RTLD_GLOBAL
#define RTLD_GLOBAL 0
#endif

/* Types defined appropriately for the dynamic linker */
typedef void* dl_handle_t;
typedef void* dl_symbol_t;

/* Do any initialization necessary.  Return 0 on success (or
   if no initialization needed. 
*/
static int 
__objc_dynamic_init(const char* exec_path)
{
    return 0;
}

/* Link in the module given by the name 'module'.  Return a handle which can
   be used to get information about the loded code.
*/
static dl_handle_t
__objc_dynamic_link(const char* module, int mode, const char* debug_file)
{
    return (dl_handle_t)dlopen(module, RTLD_LAZY | RTLD_GLOBAL);
}

/* Return the address of a symbol given by the name 'symbol' from the module
   associated with 'handle'
*/
static dl_symbol_t 
__objc_dynamic_find_symbol(dl_handle_t handle, const char* symbol)
{
    return dlsym(handle, symbol);
}

/* remove the code from memory associated with the module 'handle' */
static int 
__objc_dynamic_unlink(dl_handle_t handle)
{
    return dlclose(handle);
}

/* Print an error message (prefaced by 'error_string') relevant to the
   last error encountered
*/
static void 
__objc_dynamic_error(FILE *error_stream, const char *error_string)
{
    fprintf(error_stream, "%s:%s\n", error_string, dlerror());
}

/* Debugging:  define these if they are available */
static int 
__objc_dynamic_undefined_symbol_count(void)
{
    return 0;
}

static char** 
__objc_dynamic_list_undefined_symbols(void)
{
    return NULL;
}

#endif /* __sunos_load_h_INCLUDE */
