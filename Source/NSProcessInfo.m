/* Implementation for NSProcessInfo for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL & Academia Naturalis, 
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   
   This file is part of the GNU Objective C Class Library.

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

/*************************************************************************
 * File Name  : NSProcessInfo.m
 * Version    : 0.6 beta
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
 * Last update: 08-aug-1995
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

#ifdef NeXT
#ifdef SCITOOLS
#import <basekit/LibobjectsMain.h>
#import <foundation/NSString.h>
#import <foundation/NSArray.h>
#import <foundation/NSDictionary.h>
#import <foundation/NSDate.h>
#import <foundation/NSException.h>
#import <basekit/NSProcessInfo.h>
#else   /* SCITOOLS */
#import <foundation/NSString.h>
#import <foundation/NSArray.h>
#import <foundation/NSDictionary.h>
#import <foundation/NSDate.h>
#import <foundation/NSException.h>
#import <foundation/NSProcessInfo.h>
#endif  /* SCITOOLS */
#else
#include <string.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>
#endif  /* NeXT */



/* This is the longest max host name allowed for all different systems
 * I had a chance to read the man pages. 
 */
#define _GNU_MAX_HOST_NAMELEN    256

/* This error message should be called only if the private main function
 * was not executed successfully. This may heppen ONLY if onother library
 * or kit defines its own main function (as libobjects does).
 */
#define _GNU_MISSING_MAIN_FUNCTION_CALL @"Libobjects internal error: \
the private libobjects function to establish the argv and environment \
variables was not called. Please contact Tuparev@EMBL-Heidelberg.de for \
further information."

/*************************************************************************
 *** _NSConcreteProcessInfo
 *************************************************************************/
@interface _NSConcreteProcessInfo:NSProcessInfo
- (id)autorelease;
- (void)release;
- (id)retain;
@end

@implementation _NSConcreteProcessInfo
- (id)autorelease
{
  return self;
}

- (void)release
{
  return;
}

- (id)retain
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
static NSProcessInfo* _gnu_sharedProcessInfoObject = nil;

// Host name of the CPU executing the process
static NSString* _gnu_hostName = nil;   

// Current process name
static NSString* _gnu_processName = nil;

// Array of NSStrings (argv[1] .. argv[argc-1])
static NSMutableArray* _gnu_arguments = nil;

// Dictionary of environment vars and their values
static NSMutableDictionary* _gnu_environment = nil;

/*************************************************************************
 *** Implementing the Libobjects main function
 *************************************************************************/

static void 
_gnu_process_args(int argc, char *argv[], char *env[])
{
  int i;
	
  /* Getting the process name */
  _gnu_processName = [NSString stringWithCString:argv[0]];
  [_gnu_processName retain];
	
  /* Copy the argument list */
  _gnu_arguments = [[NSMutableArray arrayWithCapacity:0] retain];
  for (i = 1; i < argc; i++) {
    [_gnu_arguments addObject:[NSString stringWithCString:argv[i]]];
  }
	
  /* Copy the evironment list */
  _gnu_environment = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
  i = 0;
  while (env[i]) {
    char* cp;
    cp = strchr(env[i],'=');
    /* Temporary set *cp to \000 ... for copying purpose */
    *cp = '\000';
    [_gnu_environment setObject:[NSString stringWithCString:(cp+1)]
		      forKey:[NSString stringWithCString:env[i]]];
    /* Return the original value of environ[i] */
    *cp = '=';
    i++;
  }
}

/* Place the _gnu_process_args function in the _libc_subinit section so
   that it automatically gets called before main with the argument and
   environment pointers. FIXME: Would like to do something similar
   for other formats besides ELF. */
#if defined(__ELF__) || defined(SYS_AUTOLOAD)
#ifdef linux

/* Under linux the functions in __libc_subinit are called before the
 * global constructiors, therefore, we cannot send methods to any objects
 */

static int _gnu_noobjc_argc;
static char **_gnu_noobjc_argv;
static char **_gnu_noobjc_env;

static void 
_gnu_process_noobjc_args(int argc, char *argv[], char *env[]) {
	int i;

	/* We have to copy these in case the main() modifies their values
	 * somehow before we get a change to use them
	 */

	_gnu_noobjc_argc = argc;
	i=0;
	while(argv[i])
		i++;
	_gnu_noobjc_argv = NSZoneMalloc(NS_NOZONE,sizeof(char *)*(i+1));
	i=0;
	while(*argv) {
		_gnu_noobjc_argv[i] = NSZoneMalloc(NS_NOZONE,strlen(*argv)+1);
		strcpy(_gnu_noobjc_argv[i],*argv);
		argv++;
		i++;
	}
	_gnu_noobjc_argv[i] = 0;
	i=0;
	while(env[i])
		i++;
	_gnu_noobjc_env = NSZoneMalloc(NS_NOZONE,sizeof(char *)*(i+1));
	i=0;
	while(*env) {
		_gnu_noobjc_env[i] = NSZoneMalloc(NS_NOZONE,strlen(*env)+1);
		strcpy(_gnu_noobjc_env[i],*env);
		env++;
		i++;
	}
	_gnu_noobjc_env[i] = 0;

}

static void _gnu_noobjc_free_vars(void)
{
	char **p;

	p = _gnu_noobjc_argv;
	while (*p) {
		NSZoneFree(NS_NOZONE,*p);
		p++;
	}
	NSZoneFree(NS_NOZONE,_gnu_noobjc_argv);
	_gnu_noobjc_argv = 0;

	p = _gnu_noobjc_env;
	while (*p) {
		NSZoneFree(NS_NOZONE,*p);
		p++;
	}
	NSZoneFree(NS_NOZONE,_gnu_noobjc_env);
	_gnu_noobjc_env = 0;
}

static void * __libobjects_subinit_args__
__attribute__ ((section ("__libc_subinit"))) = &(_gnu_process_noobjc_args);

+ (void)initialize {
	if (!_gnu_processName && !_gnu_arguments && !_gnu_environment) {
		NSAssert(_gnu_noobjc_argv && _gnu_noobjc_env,
			_GNU_MISSING_MAIN_FUNCTION_CALL);
		_gnu_process_args(_gnu_noobjc_argc,_gnu_noobjc_argv,_gnu_noobjc_env);
		_gnu_noobjc_free_vars();
	}
}

#else
static void * __libobjects_subinit_args__
__attribute__ ((section ("_libc_subinit"))) = &(_gnu_process_args);
#endif
#else
#undef main
int main(int argc, char *argv[], char *env[])
{
  _gnu_process_args(argc, argv, env);

  /* Call the user defined main function */
  return LibobjectsMain(argc,argv);
}
#endif

/*************************************************************************
 *** Getting an NSProcessInfo Object
 *************************************************************************/
+ (NSProcessInfo *)processInfo
{
  // Check if the main() function was successfully called
  NSAssert(_gnu_processName && _gnu_arguments && _gnu_environment,
	   _GNU_MISSING_MAIN_FUNCTION_CALL);

  if (!_gnu_sharedProcessInfoObject)
    _gnu_sharedProcessInfoObject = [[_NSConcreteProcessInfo alloc] init];
		
  return _gnu_sharedProcessInfoObject;
}

/*************************************************************************
 *** Returning Process Information
 *************************************************************************/
- (NSArray *)arguments
{
  return [[_gnu_arguments copyWithZone:[self zone]] autorelease];
}

- (NSDictionary *)environment
{
  return [[_gnu_environment copyWithZone:[self zone]] autorelease];
}

- (NSString *)hostName
{
  if (!_gnu_hostName) {
    char *hn = NSZoneMalloc([self zone], _GNU_MAX_HOST_NAMELEN);
		
    gethostname(hn, _GNU_MAX_HOST_NAMELEN);
    _gnu_hostName = [NSString stringWithCString:hn];
    [_gnu_hostName retain];
    NSZoneFree([self zone], hn);
  }
	
  return [[_gnu_hostName copyWithZone:[self zone]] autorelease];
}

- (NSString *)processName
{
  return [[_gnu_processName copyWithZone:[self zone]] autorelease];
}

- (NSString *)globallyUniqueString
{
  // $$$ The format of the string is not specified by the OpenStep 
  // specification. It could be useful to change this format after
  // NeXTSTEP release 4.0 comes out.
  return [NSString stringWithFormat:@"%@:%d:[%@]",
		   [self hostName],(int)getpid(),[[NSDate date] description]];
}

/*************************************************************************
 *** Specifying a Process Name
 *************************************************************************/
- (void)setProcessName:(NSString *)newName
{
  if (newName && [newName length]) {
    [_gnu_processName autorelease];
    _gnu_processName = [newName copyWithZone:[self zone]];
  }
  return;
}

@end

