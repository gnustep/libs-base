/* Interface for NSNotification and NSNotification for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL, Academia Naturalis, & NIT
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

#ifndef __NSNotification_h_OBJECTS_INCLUDE
#define __NSNotification_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>

@class NSString;
@class NSDictionary;
@class NSMutableDictionary;
@class NSMutableArray;

@interface NSNotification:NSObject <NSCopying>
{
	NSString      *notificationName;
	id				    notificationObject;
	NSDictionary  *notificationInfo;
}

/*" Creating Notification Objects "*/
+ (NSNotification *)notificationWithName:(NSString *)aName
	object:(id)anObject;
+ (NSNotification *)notificationWithName:(NSString *)aName
	object:(id)anObject userInfo:(NSDictionary *)userInfo;

/*" Querying a Notification Object "*/
- (NSString *)name;
- (id)object;
- (NSDictionary *)userInfo;
@end

@interface NSNotificationCenter:NSObject
{
	@private
	id                  _sendLock;          // Will be used later
	NSMutableDictionary *_repositoryByName;
	NSMutableArray      *_anonymousObservers;
}

/*" Accessing the Default Notification Center "*/
+ (NSNotificationCenter *)defaultCenter;

/*" Adding and Removing Observers "*/
- (void)addObserver:(id)anObserver
	selector:(SEL)aSelector
	name:(NSString *)aName
	object:(id)anObject;
- (void)removeObserver:(id)anObserver;
- (void)removeObserver:(id)anObserver
	name:(NSString *)aName
	object:anObject;

/*" Posting Notifications "*/
- (void)postNotification:(NSNotification *)aNotification;
- (void)postNotificationName:(NSString *)aName
	object:(id)anObject;
- (void)postNotificationName:(NSString *)aName
	object:(id)anObject
	userInfo:(NSDictionary *)userInfo;
@end

#endif /*__NSNotification_h_OBJECTS_INCLUDE */
