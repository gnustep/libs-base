/* nsbundle - Program to test out dynamic linking via NSBundle.
   Copyright (C) 1993,1994,1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Jul 1995
	 
   This file is part of the GNUstep Base Library.
	    
*/
#ifndef __MINGW32__
#include <sys/param.h>
#endif
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
    
    printf("  GNUstep bundle directory is %s\n", [[[NSBundle gnustepBundle] bundlePath] cString]);

    path = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
    printf("  Executable is in %s\n", [path cString]);
    path = [NSBundle _absolutePathOfExecutable: path];
    if (!path) {
	fprintf(stderr, "* ERROR: Can't find executable\n");
	exit(1);
    }
    printf("  Full directory is %s\n", [path cString]);

    printf("Looking for LoadMe bundle...\n");
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    printf("  Bundle directory is %s\n", [path cString]);
    path = [NSBundle pathForResource:@"LoadMe" ofType:@"bundle"
                     inDirectory: path];
    if (!path) {
	fprintf(stderr, "* ERROR: Can't find LoadMe bundle\n");
	exit(1);
    }
    printf("  Found LoadMe in: %s\n\n", [path cString]);

    printf("Initializing LoadMe bundle...\n");
    bundle = [[NSBundle alloc] initWithPath:path];
    if (!bundle) {
	fprintf(stderr, "* ERROR: Can't init LoadMe bundle\n");
	exit(1);
    }
    path = [bundle pathForResource:@"NXStringTable" ofType:@"example"];
    if (!path) {
	fprintf(stderr, "* ERROR: Can't find example in LoadMe bundle\n");
	exit(1);
    }
    printf("  Found example file: %s\n\n", [path cString]);

    printf("Retreiving principal class...\n");
    NS_DURING
    	object = [bundle principalClass];
    NS_HANDLER
	object = nil;
	fprintf(stderr, "  ERROR: %s\n", [[localException reason] cString]);
        fprintf(stderr, "  Either there is a problem with dynamic loading,\n");
	fprintf(stderr, "  or there is no dynamic loader on your system\n");
	exit(1);
    NS_ENDHANDLER
    if (!object) {
	fprintf(stderr, "* ERROR: Can't find principal class\n");
	exit(1);
    }
    printf("  Principal class is: %s\n", object_get_class_name (object));

    printf("Testing LoadMe bundle classes...\n");
    printf("  This is LoadMe:\n");
    object = [[[bundle classNamed:@"LoadMe"] alloc] init];
    [object afterLoad];
    [object release];

    printf("\n  This is SecondClass:\n");
    object = [[[bundle classNamed:@"SecondClass"] alloc] init];
    [object printName];
    [object printMyName];
    [object release];

    [arp release];
    return 0;
}
