/* Implementation for GNUstep NSInvocation object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSMethodSignature.h>
#include <gnustep/base/Invocation.h>
#include <gnustep/base/behavior.h>

@implementation NSInvocation

+ (void) initialize
{
  if (self == [NSInvocation class])
    class_add_behavior (self, [MethodInvocation class]);
}

+ (NSInvocation*) invocationWithObjCTypes: (const char*) types
{
  return [[self alloc] initWithArgframe: NULL type: types];
}

+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)ms
{
  return [self invocationWithObjCTypes: [ms methodType]];
}

- (NSMethodSignature*) methodSignature
{
#if 0
  /* xxx This isn't really needed by the our implementation anyway. */
  [self notImplemented: _cmd];
#else
  SEL mysel = [self selector];
  const char * my_sel_type;
  if (mysel)
    {
      my_sel_type = sel_get_type(mysel);
      if (my_sel_type)
	return [NSMethodSignature signatureWithObjCTypes: my_sel_type];
      else
	return nil;
    }
#endif
  return nil;
}

/* All other methods come from the MethodInvocation behavior. */

@end
