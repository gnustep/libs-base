/* Interface for NSMethodSignature for GNUStep
   Copyright (C) 1995, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   Rewritten:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998
   
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

#ifndef __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#define __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

/*
 *	Info about layout of arguments.
 *	Extended from the original OpenStep version to let us know if the
 *	arg is passed in registers or on the stack.
 *
 *	NB. This no longer exists in Rhapsody/MacOS.
 */
typedef struct	{
  int		offset;
  unsigned	size;
  const char	*type;
  unsigned	align;
  unsigned	qual;
  BOOL		isReg;
} NSArgumentInfo;

@interface NSMethodSignature : NSObject
{
    const char		*methodTypes;
    unsigned		argFrameLength;
    unsigned		numArgs;
    NSArgumentInfo	*info;
}

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types;

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index;
- (unsigned) frameLength;
- (const char*) getArgumentTypeAtIndex: (unsigned)index;
- (BOOL) isOneway;
- (unsigned) methodReturnLength;
- (const char*) methodReturnType;
- (unsigned) numberOfArguments;

@end

@interface NSMethodSignature(GNU)
- (NSArgumentInfo*) methodInfo;
- (const char*) methodType;
@end
#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */
