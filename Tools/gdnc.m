/* Implementation of GNUstep Distributed Notification Center
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
    
   You should have received a copy of the GNU General Public  
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include	<Foundation/NSObject.h>
#include	<Foundation/NSConnection.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSDistantObject.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSNotification.h>
#include	<Foundation/NSHashTable.h>
#include	<Foundation/NSMapTable.h>
#include	<Foundation/NSAutoreleasePool.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDistributedNotificationCenter.h>

#include	<unistd.h>

#include	"gdnc.h"

@interface	GDNCNotification : NSObject
{
@public
  NSString	*name;
  NSString	*object;
  NSData	*info;
}
+ (GDNCNotification*) notificationWithName: (NSString*)notificationName
				    object: (NSString*)notificationObject
				      data: (NSData*)notificationData;
@end

@implementation	GDNCNotification
- (void) dealloc
{
  [name release];
  [object release];
  [info release];
  [super dealloc];
}
+ (GDNCNotification*) notificationWithName: (NSString*)notificationName
				    object: (NSString*)notificationObject
				      data: (NSData*)notificationData
{
  GDNCNotification	*tmp = [GDNCNotification alloc];

  tmp->name = [notificationName retain];
  tmp->object = [notificationObject retain];
  tmp->info = [notificationData retain];
  return [tmp autorelease];
}
@end


/*
 *	Information about a notification observer.
 */
@interface	GDNCClient : NSObject
{
@public
  BOOL			suspended;
  id <GDNCClient>	client;
  NSMutableArray	*observers;
}
@end

@implementation	GDNCClient
- (void) dealloc
{
  [observers release];
  [super dealloc];
}

- (id) init
{
  observers = [NSMutableArray new];
  return self;
}
@end



/*
 *	Information about a notification observer.
 */
@interface	GDNCObserver : NSObject
{
@public
  unsigned		observer;
  NSString		*notificationName;
  NSString		*notificationObject;
  NSString		*selector;
  GDNCClient		*client;
  NSMutableArray	*queue;
  NSNotificationSuspensionBehavior	behavior;
}
@end

@implementation	GDNCObserver

- (void) dealloc
{
  [queue release];
  [selector release];
  [notificationName release];
  [notificationObject release];
  [super dealloc];
}

- (id) init
{
  queue = [[NSMutableArray alloc] initWithCapacity: 1];
  return self;
}
@end


@interface	GDNCServer : NSObject <GDNCProtocol>
{
  NSConnection		*conn;
  NSMapTable		*connections;
  NSHashTable		*allObservers;
  NSMutableDictionary	*observersForNames;
  NSMutableDictionary	*observersForObjects;
}

- (void) addObserver: (unsigned long)anObserver
	    selector: (NSString*)aSelector
	        name: (NSString*)notificationname
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior
		 for: (id<GDNCClient>)client;

- (NSConnection*) connection: (NSConnection*)ancestor
                  didConnect: (NSConnection*)newConn;

- (id) connectionBecameInvalid: (NSNotification*)notification;

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSData*)d
	   deliverImmediately: (BOOL)deliverImmediately
			  for: (id<GDNCClient>)client;

- (void) removeObserver: (GDNCObserver*)observer;

- (void) removeObserversForClients: (NSMapTable*)clients;

- (void) removeObserver: (unsigned long)anObserver
		   name: (NSString*)notificationname
		 object: (NSString*)anObject
		    for: (id<GDNCClient>)client;

- (void) setSuspended: (BOOL)flag
		  for: (id<GDNCClient>)client;
@end

@implementation	GDNCServer

- (void) dealloc
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSMapEnumerator	enumerator;
  NSConnection		*connection;
  NSMapTable		*clients;

  if (conn)
    {
      [nc removeObserver: self
		    name: NSConnectionDidDieNotification
		  object: conn];
      [conn release];
      conn = nil;
    }

  /*
   *	Free all the client map tables in the connections map table and
   *	ignore notifications from those connections.
   */
  enumerator = NSEnumerateMapTable(connections);
  while (NSNextMapEnumeratorPair(&enumerator,
		(void**)&connection, (void**)&clients) == YES)
    {
      [nc removeObserver: self
		    name: NSConnectionDidDieNotification
		  object: connection];
      [self removeObserversForClients: clients];
      NSFreeMapTable(clients);
    }

  /*
   *	Now free the connections map itsself and the table of observers.
   */
  NSFreeMapTable(connections);
  NSFreeHashTable(allObservers);

  /*
   *	And release the maps of notification names and objects.
   */
  [observersForNames release];
  [observersForObjects release];
  [super dealloc];
}

- (id) init
{
  connections = NSCreateMapTable(NSObjectMapKeyCallBacks,
		NSNonOwnedPointerMapValueCallBacks, 0);
  allObservers = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
  observersForNames = [NSMutableDictionary new];
  observersForObjects = [NSMutableDictionary new];
  conn = [NSConnection newRegisteringAtName: GDNC_SERVICE
			     withRootObject: self];
  if (conn == nil)
    {
      NSLog(@"gdnc - unable to register with name server - quiting.\n");
      [self release];
      return nil;
    }

  /*
   *	Get notifications for new connections and connection losses.
   */
  [conn setDelegate: self];
  [[NSNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(connectionBecameInvalid:)
	   name: NSConnectionDidDieNotification
	 object: conn];
  return self;
}

- (void) addObserver: (unsigned long)anObserver
	    selector: (NSString*)aSelector
	        name: (NSString*)notificationName
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior
		 for: (id<GDNCClient>)client
{
  GDNCClient	*info;
  NSMapTable	*clients;
  GDNCObserver	*obs;
  NSConnection	*connection;

  connection = [(NSDistantObject*)client connectionForProxy];
  clients = (NSMapTable*)NSMapGet(connections, connection);
  if (clients == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown connection for new observer"];
    }
  info = (GDNCClient*)NSMapGet(clients, client);
  if (info == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown client for new observer"];
    }

  /*
   *	Create new observer info and add to array of observers for this
   *	client and the table of all observers.
   */
  obs = [GDNCObserver new];
  obs->observer = anObserver;
  obs->client = info;
  obs->behavior = suspensionBehavior;
  obs->selector = [aSelector copy];
  [info->observers addObject: obs];
  [obs release];
  NSHashInsert(allObservers, obs);

  /*
   *	Now add the observer to the lists of observers interested in it's
   *	particular notification names and objects.
   */
  if (anObject)
    {
      NSMutableArray	*objList;

      objList = [observersForObjects objectForKey: anObject];
      if (objList == nil)
	{
	  objList = [NSMutableArray new];
	  [observersForObjects setObject: objList forKey: anObject];
	  [objList release];
	}
      /*
       *	If possible use an existing string as the key.
       */ 
      if ([objList count] > 0)
	{
	  GDNCObserver	*tmp = [objList objectAtIndex: 0];

	  anObject = tmp->notificationObject;
	}
      obs->notificationObject = [anObject retain];
      [objList addObject: obs];
    }

  if (notificationName)
    {
      NSMutableArray	*namList;

      namList = [observersForNames objectForKey: notificationName];
      if (namList == nil)
	{
	  namList = [NSMutableArray new];
	  [observersForNames setObject: namList forKey: notificationName];
	  [namList release];
	}
      /*
       *	If possible use an existing string as the key.
       */ 
      if ([namList count] > 0)
	{
	  GDNCObserver	*tmp = [namList objectAtIndex: 0];

	  notificationName = tmp->notificationObject;
	}
      obs->notificationName = [notificationName retain];
      [namList addObject: obs];
    }

}

- (NSConnection*) connection: (NSConnection*)ancestor
                  didConnect: (NSConnection*)newConn
{
  NSMapTable	*table;

  [[NSNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(connectionBecameInvalid:)
	   name: NSConnectionDidDieNotification
	 object: newConn];
  [newConn setDelegate: self];
  /*
   *	Create a new map table entry for this connection with a value that
   *	is a table (normally with a single entry) containing registered
   *	clients (proxies for NSDistributedNotificationCenter objects).
   */
  table = NSCreateMapTable(NSObjectMapKeyCallBacks,
		NSObjectMapValueCallBacks, 0);
  NSMapInsert(connections, newConn, table);
  return newConn;
}

- (id) connectionBecameInvalid: (NSNotification*)notification
{
  id connection = [notification object];

  [[NSNotificationCenter defaultCenter]
    removeObserver: self
	      name: NSConnectionDidDieNotification
	    object: connection];

  if (connection == conn)
    {
      NSLog(@"argh - gdnc server root connection has been destroyed.\n");
      exit(1);
    }
  else
    {
      NSMapTable	*table;

      /*
       *	Remove all clients registered via this connection
       *	(should normally only be 1) - then the connection.
       */
      table = NSMapGet(connections, connection);
      if (table)
	{
	  [self removeObserversForClients: table];
	  NSFreeMapTable(table);
	}
      NSMapRemove(connections, connection);
    }
  return nil;
}

- (void) registerClient: (id<GDNCClient>)client
{
  NSMapTable	*table;
  GDNCClient	*info;

  table = NSMapGet(connections, [(NSDistantObject*)client connectionForProxy]);
  if (table == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"registration with unknown connection"];
    }
  if (NSMapGet(table, client) != 0)
    { 
      [NSException raise: NSInternalInconsistencyException
		  format: @"registration with registered client"];
    }
  info = [GDNCClient new];
  info->client = client;
  NSMapInsert(table, client, info);
  [info release];
}

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)notificationObject
		     userInfo: (NSData*)d
	   deliverImmediately: (BOOL)deliverImmediately
			  for: (id<GDNCClient>)client
{
  NSMutableArray	*observers = [NSMutableArray array];
  NSMutableArray	*byName;
  NSMutableArray	*byObject;
  unsigned		pos;
  GDNCNotification	*notification;

  byName = [observersForNames objectForKey: notificationName];
  byObject = [observersForObjects objectForKey: notificationObject];
  /*
   *	Build up a list of all those observers that should get sent this.
   */
  for (pos = [byName count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [byName objectAtIndex: pos - 1];

      if (obs->notificationObject == nil ||
		[obs->notificationObject isEqual: notificationObject])
	{
	  [observers addObject: obs];
	}
    }
  for (pos = [byObject count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [byObject objectAtIndex: pos - 1];

      if (obs->notificationName == nil ||
		[obs->notificationName isEqual: notificationName])
	{
	  if ([observers indexOfObjectIdenticalTo: obs] == NSNotFound)
	    {
	      [observers addObject: obs];
	    }
	}
    }

  /*
   *	Build notification object to queue for observer.
   */
  if ([observers count] > 0)
    {
      notification = [GDNCNotification notificationWithName: notificationName
						     object: notificationObject
						       data: d];
    }

  /*
   *	Add the object to the queue for this observer depending on suspension
   *	state of the client NSDistributedNotificationCenter etc.
   */
  for (pos = [observers count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [observers objectAtIndex: pos - 1];

      if (obs->client->suspended == NO || deliverImmediately == YES)
	{
	  [obs->queue addObject: notification];
	}
      else
	{
	  switch (obs->behavior)
	    {
	      case NSNotificationSuspensionBehaviorDrop:
		break;
	      case NSNotificationSuspensionBehaviorCoalesce:
		[obs->queue removeAllObjects];
		[obs->queue addObject: notification];
		break;
	      case NSNotificationSuspensionBehaviorHold:
		[obs->queue addObject: notification];
		break;
	      case NSNotificationSuspensionBehaviorDeliverImmediately:
		[obs->queue addObject: notification];
		break;
	    }
	}
    }

  /*
   *	Now perform the actual posting of the notification to the observers in
   *	our array.
   */
  for (pos = [observers count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [observers objectAtIndex: pos - 1];

      if (obs->client->suspended == NO || deliverImmediately == YES)
	{
	  /*
	   *	Post notifications to the observer until:
	   *		an exception		(obs is set to nil)
	   *		the queue is empty	([obs->queue count] == 0)
	   *		the observer is removed	(obs is not in allObservers)
	   */
	  while (obs != nil && [obs->queue count] > 0 &&
		    NSHashGet(allObservers, obs) != 0)
	    {
	      NS_DURING
		{
		  GDNCNotification	*n;

		  n = [[obs->queue objectAtIndex: 0] retain];
		  [obs->queue removeObjectAtIndex: 0];
		  [obs->client->client postNotificationName: n->name
						     object: n->object
						   userInfo: n->info
						   selector: obs->selector
							 to: obs->observer];
		  [n release];
		}
	      NS_HANDLER
		{
		  [obs release];
		  obs = nil;
		}
	      NS_ENDHANDLER
	    }
	}
    }
}

- (void) removeObserver: (GDNCObserver*)obs
{
  if (obs->notificationObject)
    {
      NSMutableArray	*objList;

      objList = [observersForObjects objectForKey: obs->notificationObject];
      if (objList != nil)
	{
	  [objList removeObjectIdenticalTo: obs];
	}
    }
  if (obs->notificationName)
    {
      NSMutableArray	*namList;

      namList = [observersForNames objectForKey: obs->notificationName];
      if (namList != nil)
	{
	  [namList removeObjectIdenticalTo: obs];
	}
    }
  NSHashRemove(allObservers, obs);
  [obs->client->observers removeObjectIdenticalTo: obs];
}

- (void) removeObserversForClients: (NSMapTable*)clients
{
  NSMapEnumerator	enumerator;
  NSObject		*client;
  GDNCClient		*info;

  enumerator = NSEnumerateMapTable(clients);
  while (NSNextMapEnumeratorPair(&enumerator,
		(void**)&client, (void**)&info) == YES)
    {
      while ([info->observers count] > 0)
	{
	  [self removeObserver: [info->observers objectAtIndex: 0]];
	}
    }
}

- (void) removeObserver: (unsigned long)anObserver
		   name: (NSString*)notificationName
		 object: (NSString*)notificationObject
		    for: (id<GDNCClient>)client
{
  if (anObserver == 0)
    {
      if (notificationName == nil)
	{
	  NSMutableArray	*observers;

	  /*
	   *	No notification name - so remove all with matching object.
	   */
	  observers = [observersForObjects objectForKey: notificationObject];
	  while ([observers count] > 0)
	    {
	      GDNCObserver	*obs;

	      obs = [observers objectAtIndex: 0];
	      [self removeObserver: obs];
	    }
	}
      else if (notificationObject == nil)
	{
	  NSMutableArray	*observers;

	  /*
	   *	No notification object - so remove all with matching name.
	   */
	  observers = [observersForObjects objectForKey: notificationName];
	  while ([observers count] > 0)
	    {
	      GDNCObserver	*obs;

	      obs = [observers objectAtIndex: 0];
	      [self removeObserver: obs];
	    }
	}
      else
	{
	  NSMutableArray	*byName;
	  NSMutableArray	*byObject;
	  unsigned		pos;

	  /*
	   *	Remove observers that match both name and object.
	   */
	  byName = [observersForObjects objectForKey: notificationName];
	  byObject = [observersForObjects objectForKey: notificationName];
	  for (pos = [byName count]; pos > 0; pos--)
	    {
	      GDNCObserver	*obs;

	      obs = [byName objectAtIndex: pos - 1];
	      if ([byObject indexOfObjectIdenticalTo: obs] != NSNotFound)
		{
		  [self removeObserver: obs];
		} 
	    }
	  for (pos = [byObject count]; pos > 0; pos--)
	    {
	      GDNCObserver	*obs;

	      obs = [byObject objectAtIndex: pos - 1];
	      if ([byName indexOfObjectIdenticalTo: obs] != NSNotFound)
		{
		  [self removeObserver: obs];
		} 
	    }
	}
    }
  else
    {
      NSMapTable	*table;
      GDNCClient	*info;

      /*
       *	If an observer object (as an unsigned) was specified then
       *	the observer MUST be from this client - so we can look
       *	through the per-client list of objects.
       */
      table = NSMapGet(connections,
		[(NSDistantObject*)client connectionForProxy]);
      if (table == 0)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"removeObserver with unknown connection"];
	}
      info = (GDNCClient*)NSMapGet(table, client);
      if (info != nil)
	{ 
	  unsigned	pos = [info->observers count];

	  while (pos > 0)
	    {
	      GDNCObserver	*obs = [info->observers objectAtIndex: --pos];

	      if (obs->observer == anObserver)
		{
		  if (notificationName == nil ||
			[notificationName isEqual: obs->notificationName])
		    {
		      if (notificationObject == nil ||
			[notificationObject isEqual: obs->notificationObject])
			{
			  [self removeObserver: obs];
			}
		    }
		}
	    }
	}
    }
}

- (void) setSuspended: (BOOL)flag
		  for: (id<GDNCClient>)client
{
  NSMapTable	*table;
  GDNCClient	*info;

  table = NSMapGet(connections, [(NSDistantObject*)client connectionForProxy]);
  if (table == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"setSuspended: with unknown connection"];
    }
  info = (GDNCClient*)NSMapGet(table, client);
  if (info == nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"setSuspended: with unregistered client"];
    }
  info->suspended = flag;
}

- (void) unregisterClient: (id<GDNCClient>)client
{
  NSMapTable	*table;
  GDNCClient	*info;

  table = NSMapGet(connections, [(NSDistantObject*)client connectionForProxy]);
  if (table == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"unregistration with unknown connection"];
    }
  info = (GDNCClient*)NSMapGet(table, client);
  if (info == nil)
    { 
      [NSException raise: NSInternalInconsistencyException
		  format: @"unregistration with unregistered client"];
    }
  while ([info->observers count] > 0)
    {
      [self removeObserver: [info->observers objectAtIndex: 0]];
    }
  NSMapRemove(table, client);
}

@end

int
main()
{
  GDNCServer		*server;
  NSAutoreleasePool	*pool;
  NSString		*str;
  BOOL			shouldFork = YES;

  pool = [NSAutoreleasePool new];
  str = [[NSUserDefaults standardUserDefaults] stringForKey: @"debug"];
  if (str != nil && [str caseInsensitiveCompare: @"yes"] == NSOrderedSame)
    {
      shouldFork = NO;
    }
  [pool release];

  if (shouldFork)
    {
      switch (fork())
	{
	  case -1:
	    fprintf(stderr, "gdnc - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    /*
	     *	Try to run in background.
	     */
    #ifdef	NeXT
	    setpgrp(0, getpid());
    #else
	    setsid();
    #endif
	    break;

	  default:
	    exit(0);
	}
    }

  pool = [NSAutoreleasePool new];
  server = [GDNCServer new];
  [pool release];
  if (server != nil)
    {
      [[NSRunLoop currentRunLoop] run];
    }
  exit(0);
}

