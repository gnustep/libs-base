/** Implementation of NSDistributedNotificationCenter class
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

   <title>NSDistributedNotificationCenter class reference</title>
   $Date$ $Revision$
   */

#include	<config.h>
#include	<base/preface.h>
#include	<Foundation/NSObject.h>
#include	<Foundation/NSConnection.h>
#include	<Foundation/NSDistantObject.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSArchiver.h>
#include	<Foundation/NSNotification.h>
#include	<Foundation/NSDate.h>
#include	<Foundation/NSPathUtilities.h>
#include	<Foundation/NSRunLoop.h>
#include	<Foundation/NSTask.h>
#include	<Foundation/NSDistributedNotificationCenter.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSHost.h>

#include	"../Tools/gdnc.h"

/*
 *	Global variables for distributed notification center types.
 */
NSString	*NSLocalNotificationCenterType =
			@"NSLocalNotificationCenterType";
NSString	*GSNetworkNotificationCenterType =
			@"GSNetworkNotificationCenterType";


@interface	NSDistributedNotificationCenter (Private)
- (void) _connect;
- (void) _invalidated: (NSNotification*)notification;
- (void) postNotificationName: (NSString*)name
		       object: (NSString*)object
		     userInfo: (NSData*)info
		     selector: (NSString*)aSelector
			   to: (unsigned long)observer;
@end

/**
 * <p>The NSDistributedNotificationCenter provides a versatile yet
 * simple mechanism for objects in different processes to communicate
 * effectively while knowing very little about each others internals.<br />
 * A distributed notification center acts much like a normal
 * notification center, but it handles notifications on a machine-wide
 * (or local network wide) basis rather than just notifications within
 * a single process.  Objects are able to register themselves as
 * observers for particular notification names and objects, and they
 * will then receive notifications (including optional user information
 * consisting of a dictionary of property-list objects) as they are posted.
 * </p>
 * <p>Since posting of distributed notifications involves inter-process
 * (and sometimes inter-host) communication, it is fundamentally slower
 * than normal notifications, and should be used relatively sparingly.
 * In order to help with this, the NSDistributedNotificationCenter
 * provides a notion of 'suspension', whereby a center can be suspended
 * causing notifications for observers in the process where the center
 * was suspended to cease receiving notifications.  Observers can
 * specify how notifications are to be handled in this case (queued
 * or discarded) and posters can specify that particular notifications
 * are to be delivered immediately irrespective of suspension.
 * </p>
 * <p>Distributed notifications are mediated by a server process which
 * handles all notifications for a particular center type.  In GNUstep
 * this process is the gdnc tool, and when started without special
 * options, a gdnc process acts as the local centre for the host it is
 * running on.  When started with the GSNetwork user default set to YES,
 * the gdnc tool acts as a local network wide server (you should only
 * run one copy of gdnc like this on your LAN).<br />
 * The gdnc process should be started at machine boot time, but GNUstep
 * will attempt to start it automatically if it can't find it.
 * </p>
 * <p>MacOS-X currently defines only a notification center for the
 * local host.  GNUstep also defines a local network center which can
 * be used from multiple hosts.  By default the system sends this to
 * any gdnc process it can find which is configured as a network-wide
 * server, but the GDNCHost user default may be used to specify a
 * particular host to be contacted ... this may be of use where you
 * wish to have logically separate clusters of machines on a shared LAN.
 * </p>
 */
@implementation	NSDistributedNotificationCenter

static NSDistributedNotificationCenter	*locCenter = nil;
static NSDistributedNotificationCenter	*netCenter = nil;

+ (id) allocWithZone: (NSZone*)z
{
  [NSException raise: NSInternalInconsistencyException
    format: @"Should not call +alloc for NSDistributedNotificationCenter"];
  return nil;
}

/**
 * Returns the default notification center ... a shared notification
 * center for the local host.  This is simply a convenience method
 * equivalent to calling +notificationCenterForType: with
 * NSLocalNotificationCenterType as its argument.
 */
+ (id) defaultCenter
{
  return [self notificationCenterForType: NSLocalNotificationCenterType];
}

/**
 * Returns a notification center of the specified type.<br />
 * The NSLocalNotificationCenterType provides a shared access to
 * a notificatiuon center used by processes on the local host.<br />
 * The GSNetworkNotificationCenterType provides a shared access to
 * a notificatiuon center used by processes on the local network.<br />
 * MacOS-X supports only NSLocalNotificationCenterType.
 */
+ (id) notificationCenterForType: (NSString*)type
{
  if ([type isEqual: NSLocalNotificationCenterType] == YES)
    {
      if (locCenter == nil)
	{
	  [gnustep_global_lock lock];
	    if (locCenter == nil)
	      {
		NS_DURING
		  {
		    NSDistributedNotificationCenter	*tmp;

		    tmp = (NSDistributedNotificationCenter*)
		      NSAllocateObject(self, 0, NSDefaultMallocZone());
		    tmp->_centerLock = [NSRecursiveLock new];
		    tmp->_type = RETAIN(NSLocalNotificationCenterType);
		    locCenter = tmp;
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
      return locCenter;
    }
  else if ([type isEqual: GSNetworkNotificationCenterType] == YES)
    {
      if (netCenter == nil)
	{
	  [gnustep_global_lock lock];
	    if (netCenter == nil)
	      {
		NS_DURING
		  {
		    NSDistributedNotificationCenter	*tmp;

		    tmp = (NSDistributedNotificationCenter*)
		      NSAllocateObject(self, 0, NSDefaultMallocZone());
		    tmp->_centerLock = [NSRecursiveLock new];
		    tmp->_type = RETAIN(GSNetworkNotificationCenterType);
		    netCenter = tmp;
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
      return netCenter;
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
      		  format: @"Unknown center type (%@)", type];
      return nil;	/* NOT REACHED */
    }
}

- (void) dealloc
{
  if ([[_remote connectionForProxy] isValid])
    {
      [_remote unregisterClient: (id<GDNCClient>)self];
    }
  RELEASE(_remote);
  RELEASE(_type);
  NSDeallocateObject(self);
}

/**
 * Should not be used.
 */
- (id) init
{
  RELEASE(self);
  [NSException raise: NSInternalInconsistencyException
    format: @"Should not call -init for NSDistributedNotificationCenter"];
  return nil;
}

/**
 * Adds an observer to the receiver.  Calls
 * -addObserver:selector:name:object:suspensionBehavior: with
 * NSNotificationSuspensionBehaviorCoalesce.
 */
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

/**
 * Adds an observer to the receiver.<br />
 * When a notification matching notificationName and anObject is
 * sent to the center, the object anObserver is sent the message
 * aSelector with the notification info dictionary as its argument.<br />
 * The suspensionBehavior governs how the center deals with notifications
 * when the process to which the notification should be delivered is
 * suspended:
 * <deflist>
 *  <term>NSNotificationSuspensionBehaviorDrop</term>
 *  <desc>
 *    Discards the notification if the observing process is suspended.
 *  </desc>
 *  <term>NSNotificationSuspensionBehaviorCoalesce</term>
 *  <desc>
 *    Discards previously queued notifications when the observing process
 *    is suspended, leaving only the last notification posted in the queue.
 *    Delivers this single notification when the process becomes unsuspended.
 *  </desc>
 *  <term>NSNotificationSuspensionBehaviorHold</term>
 *  <desc>
 *    Queues notifications when the observing process is suspended,
 *    delivering all the queued notifications when the process becomes
 *    unsuspended again.
 *  </desc>
 *  <term>NSNotificationSuspensionBehaviorDeliverImmediately</term>
 *  <desc>
 *    Deliver the notification immediately, even if the destination
 *    process is suspended.
 *  </desc>
 * </deflist>
 */
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
		  format: @"null selector"];
    }
  if (notificationName != nil
    && [notificationName isKindOfClass: [NSString class]] == NO)
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

/**
 * Posts the notification to the center using
 * postNotificationName:object:userInfo:deliverImmediately: with the
 * delivery flag set to NO.
 */
- (void) postNotification: (NSNotification*)notification
{
  [self postNotificationName: [notification name]
		      object: [notification object]
		    userInfo: [notification userInfo]
	  deliverImmediately: NO];
}

/**
 * Posts the notificationName and anObject to the center using
 * postNotificationName:object:userInfo:deliverImmediately: with the
 * user info set to nil and the delivery flag set to NO.
 */
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
{
  [self postNotificationName: notificationName
		      object: anObject
		    userInfo: nil
	  deliverImmediately: NO];
}

/**
 * Posts the notificationName, anObject and userInfo to the center using
 * postNotificationName:object:userInfo:deliverImmediately: with the
 * delivery flag set to NO.
 */
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo
{
  [self postNotificationName: notificationName
		      object: anObject
		    userInfo: userInfo
	  deliverImmediately: NO];
}

/**
 * The primitive notification posting method ...<br />
 * The userInfo dictionary may contain only property-list objects.<br />
 * The deliverImmediately flag specifies whether the suspension
 * state of the receiving process is to be ignored.
 */
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo
	   deliverImmediately: (BOOL)deliverImmediately
{
  if (notificationName == nil
    || [notificationName isKindOfClass: [NSString class]] == NO)
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

/**
 * Removes the observer from the center.
 */
- (void) removeObserver: (id)anObserver
		   name: (NSString*)notificationName
		 object: (NSString*)anObject
{
  if (notificationName != nil
    && [notificationName isKindOfClass: [NSString class]] == NO)
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

/**
 * Sets the suspension state of the receiver ... if the receiver is
 * suspended, it won't handle notification until it is unsuspended
 * again, unless the notifications are posted to be delivered
 * immediately.
 */
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

/**
 * Returns the current suspension state of the receiver.
 */
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
      NSString	*host = nil;
      NSString	*service = nil;
      NSString	*description = nil;

      if (_type == NSLocalNotificationCenterType)
        {
	  /*
	   * Connect to the NSDistributedNotificationCenter for this host.
	   */
	  host = [[NSUserDefaults standardUserDefaults]
	    stringForKey: @"NSHost"];
	  if (host == nil)
	    {
	      host = @"";
	    }
	  else
	    {
	      NSHost	*h;

	      /*
	       * If we have a host specified, but it is the current host,
	       * we do not need to ask for a host by name (nameserver lookup
	       * can be faster) and the empty host name can be used to
	       * indicate that we may start a gdnc server locally.
	       */
	      h = [NSHost hostWithName: host];
	      if (h == nil)
		{
		  NSLog(@"Unknown -NSHost '%@' ignored", host);
		  host = @"";
		}
	      else if ([h isEqual: [NSHost currentHost]] == YES)
		{
		  host = @"";
		}
	      else
		{
		  host = [h name];
		}
	    }
	  if ([host length] == 0)
	    {
	      description = @"local host";
	    }
	  else
	    {
	      description = host;
	    }
	  service = GDNC_SERVICE;
	}
      else if (_type == GSNetworkNotificationCenterType)
        {
	  host = [[NSUserDefaults standardUserDefaults]
	    stringForKey: @"GDNCHost"];
	  description = host;
	  if (host == nil)
	    {
	      host = @"*";
	      description = @"network host";
	    }
	  service = GDNC_NETWORK;
	}
      else
        {
	  [NSException raise: NSInternalInconsistencyException
	  	      format: @"Unknown center type - %@", _type];
	}


      _remote = RETAIN([NSConnection rootProxyForConnectionWithRegisteredName:
	service host: host]);

      if (_type == NSLocalNotificationCenterType
	&& _remote == nil && [host isEqual: @""] == NO)
	{
	  _remote = [NSConnection rootProxyForConnectionWithRegisteredName:
	    [service stringByAppendingFormat: @"-%@", host] host: @"*"];
	  RETAIN(_remote);
	}

      if (_remote != nil)
	{
	  NSConnection	*c = [_remote connectionForProxy];
	  Protocol	*p = @protocol(GDNCProtocol);

	  [_remote setProtocolForProxy: p];

	  /*
	   *	Ask to be told if the connection goes away.
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
	  static BOOL		recursion = NO;
	  static NSString	*cmd = nil;
	  static NSArray	*args = nil;

	  if (recursion == NO)
	    {
	      if (cmd == nil)
		{
                  cmd = RETAIN([[NSSearchPathForDirectoriesInDomains(
                    GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                    stringByAppendingPathComponent: @"gdnc"]);
		}
	    }
	  if (recursion == NO && cmd != nil)
	    {
	      NSLog(@"\nI couldn't contact the notification server for %@ -\n"
@"so I'm attempting to to start one - which will take a few seconds.\n"
@"Trying to launch gdnc from %@ or a machine/operating-system subdirectory.\n"
@"It is recommended that you start the notification server (gdnc) either at\n"
@"login or (better) when your computer is started up.\n", description,
[cmd stringByDeletingLastPathComponent]);

	      if (_type == GSNetworkNotificationCenterType)
	      	{
		  args = [[NSArray alloc] initWithObjects:
		    @"-GSNetwork", @"YES", nil];
		}
	      else if ([host length] > 0)
		{
		  args = [[NSArray alloc] initWithObjects:
		    @"-NSHost", host, nil];
		}

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: args];
	      [NSTimer scheduledTimerWithTimeInterval: 5.0
					   invocation: nil
					      repeats: NO];
	      [[NSRunLoop currentRunLoop] runUntilDate:
		[NSDate dateWithTimeIntervalSinceNow: 5.0]];
	      recursion = YES;
	      [self _connect];
	      recursion = NO;
	    }
	  else
	    { 
	      recursion = NO;
	      [NSException raise: NSInternalInconsistencyException
			  format: @"unable to contact GDNC server -\n"
		@"please check that the gdnc process is running."];
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

