/** Implementation of NSProtocolChecker for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Mike Kienenberger
   Date: Jun 1998
   Rewrite: Richard Frith-Macdonald
   Date: April 2004

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

   <title>NSProtocolChecker class reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSProtocolChecker.h"
#include "Foundation/NSException.h"
#include "Foundation/NSInvocation.h"
#include "Foundation/NSMethodSignature.h"

@implementation NSProtocolChecker

/**
 * Allocates and initializes an NSProtocolChecker instance that will
 * forward any messages in the aProtocol protocol to anObject, its
 * target. Thus, the checker can be vended in lieu of anObject to
 * restrict the messages that can be sent to anObject. Returns the
 * new instance.
 */
+ (id) protocolCheckerWithTarget: (NSObject*)anObject
			protocol: (Protocol*)aProtocol
{
  return AUTORELEASE([[NSProtocolChecker alloc] initWithTarget: anObject
						      protocol: aProtocol]);
}

- (void) dealloc
{
  DESTROY(_myTarget);
  [super dealloc];
}

/*
 * Forwards any message to the delegate if the method is declared in
 * the checker's protocol; otherwise raises an NSInvalidArgumentException.
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  if (GSObjCIsInstance(_myTarget))
    {
      if (![_myProtocol descriptionForInstanceMethod: [anInvocation selector]])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s -%@> not declared",
	    [_myProtocol name], NSStringFromSelector([anInvocation selector])];
	}
    }
  else
    {
      if (![_myProtocol descriptionForClassMethod: [anInvocation selector]])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s +%@> not declared",
	    [_myProtocol name], NSStringFromSelector([anInvocation selector])];
	}
    }
  [anInvocation invokeWithTarget: _myTarget];
}

- (id) init
{
  self = [self initWithTarget: nil protocol: nil];
  return self;
}

/**
 * Initializes a newly allocated NSProtocolChecker instance that will
 * forward any messages in the aProtocol protocol to anObject, its
 * delegate. Thus, the checker can be vended in lieu of anObject to
 * restrict the messages that can be sent to anObject. If anObject is
 * allowed to be freed or dereferenced by clients, the free method
 * should be included in aProtocol. Returns the new instance.
 */
- (id) initWithTarget: (NSObject*)anObject protocol: (Protocol*)aProtocol
{
  _myProtocol = aProtocol;
  ASSIGN(_myTarget, anObject);
  return self;
}

- (IMP) methodForSelector: (SEL)aSelector
{
  return get_imp(GSObjCClass((id)self), aSelector);
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  if (aSelector == _cmd || [self respondsToSelector: aSelector] == YES)
    {
      return [_myTarget methodSignatureForSelector: aSelector];
    }
  return nil;
}

/**
 * Returns the protocol object the checker uses to verify whether a
 * given message should be forwarded to its delegate.
 */
- (Protocol*) protocol
{
  return _myProtocol;
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
  if (GSObjCIsInstance(_myTarget))
    {
      if ([_myProtocol descriptionForInstanceMethod: aSelector])
	{
	  return YES;
	}
    }
  else
    {
      if ([_myProtocol descriptionForClassMethod: aSelector])
	{
	  return YES;
	}
    }
  return NO;
}

/**
 * Returns the target of the NSProtocolChecker.
 */
- (NSObject*) target
{
  return _myTarget;
}

@end
