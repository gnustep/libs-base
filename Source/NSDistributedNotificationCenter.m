/* Implementation of NSDistributedNotificationCenter class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

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
   */

#include	<config.h>
#include	<Foundation/NSObject.h>
#include	<Foundation/NSConnection.h>
#include	<Foundation/NSDistantObject.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSArchiver.h>
#include	<Foundation/NSNotification.h>
#include	<Foundation/NSDate.h>
#include	<Foundation/NSRunLoop.h>
#include	<Foundation/NSTask.h>
#include	<Foundation/NSDistributedNotificationCenter.h>

#include	"../Tools/gdnc.h"

/*
 *      Macros to build text to start name server and to give an error
 *      message about it - they include installation path information.
 */
#define stringify_it(X) #X
#define make_gdnc_cmd(X)      stringify_it(X) "/Tools/gdnc"
#define make_gdnc_err(X)      "check that " stringify_it(X) "/Tools/gdnc is running."

/*
 *	Global variables for distributed notification center types.
 */
NSString	*NSLocalNotificationCenterType =
			@"NSLocalNotificationCenterType";


@interface	NSDistributedNotificationCenter (Private)
- (void) _connect;
- (void) _invalidated: (NSNotification*)notification;
- (void) postNotificationName: (NSString*)name
		       object: (NSString*)object
		     userInfo: (NSData*)info
		     selector: (NSString*)aSelector
			   to: (unsigned long)observer;
@end

@implementation	NSDistributedNotificationCenter

static NSDistributedNotificationCenter	*defCenter = nil;

+ (id) defaultCenter
{
  return [self notificationCenterForType: NSLocalNotificationCenterType];
}

+ (id) notificationCenterForType: (NSString*)type
{
  NSAssert([type isEqual: NSLocalNotificationCenterType],
	NSInvalidArgumentException);
  if (defCenter == nil)
    {
      [gnustep_global_lock lock];
	if (defCenter == nil)
	  {
	    NS_DURING
	      {
		id	tmp;

		tmp = NSAllocateObject(self, 0, NSDefaultMallocZone());
		defCenter = (NSDistributedNotificationCenter*)[tmp init];
	      }
	    NS_HANDLER
	      {
		[gnustep_global_lock unlock];
		[localException raise];
	      }
	    NS_ENDHANDLER
	  }
      [gnustep_global_lock unlock];
    }
  return defCenter;
}

- (void) dealloc
{
  if ([[_remote connectionForProxy] isValid])
    {
      [_remote unregisterClient: (id<GDNCClient>)self];
    }
  RELEASE(_remote);
  [super dealloc];
}

- (id) init
{
  NSAssert(_centerLock == nil, NSInternalInconsistencyException);
  _centerLock = [NSRecursiveLock new];
  return self;
}

- (void) addObserver: (id)anObserver
	    selector: (SEL)aSelector
		name: (NSString*)notificationName
	      object: (NSString*)anObject
{
  [self addObserver: anObserver
	   selector: aSelector
	       name: notificationName
	     object: anObject
 suspensionBehavior: NSNotificationSuspensionBehaviorCoalesce];
}

- (void) addObserver: (id)anObserver
	    selector: (SEL)aSelector
		name: (NSString*)notificationName
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior
{
  if (anObserver == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil observer"];
    }
  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector"];
    }
  if (notificationName != nil &&
	[notificationName isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification name"];
    }
  if (anObject != nil && [anObject isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification object"];
    }
  if (anObject == nil && notificationName == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"notification name and object both nil"];
    }

  [_centerLock lock];
  NS_DURING
    {
      [self _connect];
      [(id<GDNCProtocol>)_remote addObserver: (unsigned long)anObserver
				   selector: NSStringFromSelector(aSelector)
				       name: notificationName
				     object: anObject
			 suspensionBehavior: suspensionBehavior
					for: (id<GDNCClient>)self];
    }
  NS_HANDLER
    {
      [_centerLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [_centerLock unlock];
}

- (void) postNotification: (NSNotification*)notification
{
  [self postNotificationName: [notification name]
		      object: [notification object]
		    userInfo: [notification userInfo]
	  deliverImmediately: NO];
}

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
{
  [self postNotificationName: notificationName
		      object: anObject
		    userInfo: nil
	  deliverImmediately: NO];
}

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo
{
  [self postNotificationName: notificationName
		      object: anObject
		    userInfo: userInfo
	  deliverImmediately: NO];
}

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo
	   deliverImmediately: (BOOL)deliverImmediately
{
  if (notificationName == nil ||
	[notificationName isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification name"];
    }
  if (anObject != nil && [anObject isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification object"];
    }

  [_centerLock lock];
  NS_DURING
    {
      NSData	*d;

      [self _connect];
      d = [NSArchiver archivedDataWithRootObject: userInfo];
      [(id<GDNCProtocol>)_remote postNotificationName: notificationName
					      object: anObject
					    userInfo: d
				  deliverImmediately: deliverImmediately
						 for: (id<GDNCClient>)self];
    }
  NS_HANDLER
    {
      [_centerLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [_centerLock unlock];
}

- (void) removeObserver: (id)anObserver
		   name: (NSString*)notificationName
		 object: (NSString*)anObject
{
  if (notificationName != nil &&
	[notificationName isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification name"];
    }
  if (anObject != nil && [anObject isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"invalid notification object"];
    }

  [_centerLock lock];
  NS_DURING
    {
      [self _connect];
      [(id<GDNCProtocol>)_remote removeObserver: (unsigned long)anObserver
					  name: notificationName
					object: anObject
					   for: (id<GDNCClient>)self];
    }
  NS_HANDLER
    {
      [_centerLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [_centerLock unlock];
}

- (void) setSuspended: (BOOL)flag
{
  [_centerLock lock];
  NS_DURING
    {
      [self _connect];
      _suspended = flag;
      [(id<GDNCProtocol>)_remote setSuspended: flag for: (id<GDNCClient>)self];
    }
  NS_HANDLER
    {
      [_centerLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [_centerLock unlock];
}

- (BOOL) suspended
{
  return _suspended;
}

@end

@implementation	NSDistributedNotificationCenter (Private)

- (void) _connect
{
  if (_remote == nil)
    {
      /*
       *	Connect to the NSDistributedNotificationCenter for this host.
       */
      _remote = RETAIN([NSConnection rootProxyForConnectionWithRegisteredName:
		GDNC_SERVICE host: @""]);

      if (_remote != nil)
	{
	  NSConnection	*c = [_remote connectionForProxy];
	  Protocol	*p = @protocol(GDNCProtocol);

	  [_remote setProtocolForProxy: p];

	  /*
	   *	Ask to be told if the copnnection goes away.
	   */
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	       selector: @selector(_invalidated:)
		   name: NSConnectionDidDieNotification
		 object: c];
	  [_remote registerClient: (id<GDNCClient>)self];
	}
      else
	{
	  static BOOL recursion = NO;

	  if (recursion == NO)
	    {
	      static NSString	*cmd = nil;

	      if (cmd == nil)
		cmd = [NSString stringWithCString:
			make_gdnc_cmd(GNUSTEP_INSTALL_PREFIX)];

NSLog(@"NSDistributedNotificationCenter failed to contact GDNC server.\n");
NSLog(@"Attempting to start GDNC process - this will take several seconds.\n");
	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
	      [NSTimer scheduledTimerWithTimeInterval: 5.0
					   invocation: nil
					      repeats: NO];
	      [[NSRunLoop currentRunLoop] runUntilDate:
		[NSDate dateWithTimeIntervalSinceNow: 5.0]];
NSLog(@"Retrying connection to the GDNC server.\n");
	      recursion = YES;
	      [self _connect];
	      recursion = NO;
NSLog(@"Connection to GDNC server established.\n");
	    }
	  else
	    { 
	      recursion = NO;
	      [NSException raise: NSInternalInconsistencyException
			  format: @"unable to contact GDNC server - %s",
		      make_gdnc_err(GNUSTEP_INSTALL_PREFIX)];
	    }
	}
    }
}

- (void) _invalidated: (NSNotification*)notification
{
  id connection = [notification object];

  /*
   *	Tidy up now that the connection has gone away.
   */
  [[NSNotificationCenter defaultCenter]
    removeObserver: self
	      name: NSConnectionDidDieNotification
	    object: connection];
  NSAssert(connection == [_remote connectionForProxy],
		 NSInternalInconsistencyException);
  RELEASE(_remote);
  _remote = nil;
}

- (void) postNotificationName: (NSString*)name
		       object: (NSString*)object
		     userInfo: (NSData*)info
		     selector: (NSString*)aSelector
			   to: (unsigned long)observer
{
  id			userInfo;
  NSNotification	*notification;
  id			recipient = (id)observer;

  userInfo = [NSUnarchiver unarchiveObjectWithData: info];
  notification = [NSNotification notificationWithName: name
					       object: object
					     userInfo: userInfo];
  [recipient performSelector: sel_get_any_typed_uid([aSelector cString])
		  withObject: notification];
}

@end

