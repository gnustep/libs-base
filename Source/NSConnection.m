#if	GS_NEW_DO
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

/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_RETAIN_KEY(X)	
#define	GSI_MAP_RELEASE_KEY(X)	
#define	GSI_MAP_RETAIN_VAL(X)	
#define	GSI_MAP_RELEASE_VAL(X)	
#define	GSI_MAP_HASH(X)	((X).uint ^ ((X).uint >> 3))
#define	GSI_MAP_EQUAL(X,Y)	((X).ptr == (Y).ptr)

#include <base/GSIMap.h>

#define	_IN_CONNECTION_M
#include <Foundation/NSConnection.h>
#undef	_IN_CONNECTION_M

#include <Foundation/NSPortCoder.h>
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

static id	dummyObject;
static Class	connectionClass;
static Class	dateClass;
static Class	distantObjectClass;
static Class	portCoderClass;
static Class	runLoopClass;

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
+ (id) newWithObject: (id)ob;
@end

@implementation	GSLocalCounter

static unsigned local_object_counter = 0;

+ (id) newWithObject: (id)obj
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
  NSDeallocateObject(self);
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
- (BOOL) countdown;
- (id) obj;
+ (id) newWithObject: (id)o time: (int)t;
@end

@implementation	CachedLocalObject

+ (id) newWithObject: (id)o time: (int)t
{
  CachedLocalObject	*item;

  item = (CachedLocalObject*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  item->obj = RETAIN(o);
  item->time = t;
  return item;
}

- (void) dealloc
{
  RELEASE(obj);
  NSDeallocateObject(self);
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
- (void) handlePortMessage: (NSPortMessage*)msg;
- (void) _runInNewThread;
+ (void) setDebug: (int)val;

- (void) _doneInRmc: (NSPortCoder*)c;
- (NSPortCoder*) _getReplyRmc: (int)sn;
- (NSPortCoder*) _makeInRmc: (NSMutableArray*)components;
- (NSPortCoder*) _makeOutRmc: (int)sequence generate: (int*)sno reply: (BOOL)f;
- (void) _sendOutRmc: (NSPortCoder*)c type: (int)msgid;

- (void) _service_forwardForProxy: (NSPortCoder*)rmc;
- (void) _service_release: (NSPortCoder*)rmc;
- (void) _service_retain: (NSPortCoder*)rmc;
- (void) _service_rootObject: (NSPortCoder*)rmc;
- (void) _service_shutdown: (NSPortCoder*)rmc;
- (void) _service_typeForSelector: (NSPortCoder*)rmc;
@end

#define _proxiesGate _refGate
#define _queueGate _refGate


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
static NSLock	*global_proxies_gate;




@implementation NSConnection

+ (NSArray*) allConnections
{
  NSArray	*a;

  M_LOCK(connection_table_gate);
  a = NSAllHashTableObjects(connection_table);
  M_UNLOCK(connection_table_gate);
  return a;
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

  s = [NSPortNameServer systemDefaultPortNameServer];
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
	  NSPort	*recvPort;

	  recvPort = [[self defaultConnection] receivePort];
	  con = existingConnection(recvPort, sendPort);
	  if (con == nil)
	    {
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
  if (self == [NSConnection class])
    {
      connectionClass = self;
      dateClass = [NSDate class];
      distantObjectClass = [NSDistantObject class];
      portCoderClass = [NSPortCoder class];
      runLoopClass = [NSRunLoop class];

      dummyObject = [NSObject new];

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
      root_object_map =
	NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
      root_object_map_gate = [NSLock new];
    }
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
  _multipleThreads = YES;
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
  return RETAIN([connectionClass defaultConnection]);
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
  NSZone		*z = NSDefaultMallocZone();

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
   * These arrays cache NSPortCoder objects
   */
  _cachedDecoders = [NSMutableArray new];
  _cachedEncoders = [NSMutableArray new];

  /*
   * This is used to queue up incoming NSPortMessages representing requests
   * that can't immediately be dealt with.
   */
  _requestQueue = [NSMutableArray new];

  /*
   * This maps request sequence numbers to the NSPortCoder objects representing
   * replies arriving from the remote connection.
   */
  _replyMap = (GSIMapTable)NSZoneMalloc(z, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(_replyMap, z, 4);

  /*
   * This maps (void*)obj to (id)obj.  The obj's are retained.
   * We use this instead of an NSHashTable because we only care about
   * the object's address, and don't want to send the -hash message to it.
   */
  _localObjects = (GSIMapTable)NSZoneMalloc(z, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(_localObjects, z, 4);

  /*
   * This maps handles for local objects to their local proxies.
   */
  _localTargets = (GSIMapTable)NSZoneMalloc(z, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(_localTargets, z, 4);

  /*
   * This maps [proxy targetForProxy] to proxy.  The proxy's are retained.
   */
  _remoteProxies = (GSIMapTable)NSZoneMalloc(z, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(_remoteProxies, z, 4);

  _requestDepth = 0;
  _delegate = nil;
  _refGate = [NSRecursiveLock new];

  /*
   * Some attributes are inherited from the parent if possible.
   */
  if (parent != nil)
    {
      unsigned	count;

      _multipleThreads = parent->_multipleThreads;
      _independentQueueing = parent->_independentQueueing;
      _replyTimeout = parent->_replyTimeout;
      _requestTimeout = parent->_requestTimeout;
      _runLoops = [parent->_runLoops mutableCopy];
      count = [parent->_requestModes count];
      _requestModes = [[NSMutableArray alloc] initWithCapacity: count];
      while (count-- > 0)
	{
	  [self addRequestMode: [parent->_requestModes objectAtIndex: count]];
	}
    }
  else
    {
      _multipleThreads = NO;
      _independentQueueing = NO;
      _replyTimeout = CONNECTION_DEFAULT_TIMEOUT;
      _requestTimeout = CONNECTION_DEFAULT_TIMEOUT;
      /*
       * Set up request modes array and make sure the receiving port
       * is added to the run loop to get data.
       */
      loop = [runLoopClass currentRunLoop];
      _runLoops = [[NSMutableArray alloc] initWithObjects: &loop count: 1];
      _requestModes = [[NSMutableArray alloc] initWithCapacity: 2];
      [self addRequestMode: NSDefaultRunLoopMode]; 
      [self addRequestMode: NSConnectionReplyMode]; 

      /*
       * If we have no parent, we must handle incoming packets on our
       * receive port ourself - so we set ourself up as the port delegate.
       */
      [_receivePort setDelegate: self];
    }

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
  M_LOCK(_refGate);
  if (_isValid == NO)
    {
      M_UNLOCK(_refGate);
      return;
    }
  _isValid = NO;
  M_LOCK(connection_table_gate);
  NSHashRemove(connection_table, self);
  [timer invalidate];
  timer = nil;
  M_UNLOCK(connection_table_gate);

  M_LOCK(_refGate);

  /*
   *	Don't need notifications any more - so remove self as observer.
   */
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  /*
   * Make sure we are not registered.
   */
  [self registerName: nil];

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
  M_LOCK(_proxiesGate);
  if (_localTargets != 0)
    {
      NSMutableArray	*targets;
      unsigned	 	i = _localTargets->nodeCount;
      GSIMapNode	node;

      targets = [[NSMutableArray alloc] initWithCapacity: i];
      node = _localTargets->firstNode;
      while (node != 0)
	{
	  [targets addObject: node->value.obj];
	  node = node->nextInMap;
	}
      while (i-- > 0)
	{
	  id	t = [[targets objectAtIndex: i] localForProxy];

	  [self removeLocalObject: t];
	}
      RELEASE(targets);
      GSIMapEmptyMap(_localTargets);
      NSZoneFree(_localTargets->zone, (void*)_localTargets);
      _localTargets = 0;
    }
  if (_remoteProxies != 0)
    {
      GSIMapEmptyMap(_remoteProxies);
      NSZoneFree(_remoteProxies->zone, (void*)_remoteProxies);
      _remoteProxies = 0;
    }
  if (_localObjects != 0)
    {
      GSIMapNode	node = _localObjects->firstNode;

      while (node != 0)
	{
	  RELEASE(node->key.obj);
	  node = node->nextInMap;
	}
      GSIMapEmptyMap(_localObjects);
      NSZoneFree(_localObjects->zone, (void*)_localObjects);
      _localObjects = 0;
    }
  M_UNLOCK(_proxiesGate);

  RELEASE(self);
}

- (BOOL) isValid
{
  return _isValid;
}

- (NSArray*) localObjects
{
  NSMutableArray	*c;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  c = [NSMutableArray arrayWithCapacity: _localObjects->nodeCount];
  node = _localObjects->firstNode;
  while (node != 0)
    {
      [c addObject: node->key.obj];
      node = node->nextInMap;
    }
  M_UNLOCK(_proxiesGate);
  return c;
}

- (BOOL) multipleThreadsEnabled
{
  return _multipleThreads;
}

- (NSPort*) receivePort
{
  return _receivePort;
}

- (BOOL) registerName: (NSString*)name
{
  NSPortNameServer	*svr = [NSPortNameServer systemDefaultPortNameServer];

  return [self registerName: name withNameServer: svr];
}

- (BOOL) registerName: (NSString*)name withNameServer: (NSPortNameServer*)svr
{
  BOOL			result = YES;

  if (name != nil)
    {
      result = [svr registerPort: _receivePort forName: name];
    }
  if (result == YES)
    {
      if (_registeredName != nil)
	{
	  [_nameServer removePort: _receivePort forName: _registeredName];
	}
      ASSIGN(_registeredName, name);
      ASSIGN(_nameServer, svr);
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
  NSMutableArray	*c;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  c = [NSMutableArray arrayWithCapacity: _remoteProxies->nodeCount];
  node = _remoteProxies->firstNode;
  while (node != 0)
    {
      [c addObject: node->key.obj];
      node = node->nextInMap;
    }
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
  return AUTORELEASE([_requestModes copy]);
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

  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];
  [self _sendOutRmc: op type: ROOTPROXY_REQUEST];

  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(id) at: &newProxy];
  DESTROY(ip);
  return AUTORELEASE(newProxy);
}

- (void) runInNewThread
{
  [self removeRunLoop: [runLoopClass currentRunLoop]];
  [NSThread detachNewThreadSelector: @selector(_runInNewThread)
			   toTarget: self
			 withObject: nil];
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
  o = [NSNumber numberWithUnsignedInt: _localTargets->nodeCount];
  [d setObject: o forKey: NSConnectionLocalCount];
  o = [NSNumber numberWithUnsignedInt: _remoteProxies->nodeCount];
  [d setObject: o forKey: NSConnectionProxyCount];
  o = [NSNumber numberWithUnsignedInt: _replyMap->nodeCount];
  [d setObject: o forKey: @"NSConnectionReplyQueue"];
  o = [NSNumber numberWithUnsignedInt: [_requestQueue count]];
  [d setObject: o forKey: @"NSConnectionRequestQueue"];

  M_UNLOCK(_refGate);

  return d;
}

@end



@implementation	NSConnection (GNUstepExtensions)

+ (NSConnection*) newRegisteringAtName: (NSString*)name
			withRootObject: (id)anObject
{
  NSConnection	*conn;

  conn = [[self alloc] initWithReceivePort: [NSPort port]
				  sendPort: nil];
  [conn setRootObject: anObject];
  if ([conn registerName: name] == NO)
    {
      DESTROY(conn);
    }
  return conn;
}

- (void) gcFinalize
{
  CREATE_AUTORELEASE_POOL(arp);

  if (debug_connection)
    NSLog(@"finalising 0x%x", (gsaddr)self);

  [self invalidate];

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

  DESTROY(_requestQueue);
  if (_replyMap != 0)
    {
      GSIMapNode	node = _replyMap->firstNode;

      while (node != 0)
	{
	  if (node->key.obj != dummyObject)
	    RELEASE(node->key.obj);
	  node = node->nextInMap;
	}
      GSIMapEmptyMap(_replyMap);
      NSZoneFree(_replyMap->zone, (void*)_replyMap);
      _replyMap = 0;
    }

  DESTROY(_cachedDecoders);
  DESTROY(_cachedEncoders);

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
  NSPortCoder	*op;
  BOOL		outParams;
  BOOL		needsResponse;
  const char	*type;
  int		seq_num;
  retval_t	retframe;

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
  if (type == 0 || *type == '\0')
    {
      type = [[object methodSignatureForSelector: sel] methodType];
      if (type)
	{
	  sel_register_typed_name(sel_get_name(sel), type);
	}
    }
  NSParameterAssert(type);
  NSParameterAssert(*type);

  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];

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
  outParams = mframe_dissect_call (argframe, type, encoder);

  if (outParams == YES)
    {
      needsResponse = YES;
    }
  else
    {
      int		flags;

      needsResponse = NO;
      flags = objc_get_type_qualifiers(type);
      if ((flags & _F_ONEWAY) == 0)
	{
	  needsResponse = YES;
	}
      else
	{
	  const char	*tmptype = objc_skip_type_qualifiers(type);

	  if (*tmptype != _C_VOID)
	    {
	      needsResponse = YES;
	    }
	}
    }

  [self _sendOutRmc: op type: METHOD_REQUEST];
  NSDebugMLLog(@"NSConnection", @"Sent message to 0x%x", (gsaddr)self);

  if (needsResponse == NO)
    {
      /*
       * Since we don't need a response, we can remove the placeholder from
       * the _replyMap.
       */
      M_LOCK(_refGate);
      GSIMapRemoveKey(_replyMap, (GSIMapKey)seq_num);
      M_UNLOCK(_refGate);
      retframe = alloca(sizeof(void*));	 /* Dummy value for void return. */
    }
  else
    {
      NSPortCoder	*ip = nil;
      BOOL		is_exception = NO;

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  if (type == 0)
	    {
	      if (ip != nil)
		{
		  DESTROY(ip);
		  /* this must be here to avoid trashing alloca'ed retframe */
		  ip = (id)-1;
		  _repInCount++;	/* received a reply */
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
	      ip = [self _getReplyRmc: seq_num];
	      /*
	       * Find out if the server is returning an exception instead
	       * of the return values.
	       */
	      [ip decodeValueOfObjCType: @encode(BOOL) at: &is_exception];
	      if (is_exception)
		{
		  /* Decode the exception object, and raise it. */
		  id exc;
		  [ip decodeValueOfObjCType: @encode(id) at: &exc];
		  DESTROY(ip);
		  ip = (id)-1;
		  /* xxx Is there anything else to clean up in
		     dissect_method_return()? */
		  [exc raise];
		}
	    }
	  [ip decodeValueOfObjCType: type at: datum];
	  /* -decodeValueOfObjCType:at: malloc's new memory
	     for pointers.  We need to make sure it gets freed eventually
	     so we don't have a memory leak.  Request here that it be
	     autorelease'ed. Also autorelease created objects. */
	  if ((*type == _C_CHARPTR || *type == _C_PTR) && *(void**)datum != 0)
	    [NSData dataWithBytesNoCopy: *(void**)datum length: 1];
	  else if (*type == _C_ID)
	    AUTORELEASE(*(id*)datum);
	}

      retframe = mframe_build_return (argframe, type, outParams, decoder);
      /* Make sure we processed all arguments, and dismissed the IP.
	 IP is always set to -1 after being dismissed; the only places
	 this is done is in this function DECODER().  IP will be nil
	 if mframe_build_return() never called DECODER(), i.e. when
	 we are just returning (void).*/
      NSAssert(ip == (id)-1 || ip == nil, NSInternalInconsistencyException);
    }
  return retframe;
}

- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target
{
  id op, ip;
  char	*type = 0;
  int	seq_num;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];
  [op encodeValueOfObjCType: ":" at: &sel];
  [op encodeValueOfObjCType: @encode(unsigned) at: &target];
  [self _sendOutRmc: op type: METHODTYPE_REQUEST];
  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(char*) at: &type];
  DESTROY(ip);
  return type;
}


/* Class-wide stats and collections. */

+ (unsigned) connectionsCount
{
  unsigned	result;

  M_LOCK(connection_table_gate);
  result = NSCountHashTable(connection_table);
  M_UNLOCK(connection_table_gate);
  return result;
}

+ (unsigned) connectionsCountWithInPort: (NSPort*)aPort
{
  unsigned		count = 0;
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
  conn = [connectionClass connectionWithReceivePort: rp sendPort: sp];
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

  if (conn->_authenticateIn == YES
    && (type == METHOD_REQUEST || type == METHOD_REPLY))
    {
      NSData	*d;
      unsigned	count = [components count];

      d = RETAIN([components objectAtIndex: --count]);
      [components removeObjectAtIndex: count];
      if ([[conn delegate] authenticateComponents: components
					 withData: d] == NO)
	{
	  RELEASE(d);
	  [NSException raise: NSFailedAuthenticationException
		      format: @"message not authenticated by delegate"];
	}
      RELEASE(d);
    }

  rmc = [conn _makeInRmc: components];

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
	    [conn->_requestQueue removeObjectAtIndex: 0];
	    M_UNLOCK(conn->_queueGate);
	    [conn _service_forwardForProxy: rmc];
	    M_LOCK(conn->_queueGate);
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
	  int		sequence;
	  GSIMapNode	node;

	  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
	  M_LOCK(conn->_queueGate);
	  node = GSIMapNodeForKey(conn->_replyMap, (GSIMapKey)sequence);
	  if (node == 0)
	    {
	      NSDebugMLLog(@"NSConnection", @"Ignoring RMC %d", sequence);
	      RELEASE(rmc);
	    }
	  else if (node->value.obj == dummyObject)
	    {
	      node->value.obj = rmc;
	    }
	  else
	    {
	      NSDebugMLLog(@"NSConnection", @"Replace RMC %d", sequence);
	      RELEASE(node->value.obj);
	      node->value.obj = rmc;
	    }
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

- (void) _runInNewThread
{
  NSRunLoop	*loop = [runLoopClass currentRunLoop];

  [self addRunLoop: loop];
  [loop run];
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
  int	reply_sno;

  void decoder (int argnum, void *datum, const char *type)
    {
      /* We need this "dismiss" to happen here and not later so that Coder
	 "-awake..." methods will get sent before the __builtin_apply! */
      if (argnum == -1 && datum == 0 && type == 0)
	{
	  [self _doneInRmc: aRmc];
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
	  op = [self _makeOutRmc: reply_sno generate: 0 reply: NO];
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
      [aRmc decodeValueOfObjCType: @encode(int) at: &reply_sno];

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
	  [self _sendOutRmc: op type: METHOD_REPLY];
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
	      op = [self _makeOutRmc: reply_sno generate: 0 reply: NO];
	      [op encodeValueOfObjCType: @encode(BOOL)
				     at: &is_exception];
	      [op encodeBycopyObject: localException];
	      [self _sendOutRmc: op type: METHOD_REPLY];
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
  [self _doneInRmc: rmc];
  op = [self _makeOutRmc: sequence generate: 0 reply: NO];
  [op encodeObject: rootObject];
  [self _sendOutRmc: op type: ROOTPROXY_REPLY];
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
  [self _doneInRmc: rmc];
}

- (void) _service_retain: (NSPortCoder*)rmc
{
  unsigned	target;
  NSPortCoder	*op;
  int		sequence;

  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeOutRmc: sequence generate: 0 reply: NO];

  [rmc decodeValueOfObjCType: @encode(typeof(target)) at: &target];
  [self _doneInRmc: rmc];

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
	  [distantObjectClass proxyWithLocal: counter->object
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

  [self _sendOutRmc: op type: RETAIN_REPLY];
}

- (void) shutdown
{
  NSPortCoder	*op;
  int		sno;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  op = [self _makeOutRmc: 0 generate: &sno reply: NO];
  [self _sendOutRmc: op type: CONNECTION_SHUTDOWN];
}

- (void) _service_shutdown: (NSPortCoder*)rmc
{
  NSParameterAssert (_isValid);
  [self _doneInRmc: rmc];
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
  op = [self _makeOutRmc: sequence generate: 0 reply: NO];

  [rmc decodeValueOfObjCType: ":" at: &sel];
  [rmc decodeValueOfObjCType: @encode(unsigned) at: &target];
  [self _doneInRmc: rmc];
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
  [self _sendOutRmc: op type: METHODTYPE_REPLY];
}



/*
 * Check the queue, then try to get it from the network by waiting
 * while we run the NSRunLoop.  Raise exception if we don't get anything
 * before timing out.
 */
- _getReplyRmc: (int)sn
{
  NSPortCoder	*rmc;
  GSIMapNode	node;
  NSDate	*timeout_date = nil;

  M_LOCK(_queueGate);
  while ((node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn)) != 0
    && node->value.obj == dummyObject)
    {
      if (timeout_date == nil)
	{
	  timeout_date = [dateClass allocWithZone: NSDefaultMallocZone()];
	  timeout_date
	    = [timeout_date initWithTimeIntervalSinceNow: _replyTimeout];
	}
      M_UNLOCK(_queueGate);
      if ([runLoopClass runOnceBeforeDate: timeout_date
				  forMode: NSConnectionReplyMode] == NO)
	{
	  M_LOCK(_queueGate);
	  node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn);
	  break;
	}
      M_LOCK(_queueGate);
    }
  if (node == 0)
    {
      rmc = nil;
    }
  else
    {
      rmc = node->value.obj;
      GSIMapRemoveKey(_replyMap, (GSIMapKey)sn);
    }
  M_UNLOCK(_queueGate);
  TEST_RELEASE(timeout_date);
  if (rmc == nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"no reply message available"];
    }
  if (rmc == dummyObject)
    {
      [NSException raise: NSPortTimeoutException
		  format: @"timed out waiting for reply"];
    }
  return rmc;
}

- (void) _doneInRmc: (NSPortCoder*)c
{
  M_LOCK(_refGate);
  [_cachedDecoders addObject: c];
  [c dispatch];	/* Tell NSPortCoder to release the connection.	*/
  RELEASE(c);
  M_UNLOCK(_refGate);
}

- (NSPortCoder*) _makeInRmc: (NSMutableArray*)components
{
  NSPortCoder	*coder;
  unsigned	count;

  NSParameterAssert(_isValid);

  M_LOCK(_refGate);
  count = [_cachedDecoders count];
  if (count > 0)
    {
      coder = [_cachedDecoders objectAtIndex: --count];
      RETAIN(coder);
      [_cachedDecoders removeObjectAtIndex: count];
    }
  else
    {
      coder = [portCoderClass allocWithZone: NSDefaultMallocZone()];
    }
  M_UNLOCK(_refGate);

  coder = [coder initWithReceivePort: _receivePort
			    sendPort: _sendPort
			  components: components];
  return coder;
}

/*
 * Create an NSPortCoder object for encoding an outgoing message or reply.
 *
 * sno		Is the seqence number to encode into the coder.
 * ret		If non-null, generate a new sequence number and return it
 *		here.  Ignore the sequence number passed in sno.
 * rep		If this flag is YES, add a placeholder to the _replyMap
 *		so we handle an incoming reply for this sequence number.
 */
- (NSPortCoder*) _makeOutRmc: (int)sno generate: (int*)ret reply: (BOOL)rep
{
  NSPortCoder	*coder;
  unsigned	count;

  NSParameterAssert(_isValid);

  M_LOCK(_refGate);
  /*
   * Generate a new sequence number if required.
   */
  if (ret != 0)
    {
      sno = _messageCount++;
      *ret = sno;
    }
  /*
   * Add a placeholder to the reply map if we expect a reply.
   */
  if (rep == YES)
    {
      GSIMapAddPair(_replyMap, (GSIMapKey)sno, (GSIMapVal)dummyObject);
    }
  /*
   * Locate or create an rmc
   */
  count = [_cachedEncoders count];
  if (count > 0)
    {
      coder = [_cachedEncoders objectAtIndex: --count];
      RETAIN(coder);
      [_cachedEncoders removeObjectAtIndex: count];
    }
  else
    {
      coder = [portCoderClass allocWithZone: NSDefaultMallocZone()];
    }
  M_UNLOCK(_refGate);

  coder = [coder initWithReceivePort: _receivePort
			    sendPort: _sendPort
			  components: nil];
  [coder encodeValueOfObjCType: @encode(int) at: &sno];
  return coder;
}

- (void) _sendOutRmc: (NSPortCoder*)c type: (int)msgid
{
  NSDate		*limit;
  BOOL			sent = NO;
  BOOL			raiseException = NO;
  BOOL			needsReply = NO;
  NSMutableArray	*components = [c _components];

  if (_authenticateOut == YES
    && (msgid == METHOD_REQUEST || msgid == METHOD_REPLY))
    {
      NSData	*d;

      d = [[self delegate] authenticationDataForComponents: components];
      if (d == nil)
	{
	  RELEASE(c);
	  [NSException raise: NSGenericException
		      format: @"Bad authentication data provided by delegate"];
	}
      [components addObject: d];
    }

  switch (msgid)
    {
      case PROXY_RETAIN:
	needsReply = YES;
      case CONNECTION_SHUTDOWN:
      case METHOD_REPLY:
      case ROOTPROXY_REPLY:
      case METHODTYPE_REPLY:
      case PROXY_RELEASE:
      case RETAIN_REPLY:
	raiseException = NO;
	break;

      case METHOD_REQUEST:
      case ROOTPROXY_REQUEST:
      case METHODTYPE_REQUEST:
	needsReply = YES;
      default:
	raiseException = YES;
	break;
    }

  limit = [dateClass dateWithTimeIntervalSinceNow: _requestTimeout];
  sent = [_sendPort sendBeforeDate: limit
			     msgid: msgid
			components: components
			      from: _receivePort
			  reserved: [_sendPort reservedSpaceLength]];

  M_LOCK(_refGate);
  /*
   * If we have sent out a request on a run loop that we don't already
   * know about, it must be on a new thread - so if we have multipleThreads
   * enabled, we must add the run loop of the new thread so that we can
   * get the reply in this thread.
   */
  if (_multipleThreads == YES && needsReply == YES)
    {
      NSRunLoop	*loop = [runLoopClass currentRunLoop];

      if ([_runLoops indexOfObjectIdenticalTo: loop] == NSNotFound)
	{
	  [self addRunLoop: loop];
	}
    }

  /*
   * We replace the code we have just used in the cache, and tell it not to
   * retain this connection any more.
   */
  [_cachedEncoders addObject: c];
  [c dispatch];	/* Tell NSPortCoder to release the connection.	*/
  RELEASE(c);
  M_UNLOCK(_refGate);

  if (sent == NO)
    {
      NSString	*text = stringFromMsgType(msgid);

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
  GSIMapNode    	node;


  NSParameterAssert (_isValid);
  M_LOCK(_proxiesGate);
  M_LOCK(global_proxies_gate);

  /*
   * Record the value in the _localObjects map, retaining it.
   */
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)object);
  IF_NO_GC(RETAIN(anObj));
  if (node)
    {
      RELEASE(node->value.obj);
      node->value.obj = anObj;
    }
  else
    {
      GSIMapAddPair(_localObjects, (GSIMapKey)object, (GSIMapVal)anObj);
    }

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
      RELEASE(counter);
    }
  [anObj setProxyTarget: target];
  GSIMapAddPair(_localTargets, (GSIMapKey)target, (GSIMapVal)anObj);
  if (debug_connection > 2)
    NSLog(@"add local object (0x%x) target (0x%x) "
	  @"to connection (0x%x) (ref %d)",
		(gsaddr)object, target, (gsaddr) self, counter->ref);
  M_UNLOCK(global_proxies_gate);
  M_UNLOCK(_proxiesGate);
}

- (NSDistantObject*) localForObject: (id)object
{
  GSIMapNode		node;
  NSDistantObject	*p;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)object);
  if (node == 0)
    {
      p = nil;
    }
  else
    {
      p = node->value.obj;
    }
  M_UNLOCK(_proxiesGate);
  NSParameterAssert(p == nil || [p connectionForProxy] == self);
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
  GSIMapNode		node;

  M_LOCK(global_proxies_gate);
  M_LOCK(_proxiesGate);

  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)anObj);
  if (node == 0)
    {
      prox = nil;
    }
  else
    {
      prox = node->value.obj;
    }
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
					 target: connectionClass
					 selector: @selector(_timeout:)
					 userInfo: nil
					  repeats: YES];
		}
	      item = [CachedLocalObject newWithObject: counter time: 30];
	      NSMapInsert(all_connections_local_cached, (void*)target, item);
	      RELEASE(item);
	      if (debug_connection > 3)
		NSLog(@"placed local object (0x%x) target (0x%x) in cache",
			    (gsaddr)anObj, target);
	    }
	  NSMapRemove(all_connections_local_objects, (void*)anObj);
	  NSMapRemove(all_connections_local_targets, (void*)target);
	}
    }

  /*
   * Remove the proxy from _localObjects and release it.
   */
  GSIMapRemoveKey(_localObjects, (GSIMapKey)anObj);
  RELEASE(prox);

  /*
   * Remove the target info too - no release required.
   */
  GSIMapRemoveKey(_localTargets, (GSIMapKey)target);

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
	  int		sequence;

	  op = [self _makeOutRmc: 0 generate: &sequence reply: NO];

	  [op encodeValueOfObjCType: @encode(unsigned) at: &number];

	  for (i = 0; i < number; i++)
	    {
	      [op encodeValueOfObjCType: @encode(unsigned) at: &list[i]];
	      if (debug_connection > 3)
		NSLog(@"sending release for target (0x%x) on (0x%x)",
		      list[i], (gsaddr)self);
	    }

	  [self _sendOutRmc: op type: PROXY_RELEASE];
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
	  int	seq_num;

	  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];
	  [op encodeValueOfObjCType: @encode(typeof(target)) at: &target];
	  [self _sendOutRmc: op type: PROXY_RETAIN];

	  ip = [self _getReplyRmc: seq_num];
	  [ip decodeValueOfObjCType: @encode(id) at: &result];
	  DESTROY(ip);
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
  GSIMapRemoveKey(_remoteProxies, (GSIMapKey)target);
  M_UNLOCK(_proxiesGate);

  /*
   *	Tell the remote application that we have removed our proxy and
   *	it can release it's local object.
   */
  [self _release_targets: &target count: 1];
}

- (NSDistantObject*) proxyForTarget: (unsigned)target
{
  NSDistantObject	*p;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);
  if (node == 0)
    {
      p = nil;
    }
  else
    {
      p = node->value.obj;
    }
  M_UNLOCK(_proxiesGate);
  return p;
}

- (void) addProxy: (NSDistantObject*) aProxy
{
  unsigned	target = (unsigned int)[aProxy targetForProxy];
  GSIMapNode	node;

  NSParameterAssert (_isValid);
  NSParameterAssert(aProxy->isa == distantObjectClass);
  NSParameterAssert([aProxy connectionForProxy] == self);
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);
  if (node != 0)
    {
      M_UNLOCK(_proxiesGate);
      [NSException raise: NSGenericException
		  format: @"Trying to add the same proxy twice"];
    }
  GSIMapAddPair(_remoteProxies, (GSIMapKey)target, (GSIMapVal)aProxy);
  M_UNLOCK(_proxiesGate);
}

- (id) includesProxyForTarget: (unsigned)target
{
  NSDistantObject	*ret;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);
  if (node == 0)
    {
      ret = nil;
    }
  else
    {
      ret = node->value.obj;
    }
  M_UNLOCK(_proxiesGate);
  return ret;
}

- (id) includesLocalObject: (id)anObj
{
  NSDistantObject	*ret;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)anObj);
  if (node == 0)
    {
      ret = nil;
    }
  else
    {
      ret = node->value.obj;
    }
  M_UNLOCK(_proxiesGate);
  return ret;
}

- (id) includesLocalTarget: (unsigned)target
{
  NSDistantObject	*ret;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_localTargets, (GSIMapKey)target);
  if (node == 0)
    {
      ret = nil;
    }
  else
    {
      ret = node->value.obj;
    }
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

#else
/* Implementation of connection object for remote object messaging
   Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

   Created by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   Rewritten for OPENSTEP by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997

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

/* To do: 
   Make it thread-safe.
   */

/* RMC == Remote Method Coder, or Remote Method Call.
   It's an instance of PortEncoder or PortDecoder. */

#include <config.h>
#include <base/preface.h>
#include <Foundation/DistributedObjects.h>
#include <base/TcpPort.h>
#include <mframe.h>
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
  [object release];
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
  return [item autorelease];
}

- (void) dealloc
{
  [obj release];
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


@interface NSConnection (GettingCoderInterface)
- (void) _handleRmc: rmc;
- (void) _handleQueuedRmcRequests;
- _getReceivedReplyRmcWithSequenceNumber: (int)n;
- newSendingRequestRmc;
- newSendingReplyRmcWithSequenceNumber: (int)n;
- (int) _newMsgNumber;
@end

@interface NSConnection (Private)
- _superInit;
- (void) handlePortMessage: (NSPortMessage*)msg;
+ (void) setDebug: (int)val;
@end

#define proxiesHashGate refGate
#define sequenceNumberGate refGate

/* xxx Fix this! */
#define refGate nil

static inline BOOL
class_is_kind_of (Class self, Class aClassObject)
{
  Class class;

  for (class = self; class!=Nil; class = class_get_super_class(class))
    if (class==aClassObject)
      return YES;
  return NO;
}

static inline unsigned int
hash_int (cache_ptr cache, const void *key)
{
  return (unsigned)key & cache->mask;
}

static inline int
compare_ints (const void *k1, const void *k2)
{
  return !(k1 - k2);
}

/* class defaults */
static id default_receive_port_class;
static id default_send_port_class;
static id default_proxy_class;
static id default_encoding_class;
static id default_decoding_class;
static int default_reply_timeout;
static int default_request_timeout;
static NSTimer *timer;

static int debug_connection = 0;

static NSHashTable *connection_table;
static NSLock *connection_table_gate;

static NSMutableDictionary *root_object_dictionary;
static NSLock *root_object_dictionary_gate;

static NSMapTable *receive_port_2_ancestor;

static NSMapTable *all_connections_local_objects = NULL;
static NSMapTable *all_connections_local_targets = NULL;
static NSMapTable *all_connections_local_cached = NULL;

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

+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
					  host: (NSString*)h
{
  NSDistantObject	*proxy;

  proxy = [self rootProxyForConnectionWithRegisteredName: n host: h];
  if (proxy != nil)
    {
      return [proxy connectionForProxy];
    }
  return nil;
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
      NSPort	*newPort;

      c = [self alloc];
      newPort = [default_receive_port_class newForReceiving];
      c = [c initWithReceivePort: newPort sendPort: nil];
      RELEASE(newPort);
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
  received_request_rmc_queue = [[NSMutableArray alloc] initWithCapacity: 32];
  received_request_rmc_queue_gate = [NSLock new];
  received_reply_rmc_queue = [[NSMutableArray alloc] initWithCapacity: 32];
  received_reply_rmc_queue_gate = [NSLock new];
  root_object_dictionary = [[NSMutableDictionary alloc] initWithCapacity: 8];
  root_object_dictionary_gate = [NSLock new];
  receive_port_2_ancestor =
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  messages_received_count = 0;
  default_receive_port_class = [TcpInPort class];
  default_send_port_class = [TcpOutPort class];
  default_proxy_class = [NSDistantObject class];
  default_encoding_class = [NSPortCoder class];
  default_decoding_class = [NSPortCoder class];
  default_reply_timeout = CONNECTION_DEFAULT_TIMEOUT;
  default_request_timeout = CONNECTION_DEFAULT_TIMEOUT;
}

+ (id) new
{
  /*
   * Undocumented feature of OPENSTEP/MacOS-X
   * +new returns the default connection.
   */
  return RETAIN([self defaultConnection]);
}

+ (id) currentConversation
{
  [self notImplemented: _cmd];
  return self;
}

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
						         host: (NSString*)h
{
  id p = [default_send_port_class newForSendingToRegisteredName: n onHost: h];
  if (p == nil)
    {
      return nil;
    }
  return [self rootProxyAtPort: [p autorelease]];
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
  if ([request_modes containsObject: mode] == NO)
    {
      [request_modes addObject: mode];
      [[NSRunLoop currentRunLoop] addPort: receive_port forMode: mode];
    }
}

- (void) addRunLoop: (NSRunLoop*)loop
{
  [self notImplemented: _cmd];
}

- (void) dealloc
{
  if (debug_connection)
    NSLog(@"deallocating 0x%x\n", (gsaddr)self);
  [super dealloc];
}

- (id) delegate
{
  return delegate;
}

- (void) handlePortMessage: (NSPortMessage*)msg
{
  [self notImplemented: _cmd];
}

- (BOOL) independentConversationQueueing
{
  return independent_queueing;
}

- (void) enableMultipleThreads
{
  [self notImplemented: _cmd];
}

- (BOOL) multipleThreadsEnabled
{
  [self notImplemented: _cmd];
  return NO;
}


- (id) init
{
  /*
   * Undocumented feature of OPENSTEP/MacOS-X
   * -init returns the default connection.
   */
  RELEASE(self);
  return [NSConnection defaultConnection];
}

/* xxx This needs locks */
- (void) invalidate
{
  if (is_valid == NO)
    return;

  is_valid = NO;

  NSHashRemove(connection_table, self);

  /*
   *	Don't need notifications any more - so remove self as observer.
   */
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  /*
   *	We can't be the ancestor of anything if we are invalid.
   */
  if (self == NSMapGet(receive_port_2_ancestor, receive_port))
    NSMapRemove(receive_port_2_ancestor, receive_port);

  /*
   *	If we have been invalidated, we don't need to retain proxies
   *	for local objects any more.  In fact, we want to get rid of
   *	these proxies in case they are keeping us retained when we
   *	might otherwise de deallocated.
   */
  {
    NSArray *targets;
    unsigned 	i;

    [proxiesHashGate lock];
    targets = NSAllMapTableValues(local_targets);
    IF_NO_GC(RETAIN(targets));
    for (i = 0; i < [targets count]; i++)
      {
	id	t = [[targets objectAtIndex: i] localForProxy];

	[self removeLocalObject: t];
      }
    [targets release];
    [proxiesHashGate unlock];
  }

  if (debug_connection)
    NSLog(@"Invalidating connection 0x%x\n\t%@\n\t%@\n", (gsaddr)self,
	    [receive_port description], [send_port description]);

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
}

- (BOOL) isValid
{
  return is_valid;
}

- (BOOL) registerName: (NSString*)name
{
  NSPortNameServer	*svr = [NSPortNameServer systemDefaultPortNameServer];
  NSArray		*names = [svr namesForPort: receive_port];
  BOOL			result = YES;

  if (name != nil)
    {
      result = [svr registerPort: receive_port forName: name];
    }
  if (result == YES && [names count] > 0)
    {
      unsigned	i;

      for (i = 0; i < [names count]; i++)
	{
	  NSString	*tmp = [names objectAtIndex: i];

	  if ([tmp isEqualToString: name] == NO)
	    {
	      [svr removePort: receive_port forName: name];
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
  [self notImplemented: _cmd];
  return nil;
}

- (void) removeRequestMode: (NSString*)mode
{
  if ([request_modes containsObject: mode])
    {
      [request_modes removeObject: mode];
      [[NSRunLoop currentRunLoop] removePort: receive_port forMode: mode];
    }
}

- (void) removeRunLoop: (NSRunLoop *)runloop
{
  [self notImplemented: _cmd];
}

- (NSTimeInterval) replyTimeout
{
  return reply_timeout;
}

- (NSArray*) requestModes
{
  return [[request_modes copy] autorelease];
}

- (NSTimeInterval) requestTimeout
{
  return request_timeout;
}

- (id) rootObject
{
  return [[self class] rootObjectForInPort: receive_port];
}

- (NSDistantObject*) rootProxy
{
  id op, ip;
  NSDistantObject *newProxy = nil;
  int seq_num = [self _newMsgNumber];

  NSParameterAssert(receive_port);
  NSParameterAssert (is_valid);
  op = [[self encodingClass]
	newForWritingWithConnection: self
	sequenceNumber: seq_num
	identifier: ROOTPROXY_REQUEST];
  [op dismiss];
  ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
  [ip decodeObjectAt: &newProxy withName: NULL];
  NSParameterAssert (class_is_kind_of (newProxy->isa, objc_get_class ("NSDistantObject")));
  [ip dismiss];
  return [newProxy autorelease];
}

- (void) setDelegate: anObj
{
  delegate = anObj;
}

- (void) setIndependentConversationQueueing: (BOOL)flag
{
  independent_queueing = flag;
}

- (void) setReplyTimeout: (NSTimeInterval)to
{
  reply_timeout = to;
}

- (void) setRequestMode: (NSString*)mode
{
  while ([request_modes count] > 0 && [request_modes objectAtIndex: 0] != mode)
    {
      [self removeRequestMode: [request_modes objectAtIndex: 0]];
    }
  while ([request_modes count] > 1)
    {
      [self removeRequestMode: [request_modes objectAtIndex: 1]];
    }
  if (mode != nil && [request_modes count] == 0)
    {
	[self addRequestMode: mode];
    }
}

- (void) setRequestTimeout: (NSTimeInterval)to
{
  request_timeout = to;
}

- (void) setRootObject: anObj
{
  [[self class] setRootObject: anObj forInPort: receive_port];
}

- (NSDictionary*) statistics
{
  NSMutableDictionary	*d;
  id			o;

  d = [NSMutableDictionary dictionaryWithCapacity: 8];

  /*
   *	These are in OPENSTEP 4.2
   */
  o = [NSNumber numberWithUnsignedInt: rep_in_count];
  [d setObject: o forKey: NSConnectionRepliesReceived];
  o = [NSNumber numberWithUnsignedInt: rep_out_count];
  [d setObject: o forKey: NSConnectionRepliesSent];
  o = [NSNumber numberWithUnsignedInt: req_in_count];
  [d setObject: o forKey: NSConnectionRequestsReceived];
  o = [NSNumber numberWithUnsignedInt: req_out_count];
  [d setObject: o forKey: NSConnectionRequestsSent];

  /*
   *	These are GNUstep extras
   */
  o = [NSNumber numberWithUnsignedInt: NSCountMapTable(local_targets)];
  [d setObject: o forKey: NSConnectionLocalCount];
  o = [NSNumber numberWithUnsignedInt: NSCountMapTable(remote_proxies)];
  [d setObject: o forKey: NSConnectionProxyCount];
  [received_request_rmc_queue_gate lock];
  o = [NSNumber numberWithUnsignedInt: [received_request_rmc_queue count]];
  [received_request_rmc_queue_gate unlock];
  [d setObject: o forKey: @"Pending packets"];

  return d;
}

@end



@implementation	NSConnection (GNUstepExtensions)

- (void) gcFinalize
{
  CREATE_AUTORELEASE_POOL(arp);

  if (debug_connection)
    NSLog(@"finalising 0x%x\n", (gsaddr)self);

  [self invalidate];

  /* Remove rootObject from root_object_dictionary
     if this is last connection */
  if (receive_port != nil
    && [NSConnection connectionsCountWithInPort: receive_port] == 0)
    {
      [NSConnection setRootObject: nil forInPort: receive_port];
    }

  /* Remove receive port from run loop. */
  [self setRequestMode: nil];
  if (receive_port != nil)
    {
      [[NSRunLoop currentRunLoop] removePort: receive_port
				     forMode: NSConnectionReplyMode];
    }
  RELEASE(request_modes);

  /* Finished with ports - releasing them may generate a notification */
  RELEASE(receive_port);
  RELEASE(send_port);

  [proxiesHashGate lock];
  if (remote_proxies != 0)
    NSFreeMapTable(remote_proxies);
  if (local_objects != 0)
    NSFreeMapTable(local_objects);
  if (local_targets != 0)
    NSFreeMapTable(local_targets);
  [proxiesHashGate unlock];

  RELEASE(arp);
}

/* Getting and setting class variables */

+ (Class) default_decoding_class
{
  return default_decoding_class;
}

+ (int) defaultInTimeout
{
  return default_reply_timeout;
}

+ (int) defaultOutTimeout
{
  return default_request_timeout;
}

+ (Class) defaultProxyClass
{
  return default_proxy_class;
}

+ (Class) defaultReceivePortClass
{
  return default_receive_port_class;
}

+ (Class) defaultSendPortClass
{
  return default_send_port_class;
}

+ (void) setDefaultDecodingClass: (Class) aClass
{
  default_decoding_class = aClass;
}

+ (void) setDefaultInTimeout: (int)to
{
  default_reply_timeout = to;
}

+ (void) setDefaultOutTimeout: (int)to
{
  default_request_timeout = to;
}

+ (void) setDefaultProxyClass: (Class)aClass
{
  default_proxy_class = aClass;
}

+ (void) setDefaultReceivePortClass: (Class)aClass
{
  default_receive_port_class = aClass;
}

+ (void) setDefaultSendPortClass: (Class)aClass
{
  default_send_port_class = aClass;
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

  [connection_table_gate lock];
  enumerator = NSEnumerateHashTable(connection_table);
  while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      if ([aPort isEqual: [o receivePort]])
	{
	  count++;
	}
    }
  [connection_table_gate unlock];

  return count;
}


/* Creating and initializing connections. */

+ (NSConnection*) newWithRootObject: anObj;
{
  id newPort;
  id newConn;

  newPort = [[default_receive_port_class newForReceiving] autorelease];
  newConn = [self newForInPort: newPort outPort: nil
		  ancestorConnection: nil];
  [[self class] setRootObject: anObj forInPort: newPort];
  return newConn;
}

/* I want this method name to clearly indicate that we're not connecting
   to a pre-existing registration name, we're registering a new name,
   and this method will fail if that name has already been registered.
   This is why I don't like "newWithRegisteredName: " --- it's unclear
   if we're connecting to another NSConnection that already registered
   with that name. */

+ (NSConnection*) newRegisteringAtName: (NSString*)n withRootObject: anObj
{
  return [self newRegisteringAtName: n
			     atPort: 0
		     withRootObject: anObj];
}

+ (NSConnection*) newRegisteringAtName: (NSString*)n
				atPort: (int)p
			withRootObject: anObj
{
  id newPort;
  id newConn;

  newPort = [default_receive_port_class newForReceiving];
  newConn = [self alloc];
  newConn = [newConn initWithReceivePort: newPort sendPort: nil];
  RELEASE(newPort);
  [newConn setRootObject: anObj];
  if ([newConn registerName: n] == NO)
    {
      DESTROY(newConn);
    }
  return newConn;
}

+ (NSDistantObject*) rootProxyAtName: (NSString*)n
{
  return [self rootProxyAtName: n onHost: @""];
}

+ (NSDistantObject*) rootProxyAtName: (NSString*)n onHost: (NSString*)h
{
  return [self rootProxyForConnectionWithRegisteredName: n host: h];
}

+ (NSDistantObject*) rootProxyAtPort: (NSPort*)anOutPort
{
  NSConnection	*c = [self connectionByOutPort: anOutPort];

  if (c)
    return [c rootProxy];
  else
    {
      id newInPort = [default_receive_port_class newForReceiving];
      return [self rootProxyAtPort: anOutPort 
	       withInPort: [newInPort autorelease]];
    }
}

+ (NSDistantObject*) rootProxyAtPort: (NSPort*)anOutPort 
			  withInPort: (NSPort *)anInPort
{
  NSConnection *newConn = [self newForInPort: anInPort
				     outPort: anOutPort
			  ancestorConnection: nil];
  NSDistantObject *newRemote;

  newRemote = [newConn rootProxy];
  [newConn autorelease];
  return newRemote;
}


+ (NSConnection*) newForInPort: (NSPort*)ip
		       outPort: (NSPort*)op
	    ancestorConnection: (NSConnection*)ancestor
{
  NSConnection	*conn;

  conn = [self alloc];
  conn = [conn initWithReceivePort: ip sendPort: op];
  return conn;
}

+ (NSConnection*) connectionByInPort: (NSPort*)ip
			     outPort: (NSPort*)op
{
  NSHashEnumerator	enumerator;
  NSConnection		*o;

  NSParameterAssert (ip);

  [connection_table_gate lock];

  enumerator = NSEnumerateHashTable(connection_table);
  while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      id newConnInPort;
      id newConnOutPort;

      newConnInPort = [o receivePort];
      newConnOutPort = [o sendPort];
      if ([newConnInPort isEqual: ip]
	  && [newConnOutPort isEqual: op])
	{
	  [connection_table_gate unlock];
	  return o;
	}
    }
  [connection_table_gate unlock];
  return nil;
}

+ (NSConnection*) connectionByOutPort: (NSPort*)op
{
  NSHashEnumerator	enumerator;
  NSConnection		*o;

  NSParameterAssert (op);

  [connection_table_gate lock];

  enumerator = NSEnumerateHashTable(connection_table);
  while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      id newConnOutPort;

      newConnOutPort = [o sendPort];
      if ([newConnOutPort isEqual: op])
	{
	  [connection_table_gate unlock];
	  return o;
	}
    }
  [connection_table_gate unlock];
  return nil;
}

- _superInit
{
  [super init];
  return self;
}

+ (void) setDebug: (int)val
{
  debug_connection = val;
}

/* Creating new rmc's for encoding requests and replies */

/* Create a new, empty rmc, which will be filled with a request. */
- newSendingRequestRmc
{
  id rmc;

  NSParameterAssert(receive_port);
  NSParameterAssert (is_valid);
  rmc = [[self encodingClass] newForWritingWithConnection: self
			      sequenceNumber: [self _newMsgNumber]
			      identifier: METHOD_REQUEST];
  return rmc;
}

/* Create a new, empty rmc, which will be filled with a reply to msg #n. */
- newSendingReplyRmcWithSequenceNumber: (int)n
{
  id rmc = [[self encodingClass] newForWritingWithConnection: self
				 sequenceNumber: n
				 identifier: METHOD_REPLY];
  NSParameterAssert (is_valid);
  return rmc;
}


/* Methods for handling client and server, requests and replies */

/* NSDistantObject's -forward: : method calls this to the the message over the wire. */
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
	    [op encodeBycopyObject: *(id*)datum withName: ENCODED_ARGNAME];
#ifdef	_F_BYREF
	  else if (flags & _F_BYREF)
	    [op encodeByrefObject: *(id*)datum withName: ENCODED_ARGNAME];
#endif
	  else
	    [op encodeObject: *(id*)datum withName: ENCODED_ARGNAME];
	  break;
	default: 
	  [op encodeValueOfObjCType: type at: datum withName: ENCODED_ARGNAME];
	}
    }

  /* Encode the method on an RMC, and send it. */
  {
    BOOL out_parameters;
    const char *type;
    retval_t retframe;
    int seq_num;

    NSParameterAssert (is_valid);

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

    op = [self newSendingRequestRmc];
    seq_num = [op sequenceNumber];
    if (debug_connection > 4)
      NSLog(@"building packet seq %d\n", seq_num);

    /* Send the types that we're using, so that the performer knows
       exactly what qualifiers we're using.
       If all selectors included qualifiers, and if I could make
       sel_types_match() work the way I wanted, we wouldn't need to do
       this. */
    [op encodeValueOfCType: @encode(char*)
	at: &type
	withName: @"selector type"];

    /* xxx This doesn't work with proxies and the NeXT runtime because
       type may be a method_type from a remote machine with a
       different architecture, and its argframe layout specifiers
       won't be right for this machine! */
    out_parameters = mframe_dissect_call (argframe, type, encoder);
    /* Send the rmc */
    [op dismiss];
    if (debug_connection > 1)
      NSLog(@"Sent message to 0x%x\n", (gsaddr)self);
    req_out_count++;	/* Sent a request.	*/

    /* Get the reply rmc, and decode it. */
    {
      NSPortCoder *ip = nil;
      BOOL is_exception = NO;

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  if (type == 0) {
	    if (ip) {
	      /* this must be here to avoid trashing alloca'ed retframe */
	      [ip dismiss]; 	
	      ip = (id)-1;
	    }
	    return;
	  }
	  /* If we didn't get the reply packet yet, get it now. */
	  if (!ip)
	    {
	      if (!is_valid)
		{
	          [NSException raise: NSGenericException
		      format: @"connection waiting for request was shut down"];
		}
	      /* xxx Why do we get the reply packet in here, and not
		 just before calling dissect_method_return() below? */
	      ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
	      /* Find out if the server is returning an exception instead
		 of the return values. */
	      [ip decodeValueOfCType: @encode(BOOL)
		  at: &is_exception
		  withName: NULL];
	      if (is_exception)
		{
		  /* Decode the exception object, and raise it. */
		  id exc;
		  [ip decodeObjectAt: &exc
		      withName: NULL];
		  [ip dismiss];
		  ip = (id)-1;
		  /* xxx Is there anything else to clean up in
		     dissect_method_return()? */
		  [exc raise];
		}
	    }
	  [ip decodeValueOfObjCType: type at: datum withName: NULL];
	  /* -decodeValueOfCType: at: withName: malloc's new memory
	     for char*'s.  We need to make sure it gets freed eventually
	     so we don't have a memory leak.  Request here that it be
	     autorelease'ed. Also autorelease created objects. */
	  if (*type == _C_CHARPTR)
	    [NSData dataWithBytesNoCopy: *(void**)datum length: 1];
          else if (*type == _C_ID)
            [*(id*)datum autorelease];
	}

      retframe = mframe_build_return (argframe, type, out_parameters,
				      decoder);
      /* Make sure we processed all arguments, and dismissed the IP.
         IP is always set to -1 after being dismissed; the only places
	 this is done is in this function DECODER().  IP will be nil
	 if mframe_build_return() never called DECODER(), i.e. when
	 we are just returning (void).*/
      NSAssert(ip == (id)-1 || ip == nil, NSInternalInconsistencyException);
      rep_in_count++;	/* received a reply */
      return retframe;
    }
  }
}

/* NSConnection calls this to service the incoming method request. */
- (void) _service_forwardForProxy: aRmc
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
	  [aRmc dismiss];
	  return;
	}

      [aRmc decodeValueOfObjCType: type
	    at: datum
	    withName: NULL];
      /* -decodeValueOfCType: at: withName: malloc's new memory
	 for char*'s.  We need to make sure it gets freed eventually
	 so we don't have a memory leak.  Request here that it be
	 autorelease'ed. Also autorelease created objects. */
      if (*type == _C_CHARPTR)
	[NSData dataWithBytesNoCopy: *(void**)datum length: 1];
      else if (*type == _C_ID)
        [*(id*)datum autorelease];
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
	  if (!is_valid)
	    return;
	  op = [self newSendingReplyRmcWithSequenceNumber: 
		       reply_sequence_number];
	  [op encodeValueOfCType: @encode(BOOL)
	      at: &is_exception
	      withName: @"Exceptional reply flag"];
	}
      switch (*type)
	{
	case _C_ID: 
	  if (flags & _F_BYCOPY)
	    [op encodeBycopyObject: *(id*)datum withName: ENCODED_RETNAME];
#ifdef	_F_BYREF
	  else if (flags & _F_BYREF)
	    [op encodeByrefObject: *(id*)datum withName: ENCODED_ARGNAME];
#endif
	  else
	    [op encodeObject: *(id*)datum withName: ENCODED_RETNAME];
	  break;
	default: 
	  [op encodeValueOfObjCType: type at: datum withName: ENCODED_RETNAME];
	}
    }

  /* Make sure don't let exceptions caused by servicing the client's
     request cause us to crash. */
  NS_DURING
    {
      NSParameterAssert (is_valid);

      /* Save this for later */
      reply_sequence_number = [aRmc sequenceNumber];

      /* Get the types that we're using, so that we know
	 exactly what qualifiers the forwarder used.
	 If all selectors included qualifiers and I could make
	 sel_types_match() work the way I wanted, we wouldn't need
	 to do this. */
      [aRmc decodeValueOfCType: @encode(char*)
			    at: &forward_type
		      withName: NULL];

      if (debug_connection > 1)
        NSLog(@"Handling message from 0x%x\n", (gsaddr)self);
      req_in_count++;	/* Handling an incoming request. */
      mframe_do_call (forward_type, decoder, encoder);
      [op dismiss];
      rep_out_count++;	/* Sent back a reply. */
    }

  /* Make sure we pass all exceptions back to the requestor. */
  NS_HANDLER
    {
      BOOL is_exception = YES;

      /* Try to clean up a little. */
      DESTROY(op);

      /* Send the exception back to the client. */
      if (is_valid)
	{
	  NS_DURING
	    {
	      op = [self newSendingReplyRmcWithSequenceNumber:
		reply_sequence_number];
	      [op encodeValueOfCType: @encode(BOOL)
				  at: &is_exception
			    withName: @"Exceptional reply flag"];
	      [op encodeBycopyObject: localException
			    withName: @"Exception object"];
	      [op dismiss];
	    }
	  NS_HANDLER
	    {
	      DESTROY(op);
	      NSLog(@"Exception when sending exception back to client - %@",
		localException);
	    }
	  NS_ENDHANDLER;
	}
    }
  NS_ENDHANDLER;

  if (forward_type)
    objc_free (forward_type);
}

- (void) _service_rootObject: rmc
{
  id rootObject = [NSConnection rootObjectForInPort: receive_port];
  NSPortCoder* op = [[self encodingClass]
			newForWritingWithConnection: [rmc connection]
			sequenceNumber: [rmc sequenceNumber]
			identifier: ROOTPROXY_REPLY];
  NSParameterAssert (receive_port);
  NSParameterAssert (is_valid);
  /* Perhaps we should turn this into a class method. */
  NSParameterAssert([rmc connection] == self);
  [op encodeObject: rootObject withName: @"root object"];
  [op dismiss];
  [rmc dismiss];
}

- (void) _service_release: rmc forConnection: receiving_connection
{
  unsigned int	count;
  unsigned int	pos;

  NSParameterAssert (is_valid);

  if ([rmc connection] != self)
    {
      [rmc dismiss];
      [NSException raise: @"ProxyDecodedBadTarget"
		  format: @"request to release object on bad connection"];
    }

  [rmc decodeValueOfCType: @encode(typeof(count))
		       at: &count
		 withName: NULL];

  for (pos = 0; pos < count; pos++)
    {
      unsigned		target;
      NSDistantObject	*prox;

      [rmc decodeValueOfCType: @encode(typeof(target))
			   at: &target
		     withName: NULL];

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

  [rmc dismiss];
}

- (void) _service_retain: rmc forConnection: receiving_connection
{
  unsigned	target;
  NSPortCoder	*op;

  NSParameterAssert (is_valid);

  if ([rmc connection] != self)
    {
      [rmc dismiss];
      [NSException raise: @"ProxyDecodedBadTarget"
		  format: @"request to retain object on bad connection"];
    }

  op = [[self encodingClass] newForWritingWithConnection: [rmc connection]
					  sequenceNumber: [rmc sequenceNumber]
					      identifier: RETAIN_REPLY];

  [rmc decodeValueOfCType: @encode(typeof(target))
		       at: &target
		 withName: NULL];

  if (debug_connection > 3)
    NSLog(@"looking to retain local object with target (0x%x) on (0x%x)",
		target, (gsaddr)self);

  if ([self includesLocalTarget: target] == nil)
    {
      GSLocalCounter	*counter;

      [proxiesHashGate lock];
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
      [proxiesHashGate unlock];
      if (counter == nil)
	{
	  [op encodeObject: @"target not found anywhere"
		  withName: @"retain failed"];
	  if (debug_connection > 3)
	    NSLog(@"target (0x%x) not found anywhere for retain", target);
	}
      else
	{
	  [NSDistantObject proxyWithLocal: counter->object
			       connection: self];
	  [op encodeObject: nil withName: @"retain ok"];
	  if (debug_connection > 3)
	    NSLog(@"retained object (0x%x) target (0x%x) on connection(0x%x)",
			counter->object, counter->target, self);
	}
    }
  else 
    {
      [op encodeObject: nil withName: @"already retained"];
      if (debug_connection > 3)
	NSLog(@"target (0x%x) already retained on connection (0x%x)",
		target, self);
    }

  [op dismiss];
  [rmc dismiss];
}

- (void) shutdown
{
  id op;

  NSParameterAssert(receive_port);
  NSParameterAssert (is_valid);
  op = [[self encodingClass]
	newForWritingWithConnection: self
	sequenceNumber: [self _newMsgNumber]
	identifier: CONNECTION_SHUTDOWN];
  [op dismiss];
}

- (void) _service_shutdown: rmc forConnection: receiving_connection
{
  NSParameterAssert (is_valid);
  [self invalidate];
  if (receiving_connection == self)
    [NSException raise: NSGenericException
		 format: @"connection waiting for request was shut down"];
  [rmc dismiss];
}

- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target
{
  id op, ip;
  char *type = 0;
  int seq_num;

  NSParameterAssert(receive_port);
  NSParameterAssert (is_valid);
  seq_num = [self _newMsgNumber];
  op = [[self encodingClass]
	newForWritingWithConnection: self
	sequenceNumber: seq_num
	identifier: METHODTYPE_REQUEST];
  [op encodeValueOfObjCType: ": "
      at: &sel
      withName: NULL];
  [op encodeValueOfCType: @encode(unsigned)
      at: &target
      withName: NULL];
  [op dismiss];
  ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
  [ip decodeValueOfCType: @encode(char*)
      at: &type
      withName: NULL];
  [ip dismiss];
  return type;
}

- (void) _service_typeForSelector: rmc
{
  NSPortCoder* op;
  unsigned target;
  NSDistantObject *p;
  id o;
  SEL sel;
  const char *type;
  struct objc_method* m;

  NSParameterAssert(receive_port);
  NSParameterAssert (is_valid);
  NSParameterAssert([rmc connection] == self);
  op = [[self encodingClass]
	newForWritingWithConnection: [rmc connection]
	sequenceNumber: [rmc sequenceNumber]
	identifier: METHODTYPE_REPLY];

  [rmc decodeValueOfObjCType: ": "
       at: &sel
       withName: NULL];
  [rmc decodeValueOfCType: @encode(unsigned)
       at: &target
       withName: NULL];
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
  [op encodeValueOfCType: @encode(char*)
      at: &type
      withName: @"Requested Method Type for Target"];
  [op dismiss];
  [rmc dismiss];
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

- (void) _handleRmc: rmc
{
  NSConnection	*conn = [rmc connection];
  int		ident = [rmc identifier];

  if (debug_connection > 4)
    NSLog(@"handling packet of type %d seq %d\n", ident, [rmc sequenceNumber]);

  switch (ident)
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
      /* We just got a new request; we need to decide whether to queue
	 it or service it now.
	 If the REPLY_DEPTH is 0, then we aren't in the middle of waiting
	 for a reply, we are waiting for requests---so service it now.
	 If REPLY_DEPTH is non-zero, we may still want to service it now
	 if independent_queuing is NO. */
      if (request_depth == 0 || independent_queueing == NO)
	{
	  request_depth++;
	  [conn _service_forwardForProxy: rmc];
	  request_depth--;
	  /* Service any requests that were queued while we
	     were waiting for replies.
	     xxx Is this the right place for this check? */
	  if (request_depth == 0)
	    [self _handleQueuedRmcRequests];
	}
      else
	{
	  [received_request_rmc_queue_gate lock];
	  [received_request_rmc_queue addObject: rmc];
	  [received_request_rmc_queue_gate unlock];
	}
      break;
    case ROOTPROXY_REPLY: 
    case METHOD_REPLY: 
    case METHODTYPE_REPLY: 
    case RETAIN_REPLY: 
      /* Remember multi-threaded callbacks will have to be handled specially */
      [received_reply_rmc_queue_gate lock];
      [received_reply_rmc_queue addObject: rmc];
      [received_reply_rmc_queue_gate unlock];
      break;
    case CONNECTION_SHUTDOWN: 
      {
	[conn _service_shutdown: rmc forConnection: self];
	break;
      }
    case PROXY_RELEASE: 
      {
	[conn _service_release: rmc forConnection: self];
	break;
      }
    case PROXY_RETAIN: 
      {
	[conn _service_retain: rmc forConnection: self];
	break;
      }
    default: 
      [rmc dismiss];
      [NSException raise: NSGenericException
		   format: @"unrecognized NSPortCoder identifier"];
    }
}

- (void) _handleQueuedRmcRequests
{
  id rmc;

  [received_request_rmc_queue_gate lock];
  RETAIN(self);
  while (is_valid && ([received_request_rmc_queue count] > 0))
    {
      rmc = [received_request_rmc_queue objectAtIndex: 0];
      RETAIN(rmc);
      [received_request_rmc_queue removeObjectAtIndex: 0];
      [received_request_rmc_queue_gate unlock];
      [self _handleRmc: rmc];
      [received_request_rmc_queue_gate lock];
      RELEASE(rmc);
    }
  RELEASE(self);
  [received_request_rmc_queue_gate unlock];
}

/* Deal with an RMC, either by queuing it for later service, or
   by servicing it right away.  This method is called by the
   receive_port's received-packet-invocation. */

/* Look for it on the queue, if it is not there, return nil. */
- _getReceivedReplyRmcFromQueueWithSequenceNumber: (int)sn
{
  id the_rmc = nil;
  unsigned count, i;

  [received_reply_rmc_queue_gate lock];

  count = [received_reply_rmc_queue count];
  /* xxx There should be a per-thread queue of rmcs so we can do
     callbacks when multi-threaded. */
  for (i = 0; i < count; i++)
    {
      id a_rmc = [received_reply_rmc_queue objectAtIndex: i];
      if ([a_rmc connection] == self
	  && [a_rmc sequenceNumber] == sn)
        {
	  if (debug_connection)
	    NSLog(@"Getting received reply from queue\n");
          [received_reply_rmc_queue removeObjectAtIndex: i];
          the_rmc = a_rmc;
          break;
        }
      /* xxx Make sure that there isn't a higher sequenceNumber, meaning
	 that we somehow dropped a packet. */
    }
  [received_reply_rmc_queue_gate unlock];
  return the_rmc;
}

/* Check the queue, then try to get it from the network by waiting
   while we run the NSRunLoop.  Raise exception if we don't get anything
   before timing out. */
- _getReceivedReplyRmcWithSequenceNumber: (int)sn
{
  id rmc;
  id timeout_date = nil;

  while (!(rmc = [self _getReceivedReplyRmcFromQueueWithSequenceNumber: sn]))
    {
      if (!timeout_date)
	timeout_date = [[NSDate alloc]
			 initWithTimeIntervalSinceNow: reply_timeout];
      if ([NSRunLoop runOnceBeforeDate: timeout_date
		   forMode: NSConnectionReplyMode] == NO)
	break;
    }
  if (timeout_date)
    [timeout_date release];
  if (rmc == nil)
    [NSException raise: NSPortTimeoutException
		 format: @"timed out waiting for reply"];
  return rmc;
}

/* Sneaky, sneaky.  See "sneaky" comment in TcpPort.m.
   This method is called by InPort when it receives a new packet. */
+ (void) invokeWithObject: packet
{
  id rmc;
  NSConnection	*connection;

  if (debug_connection > 3)
    NSLog(@"packet arrived on %@", [[packet receivingInPort] description]);

  connection = NSMapGet(receive_port_2_ancestor, [packet receivingInPort]);
  if (connection && [connection isValid])
    {
      rmc = [NSPortCoder newDecodingWithPacket: packet
				    connection: connection];
      [[rmc connection] _handleRmc: rmc];
    }
  else
    {
      [packet release];		/* Discard data on invalid connection.	*/
    }
}

- (int) _newMsgNumber
{
  int n;

  NSParameterAssert (is_valid);
  [sequenceNumberGate lock];
  n = message_count++;
  [sequenceNumberGate unlock];
  return n;
}



/* Managing objects and proxies. */
- (void) addLocalObject: anObj
{
  id			object = [anObj localForProxy];
  unsigned		target;
  GSLocalCounter	*counter;

  NSParameterAssert (is_valid);
  [proxiesHashGate lock];
  /* xxx Do we need to check to make sure it's not already there? */
  /* This retains object. */
  NSMapInsert(local_objects, (void*)object, anObj);

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
  NSMapInsert(local_targets, (void*)target, anObj);
  if (debug_connection > 2)
    NSLog(@"add local object (0x%x) target (0x%x) "
	  @"to connection (0x%x) (ref %d)\n",
		(gsaddr)object, target, (gsaddr) self, counter->ref);
  [proxiesHashGate unlock];
}

- (NSDistantObject*) localForObject: (id)object
{
  NSDistantObject *p;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  p = NSMapGet (local_objects, (void*)object);
  [proxiesHashGate unlock];
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

- (void) removeLocalObject: anObj
{
  NSDistantObject	*prox;
  unsigned		target;
  GSLocalCounter	*counter;
  unsigned		val = 0;

  [proxiesHashGate lock];

  prox = NSMapGet(local_objects, (void*)anObj);
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

  NSMapRemove(local_objects, (void*)anObj);
  NSMapRemove(local_targets, (void*)target);

  if (debug_connection > 2)
    NSLog(@"remove local object (0x%x) target (0x%x) "
	@"from connection (0x%x) (ref %d)\n",
		(gsaddr)anObj, target, (gsaddr)self, val);

  [proxiesHashGate unlock];
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
      if (receive_port && is_valid && number > 0) {
	id		op;
	unsigned 	i;

	op = [[self encodingClass]
		newForWritingWithConnection: self
			     sequenceNumber: [self _newMsgNumber]
				 identifier: PROXY_RELEASE];

	[op encodeValueOfCType: @encode(unsigned)
			    at: &number
		      withName: NULL];

	for (i = 0; i < number; i++)
	  {
	    [op encodeValueOfCType: @encode(unsigned)
				at: &list[i]
			  withName: NULL];
	    if (debug_connection > 3)
	      NSLog(@"sending release for target (0x%x) on (0x%x)",
		    list[i], (gsaddr)self);
	  }

	[op dismiss];
      }
    }
  NS_HANDLER
    {
      if (debug_connection)
        NSLog(@"failed to release targets - %@\n", [localException name]);
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
      if (receive_port && is_valid)
	{
	  id		op;
	  id		ip;
	  id		result;
	  int seq_num = [self _newMsgNumber];

	  op = [[self encodingClass]
		  newForWritingWithConnection: self
			       sequenceNumber: seq_num
				   identifier: PROXY_RETAIN];

	  [op encodeValueOfCType: @encode(typeof(target))
			      at: &target
			withName: NULL];

	  [op dismiss];
	  ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
	  [ip decodeObjectAt: &result withName: NULL];
	  if (result != nil)
	    NSLog(@"failed to retain target - %@\n", result);
	  [ip dismiss];
	}
    }
  NS_HANDLER
    {
      NSLog(@"failed to retain target - %@\n", [localException name]);
    }
  NS_ENDHANDLER
}

- (void) removeProxy: (NSDistantObject*)aProxy
{
  unsigned target = [aProxy targetForProxy];

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  /* This also releases aProxy */
  NSMapRemove (remote_proxies, (void*)target);
  [proxiesHashGate unlock];

  /*
   *	Tell the remote application that we have removed our proxy and
   *	it can release it's local object.
   */
  [self _release_targets: &target count: 1];
}

- (NSArray*) localObjects
{
  NSArray	*c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues(local_objects);
  [proxiesHashGate unlock];
  return c;
}

- (NSArray*) proxies
{
  NSArray	*c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues(remote_proxies);
  [proxiesHashGate unlock];
  return c;
}

- (NSDistantObject*) proxyForTarget: (unsigned)target
{
  NSDistantObject *p;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  p = NSMapGet (remote_proxies, (void*)target);
  [proxiesHashGate unlock];
  NSParameterAssert(!p || [p connectionForProxy] == self);
  return p;
}

- (void) addProxy: (NSDistantObject*) aProxy
{
  unsigned target = (unsigned int)[aProxy targetForProxy];

  NSParameterAssert (is_valid);
  NSParameterAssert(aProxy->isa == [NSDistantObject class]);
  NSParameterAssert([aProxy connectionForProxy] == self);
  [proxiesHashGate lock];
  if (NSMapGet (remote_proxies, (void*)target))
    {
      [proxiesHashGate unlock];
      [NSException raise: NSGenericException
		  format: @"Trying to add the same proxy twice"];
    }
  NSMapInsert (remote_proxies, (void*)target, aProxy);
  [proxiesHashGate unlock];
}

- (id) includesProxyForTarget: (unsigned)target
{
  NSDistantObject	*ret;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  ret = NSMapGet (remote_proxies, (void*)target);
  [proxiesHashGate unlock];
  return ret;
}

- (id) includesLocalObject: (id)anObj
{
  NSDistantObject* ret;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  ret = NSMapGet(local_objects, (void*)anObj);
  [proxiesHashGate unlock];
  return ret;
}

- (id) includesLocalTarget: (unsigned)target
{
  NSDistantObject* ret;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  ret = NSMapGet(local_targets, (void*)target);
  [proxiesHashGate unlock];
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

  /* Don't assert (is_valid); */
  NSParameterAssert (all_connections_local_targets);
  [proxiesHashGate lock];
  ret = NSMapGet (all_connections_local_targets, (void*)target);
  [proxiesHashGate unlock];
  return ret;
}


/* Pass nil to remove any reference keyed by aPort. */
+ (void) setRootObject: anObj forInPort: (NSPort*)aPort
{
  id oldRootObject = [self rootObjectForInPort: aPort];

  NSParameterAssert ([aPort isValid]);
  /* xxx This retains aPort?  How will aPort ever get dealloc'ed? */
  if (oldRootObject != anObj)
    {
      if (anObj)
	{
	  [root_object_dictionary_gate lock];
	  [root_object_dictionary setObject: anObj forKey: aPort];
	  [root_object_dictionary_gate unlock];
	}
      else /* anObj == nil && oldRootObject != nil */
	{
	  [root_object_dictionary_gate lock];
	  [root_object_dictionary removeObjectForKey: aPort];
	  [root_object_dictionary_gate unlock];
	}
    }
}

+ rootObjectForInPort: (NSPort*)aPort
{
  id ro;

  [root_object_dictionary_gate lock];
  ro = [root_object_dictionary objectForKey: aPort];
  [root_object_dictionary_gate unlock];
  return ro;
}


/* Accessing ivars */

- (Class) receivePortClass
{
  return receive_port_class;
}

- (Class) sendPortClass
{
  return send_port_class;
}

- (void) setReceivePortClass: (Class) aPortClass
{
  receive_port_class = aPortClass;
}

- (void) setSendPortClass: (Class) aPortClass
{
  send_port_class = aPortClass;
}

- (Class) proxyClass
{
  /* we might replace this with a per-Connection proxy class. */
  return default_proxy_class;
}

- (Class) encodingClass
{
  return encoding_class;
}

- (Class) decodingClass
{
  /* we might replace this with a per-Connection class. */
  return default_decoding_class;
}


/* Prevent trying to encode the connection itself */

- (void) encodeWithCoder: anEncoder
{
  [self shouldNotImplement: _cmd];
}

+ newWithCoder: aDecoder;
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
- (void) portIsInvalid: notification
{
  if (is_valid)
    {
      id port = [notification object];

      if (debug_connection)
	{
	  NSLog(@"Received port invalidation notification for "
	      @"connection 0x%x\n\t%@\n", (gsaddr)self, port);
	}

      /* We shouldn't be getting any port invalidation notifications,
	  except from our own ports; this is how we registered ourselves
	  with the NSNotificationCenter in
	  +newForInPort: outPort: ancestorConnection. */
      NSParameterAssert (port == receive_port || port == send_port);

      [self invalidate];
    }
}

@end



@implementation NSConnection (OPENSTEP)

+ (NSConnection*) connectionWithReceivePort: (NSPort*)r
				   sendPort: (NSPort*)s
{
  NSConnection	*c;

  c = [self alloc];
  c = [self initWithReceivePort: r sendPort: s];
  return AUTORELEASE(c);
}

/* This is the designated initializer for NSConnection */
- (id) initWithReceivePort: (NSPort*)r
		  sendPort: (NSPort*)s
{
  NSNotificationCenter	*nCenter;
  NSConnection		*conn;
  id			del;

  NSParameterAssert(r);

  /*
   * Find previously existing connection if there
   */
  conn = [NSConnection connectionByInPort: r outPort: s];
  if (conn != nil)
    {
      if (debug_connection > 2)
	{
	  NSLog(@"Found existing connection (0x%x) for \n\t%@\n\t%@\n",
	    (gsaddr)conn, r, s);
	}
      RELEASE(self);
      return RETAIN(conn);
    }
  [connection_table_gate lock];

  if (debug_connection)
    {
      NSLog(@"Initialised new connection 0x%x\n\t%@\n\t%@\n",
	(gsaddr)self, r, s);
    }
  is_valid = YES;
  receive_port = RETAIN(r);
  send_port = RETAIN(s);
  message_count = 0;
  rep_out_count = 0;
  req_out_count = 0;
  rep_in_count = 0;
  req_in_count = 0;

  /*
   * This maps (void*)obj to (id)obj.  The obj's are retained.
   * We use this instead of an NSHashTable because we only care about
   * the object's address, and don't want to send the -hash message to it.
   */
  local_objects =
    NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /*
   * This maps handles for local objects to their local proxies.
   */
  local_targets =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /*
   * This maps [proxy targetForProxy] to proxy.  The proxy's are retained.
   */
  remote_proxies =
    NSCreateMapTable(NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  reply_timeout = default_reply_timeout;
  request_timeout = default_request_timeout;
  encoding_class = default_encoding_class;

  /* xxx It this the correct behavior? */
  if ((conn = NSMapGet(receive_port_2_ancestor, r)) == nil)
    {
      NSMapInsert(receive_port_2_ancestor, r, self);
      /*
       * This will cause the connection with the registered name
       * to receive the -invokeWithObject: from the IN_PORT.
       * This ends up being the ancestor of future new NSConnections
       * on this in port.
       */
      /* xxx Could it happen that this connection was invalidated, but
	 the others would still be OK?  That would cause problems.
	 No.  I don't think that can happen. */
      [(InPort*)r setReceivedPacketInvocation: (id)[self class]];
    }

  if (conn != nil)
    {
      receive_port_class = [conn receivePortClass];
      send_port_class = [conn sendPortClass];
    }
  else
    {
      receive_port_class = default_receive_port_class;
      send_port_class = default_send_port_class;
    }
  independent_queueing = NO;
  request_depth = 0;
  delegate = nil;
  /*
   *	Set up request modes array and make sure the receiving port is
   *	added to the run loop to get data.
   */
  request_modes
    = RETAIN([NSMutableArray arrayWithObject: NSDefaultRunLoopMode]);
  [[NSRunLoop currentRunLoop] addPort: (NSPort*)r
			      forMode: NSDefaultRunLoopMode];
  [[NSRunLoop currentRunLoop] addPort: (NSPort*)r
			      forMode: NSConnectionReplyMode];

  /* Ask the delegate for permission, (OpenStep-style and GNUstep-style). */

  /* Preferred OpenStep version, which just allows the returning of BOOL */
  del = [conn delegate];
  if ([del respondsTo: @selector(connection:shouldMakeNewConnection:)])
    {
      if ([del connection: conn shouldMakeNewConnection: self] == NO)
	{
	  [connection_table_gate unlock];
	  RELEASE(self);
	  return nil;
	}
    }
  /* Deprecated OpenStep version, which just allows the returning of BOOL */
  if ([del respondsTo: @selector(makeNewConnection:sender:)])
    {
      if (![del makeNewConnection: self sender: conn])
	{
	  [connection_table_gate unlock];
	  RELEASE(self);
	  return nil;
	}
    }
  /* Here is the GNUstep version, which allows the delegate to specify
     a substitute.  Note: The delegate is responsible for freeing
     newConn if it returns something different. */
  if ([del respondsTo: @selector(connection:didConnect:)])
    self = [del connection: conn didConnect: self];

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
  [connection_table_gate unlock];

  [[NSNotificationCenter defaultCenter]
  postNotificationName: NSConnectionDidInitializeNotification
		object: self];

  return self;
}

- (NSPort*) receivePort
{
  return receive_port;
}

- (void) runInNewThread
{
  [self notImplemented: _cmd];
}

- (NSPort*) sendPort
{
  return send_port;
}

@end
#endif
