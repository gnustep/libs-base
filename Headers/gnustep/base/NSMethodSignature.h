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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#define __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#ifndef	STRICT_MACOS_X
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
#ifndef	NO_GNUSTEP
  unsigned	align;
  unsigned	qual;
  BOOL		isReg;
#endif
} NSArgumentInfo;
#endif

@interface NSMethodSignature : NSObject
{
  const char		*_methodTypes;
  unsigned		_argFrameLength;
  unsigned		_numArgs;
#ifdef	STRICT_MACOS_X
  void			*_dummy;
#else
  NSArgumentInfo	*_info;
#endif
}

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types;

#ifndef	STRICT_MACOS_X
- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index;
#endif
- (unsigned) frameLength;
- (const char*) getArgumentTypeAtIndex: (unsigned)index;
- (BOOL) isOneway;
- (unsigned) methodReturnLength;
- (const char*) methodReturnType;
- (unsigned) numberOfArguments;

@end

#ifndef	NO_GNUSTEP
@interface NSMethodSignature(GNUstep)
- (NSArgumentInfo*) methodInfo;
- (const char*) methodType;
@end
#endif

#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */
