/* This is a simple tool to read and display defaults information
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

#include	<Foundation/NSArray.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSAutoreleasePool.h>


int
main(int argc, char** argv)
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    NSUserDefaults	*defs;
    NSProcessInfo	*proc;
    NSArray		*args;
    NSArray		*domains;
    NSString		*owner = nil;
    NSString		*name = nil;
    NSString		*user = nil;
    BOOL		found = NO;
    NSDictionary	*locale;
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
"\nThe 'dread' command lets you to read a user's defaults database.\n"
"WARNING - this program is obsolete - please use 'defaults read' instead.\n\n"
"Results are printed on standard output in a format suitable for input to\n"
"the 'dwrite' command.  The value of each default is quoted with \"'\" and\n"
"may wrap over line boundaries.\n"
"Single quotes used within a default value are repeated.\n\n"
"If you have read access to another user's defaults database, you may include\n"
"the '-u' flag to read that user's database rather than your own.\n\n");
	    printf(
"dread [-u uname] -g key\n"
"    read the named default from the global domain.\n\n");
	    printf(
"dread [-u uname] -l\n"
"    read all defaults from all domains.\n\n");
	    printf(
"dread [-u uname] -n key\n"
"    read values named 'key' from all domains.\n\n");
	    printf(
"dread [-u uname] -o domain\n"
"    read all defaults from the specified domain.\n\n");
	    printf(
"dread [-u uname] domain key\n"
"    read default with name 'key' from domain 'domain'.\n\n");
	    printf(
"dread [-u uname] key\n"
"    read default named 'key' from the global domain.\n");
	    [pool release];
	    exit(0);
	}
    }

    i = 1;
    if ([args count] <= i) {
	NSLog(@"too few arguments supplied!\n");
	[pool release];
	exit(0);
    }
    
    if ([[args objectAtIndex: i] isEqual: @"-u"]) {
	if ([args count] > ++i) {
	    user = [args objectAtIndex: i++];
	}
	else {
	    NSLog(@"no name supplied for -u option!\n");
	    [pool release];
	    exit(0);
	}
    }

    if ([args count] <= i) {
	NSLog(@"too few arguments supplied!\n");
	[pool release];
	exit(0);
    }

    if ([[args objectAtIndex: i] isEqual: @"-g"]) {
	owner = NSGlobalDomain;
	if ([args count] > ++i) {
	    name = [args objectAtIndex: i];
	}
	else {
	    NSLog(@"no key supplied for -g option!\n");
	    [pool release];
	    exit(0);
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-n"]) {
	owner = nil;
	if ([args count] > ++i) {
	    name = [args objectAtIndex: i];
	}
	else {
	    NSLog(@"no key supplied for -n option!\n");
	    [pool release];
	    exit(0);
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-o"]) {
	name = nil;
	if ([args count] > ++i) {
	    owner = [args objectAtIndex: i];
	}
	else {
	    NSLog(@"no domain name supplied for -o option!\n");
	    [pool release];
	    exit(0);
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-l"]) {
	owner = nil;
	name = nil;
    }
    else {
	if ([args count] > i+1) {
	    owner = [args objectAtIndex: i];
	    name = [args objectAtIndex: ++i];
	}
	else {
	    owner = NSGlobalDomain;
	    name = [args objectAtIndex: i];
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
    /* We don't want dwrite in the defaults database - so remove it. */
    [defs removePersistentDomainForName: [proc processName]];

    locale = [defs dictionaryRepresentation];
    domains = [defs persistentDomainNames];
    for (i = 0; i < [domains count]; i++) {
	NSString	*domainName = [domains objectAtIndex: i];

	if (owner == nil || [owner isEqual: domainName]) {
	    NSDictionary	*dom;

	    dom = [defs persistentDomainForName: domainName];
	    if (dom) {
		if (name == nil) {
		    NSEnumerator	*enumerator;
		    NSString		*key;

		    enumerator = [dom keyEnumerator];
		    while ((key = [enumerator nextObject]) != nil) {
			id		obj = [dom objectForKey: key];
			const char	*ptr;

			printf("%s %s '", [domainName cString], [key cString]);
			ptr = [[obj descriptionWithLocale: locale indent: 0]
			  cString];
			while (*ptr) {
			    if (*ptr == '\'') {
				putchar('\'');
			    }
			    putchar(*ptr);
			    ptr++;
			}
			printf("'\n");
		    }
		}
		else {
		    id		obj = [dom objectForKey: name];

		    if (obj) {
			const char	*ptr;

			printf("%s %s '", [domainName cString], [name cString]);
			ptr = [[obj descriptionWithLocale: locale indent: 0]
			  cString];
			while (*ptr) {
			    if (*ptr == '\'') {
				putchar('\'');
			    }
			    putchar(*ptr);
			    ptr++;
			}
			printf("'\n");
			found = YES;
		    }
		}
	    }
	}
    }

    if (found == NO && name != nil) {
	printf("dread: couldn't read default\n");
    }

    [pool release];
    exit(0);
}


