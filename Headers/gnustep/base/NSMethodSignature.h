/* Interface for NSMethodSignature for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the Gnustep Base Library.

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

/* xxx Where does this go? */
/* Info about layout of arguments. */
typedef struct  
{
  int offset;
  int size;
  char *type;
} NSArgumentInfo;

@interface NSMethodSignature : NSObject
{
  char *types;
  char *returnTypes;
  unsigned argFrameLength;
  unsigned returnFrameLength;
  unsigned numArgs;
}

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types;

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index;
- (unsigned) frameLength;
- (BOOL) isOneway;
- (unsigned) methodReturnLength;
- (char*) methodReturnType;
- (unsigned) numberOfArguments;

@end

#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */
