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
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>

@implementation NSNotification

/* This is the designated initializer. */
- (id) initWithName: (NSString*)name
	     object: (id)object
	   userInfo: (id)info
{
  [super init];
  _name = [name copyWithZone: NSDefaultMallocZone()];
  _object = TEST_RETAIN(object);
  _info = TEST_RETAIN(info);
  return self;
}

- (void) dealloc
{
  RELEASE(_name);
  TEST_RELEASE(_object);
  TEST_RELEASE(_info);
  [super dealloc];
}


/* Creating autoreleased Notification objects. */

+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
			        userInfo: (id)info
{
  return [[[self allocWithZone: NSDefaultMallocZone()] initWithName: name 
    object: object userInfo: info] autorelease];
}

+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
{
  return [self notificationWithName: name object: object userInfo: nil];
}


/* Querying a Notification object. */

- (NSString*) name
{
  return _name;
}

- (id) object
{
  return _object;
}

- (NSDictionary*) userInfo
{
  return _info;
}


/* NSCopying protocol. */

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone (self, zone))
    return [self retain];

  return [[[self class] allocWithZone: zone]
    initWithName: _name
	  object: _object
	userInfo: _info];
}

/*
 * NSCoding protocol - the MacOS-X documentation says it should conform,
 * but how can we meaningfully encode/decode the object and userInfo.
 * We do it anyway - at least it should make sense over DO.
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_object];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_info];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_name];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_object];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_info];
  return self;
}

@end
