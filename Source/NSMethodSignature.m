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
  NSMethodSignature *newMs;

  if (t == 0 || *t == '\0')
    {
      return nil;
    }
  newMs = AUTORELEASE([NSMethodSignature alloc]);
  newMs->_methodTypes = mframe_build_signature(t, &newMs->_argFrameLength,
    &newMs->_numArgs, 0); 

  return newMs;
}

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index
{
  if (index >= _numArgs)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Index too high."];
    }
  if (_info == 0)
    {
      [self methodInfo];
    }
  return _info[index+1];
}

- (unsigned) frameLength
{
  return _argFrameLength;
}

- (const char*) getArgumentTypeAtIndex: (unsigned)index
{
  if (index >= _numArgs)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Index too high."];
    }
  if (_info == 0)
    {
      [self methodInfo];
    }
  return _info[index+1].type;
}

- (BOOL) isOneway
{
  if (_info == 0)
    {
      [self methodInfo];
    }
  return (_info[0].qual & _F_ONEWAY) ? YES : NO;
}

- (unsigned) methodReturnLength
{
  if (_info == 0)
    {
      [self methodInfo];
    }
  return _info[0].size;
}

- (const char*) methodReturnType
{
  if (_info == 0)
    {
      [self methodInfo];
    }
  return _info[0].type;
}

- (unsigned) numberOfArguments
{
  return _numArgs;
}

- (void) dealloc
{
  if (_methodTypes)
    NSZoneFree(NSDefaultMallocZone(), (void*)_methodTypes);
  if (_info)
    NSZoneFree(NSDefaultMallocZone(), (void*)_info);
  [super dealloc];
}

@end

@implementation NSMethodSignature(GNU)
- (NSArgumentInfo*) methodInfo
{
  if (_info == 0)
    {
      const char	*types = _methodTypes;
      int		i;

      _info = NSZoneMalloc(NSDefaultMallocZone(),
	sizeof(NSArgumentInfo)*(_numArgs+1));
      for (i = 0; i <= _numArgs; i++)
	{
	  types = mframe_next_arg(types, &_info[i]);
	}
    }
  return _info;
}

- (const char*) methodType
{
  return _methodTypes;
}
@end
