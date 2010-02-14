/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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

*/
#import "config.h"
#import "Foundation/NSException.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

/**
 * Extension methods for the NSObject class
 */
@implementation NSObject (GNUstepBase)

+ (id) notImplemented: (SEL)selector
{
  [NSException raise: NSGenericException
    format: @"method %@ not implemented in %s(class)",
    selector ? (id)NSStringFromSelector(selector) : (id)@"(null)",
    NSStringFromClass(self)];
  return nil;
}

- (BOOL) isInstance
{
  return GSObjCIsInstance(self);
}

- (id) notImplemented: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"method %@ not implemented in %@(%s)",
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)",
    NSStringFromClass([self class]),
    GSObjCIsInstance(self) ? "instance" : "class"];
  return nil;
}

- (id) shouldNotImplement: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"%@(%s) should not implement %@",
    NSStringFromClass([self class]),
    GSObjCIsInstance(self) ? "instance" : "class",
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return nil;
}

- (id) subclassResponsibility: (SEL)aSel
{
  [NSException raise: NSInvalidArgumentException
    format: @"subclass %@(%s) should override %@",
    NSStringFromClass([self class]),
    GSObjCIsInstance(self) ? "instance" : "class",
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return nil;
}

/**
 * WARNING: The -compare: method for NSObject is deprecated
 *          due to subclasses declaring the same selector with
 *          conflicting signatures.
 *          Comparison of arbitrary objects is not just meaningless
 *          but also dangerous as most concrete implementations
 *          expect comparable objects as arguments often accessing
 *          instance variables directly.
 *          This method will be removed in a future release.
 */
- (NSComparisonResult) compare: (id)anObject
{
  NSLog(@"WARNING: The -compare: method for NSObject is deprecated.");

  if (anObject == self)
    {
      return NSOrderedSame;
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"nil argument for compare:"];
    }
  if ([self isEqual: anObject])
    {
      return NSOrderedSame;
    }
  /*
   * Ordering objects by their address is pretty useless,
   * so subclasses should override this is some useful way.
   */
  if ((id)self > anObject)
    {
      return NSOrderedDescending;
    }
  else
    {
      return NSOrderedAscending;
    }
}

@end
