/* Implementation for NSNotification for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL, Academia Naturalis, & NIT,
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   Last update: 11-feb-1996
   
   This file is part of the GNU Objective C Class Library.

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

/*************************************************************************
 * File Name  : NSNotification.m
 * Version    : 0.6 beta
 * Date       : 11-feb-1996
 *************************************************************************
 * Notes      : 
 * - The NeXT/OpenStep specification is not very clear if the objects has
 *   to be instances of a private class and/or the ivars should be private.
 *   Because it is supposed to inherit from NSNotification class, I decided
 *   not to use a private class or ivars. This is because in my own project
 *   I have seen, that if I use a lot of notifications, it is faster to 
 *   access the ivears directly from a subclass. This is of course a 
 *   philosophical question and I would like to get some feedback.
 * To Do      : 
 * Bugs       : 
 * Last update: 11-feb-1996
 * History    : 17-jul-1995    - Birth;
 *              26-aug-1995    - v.0.5 beta - tested on: (NS - extensively)
 *                               Sun (SunOS, Solaris - compiling only);
 *              11-feb-1996    - v.0.6 beta The current implementation allows 
 *                               to create a notification with nil name;
 *************************************************************************
 * Acknowledgments: 
 * - A part of the copyWithZone method is originally written by
 *   Jeremy Bettis <jeremy@hksys.com>
 *************************************************************************/

#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>

#include <Foundation/NSNotification.h>

@implementation NSNotification

/*************************************************************************
 *** init... and dealloc
 *************************************************************************/
- initWithName:(NSString *)aName object:(id)anObject
	userInfo:(NSDictionary *)userInfo
/* The designated initalizer */
{
	[super init];
	
	notificationName = [aName retain];
	notificationObject = [anObject retain];
	notificationInfo = [userInfo retain];
	
	return self;
}

-init
{
	return [self initWithName:nil object:nil userInfo:nil];
}

- (void)dealloc
{
	[notificationName release];
	[notificationObject release];
	[notificationInfo release];
	[super dealloc];
}

/*************************************************************************
 *** Creating Notification Objects
 *************************************************************************/
+ (NSNotification *)notificationWithName:(NSString *)aName
	object:(id)anObject
{
	return [[[self alloc] initWithName:aName object:anObject
		userInfo:nil] autorelease];
}

+ (NSNotification *)notificationWithName:(NSString *)aName
	object:(id)anObject userInfo:(NSDictionary *)userInfo
{
	return [[[self alloc] initWithName:aName object:anObject
		userInfo:userInfo] autorelease];
}

/*************************************************************************
 *** Querying a Notification Object
 *************************************************************************/
- (NSString *)name
{
	return notificationName;
}

- (id)object
{
	return notificationObject;
}

- (NSDictionary *)userInfo
{
	return notificationInfo;
}

/*************************************************************************
 *** NSCopying protocol
 *************************************************************************/
- (id)copyWithZone:(NSZone *)zone
{
	// This was stolen by me from Jeremy Bettis <jeremy@hksys.com> ;-)
	if (NSShouldRetainWithZone(self,zone)) {
		return [self retain];
	}

	// Because it is not known if the notificationObject supports the
	// NSCopying protocol, I think the most correct behavior is just
	// to retain it ... but this is a philosophical question ;-)
	return [[[self class] allocWithZone:zone]
		initWithName: [notificationName copyWithZone:zone]
		object: [notificationObject	retain]
		userInfo: [notificationInfo copyWithZone:zone]];
}

#ifdef NeXT
// This is here only to avoid a nasty warning :-(
- (id)copy
{
	return [self copyWithZone:NSDefaultMallocZone()];
}
#endif
@end
