/** Implementation of GNUstep Distributed Notification Center
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

#include	"config.h"
#include	<Foundation/Foundation.h>

#include        <stdio.h>
#include	<unistd.h>

#ifdef __MINGW__
#include	"process.h"
#endif

#include <fcntl.h>
#ifdef	HAVE_SYSLOG_H
#include <syslog.h>
#endif

#include        <signal.h>

#ifndef NSIG
#define NSIG    32
#endif

static int	is_daemon = 0;		/* Currently running as daemon.	 */
static char	ebuf[2048];

#ifdef HAVE_SYSLOG

static int	log_priority;

static void
gdnc_log (int prio)
{
  if (is_daemon)
    {
      syslog (log_priority | prio, ebuf);
    }
  else if (prio == LOG_INFO)
    {
      write (1, ebuf, strlen (ebuf));
      write (1, "\n", 1);
    }
  else
    {
      write (2, ebuf, strlen (ebuf));
      write (2, "\n", 1);
    }

  if (prio == LOG_CRIT)
    {
      if (is_daemon)
	{
	  syslog (LOG_CRIT, "exiting.");
	}
      else
     	{
	  fprintf (stderr, "exiting.\n");
	  fflush (stderr);
	}
      exit(EXIT_FAILURE);
    }
}
#else

#define	LOG_CRIT	2
#define LOG_DEBUG	0
#define LOG_ERR		1
#define LOG_INFO	0
#define LOG_WARNING	0
void
gdnc_log (int prio)
{
  write (2, ebuf, strlen (ebuf));
  write (2, "\n", 1);
  if (prio == LOG_CRIT)
    {
      fprintf (stderr, "exiting.\n");
      fflush (stderr);
      exit(EXIT_FAILURE);
    }
}
#endif

static void
ihandler(int sig)
{
  static BOOL	beenHere = NO;
  BOOL		action;
  const char	*e;

  /*
   * Deal with recursive call of handler.
   */
  if (beenHere == YES)
    {
      abort();
    }
  beenHere = YES;

  /*
   * If asked to terminate, do so cleanly.
   */
  if (sig == SIGTERM)
    {
      exit(EXIT_FAILURE);
    }

#ifdef	DEBUG
  action = YES;		// abort() by default.
#else
  action = NO;		// exit() by default.
#endif
  e = getenv("CRASH_ON_ABORT");
  if (e != 0)
    {
      if (strcasecmp(e, "yes") == 0 || strcasecmp(e, "true") == 0)
	action = YES;
      else if (strcasecmp(e, "no") == 0 || strcasecmp(e, "false") == 0)
	action = NO;
      else if (isdigit(*e) && *e != '0')
	action = YES;
      else
	action = NO;
    }

  if (action == YES)
    {
      abort();
    }
  else
    {
      fprintf(stderr, "gdnc killed by signal %d\n", sig);
      exit(sig);
    }
}


#include	"gdnc.h"

/*
 * The following dummy class is here solely as a workaround for pre 3.3
 * versions of gcc where protocols didn't work properly unless implemented
 * in the source where the '@protocol()' directive is used.
 */
@interface NSDistributedNotificationCenterDummy : NSObject <GDNCClient>
- (oneway void) postNotificationName: (NSString*)name
                              object: (NSString*)object
                            userInfo: (NSData*)info
                            selector: (NSString*)aSelector
                                  to: (unsigned long)observer;
@end
@implementation	NSDistributedNotificationCenterDummy
- (oneway void) postNotificationName: (NSString*)name
                              object: (NSString*)object
                            userInfo: (NSData*)info
                            selector: (NSString*)aSelector
                                  to: (unsigned long)observer
{
}
@end


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
  RELEASE(name);
  RELEASE(object);
  RELEASE(info);
  [super dealloc];
}
+ (GDNCNotification*) notificationWithName: (NSString*)notificationName
				    object: (NSString*)notificationObject
				      data: (NSData*)notificationData
{
  GDNCNotification	*tmp = [GDNCNotification alloc];

  tmp->name = RETAIN(notificationName);
  tmp->object = RETAIN(notificationObject);
  tmp->info = RETAIN(notificationData);
  return AUTORELEASE(tmp);
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
  RELEASE(observers);
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
  RELEASE(queue);
  RELEASE(selector);
  RELEASE(notificationName);
  RELEASE(notificationObject);
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
	        name: (NSString*)notificationName
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior
		 for: (id<GDNCClient>)client;

- (BOOL) connection: (NSConnection*)ancestor
  shouldMakeNewConnection: (NSConnection*)newConn;

- (id) connectionBecameInvalid: (NSNotification*)notification;

- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)notificationObject
		     userInfo: (NSData*)d
	   deliverImmediately: (BOOL)deliverImmediately
			  for: (id<GDNCClient>)client;

- (void) removeObserver: (GDNCObserver*)observer;

- (void) removeObserversForClients: (NSMapTable*)clients;

- (void) removeObserver: (unsigned long)anObserver
		   name: (NSString*)notificationName
		 object: (NSString*)notificationObject
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
      DESTROY(conn);
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
   *	Now free the connections map itself and the table of observers.
   */
  NSFreeMapTable(connections);
  NSFreeHashTable(allObservers);

  /*
   *	And release the maps of notification names and objects.
   */
  RELEASE(observersForNames);
  RELEASE(observersForObjects);
  [super dealloc];
}

- (id) init
{
  NSString	*hostname;
  NSString	*service = GDNC_SERVICE;
  BOOL		isLocal = NO;

  connections = NSCreateMapTable(NSObjectMapKeyCallBacks,
		NSNonOwnedPointerMapValueCallBacks, 0);
  allObservers = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
  observersForNames = [NSMutableDictionary new];
  observersForObjects = [NSMutableDictionary new];

  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"GSNetwork"] == YES)
    {
      service = GDNC_NETWORK;
    }
  hostname = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
  if ([hostname length] == 0
    || [hostname isEqualToString: @"localhost"] == YES
    || [hostname isEqualToString: @"127.0.0.1"] == YES)
    {
      isLocal = YES;
    }

  /*
   * If this is the local server for the current host,
   * use the loopback network interface.  Otherwise
   * create a public connection.
   */
  if (0 && isLocal == YES && service != GDNC_NETWORK)
    {
      NSPort	*port = [NSSocketPort portWithNumber: 0
					      onHost: [NSHost localHost]
					forceAddress: @"127.0.0.1"
					    listener: YES];
      conn = [[NSConnection alloc] initWithReceivePort: port sendPort: nil];
    }
  else
    {
      conn = [NSConnection defaultConnection];
    }
  [conn setRootObject: self];

  if (isLocal == YES
    || [[NSHost hostWithName: hostname] isEqual: [NSHost currentHost]] == YES)
    {
      if ([conn registerName: service] == NO)
	{
	  NSLog(@"gdnc - unable to register with name server as %@ - quiting.",
	    service);
	  DESTROY(self);
	  return self;
	}
    }
  else
    {
      NSHost		*host = [NSHost hostWithName: hostname];
      NSPort		*port = [conn receivePort];
      NSPortNameServer	*ns = [NSPortNameServer systemDefaultPortNameServer];
      NSArray		*a;
      unsigned		c;

      if (host == nil)
	{
	  NSLog(@"gdnc - unknown NSHost argument  ... %@ - quiting.", hostname);
	  DESTROY(self);
	  return self;
	}
      a = [host names];
      c = [a count];
      while (c-- > 0)
	{
	  NSString	*name = [a objectAtIndex: c];

	  name = [service stringByAppendingFormat: @"-%@", name];
	  if ([ns registerPort: port forName: name] == NO)
	    {
	    }
	}
      a = [host addresses];
      c = [a count];
      while (c-- > 0)
	{
	  NSString	*name = [a objectAtIndex: c];

	  name = [service stringByAppendingFormat: @"-%@", name];
	  if ([ns registerPort: port forName: name] == NO)
	    {
	    }
	}
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
  RELEASE(obs);
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
	  RELEASE(objList);
	}
      /*
       *	If possible use an existing string as the key.
       */ 
      if ([objList count] > 0)
	{
	  GDNCObserver	*tmp = [objList objectAtIndex: 0];

	  anObject = tmp->notificationObject;
	}
      obs->notificationObject = RETAIN(anObject);
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
	  RELEASE(namList);
	}
      /*
       *	If possible use an existing string as the key.
       */ 
      if ([namList count] > 0)
	{
	  GDNCObserver	*tmp = [namList objectAtIndex: 0];

	  notificationName = tmp->notificationObject;
	}
      obs->notificationName = RETAIN(notificationName);
      [namList addObject: obs];
    }

}

- (BOOL) connection: (NSConnection*)ancestor
  shouldMakeNewConnection: (NSConnection*)newConn
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
  return YES;
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
      NSLog(@"argh - gdnc server root connection has been destroyed.");
      exit(EXIT_FAILURE);
    }
  else
    {
      NSMapTable	*table;

      /*
       *	Remove all clients registered via this connection
       *	(should normally only be 1) - then the connection.
       */
      table = NSMapGet(connections, connection);
      NSMapRemove(connections, connection);
      if (table != 0)
	{
	  [self removeObserversForClients: table];
	  NSFreeMapTable(table);
	}
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
  if ([(id)client isProxy] == YES)
    {
      Protocol	*p = @protocol(GDNCClient);

      [(id)client setProtocolForProxy: p];
    }
  info->client = client;
  NSMapInsert(table, client, info);
  RELEASE(info);
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
  GDNCNotification	*notification = nil;

  byName = [observersForNames objectForKey: notificationName];
  byObject = [observersForObjects objectForKey: notificationObject];
  /*
   *	Build up a list of all those observers that should get sent this.
   */
  for (pos = [byName count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [byName objectAtIndex: pos - 1];

      if (obs->notificationObject == nil
	|| [obs->notificationObject isEqual: notificationObject])
	{
	  [observers addObject: obs];
	}
    }
  for (pos = [byObject count]; pos > 0; pos--)
    {
      GDNCObserver	*obs = [byObject objectAtIndex: pos - 1];

      if (obs->notificationName == nil
	|| [obs->notificationName isEqual: notificationName])
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
	  while (obs != nil && [obs->queue count] > 0
	    && NSHashGet(allObservers, obs) != 0)
	    {
	      NS_DURING
		{
		  GDNCNotification	*n;

		  n = RETAIN([obs->queue objectAtIndex: 0]);
		  [obs->queue removeObjectAtIndex: 0];
		  [obs->client->client postNotificationName: n->name
						     object: n->object
						   userInfo: n->info
						   selector: obs->selector
							 to: obs->observer];
		  RELEASE(n);
		}
	      NS_HANDLER
		{
		  DESTROY(obs);
		}
	      NS_ENDHANDLER
	    }
	}
    }
}

- (void) removeObserver: (GDNCObserver*)observer
{
  if (observer->notificationObject)
    {
      NSMutableArray	*objList;

      objList= [observersForObjects objectForKey: observer->notificationObject];
      if (objList != nil)
	{
	  [objList removeObjectIdenticalTo: observer];
	}
    }
  if (observer->notificationName)
    {
      NSMutableArray	*namList;

      namList = [observersForNames objectForKey: observer->notificationName];
      if (namList != nil)
	{
	  [namList removeObjectIdenticalTo: observer];
	}
    }
  NSHashRemove(allObservers, observer);
  [observer->client->observers removeObjectIdenticalTo: observer];
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


/** <p>The  gdnc  daemon is used by GNUstep programs to send notifications and
       messages to one another, in conjunction with the Base library
       Notification-related classes.</p>

    <p>Every user needs to have his own instance of gdnc running.  While  gdnc
       will be started automatically as soon as it is needed, it is recommended
       to start gdnc in a personal login script like  ~/.bashrc  or  ~/.cshrc.
       Alternatively  you  can  launch  gpbs when your windowing system or the
       window manager is started. For example, on systems  with  X11  you  can
       launch  gdnc  from  your  .xinitrc script or alternatively - if you are
       running Window Maker - put it in Window Maker's autostart script.   See
       the GNUstep Build Guide for a sample startup script.</p>

     <p>Please see the man page for more information.
</p> */
int
main(int argc, char** argv, char** env)
{
  int                   c;
  GDNCServer		*server;
  NSString		*str;
  BOOL			shouldFork = YES;
  BOOL			debugging = NO;
  CREATE_AUTORELEASE_POOL(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  [NSObject enableDoubleReleaseCheck: YES];
  if (argc > 1 && strcmp(argv[argc-1], "-f") == 0)
    {
      shouldFork = NO;
    }
  str = [[NSUserDefaults standardUserDefaults] stringForKey: @"debug"];
  if (str != nil && [str caseInsensitiveCompare: @"yes"] == NSOrderedSame)
    {
      shouldFork = NO;
      debugging = YES;
    }
  RELEASE(pool);
#ifdef __MINGW__
  if (shouldFork)
    {
      char	**a = malloc((argc+2) * sizeof(char*));

      memcpy(a, argv, argc*sizeof(char*));
      a[argc] = "-f";
      a[argc+1] = 0;
      if (_spawnv(_P_NOWAIT, argv[0], a) == -1)
	{
	  fprintf(stderr, "gdnc - spawn failed - bye.\n");
	  exit(EXIT_FAILURE);
	}
      exit(EXIT_SUCCESS);
    }
#else
  if (shouldFork)
    {
      is_daemon = 1;
      switch (fork())
	{
	  case -1:
	    fprintf(stderr, "gdnc - fork failed - bye.\n");
	    exit(EXIT_FAILURE);

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
	    exit(EXIT_SUCCESS);
	}
    }

  /*
   *	Ensure we don't have any open file descriptors which may refer
   *	to sockets bound to ports we may try to use.
   *
   *	Use '/dev/null' for stdin and stdout.
   */
  for (c = 0; c < FD_SETSIZE; c++)
    {
      if (is_daemon || (c != 2))
	{
	  (void)close(c);
	}
    }
  if (open("/dev/null", O_RDONLY) != 0)
    {
      sprintf(ebuf, "failed to open stdin from /dev/null (%s)\n",
	strerror(errno));
      gdnc_log(LOG_CRIT);
      exit(EXIT_FAILURE);
    }
  if (open("/dev/null", O_WRONLY) != 1)
    {
      sprintf(ebuf, "failed to open stdout from /dev/null (%s)\n",
	strerror(errno));
      gdnc_log(LOG_CRIT);
      exit(EXIT_FAILURE);
    }
  if (is_daemon && open("/dev/null", O_WRONLY) != 2)
    {
      sprintf(ebuf, "failed to open stderr from /dev/null (%s)\n",
	strerror(errno));
      gdnc_log(LOG_CRIT);
      exit(EXIT_FAILURE);
    }
#endif /* !MINGW */

  {
#if GS_WITH_GC == 0
    CREATE_AUTORELEASE_POOL(pool);
#endif
    NSUserDefaults	*defs;
    int			sym;

    for (sym = 0; sym < NSIG; sym++)
      {
	signal(sym, ihandler);
      }
#ifndef __MINGW__
    signal(SIGPIPE, SIG_IGN);
    signal(SIGTTOU, SIG_IGN);
    signal(SIGTTIN, SIG_IGN);
    signal(SIGHUP, SIG_IGN);
#endif
    signal(SIGTERM, ihandler);

    /*
     * Make gdnc logging go to syslog unless overridden by user.
     */
    defs = [NSUserDefaults standardUserDefaults];
    [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
      @"YES", @"GSLogSyslog", nil]];

    server = [GDNCServer new];

    /*
     * Close standard input, output, and error to run as daemon.
     */
    [[NSFileHandle fileHandleWithStandardInput] closeFile];
    [[NSFileHandle fileHandleWithStandardOutput] closeFile];
#ifndef __MINGW__
    if (debugging == NO)
      {
	[[NSFileHandle fileHandleWithStandardError] closeFile];
      }
#endif

    RELEASE(pool);
  }

  if (server != nil)
    {
      CREATE_AUTORELEASE_POOL(pool);
      [[NSRunLoop currentRunLoop] run];
      RELEASE(pool);
    }
  exit(EXIT_SUCCESS);
}

