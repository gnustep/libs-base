/* Implementation for NSNotificationCeenter for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL, Academia Naturalis, & NIT,
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   Last update: 03-aug-1995
   
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
 * File Name  : NSNotificationCenter.m
 * Version    : 0.4 alpha
 * Date       : 11-feb-1996
 *************************************************************************
 * Notes      : 1. The OpenStep spec does not mention the case of calling 
 *              the addObserver method with both name and object equal to 
 *              nil. I think that such case should be forbidden therefore 
 *              in my implementation, an NSInvalidArgumentException is 
 *              raised, but this is not a standard behavior. I hope NeXT 
 *              & SUN will like my decision and include it into the
 *              next OS spec version ;-)
 *              2. The spec doesn't say what happens if you attempt to 
 *              register a (observer, selector, notification name, object)
 *              tuple that is already registered. NeXT's implementation 
 *              allows this (and I strongly suspect Sun's does too), and 
 *              the observer will get the notified multiple times for the 
 *              same notification-name/object event. (That may be desirable 
 *              in certain unusual situations. [Chris Kane, NeXT]
 * To Do      : - Test if the NSArray/Dictionary methods I'm using here 
 *                are really implemented;
 *              - TEST IT! (write good test example ... also performance)
 *              - Optimization: Put the repository in container array and
 *                pointers to beg/end of notifications with a given name
 *                implemented by hash container object. Do the same but
 *                now optimize it for fast notification sender object.
 * Bugs       : 
 * Last update: 11-feb-1996
 * History    : 17-jul-1995    - Birth;
 *************************************************************************
 * Acknowledgments: 
 * - Chris Kane (NeXT) <Christopher_Kane@NeXT.com> gave me a lot of useful 
 *   sugestions;
 *************************************************************************/

#include <stdio.h>

#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>

#include <Foundation/NSNotification.h>

#define _GNU_AnonymousNotification  @"GNU_AnonymousNotification"

@interface _NSObserver:NSObject
{
	id  myTarget;
	SEL mySelector;
	id  observantObject;
}
- (id)_initWithTarget:(id)aTarget selector:(SEL)aSelector 
	observant:(id)anObject;
- (void)_postNotification:(NSNotification *)aNotification;
- (id)_observerID;
- (SEL)_observerSelector;
- (id)_observantObject;
@end

@implementation _NSObserver
- (id)_initWithTarget:(id)aTarget selector:(SEL)aSelector 
	observant:(id)anObject
{
	[super init];
	myTarget = [aTarget retain];
	observantObject = anObject;
	mySelector = aSelector;
	return self;
}

- (void)dealloc
{
	[myTarget release];
	return [super dealloc];
}

- (void)_postNotification:(NSNotification *)aNotification
{
	if (aNotification)
		[myTarget perform:mySelector withObject:aNotification];
	return;
}

- (id)_observerID
{
	return myTarget;
}

- (SEL)_observerSelector
{
	return mySelector;
}

- (id)_observantObject
{
	return observantObject;
}
@end

@implementation NSNotificationCenter
/*************************************************************************
 *** Accessing the Default Notification Center
 *************************************************************************/
static NSNotificationCenter *_defaultCenter = nil;
 
+ (NSNotificationCenter *)defaultCenter
/*"
	Returns the default notification center object; used for generic
	notifications.
"*/
{
	if (!_defaultCenter)
		_defaultCenter = [[self alloc] init];
	return _defaultCenter;
}

/*************************************************************************
 *** Creating and destroying instances
 *************************************************************************/
- (id)init
{
	[super init];
	// Create the list of anonymous observers
	_anonymousObservers = [NSMutableArray arrayWithCapacity:1];
	
	// Create the repository sorted by Notification name
	_repositoryByName = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
	
	// Add the array for anonymous observers
	[_repositoryByName setObject:_anonymousObservers
		forKey:_GNU_AnonymousNotification];
	
	return self;
}

- (void)dealloc
{
	NSEnumerator *listEnumerator = nil;
	id allLists = [_repositoryByName allValues];
	id list = nil;
	
	listEnumerator = [allLists objectEnumerator];
	while (list = [listEnumerator nextObject]) {		
		[list removeAllObjects];
	}
	[_repositoryByName removeAllObjects];
	return [super dealloc];
}

/*************************************************************************
 *** Adding and Removing Observers
 *************************************************************************/
- (void)addObserver:(id)anObserver	selector:(SEL)aSelector
	name:(NSString *)aName  object:(id)anObject 
/*"
	Registers anObserver and aSelector with the receiver so that anObserver
	receives an aSelector message when a notification of name aName is posted 
	to the notification center by anObject. If anObject is nil, observer will 
	get posted whatever the object is. If aName is nil, observer will get 
	posted for all notifications that match anObject.
"*/
{
	_NSObserver *newObserver = nil;
	id observerList = _anonymousObservers; // Prepare for the case where the
	                                       // observer is anonymous
	
	if (!anObserver) {            // ... just forget it
		return;
	}
	
	// $$$ Check if the selector is valid! (HOW??)

	if (aName || anObject) {      // ... now I have to do some work :-(
	  // Check if the observer is anonymous
		if (!aName) {               // Find or create the list
			observerList = [_repositoryByName objectForKey:aName];
			if (!observerList) {      // The list should be created first
				observerList = [NSMutableArray arrayWithCapacity:1];
				// Add the list to the repository
				[_repositoryByName setObject:observerList forKey:aName];
			}
		}
		// Create the new observer
		newObserver = [[[_NSObserver alloc] _initWithTarget:anObserver
			selector:aSelector observant:anObject] autorelease];
		// Add teh new observer to the list
		[observerList addObject:newObserver];
	}
	else {                        // Hmmm. The developer have to RTFM!
		// $$$ Raise an exception
		return;
	}
	
	return;
}

- (void)removeObserver:(id)anObserver
/*" 
	Removes anObserver as the observer of any notifications from any objects.
"*/
{
	if (anObserver) {                 // remove it...
		NSEnumerator *listEnumerator = nil;
		NSEnumerator *observerEnumerator = nil;
		id allLists = [_repositoryByName allValues];
		id obj = nil;
		id list = nil;
		
		listEnumerator = [allLists objectEnumerator];
		while (list = [listEnumerator nextObject]) {
			NSMutableArray *removeList = [NSMutableArray arrayWithCapacity:10];
			
			observerEnumerator = [list objectEnumerator];
			while (obj = [observerEnumerator nextObject]) {
				if ([obj _observantObject] == anObserver)
					[removeList addObject:obj];
			}
			// Remove all occurrences at once
			[list removeObjectsInArray:removeList];
		}
		
	}
	return;
}

- (void)removeObserver:(id)anObserver	name:(NSString *)aName object:anObject
/*" Removes anObserver as the observer of aName notifications from anObject "*/
{
	if (anObserver) {                 // remove it...
		NSEnumerator *enumerator = nil;
		id obj = nil;
		id observerList = _anonymousObservers;
		NSMutableArray *removeList = [NSMutableArray arrayWithCapacity:10];
		
		if (aName)
			observerList = [_repositoryByName objectForKey:aName];
		
		enumerator = [observerList objectEnumerator];
		while (obj = [enumerator nextObject]) {
			if ([obj _observantObject] == anObserver)
				[removeList addObject:obj];
		}
		// Remove all occurrences at once
		[observerList removeObjectsInArray:removeList];
	}	
	
	return;
}

/*************************************************************************
 *** Posting Notifications
 *************************************************************************/
- (void)postNotification:(NSNotification *)aNotification
/*"
	Posts aNotification to the notification center. Raises 
	NSInvalidArgumentException if the name associated with aNotification 
	is nil.
"*/
{
	id notName = [aNotification name];
	id notObject = [aNotification object];
	NSEnumerator *enumerator = nil;
	id observer = nil;
	id namedList = nil;
	
	if (![aNotification name]) {       // No name defined
		[NSException raise:NSInvalidArgumentException 
			format:@"Notification name associated was posted"];
	}

	// Notify all anonymous observers.
	// Note: Anonymous observers are associated with an objects, so if 
	// notification's object is nil, this step could be skipped
	if (notObject) {                   // Scan the anonymous list
		enumerator = [_anonymousObservers objectEnumerator];
		while (observer = [enumerator nextObject]) {
			if ([observer _observantObject] == notObject)
				[observer _postNotification:aNotification];
		}
	}
	
	// Now find the named list of observer (if any) and propagate 
	// the notification
	namedList = [_repositoryByName objectForKey:notName];
	if (namedList) {                  // Scan the list
		enumerator = [namedList objectEnumerator];
		while (observer = [enumerator nextObject]) {
			id anObj = [observer _observantObject];
			if ((anObj == nil) || (anObj = notObject)) 
				[observer _postNotification:aNotification];
		}
	}
	
	return;
}

- (void)postNotificationName:(NSString *)aName	object:(id)anObject
/*"
	Creates a notification object that associates aName and anObject 
	and posts it to the notification center.
"*/
{
	return [self postNotification:
		[NSNotification notificationWithName:aName
		object:anObject]];
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject
	userInfo:(NSDictionary *)userInfo
/*"
	Creates a notification object that associates aName and anObject 
	and posts it to the notification center. userInfo is a dictionary 
	of arbitrary data that will be passed with the notification. 
	userInfo may be nil.
"*/
{
	return [self postNotification:
		[NSNotification notificationWithName:aName
		object:anObject 
		userInfo:userInfo]];
}

@end
