/* Implementation of NSMethodSignature for GNUStep
   Copyright (C) 1994, 1995, 1996, 1998 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   Rewritten:   Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1998
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <config.h>
#include <base/preface.h>
#include <mframe.h>

#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>


@implementation NSMethodSignature

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)t
{
    NSMethodSignature *newMs = [[NSMethodSignature alloc] autorelease];

    newMs->methodTypes = mframe_build_signature(t, &newMs->argFrameLength,
		&newMs->numArgs, 0); 

    return newMs;
}

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index
{
    if (index >= numArgs) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Index too high."];
    }
    if (info == 0) {
	[self methodInfo];
    }
    return info[index+1];
}

- (unsigned) frameLength
{
    return argFrameLength;
}

- (const char*) getArgumentTypeAtIndex: (unsigned)index
{
    if (index >= numArgs) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Index too high."];
    }
    if (info == 0) {
	[self methodInfo];
    }
    return info[index+1].type;
}

- (BOOL) isOneway
{
    if (info == 0) {
	[self methodInfo];
    }
    return (info[0].qual & _F_ONEWAY) ? YES : NO;
}

- (unsigned) methodReturnLength
{
    if (info == 0) {
	[self methodInfo];
    }
    return info[0].size;
}

- (const char*) methodReturnType
{
    if (info == 0) {
	[self methodInfo];
    }
    return info[0].type;
}

- (unsigned) numberOfArguments
{
    return numArgs;
}

- (void) dealloc
{
    if (methodTypes)
	objc_free((void*)methodTypes);
    if (info)
	objc_free((void*)info);
    [super dealloc];
}

@end

@implementation NSMethodSignature(GNU)
- (NSArgumentInfo*) methodInfo
{
    if (info == 0) {
	const char	*types = methodTypes;
	int		i;

	info = objc_malloc(sizeof(NSArgumentInfo)*(numArgs+1));
	for (i = 0; i <= numArgs; i++) {
	    types = mframe_next_arg(types, &info[i]);
	}
    }
    return info;
}

- (const char*) methodType
{
    return methodTypes;
}
@end
