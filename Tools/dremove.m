/* This is a simple tool to remove defaults information
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
    NSMutableDictionary	*domain;
    NSString		*owner;
    NSString		*name;

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
	char	buf[BUFSIZ*10];

	while (fgets(buf, sizeof(buf), stdin) != 0) {
	    char	*ptr;
	    char	*start;

	    start = buf;

	    if (*start == '"') {
		for (ptr = ++start; *ptr; ptr++) {
		    if (*ptr == '\\' && ptr[1] != '\0') {
			ptr++;
		    }
		    else if (*ptr == '"') {
			break;
		    }
		}
	    }
	    else {
		ptr = start;
		while (*ptr && !isspace(*ptr)) {
		    ptr++;
		}
	    }
	    if (*ptr) {
		*ptr++ = '\0';
	    }
	    while (isspace(*ptr)) {
		ptr++;
	    }
	    if (*start == '\0') {
		printf("dremove: invalid input\n");
		exit(0);
	    }
	    owner = [NSString stringWithCString: start];
	    start = ptr;

	    if (*start == '"') {
		for (ptr = ++start; *ptr; ptr++) {
		    if (*ptr == '\\' && ptr[1] != '\0') {
			ptr++;
		    }
		    else if (*ptr == '"') {
			break;
		    }
		}
	    }
	    else {
		ptr = start;
		while (*ptr && !isspace(*ptr)) {
		    ptr++;
		}
	    }
	    if (*ptr) {
		*ptr++ = '\0';
	    }
	    while (isspace(*ptr)) {
		ptr++;
	    }
	    if (*start == '\0') {
		printf("dremove: invalid input\n");
		exit(0);
	    }
	    name = [NSString stringWithCString: start];
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil || [domain objectForKey: name] == nil) {
		printf("dremoveL couldn't remove %s owned by %s\n",
		    [name quotedCString], [owner quotedCString]);
	    }
	    else {
		[domain removeObjectForKey: name];
		[defs setPersistentDomain: domain forName: owner];
	    }
	}
    }
    else if ([[args objectAtIndex: 0] isEqual: @"-g"]) {
	owner = NSGlobalDomain;
	name = [args objectAtIndex: 1];
	domain = [[defs persistentDomainForName: owner] mutableCopy];
	if (domain == nil || [domain objectForKey: name] == nil) {
	    printf("dremoveL couldn't remove %s owned by %s\n",
		[name quotedCString], [owner quotedCString]);
	}
	else {
	    [domain removeObjectForKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
    }
    else {
        if ([args count] > 1) {
	    owner = [args objectAtIndex: 0];
	    name = [args objectAtIndex: 1];
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil || [domain objectForKey: name] == nil) {
		printf("dremoveL couldn't remove %s owned by %s\n",
		    [name quotedCString], [owner quotedCString]);
	    }
	    else {
		[domain removeObjectForKey: name];
		[defs setPersistentDomain: domain forName: owner];
	    }
	}
	else {
	    NSLog(@"got app name '%s' but no variable name.\n",
			    [[args objectAtIndex: 0] cString]);
	    exit(0);
	}
    }

    /* We don't want dremove in the defaults database - so remove it. */
    [defs removePersistentDomainForName: [proc processName]];
    if ([defs synchronize] == NO) {
	NSLog(@"unable to write to defaults database - %s\n", strerror(errno));
    }

    exit(0);
}


