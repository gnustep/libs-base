/* Implementation of NSMethodSignature for GNUStep
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
   This file is part of the GNU Objective C Class Library.

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

#include "foundation/NSMethodSignature.h"
#include "objc/objc-malloc.h"

static int
types_get_size_of_arguments(const char *types)
{
  const char* type = objc_skip_typespec (types);
  return atoi (type);
}

static int
types_get_number_of_arguments (const char *types)
{
  int i = 0;
  const char* type = types;
  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
}

@implementation NSMethodSignature

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types
{
  int len;
  NSMethodSignature *newMs = [NSMethodSignature alloc];
  len = strlen(types);
  OBJC_MALLOC(newMs->types, char, len);
  bcopy(types, newMs->types, len);
  len = str??();
  OBJC_MALLOC(newMs->returnTypes, char, len);
  bcopy(types, newMs->returnTypes, len);
  newMs->argFrameLength = types_get_size_of_arguments(types);
  newMs->returnFrameLength = objc_size_of_type(types);
  newMs->numArgs = types_get_number_of_arguments(types);
  return newMs;
}

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index
{
  return 0;
}

- (unsigned) frameLength
{
  return argFrameLength;
}

- (BOOL) isOneway
{
  [self notImplemented:_cmd];
  return NO;
}

- (unsigned) methodReturnLength
{
  return returnFrameLength;
}

- (char*) methodReturnType
{
  return "";
}

- (unsigned) numberOfArguments
{
  return numArgs;
}

- (void) dealloc
{
  OBJC_FREE(types);
  [super dealloc];
}

@end
