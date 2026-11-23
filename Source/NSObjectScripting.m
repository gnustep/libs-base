/* Implementation of NSObject scripting additions
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Fri Nov  1 00:25:37 EDT 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSObjectScripting.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

@implementation NSObject (NSScripting)

- (NSDictionary *) scriptingProperties
{
  return [self notImplemented: _cmd];
}

- (void) setScriptingProperties: (NSDictionary *)properties
{
  [self notImplemented: _cmd];
}

- (id) scriptingValueForSpecifier: (NSScriptObjectSpecifier *)objectSpecifier
{
  return [self notImplemented: _cmd];
}

- (id) copyScriptingValue: (id)value
                  forKey: (NSString *)key
          withProperties: (NSDictionary *)properties
{
  return [self notImplemented: _cmd];
}

- (id) newScriptingObjectOfClass: (Class)objectClass
                 forValueForKey: (NSString *)key
              withContentsValue: (id)contentsValue
                     properties: (NSDictionary *)properties
{
  return [self notImplemented: _cmd];
}

@end

