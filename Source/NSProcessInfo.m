/** Implementation for NSProcessInfo for GNUStep
   Copyright (C) 1995-2001 Free Software Foundation, Inc.

   Written by:  Georg Tuparev <Tuparev@EMBL-Heidelberg.de>
                Heidelberg, Germany
   Modified by:  Richard Frith-Macdonald <rfm@gnu.org>

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   <title>NSProcessInfo class reference</title>
   $Date$ $Revision$
*/

/*************************************************************************
 * File Name  : NSProcessInfo.m
 * Date       : 06-aug-1995
 *************************************************************************
 * Notes      :
 * 1) The class functionality depends on the following UNIX functions and
 * global variables: gethostname(), getpid(), and environ. For all system
 * I had the opportunity to test them they are defined and have the same
 * behavior. The same is true for the meaning of argv[0] (process name).
 * 2) The global variable _gnu_sharedProcessInfoObject should NEVER be
 * deallocate during the process runtime. Therefore I implemented a
 * concrete NSProcessInfo subclass (_NSConcreteProcessInfo) with the only
 * purpose to override the autorelease, retain, and release methods.
 * To Do      :
 * 1) To test the class on more platforms;
 * Bugs       : Not known
 * Last update: 07-aug-2002
 * History    : 06-aug-1995    - Birth and the first beta version (v. 0.5);
 *              08-aug-1995    - V. 0.6 (tested on NS, SunOS, Solaris, OSF/1
 *              The use of the environ global var was changed to more
 *              conventional env[] (main function) so now the class could be
 *              used on SunOS and Solaris. [GT]
 *************************************************************************
 * Acknowledgments:
 * - Adam Fedor, Andrew McCallum, and Paul Kunz for their help;
 * - To the NEXTSTEP/GNUStep community
 *************************************************************************/

#include "config.h"
#include "GNUstepBase/preface.h"
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_STRERROR
#include <errno.h>
#endif /* HAVE_STRERROR */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#ifdef HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif

#ifdef HAVE_KVM_ENV
#include <kvm.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#endif /* HAVE_KVM_ENV */

#if HAVE_PROCFS_H
#define id _procfs_avoid_id_collision
#include <procfs.h>
#undef id
#endif

#include "GSConfig.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSBundle.h"
#include "Foundation/NSSet.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSException.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSHost.h"
#include "Foundation/NSLock.h"
#include "GNUstepBase/GSCategories.h"

#include "GSPrivate.h"

/* This error message should be called only if the private main function
 * was not executed successfully. This may happen ONLY if another library
 * or kit defines its own main function (as gnustep-base does).
 */
#if GS_FAKE_MAIN
#define _GNU_MISSING_MAIN_FUNCTION_CALL @"\nGNUSTEP Internal Error:\n\
The private GNUstep function to establish the argv and environment\n\
variables was not called.\n\
Perhaps your program failed to #include <Foundation/NSObject.h> or\n\
<Foundation/Foundation.h>?\n\
If that is not the problem, Please report the error to bug-gnustep@gnu.org.\n\n"
#else
#ifdef GS_PASS_ARGUMENTS
#define _GNU_MISSING_MAIN_FUNCTION_CALL @"\nGNUSTEP Error:\n\
A call to NSProcessInfo +initializeWithArguments:... must be made\n\
as the first ObjC statment in main. This function is used to \n\
establish the argv and environment variables.\n"
#else
#define _GNU_MISSING_MAIN_FUNCTION_CALL @"\nGNUSTEP Internal Error:\n\
The private GNUstep function to establish the argv and environment\n\
variables was not called.\n\
Please report the error to bug-gnustep@gnu.org.\n\n"
#endif
#endif

/*************************************************************************
 *** _NSConcreteProcessInfo
 *************************************************************************/
@interface _NSConcreteProcessInfo: NSProcessInfo
- (id) autorelease;
- (void) release;
- (id) retain;
@end

@implementation _NSConcreteProcessInfo
- (id) autorelease
{
  return self;
}

- (void) release
{
  return;
}

- (id) retain
{
  return self;
}
@end


/*************************************************************************
 *** NSProcessInfo implementation
 *************************************************************************/

/**
 * Instances of this class encapsulate information on the current process.
 * For example, you can get the arguments, environment variables, host name,
 * or process name.  There is only one instance per process, for obvious
 * reasons, and it may be obtained through the +processInfo method.
 */
@implementation NSProcessInfo
/*************************************************************************
 *** Static global vars
 *************************************************************************/
// The shared NSProcessInfo instance
static NSProcessInfo	*_gnu_sharedProcessInfoObject = nil;

// Host name of the CPU executing the process
static NSString		*_gnu_hostName = nil;

static char		*_gnu_arg_zero = 0;

// Current process name
static NSString		*_gnu_processName = nil;

// Array of NSStrings (argv[1] .. argv[argc-1])
static NSArray		*_gnu_arguments = nil;

// Dictionary of environment vars and their values
static NSMutableDictionary	*_gnu_environment = nil;

// Array of debug levels set.
static NSMutableSet	*_debug_set = nil;

/*************************************************************************
 *** Implementing the gnustep_base_user_main function
 *************************************************************************/

void
_gnu_process_args(int argc, char *argv[], char *env[])
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString	*arg0 = nil;
  int i;

  if (_gnu_arg_zero != 0)
    {
      free(_gnu_arg_zero);
    }

  if (argv != 0 && argv[0] != 0)
    {
      _gnu_arg_zero = (char*)malloc(strlen(argv[0]) + 1);
      strcpy(_gnu_arg_zero, argv[0]);
      arg0 = [[NSString alloc] initWithCString: _gnu_arg_zero];
    }
  else
    {
#ifdef __MINGW32__
      unichar	*buffer;
      int	buffer_size = 0;
      int	needed_size = 0;
      const char	*tmp;

      while (needed_size == buffer_size)
	{
          buffer_size = buffer_size + 256;
          buffer = (unichar*)malloc(buffer_size * sizeof(unichar));
          needed_size = GetModuleFileNameW(NULL, buffer, buffer_size);
          if (needed_size < buffer_size)
	    {
	      unsigned	i;

	      for (i = 0; i < needed_size; i++)
		{
		  if (buffer[i] == 0)
		    {
		      break;
		    }
		}
	      arg0 = [[NSString alloc] initWithCharacters: buffer length: i];
	    }
          else
	    {
              free(buffer);
	    }
	}
      tmp = [arg0 UTF8String];
      _gnu_arg_zero = (char*)malloc(strlen(tmp) + 1);
      strcpy(_gnu_arg_zero, tmp);
#else
      fprintf(stderr, "Error: for some reason, argv not properly set up "
	      "during GNUstep base initialization\n");
      abort();
#endif
    }

  /* Getting the process name */
  IF_NO_GC(RELEASE(_gnu_processName));
  _gnu_processName = [arg0 lastPathComponent];
  IF_NO_GC(RETAIN(_gnu_processName));


  /* Copy the argument list */
  {
    NSString            *str;
    NSMutableSet	*mySet;
    id			obj_argv[argc];
    int			added = 1;

    mySet = [NSMutableSet new];

    /* Copy the zero'th argument to the argument list */
    obj_argv[0] = arg0;

    for (i = 1; i < argc; i++)
      {
	str = [NSString stringWithCString: argv[i]];

	if ([str hasPrefix: @"--GNU-Debug="])
	  [mySet addObject: [str substringFromIndex: 12]];
	else
          obj_argv[added++] = str;
      }

    IF_NO_GC(RELEASE(_gnu_arguments));
    _gnu_arguments = [[NSArray alloc] initWithObjects: obj_argv count: added];
    IF_NO_GC(RELEASE(_debug_set));
    _debug_set = mySet;
    RELEASE(arg0);
  }
	
  /* Copy the evironment list */
  {
    NSMutableArray	*keys = [NSMutableArray new];
    NSMutableArray	*values = [NSMutableArray new];

    i = 0;
    while (env[i])
      {
#if defined(__MINGW32__)
	char	buf[1024];
	char	*cp;
	DWORD	len;
	
	len = ExpandEnvironmentStrings(env[i], buf, 1022);
	if (len > 1022)
	  {
	    char	longbuf[len+2];

	    len = ExpandEnvironmentStrings(env[i], longbuf, len);
	    cp = strchr(longbuf, '=');
	    *cp++ = '\0';
	    [keys addObject: [NSString stringWithCString: longbuf]];
	    [values addObject: [NSString stringWithCString: cp]];
	  }
	else
	  {
	    if (len == 0)
	      strcpy(buf, env[i]);
	    cp = strchr(buf, '=');
	    *cp++ = '\0';
	    [keys addObject: [NSString stringWithCString: buf]];
	    [values addObject: [NSString stringWithCString: cp]];
	  }
#else
        int	len = strlen(env[i]);
	char	*cp = strchr(env[i], '=');

	if (len && cp)
	  {
	    char	buf[len+2];

	    strcpy(buf, env[i]);
	    cp = &buf[cp - env[i]];
	    *cp++ = '\0';
	    [keys addObject: [NSString stringWithCString: buf]];
	    [values addObject: [NSString stringWithCString: cp]];
	  }
#endif
	i++;
      }
    IF_NO_GC(RELEASE(_gnu_environment));
    _gnu_environment = [[NSDictionary alloc] initWithObjects: values
						     forKeys: keys];
    IF_NO_GC(RELEASE(keys));
    IF_NO_GC(RELEASE(values));
  }
  IF_NO_GC(RELEASE(arp));
}

#if !GS_FAKE_MAIN && ((defined(HAVE_PROCFS)  || defined(HAVE_KVM_ENV) || defined(HAVE_PROCFS_PSINFO)) && (defined(HAVE_LOAD_METHOD)))
/*
 * We have to save program arguments and environment before main () is
 * executed, because main () could modify their values before we get a
 * chance to read them
 */
static int	_gnu_noobjc_argc = 0;
static char	**_gnu_noobjc_argv = NULL;
static char	**_gnu_noobjc_env = NULL;

/*
 * The +load method (an extension of the GNU compiler) is invoked
 * before main and +initialize (for this class) is executed.  This is
 * guaranteed if +load contains only pure C code, as we have here. The
 * code in here either uses libkvm if available, or else procfs.
 */
+ (void) load
{
#ifdef HAVE_KVM_ENV
  /*
   * Use the kvm library to open the kernel and read the environment and
   * arguments. As we are not running as root we cannot open the memory
   * device and thus we fake it using /dev/null. This is allowed under
   * FreeBSD, but may fail on other operating systems which check the
   * file type. The kvm calls used are those which are supposedly backward
   * compatible with Solaris rather than being FreeBSD specific
   */
  kvm_t *kptr = NULL;
  struct kinfo_proc *proc_ptr = NULL;
  int nprocs, i, count;
  char **vectors;

  /* open the kernel */
  kptr = kvm_open(NULL, "/dev/null", NULL, O_RDONLY, "NSProcessInfo");
  if (!kptr)
    {
      fprintf(stderr, "Error: Your system appears to provide libkvm, but the kernel open fails\n");
      fprintf(stderr, "Try to reconfigure gnustep-base with --enable-fake-main. to work\n");
      fprintf(stderr, "around this problem.");
      abort();
    }

  /* find the process */
  proc_ptr = kvm_getprocs(kptr, KERN_PROC_PID, getpid(), &nprocs);
  if (!proc_ptr || (nprocs != 1))
    {
      fprintf(stderr, "Error: libkvm cannot find the current process\n");
      abort();
    }

  /* get the environment vectors the normal way, since this always works.
     On FreeBSD, the only other way is via /proc, and in later versions
     /proc is not mounted.  */
  {
    extern char **environ;
    vectors = environ;
    if (!vectors)
      {
	fprintf(stderr, "Error: for some reason, environ == NULL "
		"during GNUstep base initialization\n"
		"Please check the linking process\n");
	abort();
      }
  }

  /* copy the environment strings */
  for (count = 0; vectors[count]; count++)
    ;
  _gnu_noobjc_env = (char**)malloc(sizeof(char*) * (count + 1));
  if (!_gnu_noobjc_env)
    goto malloc_error;
  for (i = 0; i < count; i++)
    {
      _gnu_noobjc_env[i] = (char *)strdup(vectors[i]);
      if (!_gnu_noobjc_env[i])
	goto malloc_error;
    }
  _gnu_noobjc_env[i] = NULL;

  /* get the argument vectors */
  vectors = kvm_getargv(kptr, proc_ptr, 0);
  if (!vectors)
    {
      fprintf(stderr, "Error: libkvm does not return arguments for the current process\n");
      abort();
    }

  /* copy the argument strings */
  for (_gnu_noobjc_argc = 0; vectors[_gnu_noobjc_argc]; _gnu_noobjc_argc++)
    ;
  _gnu_noobjc_argv = (char**)malloc(sizeof(char*) * (_gnu_noobjc_argc + 1));
  if (!_gnu_noobjc_argv)
    goto malloc_error;
  for (i = 0; i < _gnu_noobjc_argc; i++)
    {
      _gnu_noobjc_argv[i] = (char *)strdup(vectors[i]);
      if (!_gnu_noobjc_argv[i])
	goto malloc_error;
    }
  _gnu_noobjc_argv[i] = NULL;

  return;
#elif defined(HAVE_PROCFS_PSINFO)
  char *proc_file_name = NULL;
  FILE *ifp;
  psinfo_t pinfo;
  char **vectors;
  int i, count;
  
  // Read commandline
  proc_file_name = (char*)malloc(sizeof(char) * 2048);
  sprintf(proc_file_name, "/proc/%d/psinfo", (int) getpid());
  
  ifp = fopen(proc_file_name, "r");
  if (ifp == NULL)
  {
    fprintf(stderr, "Error: Failed to open the process info file:%s\n", 
	    proc_file_name);
    abort();
  }
  
  fread(&pinfo, sizeof(pinfo), 1, ifp);
  fclose(ifp);
  
  vectors = (char **)pinfo.pr_envp;
  if (!vectors)
  {
    fprintf(stderr, "Error: for some reason, environ == NULL "
      "during GNUstep base initialization\n"
      "Please check the linking process\n");
    abort();
  }
  
  /* copy the environment strings */
  for (count = 0; vectors[count]; count++)
    ;
  _gnu_noobjc_env = (char**)malloc(sizeof(char*) * (count + 1));
  if (!_gnu_noobjc_env)
    goto malloc_error;
  for (i = 0; i < count; i++)
  {
  	_gnu_noobjc_env[i] = (char *)strdup(vectors[i]);
    if (!_gnu_noobjc_env[i])
      goto malloc_error;
  }
  _gnu_noobjc_env[i] = NULL;

  /* get the argument vectors */
  vectors = (char **)pinfo.pr_argv;
  if (!vectors)
  {
    fprintf(stderr, "Error: psinfo does not return arguments for the current process\n");
    abort();
  }
  /* copy the argument strings */
  for (_gnu_noobjc_argc = 0; vectors[_gnu_noobjc_argc]; _gnu_noobjc_argc++)
    ;
  _gnu_noobjc_argv = (char**)malloc(sizeof(char*) * (_gnu_noobjc_argc + 1));
  if (!_gnu_noobjc_argv)
    goto malloc_error;
  for (i = 0; i < _gnu_noobjc_argc; i++)
    {
      _gnu_noobjc_argv[i] = (char *)strdup(vectors[i]);
      if (!_gnu_noobjc_argv[i])
	goto malloc_error;
    }
  _gnu_noobjc_argv[i] = NULL;

  return;
#else /* !HAVE_KVM_ENV (i.e. HAVE_PROCFS).  */
  /*
   * Now we have the problem of reading program arguments and
   * environment.  We take the environment from extern char **environ, and
   * the program arguments from the /proc filesystem.
   */
  extern char	**environ;
  char		*proc_file_name = NULL;
  FILE		*ifp;
  int		c;
  int		argument;
  int		length;
  int		position;
  int		env_terms;
  BOOL		stripTrailingNewline = NO;
#ifdef HAVE_PROGRAM_INVOCATION_NAME
  extern char	*program_invocation_name;
#endif /* HAVE_PROGRAM_INVOCATION_NAME */

  // Read environment

  /* NB: This should *never* happen if your compiler tools are
     sane.  But, if you are playing with them, you could break
     them to the point you get here. :-) */
  if (environ == NULL)
    {
      /* TODO: Try reading environment from /proc before aborting. */
      fprintf(stderr, "Error: for some reason, environ == NULL "
	      "during GNUstep base initialization\n"
	      "Please check the linking process\n");
      abort();
    }

  c = 0;
  while (environ[c] != NULL)
    c++;
  env_terms = c;
  _gnu_noobjc_env = (char**)malloc(sizeof(char*) * (env_terms + 1));
  if (_gnu_noobjc_env == NULL)
    goto malloc_error;
  for (c = 0; c < env_terms; c++)
    {
      _gnu_noobjc_env[c] = (char *)strdup(environ[c]);
      if (_gnu_noobjc_env[c] == NULL)
	goto malloc_error;
    }
  _gnu_noobjc_env[c] = NULL;

  // Read commandline
  proc_file_name = (char *)malloc(sizeof(char) * 2048);
  sprintf(proc_file_name, "/proc/%d/cmdline", (int) getpid());

  /*
   * We read the /proc file thrice.
   * First, to know how many arguments there are and allocate memory for them.
   * Second, to know how long each argument is, and allocate memory accordingly.
   * Third, to actually copy the arguments into memory.
   */
  _gnu_noobjc_argc = 0;
#ifdef HAVE_STRERROR
  errno = 0;
#endif /* HAVE_STRERROR */
  ifp = fopen(proc_file_name, "r");
  if (ifp == NULL)
    goto proc_fs_error;
  while (1)
    {
      c = getc(ifp);
      if (c == 0)
	_gnu_noobjc_argc++;
      else if (c == EOF)
	break;
    }
#if (CMDLINE_TERMINATED == 0)
  _gnu_noobjc_argc++;
#endif
  fclose(ifp);

  /*
   * Now _gnu_noobcj_argc is the number of arguments;
   * allocate memory accordingly.
   */
  _gnu_noobjc_argv = (char **)malloc((sizeof(char *)) * (_gnu_noobjc_argc + 1));
  if (_gnu_noobjc_argv == NULL)
    goto malloc_error;


  ifp=fopen(proc_file_name,"r");
  //freopen(proc_file_name, "r", ifp);
  if (ifp == NULL)
    {
      free(_gnu_noobjc_argv);
      goto proc_fs_error;
    }
  argument = 0;
  length = 0;
  while (argument < _gnu_noobjc_argc)
    {
      c = getc(ifp);
      length++;
      if ((c == EOF) || (c == 0)) // End of a parameter
	{
	  _gnu_noobjc_argv[argument] = (char*)malloc((sizeof(char))*length);
	  if (_gnu_noobjc_argv[argument] == NULL)
	    goto malloc_error;
	  argument++;
	  length = 0;
	  if (c == EOF) // End of command line
	    break;
	}
    }
  fclose(ifp);
  ifp=fopen(proc_file_name,"r");
  //freopen(proc_file_name, "r", ifp);
  if (ifp == NULL)
    {
      for (c = 0; c < _gnu_noobjc_argc; c++)
	free(_gnu_noobjc_argv[c]);
      free(_gnu_noobjc_argv);
      goto proc_fs_error;
    }
  argument = 0;
  position = 0;
  while (argument < _gnu_noobjc_argc)
    {
      c = getc(ifp);
      if ((c == EOF) || (c == 0)) // End of a parameter
	{
	  if (argument == 0 && position > 0
	    && _gnu_noobjc_argv[argument][position-1] == '\n')
	    {
	      stripTrailingNewline = YES;
	    }
	  if (stripTrailingNewline == YES && position > 0
	    && _gnu_noobjc_argv[argument][position-1] == '\n')
	    {
	      position--;
	    }
	  _gnu_noobjc_argv[argument][position] = '\0';
	  argument++;
	  if (c == EOF) // End of command line
	    break;
	  position = 0;
	  continue;
	}
      _gnu_noobjc_argv[argument][position] = c;
      position++;
    }
  _gnu_noobjc_argv[argument] = NULL;
  fclose(ifp);
  free(proc_file_name);
  return;

 proc_fs_error:
#ifdef HAVE_STRERROR
  fprintf(stderr, "Couldn't open file %s when starting gnustep-base; %s\n",
	   proc_file_name, strerror(errno));
#else  /* !HAVE_FUNCTION_STRERROR */
  fprintf(stderr, "Couldn't open file %s when starting gnustep-base.\n",
	   proc_file_name);
#endif /* HAVE_FUNCTION_STRERROR */
  fprintf(stderr, "Your gnustep-base library is compiled for a kernel supporting the /proc filesystem, but it can't access it.\n");
  fprintf(stderr, "You should recompile or change your kernel.\n");
#ifdef HAVE_PROGRAM_INVOCATION_NAME
  fprintf(stderr, "We try to go on anyway; but the program will ignore any argument which were passed to it.\n");
  _gnu_noobjc_argc = 1;
  _gnu_noobjc_argv = malloc(sizeof(char *) * 2);
  if (_gnu_noobjc_argv == NULL)
    goto malloc_error;
  _gnu_noobjc_argv[0] = strdup(program_invocation_name);
  if (_gnu_noobjc_argv[0] == NULL)
    goto malloc_error;
  _gnu_noobjc_argv[1] = NULL;
  return;
#else /* !HAVE_PROGRAM_INVOCATION_NAME */
  /*
   * There is really little sense in going on here, because NSBundle
   * will anyway crash later if we just put something like "_Unknown_"
   * as the program name.
   */
  abort();
#endif /* HAVE_PROGRAM_INVOCATION_NAME */
#endif /* !HAVE_KVM_ENV (e.g. HAVE_PROCFS) */
 malloc_error:
  fprintf(stderr, "malloc() error when starting gnustep-base.\n");
  fprintf(stderr, "Free some memory and then re-run the program.\n");
  abort();
}

static void
_gnu_noobjc_free_vars(void)
{
  char **p;

  p = _gnu_noobjc_argv;
  while (*p)
    {
      free(*p);
      p++;
    }
  free(_gnu_noobjc_argv);
  _gnu_noobjc_argv = 0;

  p = _gnu_noobjc_env;
  while (*p)
    {
      free(*p);
      p++;
    }
  free(_gnu_noobjc_env);
  _gnu_noobjc_env = 0;
}

+ (void) initialize
{
  if (self == [NSProcessInfo class]
    && !_gnu_processName && !_gnu_arguments && !_gnu_environment)
    {
      NSAssert(_gnu_noobjc_argv && _gnu_noobjc_env,
	_GNU_MISSING_MAIN_FUNCTION_CALL);
      _gnu_process_args(_gnu_noobjc_argc, _gnu_noobjc_argv, _gnu_noobjc_env);
      _gnu_noobjc_free_vars();
    }
}
#else /*! HAVE_PROCFS !HAVE_LOAD_METHOD !HAVE_KVM_ENV */

#ifdef __MINGW32__
/* For WindowsAPI Library, we know the global variables (argc, etc) */
+ (void) initialize
{
  if (self == [NSProcessInfo class]
    && !_gnu_processName && !_gnu_arguments && !_gnu_environment)
    {
      _gnu_process_args(__argc, __argv, _environ);
    }
}
#elif defined(__BEOS__)

extern int __libc_argc;
extern char **__libc_argv;
+ (void) initialize
{
  if (self == [NSProcessInfo class]
    && !_gnu_processName && !_gnu_arguments && !_gnu_environment)
    {
      _gnu_process_args(__libc_argc, __libc_argv, environ);
    }
}


#else
#ifndef GS_PASS_ARGUMENTS
#undef main
int main(int argc, char *argv[], char *env[])
{
#ifdef NeXT_RUNTIME
  /* This memcpy has to be done before the first message is sent to any
     constant string object. See Apple Radar 2870817 */
  memcpy(&_NSConstantStringClassReference,
         objc_getClass(STRINGIFY(NXConstantString)),
         sizeof(_NSConstantStringClassReference));
#endif

#if defined(__MINGW32__)
  WSADATA lpWSAData;

  // Initialize Windows Sockets
  if (WSAStartup(MAKEWORD(1,1), &lpWSAData))
    {
      printf("Could not startup Windows Sockets\n");
      exit(1);
    }
#endif /* __MINGW32__ */

#ifdef __MS_WIN__
  _MB_init_runtime();
#endif /* __MS_WIN__ */

  _gnu_process_args(argc, argv, env);

  /* Call the user defined main function */
  return gnustep_base_user_main(argc, argv, env);
}
#endif /* !GS_PASS_ARGUMENTS */
#endif /* __MINGW32__ */

#endif /* HAS_LOAD_METHOD && HAS_PROCFS */

/**
 * Returns the shared NSProcessInfo object for the current process.
 */
+ (NSProcessInfo *) processInfo
{
  // Check if the main() function was successfully called
  // We can't use NSAssert, which calls NSLog, which calls NSProcessInfo...
  if (!(_gnu_processName && _gnu_arguments && _gnu_environment))
    {
      _NSLog_printf_handler(_GNU_MISSING_MAIN_FUNCTION_CALL);
      [NSException raise: NSInternalInconsistencyException
	          format: _GNU_MISSING_MAIN_FUNCTION_CALL];
    }

  if (!_gnu_sharedProcessInfoObject)
    {
      _gnu_sharedProcessInfoObject = [[_NSConcreteProcessInfo alloc] init];
    }
  return _gnu_sharedProcessInfoObject;
}

/**
 * Returns an array containing the arguments supplied to start this
 * process.<br />
 * NB. In GNUstep, any arguments of the form --GNU-Debug=...
 * are <em>not</em> included in this array ... they are part of the
 * debug mechanism, and are hidden so that setting debug variables
 * will not effect the normal operation of the program.<br />
 * Please note, the special <code>--GNU-Debug=...</code> syntax differs from
 * that which is used to specify values for the [NSUserDefaults] system.<br />
 * User defaults are set on the command line by specifying the default name
 * (with a leading hyphen) as one argument, and the default value as the
 * following argument.  The arguments used to set user defaults are
 * present in the array returned by this method.
 */
- (NSArray *) arguments
{
  return _gnu_arguments;
}

/**
 * Returns a dictionary giving the environment variables which were
 * provided for the process to use.
 */
- (NSDictionary *) environment
{
  return _gnu_environment;
}

/**
 * Returns a string which may be used as a globally unique identifier.<br />
 * The string contains the host name, the process ID, a timestamp and a
 * counter.<br />
 * The first three values identify the process in which the string is
 * generated, while the fourth ensures that multiple strings generated
 * within the same process are unique.
 */
- (NSString *) globallyUniqueString
{
  static unsigned long	counter = 0;
  int			count;
  static NSString	*host = nil;
  static int		pid;
  static unsigned long	start;

  [gnustep_global_lock lock];
  if (host == nil)
    {
      extern NSTimeInterval GSTimeNow(void);

      pid = [self processIdentifier];
      start = (unsigned long)GSTimeNow();
      host = [[self hostName] stringByReplacingString: @"." withString: @"_"];
      RETAIN(host);
    }
  count = counter++;
  [gnustep_global_lock unlock];

  // $$$ The format of the string is not specified by the OpenStep
  // specification.
  return [NSString stringWithFormat: @"%@_%x_%lx_%lx",
    host, pid, start, count];
}

/**
 * Returns the name of the machine on which this process is running.
 */
- (NSString *) hostName
{
  if (!_gnu_hostName)
    {
      _gnu_hostName = [[[NSHost currentHost] name] copy];
    }
  return _gnu_hostName;
}

/**
 * Return a number representing the operating system type.<br />
 * The known types are listed in the header file, but not all of the
 * listed types are actually implemented ... some are present for
 * MacOS-X compatibility only.<br />
 * <list>
 * <item>NSWindowsNTOperatingSystem - used for windows NT, 2000, XP</item>
 * <item>NSWindows95OperatingSystem - probably never to be implemented</item>
 * <item>NSSolarisOperatingSystem - not yet recognised</item>
 * <item>NSHPUXOperatingSystem - not implemented</item>
 * <item>NSMACHOperatingSystem - perhaps the HURD in future?</item>
 * <item>NSSunOSOperatingSystem - probably never to be implemented</item>
 * <item>NSOSF1OperatingSystem - probably never to be implemented</item>
 * <item>NSGNULinuxOperatingSystem - the GNUstep 'standard'</item>
 * <item>NSBSDOperatingSystem - BSD derived operating systems</item>
 * </list>
 */
- (unsigned int) operatingSystem
{
  static unsigned int	os = 0;

  if (os == 0)
    {
      NSString	*n = [self operatingSystemName];

      if ([n isEqualToString: @"linux-gnu"] == YES)
        {
	  os = NSGNULinuxOperatingSystem;
	}
      else if ([n isEqualToString: @"mingw"] == YES)
        {
	  os = NSWindowsNTOperatingSystem;
	}
      else if ([n isEqualToString: @"cygwin"] == YES)
        {
	  os = NSWindowsNTOperatingSystem;
	}
      else if ([n hasPrefix: @"bsd"] == YES)
        {
	  os = NSBSDOperatingSystem;
	}
      else if ([n hasPrefix: @"freebsd"] == YES)
        {
	  os = NSBSDOperatingSystem;
	}
      else if ([n hasPrefix: @"netbsd"] == YES)
        {
	  os = NSBSDOperatingSystem;
	}
      else if ([n hasPrefix: @"openbsd"] == YES)
        {
	  os = NSBSDOperatingSystem;
	}
      else if ([n isEqualToString: @"beos"] == YES)
	{
          os = NSBeOperatingSystem;
        }
      else if ([n hasPrefix: @"darwin"] == YES)
	{
          os = NSMACHOperatingSystem;
        }
      else if ([n hasPrefix: @"solaris"] == YES)
	{
          os = NSSolarisOperatingSystem;
        }
      else if ([n hasPrefix: @"hpux"] == YES)
	{
          os = NSHPUXOperatingSystem;
        }
      else
        {
	  NSLog(@"Unable to determine O/S ... assuming GNU/Linux");
	  os = NSGNULinuxOperatingSystem;
	}
    }
  return os;
}

/**
 * Returns the name of the operating system in use.
 */
- (NSString*) operatingSystemName
{
  static NSString	*os = nil;

  if (os == nil)
    {
      os = [[NSBundle _gnustep_target_os] copy];
    }
  return os;
}

/**
 * Returns the process identifier number which identifies this process
 * on this machine.
 */
- (int) processIdentifier
{
  int	pid;

#if defined(__MINGW32__)
  pid = (int)GetCurrentProcessId();
#else
  pid = (int)getpid();
#endif
  return pid;
}

/**
 * Returns the process name for this process. This may have been set using
 * the -setProcessName: method, or may be the default process name (the
 * file name of the binary being executed).
 */
- (NSString *) processName
{
  return _gnu_processName;
}

/**
 * Change the name of the current process to newName.
 */
- (void) setProcessName: (NSString *)newName
{
  if (newName && [newName length]) {
    [_gnu_processName autorelease];
    _gnu_processName = [newName copyWithZone: [self zone]];
  }
  return;
}

@end

/**
 * Provides GNUstep-specific methods for controlled debug logging (a GNUstep
 * facility) and an internal/developer-related method.
 */
@implementation	NSProcessInfo (GNUstep)

static BOOL	debugTemporarilyDisabled = NO;

/**
 * Fallback method. The developer must call this method to initialize
 * the NSProcessInfo system if none of the system-specific hacks to
 * auto-initialize it are working.<br />
 * It should also be safe to call this method to override the effects
 * of the automatic initialisation.
 */
+ (void) initializeWithArguments: (char**)argv
                           count: (int)argc
                     environment: (char**)env
{
  [gnustep_global_lock lock];
  _gnu_process_args(argc, argv, env);
  [gnustep_global_lock unlock];
}

/**
 * Returns a indication of whether debug logging is enabled.
 * This returns YES unless a call to -setDebugLoggingEnabled: has
 * been used to turn logging off.
 */
- (BOOL) debugLoggingEnabled
{
  if (debugTemporarilyDisabled == YES)
    {
      return NO;
    }
  else
    {
      return YES;
    }
}

/**
 * This method returns a set of debug levels set using the
 * --GNU-Debug=... command line option and/or the GNU-Debug
 * user default.<br />
 * You can modify this set to change the debug logging under
 * your programs control ... but such modifications are not
 * thread-safe.
 */
- (NSMutableSet*) debugSet
{
  return _debug_set;
}

/**
 * This method permits you to turn all debug logging on or off
 * without modifying the set of debug levels in use.
 */
- (void) setDebugLoggingEnabled: (BOOL)flag
{
  if (flag == NO)
    {
      debugTemporarilyDisabled = YES;
    }
  else
    {
      debugTemporarilyDisabled = NO;
    }
}

/**
 * Set the file to which NSLog output should be directed.<br />
 * Returns YES on success, NO on failure.<br />
 * By default logging goes to standard error.
 */
- (BOOL) setLogFile: (NSString*)path
{
  extern int	_NSLogDescriptor;
  int		desc;

  desc = open([path fileSystemRepresentation], O_RDWR|O_CREAT|O_APPEND, 0644);
  if (desc >= 0)
    {
      if (_NSLogDescriptor >= 0 && _NSLogDescriptor != 2)
	{
	  close(_NSLogDescriptor);
	}
      _NSLogDescriptor = desc;
      return YES;
    }
  return NO;
}
@end

/**
 * Function for rapid testing to see if a debug level is set.<br />
 * This is used by the debugging macros.<br />
 * If debug logging has been turned off, this returns NO even if
 * the specified level exists in the set of debug levels.
 */
BOOL GSDebugSet(NSString *level)
{
  static IMP debugImp = 0;
  static SEL debugSel;

  if (debugTemporarilyDisabled == YES)
    {
      return NO;
    }
  if (debugImp == 0)
    {
      debugSel = @selector(member:);
      if (_debug_set == nil)
	{
	  [[NSProcessInfo processInfo] debugSet];
	}
      debugImp = [_debug_set methodForSelector: debugSel];
    }
  if ((*debugImp)(_debug_set, debugSel, level) == nil)
    {
      return NO;
    }
  return YES;
}


BOOL
GSEnvironmentFlag(const char *name, BOOL def)
{
  const char	*c = getenv(name);
  BOOL		a = def;

  if (c != 0)
    {
      a = NO;
      if ((c[0] == 'y' || c[0] == 'Y') && (c[1] == 'e' || c[1] == 'E')
	&& (c[2] == 's' || c[2] == 'S') && c[3] == 0)
	{
	  a = YES;
	}
      else if ((c[0] == 't' || c[0] == 'T') && (c[1] == 'r' || c[1] == 'R')
	&& (c[2] == 'u' || c[2] == 'U') && (c[3] == 'e' || c[3] == 'E')
	&& c[4] == 0)
	{
	  a = YES;
	}
      else if (isdigit(c[0]) && c[0] != '0')
	{
	  a = YES;
	}
    }
  return a;
}

/**
 * Used by NSException uncaught exception handler - must not call any
 * methods/functions which might cause a recursive exception.
 */
const char*
GSArgZero(void)
{
  if (_gnu_arg_zero == 0)
    return "";
  else
    return _gnu_arg_zero;
}


