/* Implementation of NSNotification for GNUstep
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <config.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSString.h>

@implementation NSNotification

/* This is the designated initializer. */
- initWithName: (NSString*)name
	object: object
      userInfo: info
{
  [super init];
  _name = [name copy];
  _object = [object retain];
  _info = [info retain];
  return self;
}

- (void) dealloc
{
  [_name release];
  [_object release];
  [_info release];
  [super dealloc];
}


/* Creating autoreleased Notification objects. */

+ notificationWithName: (NSString*)name
		object: object
	      userInfo: info
{
  return [[[self alloc] initWithName: name 
			object: object 
			userInfo: info]
	   autorelease];
}

+ notificationWithName: (NSString*)name
		object: object
{
  return [self notificationWithName: name 
	       object: object 
	       userInfo: nil];
}


/* Querying a Notification object. */

- (NSString*) name
{
  return _name;
}

- object
{
  return _object;
}

- userInfo
{
  return _info;
}


/* NSCopying protocol. */

- copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone (self, zone))
    return [self retain];

  return [[[self class] allocWithZone: zone]
	   initWithName: _name
	   object: _object
	   userInfo: _info];
}

@end
