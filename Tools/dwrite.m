/* This is a simple tool to write defaults information to the database
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
    NSString		*value;
    const char		*text;
    id			obj = nil;
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
	char	buf[BUFSIZ*10];

	while (fgets(buf, sizeof(buf), stdin) != 0) {
	    char	*ptr;
	    char	*start;

	    obj = nil;
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
		printf("dwrite: invalid input\n");
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
		printf("dwrite: invalid input\n");
		exit(0);
	    }
	    name = [NSString stringWithCString: start];
	    start = ptr;

	    if (*start == '(' || *start == '{' || *start == '<') {
		ptr = &start[strlen(start)-1];
		while (isspace(*ptr)) {
		    *ptr-- = '\0';
		}
	        value = [NSString stringWithCString: start];
		while ((obj = [value propertyList]) == nil) {
		    if (fgets(buf, sizeof(buf), stdin) != 0) {
			ptr = &buf[strlen(buf)-1];
			while (isspace(*ptr)) {
			    *ptr-- = '\0';
			}
		        value = [value stringByAppendingString: @"\n"];
			value = [value stringByAppendingString:
					[NSString stringWithCString: buf]];
		    }
		    else {
			printf("dwrite: invalid input\n");
			exit(0);
		    }
		}
	    }
	    else if (*start == '"') {
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
	    if (obj == nil) {
		if (*ptr) {
		    *ptr++ = '\0';
		}
		if (*start == '\0') {
		    printf("dwrite: invalid input\n");
		    exit(0);
		}
		obj = [NSString stringWithCString: start];
	    }
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil) {
		domain = [NSMutableDictionary dictionaryWithCapacity:1];
	    }
	    [domain setObject: obj forKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
    }
    else if ([[args objectAtIndex: 0] isEqual: @"-g"]) {
        if ([args count] > 2) {
	    owner = NSGlobalDomain;
	    name = [args objectAtIndex: 1];
	    value = [args objectAtIndex: 2];
	    text = [value cStringNoCopy];
	    if (*text == '(' || *text == '{' || *text == '<') {
		obj = [value propertyList];
	    }
	    if (obj == nil) {
		obj = value;
	    }
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil) {
		domain = [NSMutableDictionary dictionaryWithCapacity:1];
	    }
	    [domain setObject: obj forKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
	else {
	    NSLog(@"too few arguments supplied!\n");
	    exit(0);
	}
    }
    else {
        if ([args count] > 2) {
	    owner = [args objectAtIndex: 0];
	    name = [args objectAtIndex: 1];
	    value = [args objectAtIndex: 2];
	    text = [value cStringNoCopy];
	    if (*text == '(' || *text == '{' || *text == '<') {
		obj = [value propertyList];
	    }
	    if (obj == nil) {
		obj = value;
	    }
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil) {
		domain = [NSMutableDictionary dictionaryWithCapacity:1];
	    }
	    [domain setObject: obj forKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
	else {
	    NSLog(@"too few arguments supplied!\n");
	    exit(0);
	}
    }

    /* We don't want dwrite in the defaults database - so remove it. */
    [defs removePersistentDomainForName: [proc processName]];
    [defs synchronize];

    exit(0);
}


