/* nsbundle - Program to test out dynamic linking via NSBundle.
   Copyright (C) 1993,1994,1995, 1996 Free Software Foundation, Inc.

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Jul 1995
	
   This file is part of the GNUstep Base Library.
	
*/
#ifndef __MINGW32__
#include <sys/param.h>
#endif
#include "Foundation/NSArray.h"
#include "Foundation/NSBundle.h"
#include "Foundation/NSException.h"
#include "Foundation/NSString.h"
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include "LoadMe.h"
#include "SecondClass.h"
#include "MyCategory.h"

int
main(int argc, char *argv[], char **env)
{
    NSBundle *bundle;
    NSString *path;
    id object;
    NSAutoreleasePool	*arp;

#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
   [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
    arp = [NSAutoreleasePool new];

    setbuf(stdout, 0);
    /* Test bundle version and info files */
    bundle = [NSBundle bundleForLibrary: @"gnustep-base"];
    GSPrintf(stdout, @"  GNUstep Base Resources: %@\n", [bundle bundlePath]);
    object = [bundle infoDictionary];
    GSPrintf(stdout, @"  gnustep-base version string = %@\n",
    	     [object objectForKey: @"GSBundleShortVersionString"]);
    GSPrintf(stdout, @"  gnustep-base version number = %g\n\n",
    	     [[object objectForKey: @"GSBundleVersion"] doubleValue]);


    path = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
    printf("  Executable is in %s\n", [path cString]);
    path = [NSBundle _absolutePathOfExecutable: path];
    if (!path) {
	fprintf(stdout, "* ERROR: Can't find executable\n");
	exit(1);
    }
    printf("  Full directory is %s\n", [path cString]);

    printf("Looking for LoadMe bundle...\n");
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    if ([[path lastPathComponent] isEqualToString:@"Testing"] == NO)
      {
	/* Delete library combo */
	path = [path stringByDeletingLastPathComponent];
	path = [path stringByDeletingLastPathComponent];
	path = [path stringByDeletingLastPathComponent];
      }
    printf("  Bundle directory is %s\n", [path cString]);
    path = [NSBundle pathForResource:@"LoadMe" ofType:@"bundle"
                     inDirectory: path];
    if (!path) {
	fprintf(stdout, "* ERROR: Can't find LoadMe bundle\n");
	exit(1);
    }
    printf("  Found LoadMe in: %s\n\n", [path cString]);

    printf("Initializing LoadMe bundle...\n");
    bundle = [[NSBundle alloc] initWithPath:path];
    if (!bundle) {
	fprintf(stdout, "* ERROR: Can't init LoadMe bundle\n");
	exit(1);
    }
    path = [bundle pathForResource:@"NXStringTable" ofType:@"example"];
    if (!path) {
	fprintf(stdout, "* ERROR: Can't find example in LoadMe bundle\n");
	exit(1);
    }
    printf("  Found example file: %s\n\n", [path cString]);

    printf("Retreiving principal class...\n");
    NS_DURING
    	object = [bundle principalClass];
    NS_HANDLER
	object = nil;
	fprintf(stdout, "  ERROR: %s\n", [[localException reason] cString]);
        fprintf(stdout, "  Either there is a problem with dynamic loading,\n");
	fprintf(stdout, "  or there is no dynamic loader on your system\n");
	exit(1);
    NS_ENDHANDLER
    if (!object)
      {
	printf("* ERROR: Can't find principal class\n");
      }
    else
      printf("  Principal class is: %s\n", GSClassNameFromObject(object));

    printf("Testing LoadMe bundle classes...\n");
    printf("  This is LoadMe:\n");
    object = [[[bundle classNamed:@"LoadMe"] alloc] init];
    if (!object)
      {
	printf("* ERROR: Can't find LoadMe class\n");
      }
    else
      {
	[object afterLoad];
	[object release];
      }

    printf("\n  This is SecondClass:\n");
    object = [[[bundle classNamed:@"SecondClass"] alloc] init];
    if (!object)
      {
	printf("* ERROR: Can't find SecondClass class\n");
      }
    else
      {
	[object printName];
	[object printMyName];
	[object release];
      }


    [arp release];
    return 0;
}
