/*
    dld-load - Definitions and translations for dynamic loading with GNU dld.

    Copyright (C) 1995, Free Software Foundation.

    BUGS: 
	- object files loaded by dld must be loaded with 'ld -r' rather
	than 'gcc -nostdlib', because dld can't handle multiple symbols
	like multiple CTOR_LISTS.  So here we construct our own CTOR
	list and return it when asked for (Ack! Pthet!).
	- __dld_construct_ctor_list may find a constructor that belongs
	to another module whose name is a super-string of the desired
	module name.

*/

#ifndef __dld_load_h_INCLUDE
#define __dld_load_h_INCLUDE

#include <dld/defs.h>

/* This is the GNU gcc name for the CTOR list */
#define CTOR_LIST	"___CTOR_LIST__"

/* The compiler generates a constructor function for each class.  The function
   has the prefix given below.
*/
#define GLOBAL_PREFIX   "_GLOBAL_$I$"

/* Types defined appropriately for the dynamic linker */
typedef char* dl_handle_t;
typedef unsigned long dl_symbol_t;

static void **dld_ctor_list = 0;

static void**
__dld_construct_ctor_list(dl_handle_t module)
{
    int i, ctors, length;

    length = 100;
    ctors  = 1;
    if (dld_ctor_list)
	free(dld_ctor_list);
    dld_ctor_list = (void **) __objc_xmalloc(length * sizeof(void *));
    /* Find all symbols with the GLOBAL_PREFIX prefix */
    for (i=0; i < TABSIZE; i++) {
        struct glosym *sym_entry = _dld_symtab[i];
   	for (; sym_entry; sym_entry = sym_entry->link) {
	    if (strstr(sym_entry->name, GLOBAL_PREFIX)
		    && strstr(sym_entry->defined_by->filename, module)) {
		dld_ctor_list[ctors] = (void **)sym_entry->value;
		ctors++;
		if (ctors > length) {
		    length *= 2;
		    dld_ctor_list = (void **) __objc_xrealloc(dld_ctor_list, 
						length * sizeof(void *));
		}
	    }
	}
    }
    dld_ctor_list[ctors] = (void **)0;
    dld_ctor_list[0] = (void **)(ctors - 1);

    return dld_ctor_list;
}

/* Do any initialization necessary.  Return 0 on success (or
   if no initialization needed. 
*/
static int 
__objc_dynamic_init(const char* exec_path)
{
    return dld_init(exec_path);
}

/* Link in the module given by the name 'module'.  Return a handle which can
   be used to get information about the loded code.
*/
static dl_handle_t
__objc_dynamic_link(const char* module, int mode, const char* debug_file)
{
    int error;
    dl_handle_t handle;

    error = dld_link(module);
    if (error)
	return NULL;
    handle = (dl_handle_t)__objc_xmalloc (strlen(module) + 1);
    strcpy(handle, module);
    return handle;
}

/* Return the address of a symbol given by the name 'symbol' from the module
   associated with 'handle'
*/
static dl_symbol_t 
__objc_dynamic_find_symbol(dl_handle_t handle, const char* symbol)
{
    if (strcmp(symbol, DLD_CTOR_LIST) == 0) {
	return (dl_symbol_t)__dld_construct_ctor_list(handle);
    }
    return dld_get_bare_symbol(symbol);
}

/* remove the code from memory associated with the module 'handle' */
static int 
__objc_dynamic_unlink(dl_handle_t handle)
{
    int error;
    error =  dld_unlink_by_file(handle, 0);
    free(handle);
    return error;
}

/* Print an error message (prefaced by 'error_string') relevant to the
   last error encountered
*/
static void 
__objc_dynamic_error(FILE *error_stream, const char *error_string)
{
    /* dld won't print to error stream, sorry */
    dld_perror(error_string);
}

/* Debugging:  define these if they are available */
static int 
__objc_dynamic_undefined_symbol_count(void)
{
    return dld_undefined_sym_count;
}

static char** 
__objc_dynamic_list_undefined_symbols(void)
{
    return dld_list_undefined_sym();
}

#endif /* __dld_load_h_INCLUDE */
