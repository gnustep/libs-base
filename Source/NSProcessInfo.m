/* Implementation for NSProcessInfo for GNUStep
   Copyright (C) 1995-1999 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL & Academia Naturalis, 
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   
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
 * 2) To change the format of the string renurned by globallyUniqueString;
 * Bugs       : Not known
 * Last update: 22-jul-1999
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

#include <config.h>
#include <base/preface.h>
#include <unistd.h>

#ifdef HAVE_STRERROR 
#include <errno.h>
#endif /* HAVE_STRERROR */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSHost.h>

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
#define _GNU_MISSING_MAIN_FUNCTION_CALL @"\nGNUSTEP Internal Error:\n\
The private GNUstep function to establish the argv and environment\n\
variables was not called.\n\
Please report the error to bug-gnustep@gnu.org.\n\n"
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
@implementation NSProcessInfo
/*************************************************************************
 *** Static global vars
 *************************************************************************/
// The shared NSProcessInfo instance
static NSProcessInfo	*_gnu_sharedProcessInfoObject = nil;

// Host name of the CPU executing the process
static NSString		*_gnu_hostName = nil;   

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

static void 
_gnu_process_args(int argc, char *argv[], char *env[])
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  int i;

  /* Getting the process name */
  _gnu_processName = [[NSString stringWithCString: argv[0]] lastPathComponent];
  IF_NO_GC(RETAIN(_gnu_processName));


  /* Copy the argument list */
  {
    NSMutableSet	*mySet;
    id			obj_argv[argc];
    int			added = 0;

    mySet = [NSMutableSet new];
    for (i = 0; i < argc; i++) 
      {
	NSString	*str = [NSString stringWithCString: argv[i]];

	if ([str hasPrefix: @"--GNU-Debug="])
	  [mySet addObject: [str substringFromIndex: 12]];
	else
          obj_argv[added++] = str;
      }
    _gnu_arguments = [[NSArray alloc] initWithObjects: obj_argv count: added];
    _debug_set = mySet;
  }
	
  /* Copy the evironment list */
  {
    NSMutableArray	*keys = [NSMutableArray new];
    NSMutableArray	*values = [NSMutableArray new];

    i = 0;
    while (env[i]) 
      {
#if defined(__MINGW__)
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
    _gnu_environment = [[NSDictionary alloc] initWithObjects: values
						     forKeys: keys];
    [keys release];
    [values release];
  }
  [arp release];
}

#if !GS_FAKE_MAIN && (defined(HAVE_PROC_FS) && defined(HAVE_LOAD_METHOD))
/*
 * We have to save program arguments and environment before main () is
 * executed, because main () could modify their values before we get a
 * chance to read them 
 */
static int	_gnu_noobjc_argc;
static char	**_gnu_noobjc_argv;
static char	**_gnu_noobjc_env;

/*
 * The +load method (an extension of the GNU compiler) is invoked
 * before main and +initialize (for this class) is executed.  This is
 * guaranteed if +load contains only pure C code, as we have here. 
 */
+ (void) load 
{
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
  _gnu_noobjc_argc++;
  /*
   * Now _gnu_noobcj_argc is the number of arguments;
   * allocate memory accordingly.
   */
  _gnu_noobjc_argv = (char **)malloc((sizeof(char *)) * (_gnu_noobjc_argc + 1));
  if (_gnu_noobjc_argv == NULL)
    goto malloc_error;

  fclose(ifp);
  ifp=fopen(proc_file_name,"r");
  //freopen(proc_file_name, "r", ifp);
  if (ifp == NULL)
    {
      free(_gnu_noobjc_argv);
      goto proc_fs_error;
    }
  argument = 0;
  length = 0;
  while (1)
    {
      c = getc(ifp);
      length++;
      if ((c == EOF) || (c == 0)) // End of a parameter 
	{ 
	  _gnu_noobjc_argv[argument] = (char*)malloc((sizeof(char))*length);
	  if (_gnu_noobjc_argv[argument] == NULL)
	    goto malloc_error;
	  argument++;
	  if (c == EOF) // End of command line
	    break;
	  length = 0;
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
  while (1)
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
  if (!_gnu_processName && !_gnu_arguments && !_gnu_environment)
    {
      NSAssert(_gnu_noobjc_argv && _gnu_noobjc_env,
	_GNU_MISSING_MAIN_FUNCTION_CALL);
      _gnu_process_args(_gnu_noobjc_argc, _gnu_noobjc_argv, _gnu_noobjc_env);
      _gnu_noobjc_free_vars();
    }
}
#else /* !HAVE_PROC_FS || !HAVE_LOAD_METHOD */

#ifdef __MINGW32__
/* For Windows32API Library, we know the global variables */
extern int __argc;
extern char** __argv;
extern char** _environ;

+ (void) initialize
{
  if (self == [NSProcessInfo class])
    _gnu_process_args(__argc, __argv, _environ);
}

#else
#undef main
int main(int argc, char *argv[], char *env[])
{
#if defined(__MINGW__)
  WSADATA lpWSAData;

  // Initialize Windows Sockets
  if (WSAStartup(MAKEWORD(1,1), &lpWSAData))
    {
      printf("Could not startup Windows Sockets\n");
      exit(1);
    }
#endif /* __MINGW__ */

#ifdef __MS_WIN32__
  _MB_init_runtime();
#endif /* __MS_WIN32__ */

  _gnu_process_args(argc, argv, env);

  /* Call the user defined main function */
  return gnustep_base_user_main(argc, argv, env);
}
#endif /* __MINGW32__ */

#endif /* HAS_LOAD_METHOD && HAS_PROC_FS */ 

/*************************************************************************
 *** Getting an NSProcessInfo Object
 *************************************************************************/
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
    _gnu_sharedProcessInfoObject = [[_NSConcreteProcessInfo alloc] init];
		
  return _gnu_sharedProcessInfoObject;
}

/*************************************************************************
 *** Returning Process Information
 *************************************************************************/
- (NSArray *) arguments
{
  return _gnu_arguments;
}

- (NSMutableSet*) debugSet
{
  return _debug_set;
}

- (NSDictionary *) environment
{
  return _gnu_environment;
}

- (NSString *) hostName
{
  if (!_gnu_hostName) 
    {
      _gnu_hostName = [[[NSHost currentHost] name] copy];
    }
  return _gnu_hostName;
}

- (NSString *) processName
{
  return _gnu_processName;
}

- (NSString *) globallyUniqueString
{
  int	pid;

#if defined(__MINGW__)
  pid = (int)GetCurrentProcessId();
#else
  pid = (int)getpid();
#endif

  // $$$ The format of the string is not specified by the OpenStep 
  // specification. It could be useful to change this format after
  // NeXTSTEP release 4.0 comes out.
  return [NSString stringWithFormat: @"%@:%d:[%@]",
    [self hostName], pid, [NSDate date]];
}

/*************************************************************************
 *** Specifying a Process Name
 *************************************************************************/
- (void) setProcessName: (NSString *)newName
{
  if (newName && [newName length]) {
    [_gnu_processName autorelease];
    _gnu_processName = [newName copyWithZone: [self zone]];
  }
  return;
}

@end

/*
 *	Function for rapid testing to see if a debug level is set.
 */
BOOL GSDebugSet(NSString *val)
{
  static SEL debugSel = @selector(member:);
  static IMP debugImp = 0;

  if (debugImp == 0)
    {
      if (_debug_set == nil)
	{
	  [[NSProcessInfo processInfo] debugSet];
	}
      debugImp = [_debug_set methodForSelector: debugSel];
    }
  if ((*debugImp)(_debug_set, debugSel, val) == nil)
    return NO;
  return YES;
}

