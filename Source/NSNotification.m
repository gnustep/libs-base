/** Implementation of NSNotification for GNUstep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

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

   <title>NSNotification class reference</title>
   $Date$ $Revision$
*/

#include <config.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>

@implementation NSNotification

static Class	concreteClass = 0;

@class	GSNotification;

+ (NSNotification*) allocWithZone: (NSZone*)z
{
  return (id)NSAllocateObject(concreteClass, 0, z);
}

+ (void) initialize
{
  if (concreteClass == 0)
    {
      concreteClass = [GSNotification class];
    }
}

/**
 * Create a new autoreleased notification.  Concrete subclasses override
 * this method to create actual notification objects.
 */
+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
			        userInfo: (NSDictionary*)info
{
  return [concreteClass notificationWithName: name
				      object: object
				    userInfo: info];
}

/**
 * Create a new autoreleased notification by calling
 * +notificationWithName:object:userInfo: with a nil user info argument.
 */
+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
{
  return [concreteClass notificationWithName: name
				      object: object
				    userInfo: nil];
}

/**
 * The abstract class implements a copy as a simple retain ...
 * subclasses should override this to perform more intelligent
 * copy operations.
 */
- (id) copyWithZone: (NSZone*)zone
{
  return [self retain];
}

/**
 * Return a description of the parts of the notification.
 */
- (NSString*) description
{
  return [[super description] stringByAppendingFormat:
    @" Name: %@ Object: %@ Info: %@",
    [self name], [self object], [self userInfo]];
}

- (id) init
{
  if ([self class] == [NSNotification class])
    {
      NSZone	*z = [self zone];

      RELEASE(self);
      self = (id)NSAllocateObject (concreteClass, 0, z);
    }
  return self; 
}

/**
 * Concrete subclasses of NSNotification are responsible for
 * implementing this method to return the notification name.
 */
- (NSString*) name
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Concrete subclasses of NSNotification are responsible for
 * implementing this method to return the notification object.
 */
- (id) object
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Concrete subclasses of NSNotification are responsible for
 * implementing this method to return the notification user information.
 */
- (NSDictionary*) userInfo
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/*
 * NSCoding protocol - the MacOS-X documentation says it should conform,
 * but how can we meaningfully encode/decode the object and userInfo.
 * We do it anyway - at least it should make sense over DO.
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  id	o;

  o = [self name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
  o = [self object];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
  o = [self userInfo];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSString	*name;
  id		object;
  NSDictionary	*info;
  id		n;

  [aCoder decodeValueOfObjCType: @encode(id) at: &name];
  [aCoder decodeValueOfObjCType: @encode(id) at: &object];
  [aCoder decodeValueOfObjCType: @encode(id) at: &info];
  n = [NSNotification notificationWithName: name object: object userInfo: info];
  RELEASE(name);
  RELEASE(object);
  RELEASE(info);
  RELEASE(self);
  return RETAIN(n);
}

@end
