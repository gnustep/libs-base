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
#include "LoadMe.h"
#include "SecondClass.h"
#include "MyCategory.h"

int 
main(int ac, char *av[]) 
{
    NSBundle *main;
    NSBundle *bundle;
    NSString *path;
    id object;
    
    main = [NSBundle mainBundle];
    printf("Looking for main bundle...\n");
    if (!main) {
	fprintf(stderr, "* ERROR: Can't get main bundle\n");
	exit(1);
    }
    printf("  Main bundle directory is %s\n", [[main bundlePath] cString]);

    printf("Looking for LoadMe bundle...\n");
    path = [main pathForResource:@"LoadMe" ofType:@"bundle"];
    if (!path) {
	fprintf(stderr, "* ERROR: Can't find LoadMe bundle in main bundle\n");
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

    return 0;
}
