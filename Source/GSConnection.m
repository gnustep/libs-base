/* Implementation of connection object for remote object messaging
   Copyright (C) 1994, 1995, 1996, 1997, 2000 Free Software Foundation, Inc.

   Created by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   Minor rewrite for OPENSTEP by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: August 1997
   Major rewrite for MACOSX by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2000

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

#include <config.h>
#include <base/preface.h>
#include <mframe.h>

#include <Foundation/GSConnection.h>
#include <Foundation/GSPortCoder.h>
#include <Foundation/DistributedObjects.h>

#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSData.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSDebug.h>

#define F_LOCK(X) {NSDebugFLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define F_UNLOCK(X) {NSDebugFLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}
#define M_LOCK(X) {NSDebugMLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define M_UNLOCK(X) {NSDebugMLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}

static NSString*
stringFromMsgType(int type)
{
  switch (type)
    {
      case METHOD_REQUEST:
	return @"method request";
      case METHOD_REPLY:
	return @"method reply";
      case ROOTPROXY_REQUEST:
	return @"root proxy request";
      case ROOTPROXY_REPLY:
	return @"root proxy reply";
      case CONNECTION_SHUTDOWN:
	return @"connection shutdown";
      case METHODTYPE_REQUEST:
	return @"methodtype request";
      case METHODTYPE_REPLY:
	return @"methodtype reply";
      case PROXY_RELEASE:
	return @"proxy release";
      case PROXY_RETAIN:
	return @"proxy retain";
      case RETAIN_REPLY:
	return @"retain replay";
      default:
	return @"unknown operation type!";
    }
}

@interface	NSDistantObject (NSConnection)
- (id) localForProxy;
- (void) setProxyTarget: (unsigned)target;
- (unsigned) targetForProxy;
@end

@implementation	NSDistantObject (NSConnection)
- (id) localForProxy
{
  return _object;
}
- (void) setProxyTarget: (unsigned)target
{
  _handle = target;
}
- (unsigned) targetForProxy
{
  return _handle;
}
@end

/*
 *	GSLocalCounter is a trivial class to keep track of how
 *	many different connections a particular local object is vended
 *	over.  This is required so that we know when to remove an object
 *	from the global list when it is removed from the list of objects
 *	vended on a particular connection.
 */
@interface	GSLocalCounter : NSObject
{
@public
  unsigned	ref;
  unsigned	target;
  id		object;
}
+ (GSLocalCounter*) newWithObject: (id)ob;
@end

@implementation	GSLocalCounter

static unsigned local_object_counter = 0;

+ (GSLocalCounter*) newWithObject: (id)obj
{
  GSLocalCounter	*counter;

  counter = (GSLocalCounter*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  counter->ref = 1;
  counter->object = RETAIN(obj);
  counter->target = ++local_object_counter;
  return counter;
}
- (void) dealloc
{
  RELEASE(object);
  [super dealloc];
}
@end



/*
 *	CachedLocalObject is a trivial class to keep track of how
 *	many different connections a particular local object is vended
 *	over.  This is required so that we know when to remove an object
 *	from the global list when it is removed from the list of objects
 *	vended on a particular connection.
 */
@interface	CachedLocalObject : NSObject
{
  id	obj;
  int	time;
}
- (BOOL)countdown;
- (id) obj;
+ (CachedLocalObject*) itemWithObject: (id)o time: (int)t;
@end

@implementation	CachedLocalObject

+ (CachedLocalObject*) itemWithObject: (id)o time: (int)t
{
  CachedLocalObject	*item = [[self alloc] init];

  item->obj = RETAIN(o);
  item->time = t;
  return AUTORELEASE(item);
}

- (void) dealloc
{
  RELEASE(obj);
  [super dealloc];
}

- (BOOL) countdown
{
  if (time-- > 0)
    return YES;
  return NO;
}

- (id) obj
{
  return obj;
}

@end



@interface NSConnection (Private)
+ (void) setDebug: (int)val;
- (void) handlePortMessage: (NSPortMessage*)msg;

- _getReplyRmc: (int)n;
- (NSPortCoder*) _makeRmc: (int)sequence;
- (int) _newMsgNumber;
- (void) _sendRmc: (NSPortCoder*)c type: (int)msgid;

- (void) _service_forwardForProxy: (NSPortCoder*)rmc;
- (void) _service_release: (NSPortCoder*)rmc;
- (void) _service_retain: (NSPortCoder*)rmc;
- (void) _service_rootObject: (NSPortCoder*)rmc;
- (void) _service_shutdown: (NSPortCoder*)rmc;
- (void) _service_typeForSelector: (NSPortCoder*)rmc;
@end

#define _proxiesGate _refGate
#define _queueGate _refGate
#define sequenceNumberGate _refGate


/* class defaults */
static NSTimer *timer;

static int debug_connection = 0;

static NSHashTable	*connection_table;
static NSLock		*connection_table_gate;

/*
 * Locate an existing connection with the specified send and receive ports.
 * nil ports act as wildcards and return the first match.
 */
static NSConnection*
existingConnection(NSPort *receivePort, NSPort *sendPort)
{
  NSHashEnumerator	enumerator;
  NSConnection		*c;

  F_LOCK(connection_table_gate);
  enumerator = NSEnumerateHashTable(connection_table);
  while ((c = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      if ((sendPort == nil || [sendPort isEqual: [c sendPort]])
        && (receivePort == nil || [receivePort isEqual: [c receivePort]]))
	{
	  /*
	   * We don't want this connection to be destroyed by another thread
	   * between now and when it's returned from this function and used!
	   */
	  AUTORELEASE(RETAIN(c));
	  break;
	}
    }
  F_UNLOCK(connection_table_gate);
  return c;
}

static NSMapTable *root_object_map;
static NSLock *root_object_map_gate;

static id
rootObjectForInPort(NSPort *aPort)
{
  id	rootObject;

  F_LOCK(root_object_map_gate);
  rootObject = (id)NSMapGet(root_object_map, (void*)(gsaddr)aPort);
  F_UNLOCK(root_object_map_gate);
  return rootObject;
}

/* Pass nil to remove any reference keyed by aPort. */
static void
setRootObjectForInPort(id anObj, NSPort *aPort)
{
  id	oldRootObject;

  F_LOCK(root_object_map_gate);
  oldRootObject = (id)NSMapGet(root_object_map, (void*)(gsaddr)aPort);
  if (oldRootObject != anObj)
    {
      if (anObj != nil)
	{
	  NSMapInsert(root_object_map, (void*)(gsaddr)aPort,
	    (void*)(gsaddr)anObj);
	}
      else /* anObj == nil && oldRootObject != nil */
	{
	  NSMapRemove(root_object_map, (void*)(gsaddr)aPort);
	}
    }
  F_UNLOCK(root_object_map_gate);
}

static NSMapTable *all_connections_local_objects = NULL;
static NSMapTable *all_connections_local_targets = NULL;
static NSMapTable *all_connections_local_cached = NULL;
static NSLock		*global_proxies_gate;

/* rmc handling */
static NSMutableArray *received_request_rmc_queue;
static NSLock *received_request_rmc_queue_gate;
static NSMutableArray *received_reply_rmc_queue;
static NSLock *received_reply_rmc_queue_gate;

static int messages_received_count;




@implementation NSConnection

+ (NSArray*) allConnections
{
  return NSAllHashTableObjects(connection_table);
}

+ (NSConnection*) connectionWithReceivePort: (NSPort*)r
				   sendPort: (NSPort*)s
{
  NSConnection	*c = existingConnection(r, s);

  if (c == nil)
    {
      c = [self allocWithZone: NSDefaultMallocZone()];
      c = [c initWithReceivePort: r sendPort: s];
      AUTORELEASE(c);
    }
  return c;
}

+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
					  host: (NSString*)h
{
  NSPortNameServer	*s;

  s = [NSPortNameServer defaultPortNameServer];
  return [self connectionWithRegisteredName: n
				       host: h
			    usingNameServer: s];
}

+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
					  host: (NSString*)h
			       usingNameServer: (NSPortNameServer*)s
{
  NSConnection		*con = nil;

  if (s != nil)
    {
      NSPort	*sendPort = [s portForName: n onHost: h];

      if (sendPort != nil)
	{
	  con = existingConnection(nil, sendPort);
	  if (con == nil)
	    {
	      NSPort	*recvPort;

	      recvPort = [[self defaultConnection] receivePort];
	      con = [self connectionWithReceivePort: recvPort
					   sendPort: sendPort];
	    }
	}
    }
  return con;
}

+ (id) currentConversation
{
  [self notImplemented: _cmd];
  return self;
}

/*
 *	Get the default connection for a thread.
 *	Possible problem - if the connection is invalidated, it won't be
 *	cleaned up until this thread calls this method again.  The connection
 *	and it's ports could hang around for a very long time.
 */
+ (NSConnection*) defaultConnection
{
  static NSString	*tkey = @"NSConnectionThreadKey";
  NSConnection		*c;
  NSMutableDictionary	*d;

  d = GSCurrentThreadDictionary();
  c = (NSConnection*)[d objectForKey: tkey];
  if (c != nil && [c isValid] == NO)
    {
      /*
       * If the default connection for this thread has been invalidated -
       * release it and create a new one.
       */
      [d removeObjectForKey: tkey];
      c = nil;
    }
  if (c == nil)
    {
      NSPort	*port;

      c = [self alloc];
      port = [NSPort port];
      c = [c initWithReceivePort: port sendPort: nil];
      [d setObject: c forKey: tkey];
      RELEASE(c);
    }
  return c;
}

+ (void) initialize
{
  connection_table = 
    NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 0);
  connection_table_gate = [NSLock new];
  /* xxx When NSHashTable's are working, change this. */
  all_connections_local_objects =
    NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  all_connections_local_targets =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  all_connections_local_cached =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  global_proxies_gate = [NSLock new];
  received_request_rmc_queue = [[NSMutableArray alloc] initWithCapacity: 32];
  received_request_rmc_queue_gate = [NSLock new];
  received_reply_rmc_queue = [[NSMutableArray alloc] initWithCapacity: 32];
  received_reply_rmc_queue_gate = [NSLock new];
  root_object_map =
    NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  root_object_map_gate = [NSLock new];
  messages_received_count = 0;
}

+ (id) new
{
  /*
   * Undocumented feature of OPENSTEP/MacOS-X
   * +new returns the default connection.
   */
  return RETAIN([self defaultConnection]);
}

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
						         host: (NSString*)h
{
  NSConnection		*connection;
  NSDistantObject	*proxy = nil;

  connection = [self connectionWithRegisteredName: n host: h];
  if (connection != nil)
    {
      proxy = [connection rootProxy];
    }
  
  return proxy;
}

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
  host: (NSString*)h usingNameServer: (NSPortNameServer*)s
{
  NSConnection		*connection;
  NSDistantObject	*proxy = nil;

  connection = [self connectionWithRegisteredName: n
					     host: h
				  usingNameServer: s];
  if (connection != nil)
    {
      proxy = [connection rootProxy];
    }
  
  return proxy;
}

+ (void) _timeout: (NSTimer*)t
{
  NSArray	*cached_locals;
  int	i;

  cached_locals = NSAllMapTableValues(all_connections_local_cached);
  for (i = [cached_locals count]; i > 0; i--)
    {
      CachedLocalObject *item = [cached_locals objectAtIndex: i-1];

      if ([item countdown] == NO)
	{
	  GSLocalCounter	*counter = [item obj];
	  NSMapRemove(all_connections_local_cached, (void*)counter->target);
	}
    }
  if ([cached_locals count] == 0)
    {
      [t invalidate];
      timer = nil;
    }
}

- (void) addRequestMode: (NSString*)mode
{
  M_LOCK(_refGate);
  if ([self isValid] == YES)
    {
      if ([_requestModes containsObject: mode] == NO)
	{
	  unsigned	c = [_runLoops count];

	  while (c-- > 0)
	    {
	      NSRunLoop	*loop = [_runLoops objectAtIndex: c];

	      [loop addPort: _receivePort forMode: mode];
	    }
	  [_requestModes addObject: mode];
	}
    }
  M_UNLOCK(_refGate);
}

- (void) addRunLoop: (NSRunLoop*)loop
{
  M_LOCK(_refGate);
  if ([self isValid] == YES)
    {
      if ([_runLoops indexOfObjectIdenticalTo: loop] == NSNotFound)
	{
	  unsigned	c = [_requestModes count];

	  while (c-- > 0)
	    {
	      NSString	*mode = [_requestModes objectAtIndex: c];

	      [loop addPort: _receivePort forMode: mode];
	    }
	  [_runLoops addObject: loop];
	}
    }
  M_UNLOCK(_refGate);
}

- (void) dealloc
{
  if (debug_connection)
    NSLog(@"deallocating 0x%x", (gsaddr)self);
  [super dealloc];
}

- (id) delegate
{
  return GS_GC_UNHIDE(_delegate);
}

- (void) enableMultipleThreads
{
  [self notImplemented: _cmd];
}

- (BOOL) independentConversationQueueing
{
  return _independentQueueing;
}

- (id) init
{
  /*
   * Undocumented feature of OPENSTEP/MacOS-X
   * -init returns the default connection.
   */
  RELEASE(self);
  return RETAIN([NSConnection defaultConnection]);
}

/* This is the designated initializer for NSConnection */
- (id) initWithReceivePort: (NSPort*)r
		  sendPort: (NSPort*)s
{
  NSNotificationCenter	*nCenter;
  NSConnection		*parent;
  NSConnection		*conn;
  NSRunLoop		*loop;
  id			del;

  /*
   * If the receive port is nil, deallocate connection and return nil.
   */
  if (r == nil)
    {
      if (debug_connection > 2)
	{
	  NSLog(@"Asked to create connection with nil receive port");
	}
      DESTROY(self);
      return self;
    }

  /*
   * If the send port is nil, set it to the same as the receive port
   * This connection will then only be useful to act as a server.
   */
  if (s == nil)
    {
      s = r;
    }

  conn = existingConnection(r, s);

  /*
   * If the send and receive ports match an existing connection
   * deallocate the new one and retain and return the old one.
   */
  if (conn != nil)
    {
      RELEASE(self);
      self = RETAIN(conn);
      if (debug_connection > 2)
	{
	  NSLog(@"Found existing connection (0x%x) for \n\t%@\n\t%@",
	    (gsaddr)conn, r, s);
	}
      return self;
    }

  /*
   * The parent connection is the one whose send and receive ports are
   * both the same as our receive port.
   */
  parent = existingConnection(r, r);

  if (debug_connection)
    {
      NSLog(@"Initialising new connection with parent 0x%x, 0x%x\n\t%@\n\t%@",
	(gsaddr)parent, (gsaddr)self, r, s);
    }

  M_LOCK(connection_table_gate);

  _isValid = YES;
  _receivePort = RETAIN(r);
  _sendPort = RETAIN(s);
  _messageCount = 0;
  _repOutCount = 0;
  _reqOutCount = 0;
  _repInCount = 0;
  _reqInCount = 0;

  /*
   * This is used to queue up incoming NSPortMessages representing requests
   * that can't immediately be dealt with.
   */
  _requestQueue = [NSMutableArray new];

  /*
   * This maps request sequence numbers to the NSPortCoder objects representing
   * replies arriving from the remote connection.
   */
  _replyMap =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /*
   * This maps (void*)obj to (id)obj.  The obj's are retained.
   * We use this instead of an NSHashTable because we only care about
   * the object's address, and don't want to send the -hash message to it.
   */
  _localObjects =
    NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /*
   * This maps handles for local objects to their local proxies.
   */
  _localTargets =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /*
   * This maps [proxy targetForProxy] to proxy.  The proxy's are retained.
   */
  _remoteProxies =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /*
   * Some attributes are inherited from the parent if possible.
   */
  if (parent != nil)
    {
      _independentQueueing = parent->_independentQueueing;
      _replyTimeout = parent->_replyTimeout;
      _requestTimeout = parent->_requestTimeout;
    }
  else
    {
      _independentQueueing = NO;
      _replyTimeout = CONNECTION_DEFAULT_TIMEOUT;
      _requestTimeout = CONNECTION_DEFAULT_TIMEOUT;
    }

  _requestDepth = 0;
  _delegate = nil;
  _refGate = [NSRecursiveLock new];

  /*
   *	Set up request modes array and make sure the receiving port is
   *	added to the run loop to get data.
   */
  loop = [NSRunLoop currentRunLoop];
  _runLoops = [[NSMutableArray alloc] initWithObjects: &loop count: 1];
  _requestModes = [[NSMutableArray alloc] initWithCapacity: 2];
  [self addRequestMode: NSDefaultRunLoopMode]; 
  [self addRequestMode: NSConnectionReplyMode]; 

  /* Ask the delegate for permission, (OpenStep-style and GNUstep-style). */

  /* Preferred MacOS-X version, which just allows the returning of BOOL */
  del = [parent delegate];
  if ([del respondsTo: @selector(connection:shouldMakeNewConnection:)])
    {
      if ([del connection: parent shouldMakeNewConnection: self] == NO)
	{
	  M_UNLOCK(connection_table_gate);
	  RELEASE(self);
	  return nil;
	}
    }
  /* Deprecated OpenStep version, which just allows the returning of BOOL */
  if ([del respondsTo: @selector(makeNewConnection:sender:)])
    {
      if (![del makeNewConnection: self sender: parent])
	{
	  M_UNLOCK(connection_table_gate);
	  RELEASE(self);
	  return nil;
	}
    }
  /* Here is the GNUstep version, which allows the delegate to specify
     a substitute.  Note: The delegate is responsible for freeing
     newConn if it returns something different. */
  if ([del respondsTo: @selector(connection:didConnect:)])
    self = [del connection: parent didConnect: self];

  /*
   * If we have no parent, we must handle incoming packets on our
   * receive port ourself - so we set ourself up as the port delegate.
   */
  if (parent == nil)
    {
      [_receivePort setDelegate: self];
    }

  /* Register ourselves for invalidation notification when the
     ports become invalid. */
  nCenter = [NSNotificationCenter defaultCenter];
  [nCenter addObserver: self
	      selector: @selector(portIsInvalid:)
		  name: NSPortDidBecomeInvalidNotification
		object: r];
  if (s != nil)
    [nCenter addObserver: self
		selector: @selector(portIsInvalid:)
		    name: NSPortDidBecomeInvalidNotification
		  object: s];

  /* In order that connections may be deallocated - there is an
     implementation of [-release] to automatically remove the connection
     from this array when it is the only thing retaining it. */
  NSHashInsert(connection_table, (void*)self);
  M_UNLOCK(connection_table_gate);

  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSConnectionDidInitializeNotification
		  object: self];

  return self;
}

- (void) invalidate
{
  BOOL	wasValid;

  M_LOCK(_refGate);
  wasValid = _isValid;
  _isValid = NO;
  M_UNLOCK(_refGate);

  if (wasValid == NO)
    {
      return;
    }

  /*
   *	Don't need notifications any more - so remove self as observer.
   */
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  /*
   * Withdraw from run loops.
   */
  [self setRequestMode: nil];

  RETAIN(self);

  if (debug_connection)
    {
      NSLog(@"Invalidating connection 0x%x\n\t%@\n\t%@",
	(gsaddr)self, _receivePort, _sendPort);
    }
  /*
   *	We need to notify any watchers of our death - but if we are already
   *	in the deallocation process, we can't have a notification retaining
   *	and autoreleasing us later once we are deallocated - so we do the
   *	notification with a local autorelease pool to ensure that any release
   *	is done before the deallocation completes.
   */
  {
    CREATE_AUTORELEASE_POOL(arp);

    [[NSNotificationCenter defaultCenter]
      postNotificationName: NSConnectionDidDieNotification
		    object: self];
    RELEASE(arp);
  }

  /*
   *	If we have been invalidated, we don't need to retain proxies
   *	for local objects any more.  In fact, we want to get rid of
   *	these proxies in case they are keeping us retained when we
   *	might otherwise de deallocated.
   */
  {
    NSArray *targets;
    unsigned 	i;

    M_LOCK(_proxiesGate);
    targets = NSAllMapTableValues(_localTargets);
    IF_NO_GC(RETAIN(targets));
    for (i = 0; i < [targets count]; i++)
      {
	id	t = [[targets objectAtIndex: i] localForProxy];

	[self removeLocalObject: t];
      }
    [targets release];
    M_UNLOCK(_proxiesGate);
  }

  RELEASE(self);
}

- (BOOL) isValid
{
  return _isValid;
}

- (NSArray*) localObjects
{
  NSArray	*c;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  c = NSAllMapTableValues(_localObjects);
  M_UNLOCK(_proxiesGate);
  return c;
}

- (BOOL) multipleThreadsEnabled
{
  [self notImplemented: _cmd];
  return NO;
}

- (NSPort*) receivePort
{
  return _receivePort;
}

- (BOOL) registerName: (NSString*)name
{
  NSPortNameServer	*svr = [NSPortNameServer defaultPortNameServer];

  return [self registerName: name withNameServer: svr];
}

- (BOOL) registerName: (NSString*)name withNameServer: (NSPortNameServer*)svr
{
  NSArray		*names = [svr namesForPort: _receivePort];
  BOOL			result = YES;
  unsigned		c;

  if (name != nil)
    {
      result = [svr registerPort: _receivePort forName: name];
    }
  if (result == YES && (c = [names count]) > 0)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  NSString	*tmp = [names objectAtIndex: i];

	  if ([tmp isEqualToString: name] == NO)
	    {
	      [svr removePort: _receivePort forName: name];
	    }
	}
    }
  return result;
}

- (void) release
{
  /*
   *	If this would cause the connection to be deallocated then we
   *	must perform all necessary work (done in [-gcFinalize]).
   *	We bracket the code with a retain and release so that any
   *	retain/release pairs in the code won't cause recursion.
   */
  if ([self retainCount] == 1)
    {
      [super retain];
      [self gcFinalize];
      [super release];
    }
  [super release];
}

- (NSArray *) remoteObjects
{
  NSArray	*c;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  c = NSAllMapTableValues(_remoteProxies);
  M_UNLOCK(_proxiesGate);
  return c;
}

- (void) removeRequestMode: (NSString*)mode
{
  M_LOCK(_refGate);
  if ([_requestModes containsObject: mode])
    {
      unsigned	c = [_runLoops count];

      while (c-- > 0)
	{
	  NSRunLoop	*loop = [_runLoops objectAtIndex: c];

	  [loop removePort: _receivePort forMode: mode];
	}
      [_requestModes removeObject: mode];
    }
  M_UNLOCK(_refGate);
}

- (void) removeRunLoop: (NSRunLoop*)loop
{
  unsigned	pos;

  M_LOCK(_refGate);
  pos = [_runLoops indexOfObjectIdenticalTo: loop];
  if (pos != NSNotFound)
    {
      unsigned	c = [_requestModes count];

      while (c-- > 0)
	{
	  NSString	*mode = [_requestModes objectAtIndex: c];

	  [loop removePort: _receivePort forMode: mode];
	}
      [_runLoops removeObjectAtIndex: pos];
    }
  M_UNLOCK(_refGate);
}

- (NSTimeInterval) replyTimeout
{
  return _replyTimeout;
}

- (NSArray*) requestModes
{
  return [[_requestModes copy] autorelease];
}

- (NSTimeInterval) requestTimeout
{
  return _requestTimeout;
}

- (id) rootObject
{
  return rootObjectForInPort(_receivePort);
}

- (NSDistantObject*) rootProxy
{
  NSPortCoder		*op;
  NSPortCoder		*ip;
  NSDistantObject	*newProxy = nil;
  int			seq_num;

  NSParameterAssert(_receivePort);
  NSParameterAssert(_isValid);

  seq_num = [self _newMsgNumber];
  op = [self _makeRmc: seq_num];
  [self _sendRmc: op type: ROOTPROXY_REQUEST];

  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(id) at: &newProxy];
  return AUTORELEASE(newProxy);
}

- (void) runInNewThread
{
  [self notImplemented: _cmd];
}

- (NSPort*) sendPort
{
  return _sendPort;
}

- (void) setDelegate: (id)anObj
{
  _delegate = GS_GC_HIDE(anObj);
  _authenticateIn =
    [anObj respondsToSelector: @selector(authenticateComponents:withData:)];
  _authenticateOut =
    [anObj respondsToSelector: @selector(authenticationDataForComponents:)];
}

- (void) setIndependentConversationQueueing: (BOOL)flag
{
  _independentQueueing = flag;
}

- (void) setReplyTimeout: (NSTimeInterval)to
{
  _replyTimeout = to;
}

- (void) setRequestMode: (NSString*)mode
{
  M_LOCK(_refGate);
  while ([_requestModes count] > 0 && [_requestModes objectAtIndex: 0] != mode)
    {
      [self removeRequestMode: [_requestModes objectAtIndex: 0]];
    }
  while ([_requestModes count] > 1)
    {
      [self removeRequestMode: [_requestModes objectAtIndex: 1]];
    }
  if (mode != nil && [_requestModes count] == 0)
    {
      [self addRequestMode: mode];
    }
  M_UNLOCK(_refGate);
}

- (void) setRequestTimeout: (NSTimeInterval)to
{
  _requestTimeout = to;
}

- (void) setRootObject: (id)anObj
{
  setRootObjectForInPort(anObj, _receivePort);
}

- (NSDictionary*) statistics
{
  NSMutableDictionary	*d;
  id			o;

  d = [NSMutableDictionary dictionaryWithCapacity: 8];

  M_LOCK(_refGate);

  /*
   *	These are in OPENSTEP 4.2
   */
  o = [NSNumber numberWithUnsignedInt: _repInCount];
  [d setObject: o forKey: NSConnectionRepliesReceived];
  o = [NSNumber numberWithUnsignedInt: _repOutCount];
  [d setObject: o forKey: NSConnectionRepliesSent];
  o = [NSNumber numberWithUnsignedInt: _reqInCount];
  [d setObject: o forKey: NSConnectionRequestsReceived];
  o = [NSNumber numberWithUnsignedInt: _reqOutCount];
  [d setObject: o forKey: NSConnectionRequestsSent];

  /*
   *	These are GNUstep extras
   */
  o = [NSNumber numberWithUnsignedInt: NSCountMapTable(_localTargets)];
  [d setObject: o forKey: NSConnectionLocalCount];
  o = [NSNumber numberWithUnsignedInt: NSCountMapTable(_remoteProxies)];
  [d setObject: o forKey: NSConnectionProxyCount];
  M_LOCK(received_request_rmc_queue_gate);
  o = [NSNumber numberWithUnsignedInt: [received_request_rmc_queue count]];
  M_UNLOCK(received_request_rmc_queue_gate);
  [d setObject: o forKey: @"Pending packets"];

  M_UNLOCK(_refGate);

  return d;
}

@end



@implementation	NSConnection (GNUstepExtensions)

- (void) gcFinalize
{
  CREATE_AUTORELEASE_POOL(arp);

  if (debug_connection)
    NSLog(@"finalising 0x%x", (gsaddr)self);

  [self invalidate];
  M_LOCK(connection_table_gate);
  NSHashRemove(connection_table, self);
  [timer invalidate];
  timer = nil;
  M_UNLOCK(connection_table_gate);

  /* Remove rootObject from root_object_map if this is last connection */
  if (_receivePort != nil && existingConnection(_receivePort, nil) == nil)
    {
      setRootObjectForInPort(nil, _receivePort);
    }

  /* Remove receive port from run loop. */
  [self setRequestMode: nil];

  DESTROY(_requestModes);
  DESTROY(_runLoops);

  /*
   * Finished with ports - releasing them may generate a notification
   * If we are the receive port delagate, try to shift responsibility.
   */
  if ([_receivePort delegate] == self)
    {
      NSConnection	*root = existingConnection(_receivePort, _receivePort);

      if (root == nil)
	{
	  root =  existingConnection(_receivePort, nil);
	}
      [_receivePort setDelegate: root];
    }
  DESTROY(_receivePort);
  DESTROY(_sendPort);

  M_LOCK(_proxiesGate);
  if (_remoteProxies != 0)
    {
      NSFreeMapTable(_remoteProxies);
      _remoteProxies = 0;
    }
  if (_localObjects != 0)
    {
      NSFreeMapTable(_localObjects);
      _localObjects = 0;
    }
  if (_localTargets != 0)
    {
      NSFreeMapTable(_localTargets);
      _localTargets = 0;
    }
  M_UNLOCK(_proxiesGate);

  DESTROY(_requestQueue);
  if (_replyMap != 0)
    {
      NSFreeMapTable(_replyMap);
      _replyMap = 0;
    }

  DESTROY(_refGate);
  RELEASE(arp);
}

/*
 * NSDistantObject's -forward: : method calls this to send the message
 * over the wire.
 */
- (retval_t) forwardForProxy: (NSDistantObject*)object
		    selector: (SEL)sel
                    argFrame: (arglist_t)argframe
{
  NSPortCoder *op;

  /* The callback for encoding the args of the method call. */
  void encoder (int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_ARGNAME @"argument value"
      switch (*type)
	{
	case _C_ID: 
	  if (flags & _F_BYCOPY)
	    [op encodeBycopyObject: *(id*)datum];
#ifdef	_F_BYREF
	  else if (flags & _F_BYREF)
	    [op encodeByrefObject: *(id*)datum];
#endif
	  else
	    [op encodeObject: *(id*)datum];
	  break;
	default: 
	  [op encodeValueOfObjCType: type at: datum];
	}
    }

  /* Encode the method on an RMC, and send it. */
  {
    BOOL	out_parameters;
    const char	*type;
    int		seq_num;
    retval_t	retframe;

    NSParameterAssert (_isValid);

    /* get the method types from the selector */
#if NeXT_runtime
    [NSException
      raise: NSGenericException
      format: @"Sorry, distributed objects does not work with NeXT runtime"];
    /* type = [object selectorTypeForProxy: sel]; */
#else
    type = sel_get_type(sel);
#endif
    if (type == 0 || *type == '\0') {
	type = [[object methodSignatureForSelector: sel] methodType];
	if (type) {
	    sel_register_typed_name(sel_get_name(sel), type);
	}
    }
    NSParameterAssert(type);
    NSParameterAssert(*type);

    seq_num = [self _newMsgNumber];
    op = [self _makeRmc: seq_num];

    if (debug_connection > 4)
      NSLog(@"building packet seq %d", seq_num);

    /* Send the types that we're using, so that the performer knows
       exactly what qualifiers we're using.
       If all selectors included qualifiers, and if I could make
       sel_types_match() work the way I wanted, we wouldn't need to do
       this. */
    [op encodeValueOfObjCType: @encode(char*) at: &type];

    /* xxx This doesn't work with proxies and the NeXT runtime because
       type may be a method_type from a remote machine with a
       different architecture, and its argframe layout specifiers
       won't be right for this machine! */
    out_parameters = mframe_dissect_call (argframe, type, encoder);

    [self _sendRmc: op type: METHOD_REQUEST];

    if (debug_connection > 1)
      NSLog(@"Sent message to 0x%x", (gsaddr)self);

    /* Get the reply rmc, and decode it. */
    {
      NSPortCoder	*ip = nil;
      BOOL		is_exception = NO;

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  if (type == 0)
	    {
	      if (ip != nil)
		{
		  /* this must be here to avoid trashing alloca'ed retframe */
		  ip = (id)-1;
		}
	      return;
	    }
	  /* If we didn't get the reply packet yet, get it now. */
	  if (!ip)
	    {
	      if (!_isValid)
		{
	          [NSException raise: NSGenericException
		      format: @"connection waiting for request was shut down"];
		}
	      /* xxx Why do we get the reply packet in here, and not
		 just before calling dissect_method_return() below? */
	      ip = [self _getReplyRmc: seq_num];
	      /* Find out if the server is returning an exception instead
		 of the return values. */
	      [ip decodeValueOfObjCType: @encode(BOOL) at: &is_exception];
	      if (is_exception)
		{
		  /* Decode the exception object, and raise it. */
		  id exc;
		  [ip decodeValueOfObjCType: @encode(id) at: &exc];
		  ip = (id)-1;
		  /* xxx Is there anything else to clean up in
		     dissect_method_return()? */
		  [exc raise];
		}
	    }
	  [ip decodeValueOfObjCType: type at: datum];
	  /* -decodeValueOfObjCType: at: malloc's new memory
	     for char*'s.  We need to make sure it gets freed eventually
	     so we don't have a memory leak.  Request here that it be
	     autorelease'ed. Also autorelease created objects. */
	  if ((*type == _C_CHARPTR || *type == _C_PTR) && *(void**)datum != 0)
	    [NSData dataWithBytesNoCopy: *(void**)datum length: 1];
          else if (*type == _C_ID)
            AUTORELEASE(*(id*)datum);
	}

      retframe = mframe_build_return (argframe, type, out_parameters, decoder);
      /* Make sure we processed all arguments, and dismissed the IP.
         IP is always set to -1 after being dismissed; the only places
	 this is done is in this function DECODER().  IP will be nil
	 if mframe_build_return() never called DECODER(), i.e. when
	 we are just returning (void).*/
      NSAssert(ip == (id)-1 || ip == nil, NSInternalInconsistencyException);
      _repInCount++;	/* received a reply */
      return retframe;
    }
  }
}

- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target
{
  id op, ip;
  char	*type = 0;
  int	seq_num;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  seq_num = [self _newMsgNumber];
  op = [self _makeRmc: seq_num];
  [op encodeValueOfObjCType: ":" at: &sel];
  [op encodeValueOfObjCType: @encode(unsigned) at: &target];
  [self _sendRmc: op type: METHODTYPE_REQUEST];
  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(char*) at: &type];
  return type;
}


/* Class-wide stats and collections. */

+ (int) messagesReceived
{
  return messages_received_count;
}

+ (unsigned) connectionsCount
{
  return NSCountHashTable(connection_table);
}

+ (unsigned) connectionsCountWithInPort: (NSPort*)aPort
{
  unsigned	count = 0;
  NSHashEnumerator	enumerator;
  NSConnection		*o;

  M_LOCK(connection_table_gate);
  enumerator = NSEnumerateHashTable(connection_table);
  while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      if ([aPort isEqual: [o receivePort]])
	{
	  count++;
	}
    }
  M_UNLOCK(connection_table_gate);

  return count;
}

@end





@implementation	NSConnection (Private)

- (void) handlePortMessage: (NSPortMessage*)msg
{
  NSPortCoder		*rmc;
  int			type = [msg msgid];
  NSMutableArray	*components = [msg _components];
  NSPort		*rp = [msg receivePort];
  NSPort		*sp = [msg sendPort];
  NSConnection		*conn;

  if (debug_connection > 4)
    {
      NSLog(@"handling packet of type %d (%@)", type, stringFromMsgType(type));
    }
  conn = [NSConnection connectionWithReceivePort: rp sendPort: sp];
  if (conn == nil)
    {
      NSLog(@"received port message for unknown connection - %@", msg);
      return;
    }
  else if ([conn isValid] == NO)
    {
      if (debug_connection)
	{
	  NSLog(@"received port message for invalid connection - %@", msg);
	}
      return;
    }

  if (_authenticateIn == YES)
    {
      NSData	*d;
      unsigned	count = [components count];

      d = AUTORELEASE(RETAIN([components objectAtIndex: --count]));
      [components removeObjectAtIndex: count];
      if ([[self delegate] authenticateComponents: components
					 withData: d] == NO)
	{
	  [NSException raise: NSFailedAuthenticationException
		      format: @"message not authenticated by delegate"];
	}
    }

  rmc = [NSPortCoder portCoderWithReceivePort: rp
				     sendPort: sp
				   components: components];
  switch (type)
    {
      case ROOTPROXY_REQUEST: 
	/* It won't take much time to handle this, so go ahead and service
	   it, even if we are waiting for a reply. */
	[conn _service_rootObject: rmc];
	break;

      case METHODTYPE_REQUEST: 
	/* It won't take much time to handle this, so go ahead and service
	   it, even if we are waiting for a reply. */
	[conn _service_typeForSelector: rmc];
	break;

      case METHOD_REQUEST: 
	/*
	 * We just got a new request; we need to decide whether to queue
	 * it or service it now.
	 * If the REPLY_DEPTH is 0, then we aren't in the middle of waiting
	 * for a reply, we are waiting for requests---so service it now.
	 * If REPLY_DEPTH is non-zero, we may still want to service it now
	 * if independent_queuing is NO.
	 */
	M_LOCK(conn->_queueGate);
	if (conn->_requestDepth == 0 || conn->_independentQueueing == NO)
	  {
	    conn->_requestDepth++;
	    M_UNLOCK(conn->_queueGate);
	    [conn _service_forwardForProxy: rmc];
	    M_LOCK(conn->_queueGate);
	    conn->_requestDepth--;
	  }
	else
	  {
	    [conn->_requestQueue addObject: rmc];
	  }
	/*
	 * Service any requests that were queued while we
	 * were waiting for replies.
	 */
	while (conn->_requestDepth == 0 && [conn->_requestQueue count] > 0)
	  {
	    rmc = [conn->_requestQueue objectAtIndex: 0];
	    RETAIN(rmc);
	    [conn->_requestQueue removeObjectAtIndex: 0];
	    M_UNLOCK(conn->_queueGate);
	    [conn _service_forwardForProxy: rmc];
	    M_LOCK(conn->_queueGate);
	    RELEASE(rmc);
	  }
	M_UNLOCK(conn->_queueGate);
	break;

      /*
       * For replies, we read the sequence number from the reply object and
       * store it in a map using thee sequence number as the key.  That way
       * it's easy for the connection to find replies by their numbers.
       */
      case ROOTPROXY_REPLY: 
      case METHOD_REPLY: 
      case METHODTYPE_REPLY: 
      case RETAIN_REPLY: 
	{
	  int	sequence;

	  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
	  M_LOCK(conn->_queueGate);
	  NSMapInsert(conn->_replyMap, (void*)sequence, rmc);
	  M_UNLOCK(conn->_queueGate);
	}
	break;

      case CONNECTION_SHUTDOWN: 
	{
	  [conn _service_shutdown: rmc];
	  break;
	}
      case PROXY_RELEASE: 
	{
	  [conn _service_release: rmc];
	  break;
	}
      case PROXY_RETAIN: 
	{
	  [conn _service_retain: rmc];
	  break;
	}
      default: 
	[NSException raise: NSGenericException
		    format: @"unrecognized NSPortCoder identifier"];
    }
}

+ (void) setDebug: (int)val
{
  debug_connection = val;
}

/* NSConnection calls this to service the incoming method request. */
- (void) _service_forwardForProxy: (NSPortCoder*)aRmc
{
  char	*forward_type = 0;
  id	op = nil;
  int	reply_sequence_number;

  void decoder (int argnum, void *datum, const char *type)
    {
      /* We need this "dismiss" to happen here and not later so that Coder
	 "-awake..." methods will get sent before the __builtin_apply! */
      if (argnum == -1 && datum == 0 && type == 0)
	{
	  return;
	}

      [aRmc decodeValueOfObjCType: type at: datum];
      /* -decodeValueOfObjCType: at: malloc's new memory
	 for char*'s.  We need to make sure it gets freed eventually
	 so we don't have a memory leak.  Request here that it be
	 autorelease'ed. Also autorelease created objects. */
      if ((*type == _C_CHARPTR || *type == _C_PTR) && *(void**)datum != 0)
	[NSData dataWithBytesNoCopy: *(void**)datum length: 1];
      else if (*type == _C_ID)
        AUTORELEASE(*(id*)datum);
    }

  void encoder (int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_RETNAME @"return value"
      if (op == nil)
	{
	  BOOL is_exception = NO;
	  /* It is possible that our connection died while the method was
	     being called - in this case we mustn't try to send the result
	     back to the remote application!	*/
	  if (!_isValid)
	    return;
	  op = [self _makeRmc: reply_sequence_number];
	  [op encodeValueOfObjCType: @encode(BOOL) at: &is_exception];
	}
      switch (*type)
	{
	  case _C_ID: 
	    if (flags & _F_BYCOPY)
	      [op encodeBycopyObject: *(id*)datum];
#ifdef	_F_BYREF
	    else if (flags & _F_BYREF)
	      [op encodeByrefObject: *(id*)datum];
#endif
	    else
	      [op encodeObject: *(id*)datum];
	    break;
	  default: 
	    [op encodeValueOfObjCType: type at: datum];
	}
    }

  /* Make sure don't let exceptions caused by servicing the client's
     request cause us to crash. */
  NS_DURING
    {
      NSParameterAssert (_isValid);

      /* Save this for later */
      [aRmc decodeValueOfObjCType: @encode(int) at: &reply_sequence_number];

      /* Get the types that we're using, so that we know
	 exactly what qualifiers the forwarder used.
	 If all selectors included qualifiers and I could make
	 sel_types_match() work the way I wanted, we wouldn't need
	 to do this. */
      [aRmc decodeValueOfObjCType: @encode(char*) at: &forward_type];

      if (debug_connection > 1)
        NSLog(@"Handling message from 0x%x", (gsaddr)self);
      _reqInCount++;	/* Handling an incoming request. */
      mframe_do_call (forward_type, decoder, encoder);
      if (op != nil)
	{
	  [self _sendRmc: op type: METHOD_REPLY];
	}
    }

  /* Make sure we pass all exceptions back to the requestor. */
  NS_HANDLER
    {
      BOOL is_exception = YES;

      /* Send the exception back to the client. */
      if (_isValid)
	{
	  NS_DURING
	    {
	      op = [self _makeRmc: reply_sequence_number];
	      [op encodeValueOfObjCType: @encode(BOOL)
				     at: &is_exception];
	      [op encodeBycopyObject: localException];
	      [self _sendRmc: op type: METHOD_REPLY];
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Exception when sending exception back to client - %@",
		localException);
	    }
	  NS_ENDHANDLER;
	}
    }
  NS_ENDHANDLER;
  if (forward_type != 0)
    {
      NSZoneFree(NSDefaultMallocZone(), forward_type);
    }
}

- (void) _service_rootObject: (NSPortCoder*)rmc
{
  id		rootObject = rootObjectForInPort(_receivePort);
  int		sequence;
  NSPortCoder	*op;

  NSParameterAssert(_receivePort);
  NSParameterAssert(_isValid);
  NSParameterAssert([rmc connection] == self);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeRmc: sequence];
  [op encodeObject: rootObject];
  [self _sendRmc: op type: ROOTPROXY_REPLY];
}

- (void) _service_release: (NSPortCoder*)rmc
{
  unsigned int	count;
  unsigned int	pos;
  int		sequence;

  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  [rmc decodeValueOfObjCType: @encode(typeof(count)) at: &count];

  for (pos = 0; pos < count; pos++)
    {
      unsigned		target;
      NSDistantObject	*prox;

      [rmc decodeValueOfObjCType: @encode(typeof(target)) at: &target];

      prox = (NSDistantObject*)[self includesLocalTarget: target];
      if (prox != nil)
	{
	  if (debug_connection > 3)
	    NSLog(@"releasing object with target (0x%x) on (0x%x)",
		target, (gsaddr)self);
	  [self removeLocalObject: [prox localForProxy]];
	}
      else if (debug_connection > 3)
	NSLog(@"releasing object with target (0x%x) on (0x%x) - nothing to do",
		target, (gsaddr)self);
    }
}

- (void) _service_retain: (NSPortCoder*)rmc
{
  unsigned	target;
  NSPortCoder	*op;
  int		sequence;

  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeRmc: sequence];

  [rmc decodeValueOfObjCType: @encode(typeof(target)) at: &target];

  if (debug_connection > 3)
    NSLog(@"looking to retain local object with target (0x%x) on (0x%x)",
		target, (gsaddr)self);

  if ([self includesLocalTarget: target] == nil)
    {
      GSLocalCounter	*counter;

      M_LOCK(global_proxies_gate);
      counter = NSMapGet (all_connections_local_targets, (void*)target);
      if (counter == nil)
	{
	  /*
	   *	If the target doesn't exist for any connection, but still
	   *	persists in the cache (ie it was recently released) then
	   *	we move it back from the cache to the main maps so we can
	   *	retain it on this connection.
	   */
	  counter = NSMapGet (all_connections_local_cached, (void*)target);
	  if (counter)
	    {
	      unsigned	t = counter->target;
	      id	o = counter->object;

	      NSMapInsert(all_connections_local_objects, (void*)o, counter);
	      NSMapInsert(all_connections_local_targets, (void*)t, counter);
	      NSMapRemove(all_connections_local_cached, (void*)t);
	      if (debug_connection > 3)
		NSLog(@"target (0x%x) moved from cache", target);
	    }
	}
      M_UNLOCK(global_proxies_gate);
      if (counter == nil)
	{
	  [op encodeObject: @"target not found anywhere"];
	  if (debug_connection > 3)
	    NSLog(@"target (0x%x) not found anywhere for retain", target);
	}
      else
	{
	  [NSDistantObject proxyWithLocal: counter->object
			       connection: self];
	  [op encodeObject: nil];
	  if (debug_connection > 3)
	    NSLog(@"retained object (0x%x) target (0x%x) on connection(0x%x)",
			counter->object, counter->target, self);
	}
    }
  else 
    {
      [op encodeObject: nil];
      if (debug_connection > 3)
	NSLog(@"target (0x%x) already retained on connection (0x%x)",
		target, self);
    }

  [self _sendRmc: op type: RETAIN_REPLY];
}

- (void) shutdown
{
  NSPortCoder	*op;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  op = [self _makeRmc: [self _newMsgNumber]];
  [self _sendRmc: op type: CONNECTION_SHUTDOWN];
}

- (void) _service_shutdown: (NSPortCoder*)rmc
{
  NSParameterAssert (_isValid);
  [self invalidate];
  [NSException raise: NSGenericException
	      format: @"connection waiting for request was shut down"];
}

- (void) _service_typeForSelector: (NSPortCoder*)rmc
{
  NSPortCoder	*op;
  unsigned	target;
  NSDistantObject *p;
  int		sequence;
  id o;
  SEL sel;
  const char *type;
  struct objc_method* m;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeRmc: sequence];

  [rmc decodeValueOfObjCType: ":" at: &sel];
  [rmc decodeValueOfObjCType: @encode(unsigned) at: &target];
  p = [self includesLocalTarget: target];
  o = [p localForProxy];

  /* xxx We should make sure that TARGET is a valid object. */
  /* Not actually a Proxy, but we avoid the warnings "id" would have made. */
  m = class_get_instance_method(((NSDistantObject*)o)->isa, sel);
  /* Perhaps I need to be more careful in the line above to get the
     version of the method types that has the type qualifiers in it.
     Search the protocols list. */
  if (m)
    type = m->method_types;
  else
    type = "";
  [op encodeValueOfObjCType: @encode(char*) at: &type];
  [self _sendRmc: op type: METHODTYPE_REPLY];
}


/* Running the connection, getting/sending requests/replies. */

- (void) runConnectionUntilDate: date
{
  [NSRunLoop runUntilDate: date];
}

- (void) runConnection
{
  [self runConnectionUntilDate: [NSDate distantFuture]];
}

/*
 * Check the queue, then try to get it from the network by waiting
 * while we run the NSRunLoop.  Raise exception if we don't get anything
 * before timing out.
 */
- _getReplyRmc: (int)sn
{
  NSPortCoder	*rmc;
  NSDate	*timeout_date = nil;

  M_LOCK(_queueGate);
  while ((rmc = (NSPortCoder*)NSMapGet(_replyMap, (void*)sn)) == nil)
    {
      if (timeout_date == nil)
	{
	  timeout_date = [NSDate dateWithTimeIntervalSinceNow: _replyTimeout];
	}
      M_UNLOCK(_queueGate);
      if ([NSRunLoop runOnceBeforeDate: timeout_date
			       forMode: NSConnectionReplyMode] == NO)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out waiting for reply"];
	}
      M_LOCK(_queueGate);
    }
  M_UNLOCK(_queueGate);
  return rmc;
}

- (NSPortCoder*) _makeRmc: (int)sequence
{
  NSPortCoder		*coder;

  NSParameterAssert(_isValid);

  coder = [NSPortCoder portCoderWithReceivePort: [self receivePort]
				       sendPort: [self sendPort]
				     components: nil];
  [coder encodeValueOfObjCType: @encode(int) at: &sequence];
  return coder;
}

- (int) _newMsgNumber
{
  int n;

  NSParameterAssert (_isValid);
  M_LOCK(sequenceNumberGate);
  n = _messageCount++;
  M_UNLOCK(sequenceNumberGate);
  return n;
}

- (void) _sendRmc: (NSPortCoder*)c type: (int)msgid
{
  NSDate		*limit;
  BOOL			raiseException = NO;
  NSMutableArray	*components = [c _components];

  if (_authenticateOut == YES)
    {
      NSData	*d;

      d = [[self delegate] authenticationDataForComponents: components];
      if (d == nil)
	{
	  [NSException raise: NSGenericException
		      format: @"Bad authentication data provided by delegate"];
	}
      [components addObject: d];
    }
  limit = [NSDate dateWithTimeIntervalSinceNow: [self requestTimeout]];
  if ([_sendPort sendBeforeDate: limit
			  msgid: msgid
		     components: components
			   from: _receivePort
		       reserved: [_sendPort reservedSpaceLength]] == NO)
    {
      NSString	*text;

      switch (msgid)
	{
	  case CONNECTION_SHUTDOWN:
	  case METHOD_REPLY:
	  case ROOTPROXY_REPLY:
	  case METHODTYPE_REPLY:
	  case PROXY_RELEASE:
	  case PROXY_RETAIN:
	  case RETAIN_REPLY:
	    raiseException = YES;
	    break;

	  case METHOD_REQUEST:
	  case ROOTPROXY_REQUEST:
	  case METHODTYPE_REQUEST:
	  default:
	    raiseException = YES;
	    break;
	}
      text = stringFromMsgType(msgid);
      if (raiseException == YES)
	{
	  [NSException raise: NSPortTimeoutException format: text];
	}
      else
	{
	  NSLog(@"Port operation timed out - %@", text);
	}
    }
  else
    {
      switch (msgid)
	{
	  case METHOD_REQUEST:
	    _reqOutCount++;		/* Sent a request.	*/
	    break;
	  case METHOD_REPLY:
	    _repOutCount++;		/* Sent back a reply. */
	    break;
	  default:
	    break;
	}
    }
}




/* Managing objects and proxies. */
- (void) addLocalObject: (id)anObj
{
  id			object = [anObj localForProxy];
  unsigned		target;
  GSLocalCounter	*counter;

  NSParameterAssert (_isValid);
  M_LOCK(_proxiesGate);
  M_LOCK(global_proxies_gate);
  /* xxx Do we need to check to make sure it's not already there? */
  /* This retains object. */
  NSMapInsert(_localObjects, (void*)object, anObj);

  /*
   *	Keep track of local objects accross all connections.
   */
  counter = NSMapGet(all_connections_local_objects, (void*)object);
  if (counter)
    {
      counter->ref++;
      target = counter->target;
    }
  else
    {
      counter = [GSLocalCounter newWithObject: object];
      target = counter->target;
      NSMapInsert(all_connections_local_objects, (void*)object, counter);
      NSMapInsert(all_connections_local_targets, (void*)target, counter);
      [counter release];
    }
  [anObj setProxyTarget: target];
  NSMapInsert(_localTargets, (void*)target, anObj);
  if (debug_connection > 2)
    NSLog(@"add local object (0x%x) target (0x%x) "
	  @"to connection (0x%x) (ref %d)",
		(gsaddr)object, target, (gsaddr) self, counter->ref);
  M_UNLOCK(global_proxies_gate);
  M_UNLOCK(_proxiesGate);
}

- (NSDistantObject*) localForObject: (id)object
{
  NSDistantObject *p;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  p = NSMapGet (_localObjects, (void*)object);
  M_UNLOCK(_proxiesGate);
  NSParameterAssert(!p || [p connectionForProxy] == self);
  return p;
}

/* This should get called whenever an object free's itself */
+ (void) removeLocalObject: (id)anObj
{
  NSHashEnumerator	enumerator;
  NSConnection		*o;

  enumerator = NSEnumerateHashTable(connection_table);
  while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      [o removeLocalObject: anObj];
    }
}

- (void) removeLocalObject: (id)anObj
{
  NSDistantObject	*prox;
  unsigned		target;
  GSLocalCounter	*counter;
  unsigned		val = 0;

  M_LOCK(global_proxies_gate);
  M_LOCK(_proxiesGate);

  prox = NSMapGet(_localObjects, (void*)anObj);
  target = [prox targetForProxy];

  /*
   *	If all references to a local proxy have gone - remove the
   *	global reference as well.
   */
  counter = NSMapGet(all_connections_local_objects, (void*)anObj);
  if (counter)
    {
      counter->ref--;
      if ((val = counter->ref) == 0)
	{
	  /*
	   *	If this proxy has been vended onwards by another process, we
	   *	need to keep a reference to the local object around for a
	   *	while in case that other process needs it.
	   */
	  if (0)
	    {
	      id	item;
	      if (timer == nil)
		{
		  timer = [NSTimer scheduledTimerWithTimeInterval: 1.0
					 target: [NSConnection class]
					 selector: @selector(_timeout: )
					 userInfo: nil
					  repeats: YES];
		}
	      item = [CachedLocalObject itemWithObject: counter time: 30];
	      NSMapInsert(all_connections_local_cached, (void*)target, item);
	      if (debug_connection > 3)
		NSLog(@"placed local object (0x%x) target (0x%x) in cache",
			    (gsaddr)anObj, target);
	    }
	  NSMapRemove(all_connections_local_objects, (void*)anObj);
	  NSMapRemove(all_connections_local_targets, (void*)target);
	}
    }

  NSMapRemove(_localObjects, (void*)anObj);
  NSMapRemove(_localTargets, (void*)target);

  if (debug_connection > 2)
    NSLog(@"remove local object (0x%x) target (0x%x) "
	@"from connection (0x%x) (ref %d)",
		(gsaddr)anObj, target, (gsaddr)self, val);

  M_UNLOCK(_proxiesGate);
  M_UNLOCK(global_proxies_gate);
}

- (void) _release_targets: (unsigned*)list count: (unsigned)number
{
  NS_DURING
    {
      /*
       *	Tell the remote app that it can release its local objects
       *	for the targets in the specified list since we don't have
       *	proxies for them any more.
       */
      if (_receivePort && _isValid && number > 0)
	{
	  id		op;
	  unsigned 	i;
	  int		sequence = [self _newMsgNumber];

	  op = [self _makeRmc: sequence];

	  [op encodeValueOfObjCType: @encode(unsigned) at: &number];

	  for (i = 0; i < number; i++)
	    {
	      [op encodeValueOfObjCType: @encode(unsigned) at: &list[i]];
	      if (debug_connection > 3)
		NSLog(@"sending release for target (0x%x) on (0x%x)",
		      list[i], (gsaddr)self);
	    }

	  [self _sendRmc: op type: PROXY_RELEASE];
	}
    }
  NS_HANDLER
    {
      if (debug_connection)
        NSLog(@"failed to release targets - %@", localException);
    }
  NS_ENDHANDLER
}

- (void) retainTarget: (unsigned)target
{
  NS_DURING
    {
      /*
       *	Tell the remote app that it must retain the local object
       *	for the target on this connection.
       */
      if (_receivePort && _isValid)
	{
	  NSPortCoder	*op;
	  id	ip;
	  id	result;
	  int	seq_num = [self _newMsgNumber];

	  op = [self _makeRmc: seq_num];
	  [op encodeValueOfObjCType: @encode(typeof(target)) at: &target];
	  [self _sendRmc: op type: PROXY_RETAIN];

	  ip = [self _getReplyRmc: seq_num];
	  [ip decodeValueOfObjCType: @encode(id) at: &result];
	  if (result != nil)
	    NSLog(@"failed to retain target - %@", result);
	}
    }
  NS_HANDLER
    {
      NSLog(@"failed to retain target - %@", localException);
    }
  NS_ENDHANDLER
}

- (void) removeProxy: (NSDistantObject*)aProxy
{
  unsigned target = [aProxy targetForProxy];

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  /* This also releases aProxy */
  NSMapRemove(_remoteProxies, (void*)target);
  M_UNLOCK(_proxiesGate);

  /*
   *	Tell the remote application that we have removed our proxy and
   *	it can release it's local object.
   */
  [self _release_targets: &target count: 1];
}

- (NSDistantObject*) proxyForTarget: (unsigned)target
{
  NSDistantObject *p;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  p = NSMapGet(_remoteProxies, (void*)target);
  M_UNLOCK(_proxiesGate);
  NSParameterAssert(!p || [p connectionForProxy] == self);
  return p;
}

- (void) addProxy: (NSDistantObject*) aProxy
{
  unsigned target = (unsigned int)[aProxy targetForProxy];

  NSParameterAssert (_isValid);
  NSParameterAssert(aProxy->isa == [NSDistantObject class]);
  NSParameterAssert([aProxy connectionForProxy] == self);
  M_LOCK(_proxiesGate);
  if (NSMapGet(_remoteProxies, (void*)target))
    {
      M_UNLOCK(_proxiesGate);
      [NSException raise: NSGenericException
		  format: @"Trying to add the same proxy twice"];
    }
  NSMapInsert(_remoteProxies, (void*)target, aProxy);
  M_UNLOCK(_proxiesGate);
}

- (id) includesProxyForTarget: (unsigned)target
{
  NSDistantObject	*ret;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  ret = NSMapGet (_remoteProxies, (void*)target);
  M_UNLOCK(_proxiesGate);
  return ret;
}

- (id) includesLocalObject: (id)anObj
{
  NSDistantObject	*ret;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  ret = NSMapGet(_localObjects, (void*)anObj);
  M_UNLOCK(_proxiesGate);
  return ret;
}

- (id) includesLocalTarget: (unsigned)target
{
  NSDistantObject	*ret;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  ret = NSMapGet(_localTargets, (void*)target);
  M_UNLOCK(_proxiesGate);
  return ret;
}

/* Check all connections.
   Proxy needs to use this when decoding a local object in order to
   make sure the target address is a valid object.  It is not enough
   for the Proxy to check the Proxy's connection only (using
   -includesLocalTarget), because the proxy may have come from a
   triangle connection. */
+ (id) includesLocalTarget: (unsigned)target
{
  id ret;

  /* Don't assert (_isValid); */
  M_LOCK(global_proxies_gate);
  ret = NSMapGet(all_connections_local_targets, (void*)target);
  M_UNLOCK(global_proxies_gate);
  return ret;
}


/* Accessing ivars */


/* Prevent trying to encode the connection itself */

- (void) encodeWithCoder: (NSCoder*)anEncoder
{
  [self shouldNotImplement: _cmd];
}

- (id) initWithCoder: (NSCoder*)aDecoder;
{
  [self shouldNotImplement: _cmd];
  return self;
}


/* Shutting down and deallocating. */

/*
 *	We register this method for a notification when a port dies.
 *	NB. It is possible that the death of a port could be notified
 *	to us after we are invalidated - in which case we must ignore it.
 */
- (void) portIsInvalid: (NSNotification*)notification
{
  if (_isValid)
    {
      id port = [notification object];

      if (debug_connection)
	{
	  NSLog(@"Received port invalidation notification for "
	      @"connection 0x%x\n\t%@", (gsaddr)self, port);
	}

      /* We shouldn't be getting any port invalidation notifications,
	  except from our own ports; this is how we registered ourselves
	  with the NSNotificationCenter in
	  +newForInPort: outPort: ancestorConnection. */
      NSParameterAssert (port == _receivePort || port == _sendPort);

      [self invalidate];
    }
}

@end

