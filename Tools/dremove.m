/* This is a simple tool to remove defaults information
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1997

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
    
   You should have received a copy of the GNU General Public  
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include "config.h"
#include	<Foundation/NSArray.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSAutoreleasePool.h>


int
main(int argc, char** argv)
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    NSUserDefaults	*defs;
    NSProcessInfo	*proc;
    NSArray		*args;
    NSMutableDictionary	*domain;
    NSString		*owner;
    NSString		*name;
    NSString		*user = nil;
    int			i;

    proc = [NSProcessInfo processInfo];
    if (proc == nil) {
	NSLog(@"unable to get process information!\n");
	[pool release];
	exit(0);
    }

    args = [proc arguments];

    for (i = 1; i < [args count]; i++) {
        if ([[args objectAtIndex: i] isEqual: @"--help"]) {
	    printf(
"The 'dremove' command lets you delete entries in a user's defaults database.\n"
"WARNING - this program is obsolete - please use 'defaults delete' instead.\n\n"
"The value written must be a property list and must be enclosed in quotes.\n"
"If you have write access to another user's database, you may include\n"
"the '-u' flag to modify that user's database rather than your own.\n\n");
	    printf(
"dremove [-u uname] -g key\n"
"    removed the named default to the global domain.\n\n");
	    printf(
"dremove [-u uname] -o domain\n"
"    removed the named domain and all its contents.\n\n");
	    printf(
"dremove [-u uname] domain key\n"
"    remove default with name 'key' from domain 'domain'.\n\n");
	    printf(
"dremove\n"
"    read the standard input for a series of lines listing domain name and\n"
"    default key pairs to be removed.  Domain names and default keys must be\n"
"    separated by spaces.\n");
	    [pool release];
	    exit(0);
	}
    }

    i = 1;
    if ([args count] > i && [[args objectAtIndex: i] isEqual: @"-u"]) {
	if ([args count] > ++i) {
	    user = [args objectAtIndex: i++];
	}
	else {
	    NSLog(@"no name supplied for -u option!\n");
	    [pool release];
	    exit(0);
	}
    }

    if (user) {
	defs = [[NSUserDefaults alloc] initWithUser: user];
    }
    else {
        defs = [NSUserDefaults standardUserDefaults];
    }
    if (defs == nil) {
	NSLog(@"unable to access defaults database!\n");
	[pool release];
	exit(0);
    }

    if ([args count] == i) {
	char	buf[BUFSIZ*10];

	while (fgets(buf, sizeof(buf), stdin) != 0) {
	    char	*ptr;
	    char	*start;

	    start = buf;

	    ptr = start;
	    while (*ptr && !isspace(*ptr)) {
		ptr++;
	    }
	    if (*ptr) {
		*ptr++ = '\0';
	    }
	    while (isspace(*ptr)) {
		ptr++;
	    }
	    if (*start == '\0') {
		printf("dremove: invalid input\n");
		[pool release];
		exit(0);
	    }
	    owner = [NSString stringWithCString: start];
	    start = ptr;

	    ptr = start;
	    while (*ptr && !isspace(*ptr)) {
		ptr++;
	    }
	    if (*ptr) {
		*ptr++ = '\0';
	    }
	    while (isspace(*ptr)) {
		ptr++;
	    }
	    if (*start == '\0') {
		printf("dremove: invalid input\n");
		[pool release];
		exit(0);
	    }
	    name = [NSString stringWithCString: start];
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil || [domain objectForKey: name] == nil) {
		printf("dremove: couldn't remove %s owned by %s\n",
		    [name cString], [owner cString]);
	    }
	    else {
		[domain removeObjectForKey: name];
		[defs setPersistentDomain: domain forName: owner];
	    }
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-g"]) {
	owner = NSGlobalDomain;
	if ([args count] > ++i) {
	    name = [args objectAtIndex: i];
	}
	else {
	    NSLog(@"no key supplied for -g option.\n");
	    [pool release];
	    exit(0);
	}
	domain = [[defs persistentDomainForName: owner] mutableCopy];
	if (domain == nil || [domain objectForKey: name] == nil) {
	    printf("dremove: couldn't remove %s owned by %s\n",
		[name cString], [owner cString]);
	}
	else {
	    [domain removeObjectForKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-o"]) {
	if ([args count] > ++i) {
	    owner = [args objectAtIndex: i];
	}
	else {
	    NSLog(@"no domain supplied for -o option.\n");
	    [pool release];
	    exit(0);
	}
        [defs removePersistentDomainForName: owner];
    }
    else {
        if ([args count] > i+1) {
	    owner = [args objectAtIndex: i];
	    name = [args objectAtIndex: ++i];
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil || [domain objectForKey: name] == nil) {
		printf("dremove: couldn't remove %s owned by %s\n",
		    [name cString], [owner cString]);
	    }
	    else {
		[domain removeObjectForKey: name];
		[defs setPersistentDomain: domain forName: owner];
	    }
	}
	else {
	    NSLog(@"got app name '%s' but no variable name.\n",
			    [[args objectAtIndex: 0] cString]);
	    [pool release];
	    exit(0);
	}
    }

    /* We don't want dremove in the defaults database - so remove it. */
    [defs removePersistentDomainForName: [proc processName]];
    if ([defs synchronize] == NO) {
	NSLog(@"unable to write to defaults database - %s\n", strerror(errno));
    }

    [pool release];
    exit(0);
}


