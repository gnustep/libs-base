
/* WIN32 extra config stuff */

#define STDC_HEADERS 1
#define HAVE_STRING_H 1
#define HAVE_MEMORY_H 1
#define HAVE_VSPRINTF 1

#define NeXT_cc 0
#define NeXT_runtime 0

// Define OBJC_BOOL so that Win32 does not typedef BOOL differently
#ifndef OBJC_BOOL
#define OBJC_BOOL
#endif

//
// WIN32
//
#ifdef __WIN32__
# include <windows.h>
# ifndef vm_page_size
#  define vm_page_size 4096
# endif
# define popen _popen

#include <sys/types.h>

/* WIN32 does not define a gettimeofday() */
int gettimeofday(struct timeval *tvp, struct timezone *tzp);

/* WIN32 does not define a times structure */
#ifndef _TIMES_DEFINED
//typedef long time_t;
struct tms {
  time_t tms_utime;  /* user time */
  time_t tms_stime;  /* system time */
  time_t tms_cutime; /* user time of children */
  time_t tms_cstime; /* system time of children */
};
#define _TIMES_DEFINED
#endif
int times(struct tms *atms);

#define CLOCKS_PER_SEC 1000
#define CLK_TCK  CLOCKS_PER_SEC
#define BITSPERBYTE 8

#endif /* __WIN32__ */

