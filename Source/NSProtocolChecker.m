/** Implementation of NSProtocolChecker for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Original by:  Mike Kienenberger
   Date: Jun 1998
   Written: Richard Frith-Macdonald
   Date: April 2004

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSProtocolChecker class reference</title>
   $Date$ $Revision$
   */

#import "config.h"
#define	EXPOSE_NSProtocolChecker_IVARS	1
#import "GNUstepBase/preface.h"
#import "Foundation/NSProtocolChecker.h"
#import "Foundation/NSException.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"
#include <objc/Protocol.h>

/**
 * The NSProtocolChecker and NSProxy classes provide message filtering and
 * forwarding capabilities. If you wish to ensure at runtime that a given
 * object will only be sent messages in a certain protocol, you create an
 * <code>NSProtocolChecker</code> instance with the protocol and the object as
 * arguments-

<example>
    id versatileObject = [[ClassWithManyMethods alloc] init];
    id narrowObject = [NSProtocolChecker protocolCheckerWithTarget: versatileObject
                                         protocol: @protocol(SomeSpecificProtocol)];
    return narrowObject;
</example>

 * This is often used in conjunction with distributed objects to expose only a
 * subset of an objects methods to remote processes
 */
@implementation NSProtocolChecker

/**
 * Allocates and initializes an NSProtocolChecker instance by calling
 * -initWithTarget:protocol:<br />
 * Autoreleases and returns the new instance.
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

- (struct objc_method_description*) _methodDescription: (SEL)aSelector
{
  extern struct objc_method_description	*GSDescriptionForInstanceMethod();
  extern struct objc_method_description	*GSDescriptionForClassMethod();

  if (_myProtocol != nil && _myTarget != nil)
    {
      struct objc_method_description* mth;

      /* Older gcc versions may not initialise Protocol objects properly
       * so we have an evil hack which checks for a known bad value of
       * the class pointer, and uses an internal function
       * (implemented in NSObject.m) to examine the protocol contents
       * without sending any ObjectiveC message to it.
       */
      if (GSObjCIsInstance(_myTarget))
	{
	  if ((uintptr_t)GSObjCClass(_myProtocol) == 0x2)
	    {
	      mth = GSDescriptionForInstanceMethod(_myProtocol, aSelector);
	    }
	  else
	    {
	      mth = [_myProtocol descriptionForInstanceMethod: aSelector];
	    }
	}
      else
	{
	  if ((uintptr_t)GSObjCClass(_myProtocol) == 0x2)
	    {
	      mth = GSDescriptionForClassMethod(_myProtocol, aSelector);
	    }
	  else
	    {
	      mth = [_myProtocol descriptionForClassMethod: aSelector];
	    }
	}
      return mth;
    }
  return 0;
}

/**
 * Forwards any message to the delegate if the method is declared in
 * the checker's protocol; otherwise raises an
 * <code>NSInvalidArgumentException</code>.
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  const char	*type;

  if ([self _methodDescription: [anInvocation selector]] == 0)
    {
      if (GSObjCIsInstance(_myTarget))
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s -%@> not declared",
	    [_myProtocol name], NSStringFromSelector([anInvocation selector])];
	}
      else
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s +%@> not declared",
	    [_myProtocol name], NSStringFromSelector([anInvocation selector])];
	}
    }
  [anInvocation invokeWithTarget: _myTarget];

  /*
   * If the method returns 'self' (ie the target object) replace the
   * returned value with the protocol checker.
   */
  type = [[anInvocation methodSignature] methodReturnType];
  if (strcmp(type, @encode(id)) == 0)
    {
      id	buf;

      [anInvocation getReturnValue: &buf];
      if (buf == _myTarget)
	{
	  buf = self;
	  [anInvocation setReturnValue: &buf];
	}
    }
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
 * restrict the messages that can be sent to anObject. If any method
 * in the protocol returns anObject, the checker will replace the returned
 * value with itself rather than the target object.<br />
 * Returns the new instance.
 */
- (id) initWithTarget: (NSObject*)anObject protocol: (Protocol*)aProtocol
{
  _myProtocol = aProtocol;
  ASSIGN(_myTarget, anObject);
  return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  const char		*types;
  struct objc_method	*mth;
  Class			c;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  /*
   * Evil hack to prevent recursion - if we are asking a remote
   * object for a method signature, we can't ask it for the
   * signature of methodSignatureForSelector:, so we hack in
   * the signature required manually :-(
   */
  if (sel_eq(aSelector, _cmd))
    {
      static	NSMethodSignature	*sig = nil;

      if (sig == nil)
	{
	  sig = [NSMethodSignature signatureWithObjCTypes: "@@::"];
	  IF_NO_GC(RETAIN(sig);)
	}
      return sig;
    }

  if (_myProtocol != nil)
    {
      const char			*types = 0;
      struct objc_method_description	*desc;

      desc = [self _methodDescription: aSelector];
      if (desc != 0)
	{
	  types = desc->types;
	}
      if (types == 0)
	{
	  return nil;
	}
      return [NSMethodSignature signatureWithObjCTypes: types];
    }

  c = GSObjCClass(self);
  mth = GSGetMethod(c, aSelector, YES, YES);
  if (mth == 0)
    {
      return nil; // Method not implemented
    }
  types = mth->method_types;

  /*
   * If there are protocols that this class conforms to,
   * the method may be listed in a protocol with more
   * detailed type information than in the class itself
   * and we must therefore use the information from the
   * protocol.
   * This is because protocols also carry information
   * used by the Distributed Objects system, which the
   * runtime does not maintain in classes.
   */
  if (c->protocols != 0)
    {
      struct objc_protocol_list	*protocols = c->protocols;
      BOOL			found = NO;

      while (found == NO && protocols != 0)
	{
	  unsigned	i = 0;

	  while (found == NO && i < protocols->count)
	    {
	      Protocol				*p;
	      struct objc_method_description	*pmth;

	      p = protocols->list[i++];
	      if (c == (Class)self)
		{
		  pmth = [p descriptionForClassMethod: aSelector];
		}
	      else
		{
		  pmth = [p descriptionForInstanceMethod: aSelector];
		}
	      if (pmth != 0)
		{
		  types = pmth->types;
		  found = YES;
		}
	    }
	  protocols = protocols->next;
	}
    }

  if (types == 0)
    {
      return nil;
    }
  return [NSMethodSignature signatureWithObjCTypes: types];
}

/**
 * Returns the protocol object the checker uses to verify whether a
 * given message should be forwarded to its delegate.
 */
- (Protocol*) protocol
{
  return _myProtocol;
}

/**
 * Returns the target of the NSProtocolChecker.
 */
- (NSObject*) target
{
  return _myTarget;
}

@end
