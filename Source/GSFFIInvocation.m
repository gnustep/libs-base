/** Implementation of GSFFIInvocation for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written: Adam Fedor <fedor@gnu.org>
   Date: Nov 2000
   
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

#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <base/GSInvocation.h>
#include <config.h>
#include <mframe.h>
#include "cifframe.h"

/* The FFI library doesn't have closures (well it does, but only for ix86), so
   we still use a lot of the argframe (mframe) functions for things like
   forwarding
*/

@implementation GSFFIInvocation

- (id) initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
{
  const char		*types;
  NSMethodSignature	*newSig;

  types = sel_get_type(aSelector);
  if (types == 0)
    {
      types = sel_get_type(sel_get_any_typed_uid(sel_get_name(aSelector)));
    }
  if (types == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Couldn't find encoding type for selector %s.",
			 sel_get_name(aSelector)];
    }
  newSig = [NSMethodSignature signatureWithObjCTypes: types];
  self = [self initWithMethodSignature: newSig];

  if (self)
    {
      [self setSelector: aSelector];
      /*
       *	Copy the _cframe we were given.
       */
      if (frame)
	{
	  int	i;

	  mframe_get_arg(frame, &_info[1], &_target);
	  for (i = 1; i <= _numArgs; i++)
	    {
	      mframe_get_arg(frame, &_info[i], 
			     ((cifframe_t *)_cframe)->values[i-1]);
	    }
	}
    }
  return self;
}

/*
 *	This is the de_signated initialiser.
 */
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature
{
  _sig = RETAIN(aSignature);
  _numArgs = [aSignature numberOfArguments];
  _info = [aSignature methodInfo];
  _cframe = cifframe_from_sig([_sig methodType], &_retval);
  if (_retval == 0 && _info[0].size > 0)
    {
      _retval = NSZoneMalloc(NSDefaultMallocZone(), _info[0].size);
    }
  return self;
}


- (void*) returnFrame: (arglist_t)argFrame
{
  return mframe_handle_return(_info[0].type, _retval, argFrame);
}
@end

