/* This is a simple tool to read and display defaults information
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1997

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include	<Foundation/NSArray.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>


int
main(int argc, char** argv)
{
    NSUserDefaults	*defs;
    NSProcessInfo	*proc;
    NSArray		*args;
    NSArray		*domains;
    NSString		*owner;
    NSString		*name;
    int			i;

    [NSObject enableDoubleReleaseCheck: YES];

    proc = [NSProcessInfo processInfo];
    if (proc == nil) {
	NSLog(@"unable to get process information!\n");
	exit(0);
    }

    defs = [NSUserDefaults standardUserDefaults];
    if (defs == nil) {
	NSLog(@"unable to access defaults database!\n");
	exit(0);
    }

    args = [proc arguments];
    if ([args count] == 0) {
	NSLog(@"no arguments supplied!\n");
	exit(0);
    }

    if ([[args objectAtIndex: 0] isEqual: @"-g"]) {
	owner = NSGlobalDomain;
	name = [args objectAtIndex: 1];
    }
    else if ([[args objectAtIndex: 0] isEqual: @"-l"]) {
	owner = nil;
	name = nil;
    }
    else if ([[args objectAtIndex: 0] isEqual: @"-n"]) {
	owner = NSGlobalDomain;
	name = [args objectAtIndex: 1];
    }
    else if ([[args objectAtIndex: 0] isEqual: @"-o"]) {
	owner = [args objectAtIndex: 1];
	name = nil;
    }
    else {
        if ([args count] > 1) {
	    owner = [args objectAtIndex: 0];
	    name = [args objectAtIndex: 1];
	}
	else {
	    owner = NSGlobalDomain;
	    name = [args objectAtIndex: 0];
	}
    }

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
			id	obj = [dom objectForKey: key];

			printf("%s %s %s\n",
			    [domainName cString], [key cString],
			    [[obj description] cString]);
		    }
		}
		else {
		    id	obj = [dom objectForKey: name];

		    if (obj) {
		        printf("%s %s %s\n",
			    [domainName cString], [name cString],
			    [[obj description] cString]);
		    }
		    else {
			printf("dread: couldn't read default\n");
		    }
		}
	    }
	}
    }

    exit(0);
}


