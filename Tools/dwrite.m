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
    NSString		*user = nil;
    const char		*text;
    const char		*str;
    id			obj = nil;
    int			i;

    proc = [NSProcessInfo processInfo];
    if (proc == nil) {
	NSLog(@"unable to get process information!\n");
	exit(0);
    }

    args = [proc arguments];

    for (i = 0; i < [args count]; i++) {
        if ([[args objectAtIndex: i] isEqual: @"--help"]) {
	    printf(
"The 'dwrite' command lets you modify a user's defaults database.\n"
"WARNING - this program is obsolete - please use 'defaults write' instead.\n\n"
"The value written must be a property list and (if being read from standard\n"
"input) must be enclosed in single quotes unless it is a simple alphanumeric\n"
"string.\n"
"Quotes appearing inside a quoted property list must be repeated to avoid\n"
"their being interpreted as the end of the property list.\n"
"If you have write access to another user's database, you may include\n"
"the '-u' flag to modify that user's database rather than your own.\n\n");
	    printf(
"dwrite [-u uname] -g key value\n"
"    write the named default to the global domain.\n\n");
	    printf(
"dwrite [-u uname] domain key value\n"
"    write default with name 'key' to domain 'domain'.\n\n");
	    printf(
"dwrite\n"
"    read the standard input for a series of lines listing defaults to be\n"
"    written.  Domain names, default keys, and default values must be\n"
"    separated on each line by spaces.\n");
	    exit(0);
	}
    }

    i = 0;
    if ([args count] > i && [[args objectAtIndex: i] isEqual: @"-u"]) {
	if ([args count] > ++i) {
	    user = [args objectAtIndex: i++];
	}
	else {
	    NSLog(@"no name supplied for -u option!\n");
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
	exit(0);
    }
    /* We don't want dwrite in the defaults database - so remove it. */
    [defs removePersistentDomainForName: [proc processName]];

    if ([args count] == i) {
	char	buf[BUFSIZ*10];

	while (fgets(buf, sizeof(buf), stdin) != 0) {
	    char	*ptr;
	    char	*start;

	    obj = nil;
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
		printf("dwrite: invalid input - nul domain name\n");
		exit(0);
	    }
	    for (str = start; *str; str++) {
		if (isspace(*str)) {
		    printf("dwrite: invalid input - space in domain name.\n");
		    exit(0);
		}
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
		printf("dwrite: invalid input - nul default name.\n");
		exit(0);
	    }
	    for (str = start; *str; str++) {
		if (isspace(*str)) {
		    printf("dwrite: invalid input - space in default name.\n");
		    exit(0);
		}
	    }
	    name = [NSString stringWithCString: start];
	    start = ptr;

	    if (*start == '\'') {
		for (ptr = ++start; ; ptr++) {
		    if (*ptr == '\0') {
			if (fgets(ptr, sizeof(buf) - (ptr-buf), stdin) == 0) {
			    printf("dwrite: invalid input - no final quote.\n");
			    exit(0);
			}
		    }
		    if (*ptr == '\'') {
			if (ptr[1] == '\'') {
			    strcpy(ptr, &ptr[1]);
			}
			else {
			    break;
			}
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
		    printf("dwrite: invalid input - empty property list\n");
		    exit(0);
		}
		obj = [NSString stringWithCString: start];
		if (*start == '(' || *start == '{' || *start == '<') {
		    id	tmp = [obj propertyList];

		    if (tmp == nil) {
		        printf("dwrite: invalid input - bad property list\n");
		        exit(0);
		    }
		    else {
			obj = tmp;
		    }
		}
	    }
	    domain = [[defs persistentDomainForName: owner] mutableCopy];
	    if (domain == nil) {
		domain = [NSMutableDictionary dictionaryWithCapacity:1];
	    }
	    [domain setObject: obj forKey: name];
	    [defs setPersistentDomain: domain forName: owner];
	}
    }
    else if ([[args objectAtIndex: i] isEqual: @"-g"]) {
        if ([args count] > i+2) {
	    owner = NSGlobalDomain;
	    name = [args objectAtIndex: ++i];
	    for (str = [name cString]; *str; str++) {
		if (isspace(*str)) {
		    printf("dwrite: invalid input - space in default name.\n");
		    exit(0);
		}
	    }
	    value = [args objectAtIndex: ++i];
	    text = [value cStringNoCopy];
	    if (*text == '(' || *text == '{' || *text == '<') {
		obj = [value propertyList];
	    }
	    else {
		obj = value;
	    }
	    if (obj == nil) {
		printf("dwrite: invalid input - bad property list\n");
		exit(0);
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
        if ([args count] > i+2) {
	    owner = [args objectAtIndex: i];
	    for (str = [owner cString]; *str; str++) {
		if (isspace(*str)) {
		    printf("dwrite: invalid input - space in domain name.\n");
		    exit(0);
		}
	    }
	    name = [args objectAtIndex: ++i];
	    for (str = [name cString]; *str; str++) {
		if (isspace(*str)) {
		    printf("dwrite: invalid input - space in default name.\n");
		    exit(0);
		}
	    }
	    value = [args objectAtIndex: ++i];
	    text = [value cStringNoCopy];
	    if (*text == '(' || *text == '{' || *text == '<') {
		obj = [value propertyList];
	    }
	    else {
		obj = value;
	    }
	    if (obj == nil) {
		printf("dwrite: invalid input - bad property list\n");
		exit(0);
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

    [defs synchronize];

    exit(0);
}


