
/* WIN32 extra config stuff */

//
// WIN32
//
#ifdef WIN32
# include <windows.h>
# ifndef vm_page_size
#  define vm_page_size 4096
# endif
# define popen _popen
#endif

#define BITSPERBYTE 8

/* WIN32 extra config stuff */

//
// WIN32
//
#ifdef WIN32
# include <windows.h>
# ifndef vm_page_size
#  define vm_page_size 4096
# endif
# define popen _popen
#endif
