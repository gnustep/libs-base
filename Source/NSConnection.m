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

#include <mframe.h>
#if defined(USE_LIBFFI)
#include "cifframe.h"
#elif defined(USE_FFCALL)
#include "callframe.h"
#endif

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
#include <base/GSInvocation.h>

#define F_LOCK(X) {NSDebugFLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define F_UNLOCK(X) {NSDebugFLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}
#define M_LOCK(X) {NSDebugMLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define M_UNLOCK(X) {NSDebugMLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}

/*
 * Set up a type to permit us to have direct access into an NSDistantObject
 */
typedef struct {
  @defs(NSDistantObject)
} ProxyStruct;

/*
 * Cache various class pointers.
 */
static id	dummyObject;
static Class	connectionClass;
static Class	dateClass;
static Class	distantObjectClass;
static Class	localCounterClass;
static Class	sendCoderClass;
static Class	recvCoderClass;
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

- (void) addLocalObject: (NSDistantObject*)anObj;
- (NSDistantObject*) localForObject: (id)object;
- (void) removeLocalObject: (id)anObj;

- (void) _doneInReply: (NSPortCoder*)c;
- (void) _doneInRmc: (NSPortCoder*)c;
- (void) _failInRmc: (NSPortCoder*)c;
- (void) _failOutRmc: (NSPortCoder*)c;
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
static NSTimer		*timer;

static BOOL cacheCoders = NO;
static int debug_connection = 0;

static NSHashTable	*connection_table;
static NSLock		*connection_table_gate = nil;

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
static NSLock *root_object_map_gate = nil;

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

static NSMapTable *objectToCounter = NULL;
static NSMapTable *targetToCounter = NULL;
static NSMapTable *targetToCached = NULL;
static NSLock	*global_proxies_gate = nil;

static BOOL	multi_threaded = NO;



@implementation NSConnection

/*
 *	When the system becomes multithreaded, we set a flag to say so and
 *	make sure that connection locking is enabled.
 */
+ (void) _becomeThreaded: (NSNotification*)notification
{
  if (multi_threaded == NO)
    {
      NSHashEnumerator	enumerator;
      NSConnection		*c;

      multi_threaded = YES;
      if (connection_table_gate == nil)
	{
	  connection_table_gate = [NSLock new];
	}
      if (global_proxies_gate == nil)
	{
	  global_proxies_gate = [NSLock new];
	}
      if (root_object_map_gate == nil)
	{
	  root_object_map_gate = [NSLock new];
	}
      enumerator = NSEnumerateHashTable(connection_table);
      while ((c = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
	{
	  if (c->_refGate == nil)
	    {
	      c->_refGate = [NSRecursiveLock new];
	    }
	}
    }
  [[NSNotificationCenter defaultCenter]
    removeObserver: self
	      name: NSWillBecomeMultiThreadedNotification
	    object: nil];
}

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

/*
 * Create a connection to a remote server.
 */
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
	  if (recvPort == sendPort)
	    {
	      /*
	       * If the receive and send port are the same, the server
	       * must be in this process - so we need to create a new
	       * connection to talk to it.
	       */
	      recvPort = [NSPort port];
	    }
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
      if (c != nil)
	{
	  [d setObject: c forKey: tkey];
	  RELEASE(c);
	}
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
      localCounterClass = [GSLocalCounter class];
      sendCoderClass = [NSPortCoder class];
      recvCoderClass = [NSPortCoder class];
      runLoopClass = [NSRunLoop class];

      dummyObject = [NSObject new];

      connection_table = 
	NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 0);

      objectToCounter =
	NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
      targetToCounter =
	NSCreateMapTable(NSIntMapKeyCallBacks,
			  NSNonOwnedPointerMapValueCallBacks, 0);
      targetToCached =
	NSCreateMapTable(NSIntMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);

      root_object_map =
	NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
      if ([NSThread isMultiThreaded])
	{
	  [self _becomeThreaded: nil];
	}
      else
	{
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	       selector: @selector(_becomeThreaded:)
		   name: NSWillBecomeMultiThreadedNotification
		 object: nil];
	}
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

  cached_locals = NSAllMapTableValues(targetToCached);
  for (i = [cached_locals count]; i > 0; i--)
    {
      CachedLocalObject *item = [cached_locals objectAtIndex: i-1];

      if ([item countdown] == NO)
	{
	  GSLocalCounter	*counter = [item obj];
	  NSMapRemove(targetToCached, (void*)counter->target);
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
  if (cacheCoders == YES)
    {
      _cachedDecoders = [NSMutableArray new];
      _cachedEncoders = [NSMutableArray new];
    }

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
   * This maps targets to remote proxies.
   */
  _remoteProxies = (GSIMapTable)NSZoneMalloc(z, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(_remoteProxies, z, 4);

  _requestDepth = 0;
  _delegate = nil;
  if (multi_threaded == YES)
    {
      _refGate = [NSRecursiveLock new];
    }

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
  if ([del respondsToSelector: @selector(connection:shouldMakeNewConnection:)])
    {
      if ([del connection: parent shouldMakeNewConnection: self] == NO)
	{
	  M_UNLOCK(connection_table_gate);
	  RELEASE(self);
	  return nil;
	}
    }
  /* Deprecated OpenStep version, which just allows the returning of BOOL */
  if ([del respondsToSelector: @selector(makeNewConnection:sender:)])
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
  if ([del respondsToSelector: @selector(connection:didConnect:)])
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

  M_UNLOCK(_refGate);

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
      GSIMapEnumerator_t	enumerator;
      GSIMapNode 		node;

      targets = [[NSMutableArray alloc] initWithCapacity: i];
      enumerator = GSIMapEnumeratorForMap(_localTargets);
      node = GSIMapEnumeratorNextNode(&enumerator);
      while (node != 0)
	{
	  [targets addObject: node->value.obj];
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
      while (i-- > 0)
	{
	  id	t = ((ProxyStruct*)[targets objectAtIndex: i])->_object;

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
      GSIMapEnumerator_t	enumerator;
      GSIMapNode 		node;

      enumerator = GSIMapEnumeratorForMap(_localObjects);
      node = GSIMapEnumeratorNextNode(&enumerator);

      while (node != 0)
	{
	  RELEASE(node->key.obj);
	  node = GSIMapEnumeratorNextNode(&enumerator);
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

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  if (_localObjects != 0)
    {
      GSIMapEnumerator_t	enumerator;
      GSIMapNode 		node;

      enumerator = GSIMapEnumeratorForMap(_localObjects);
      node = GSIMapEnumeratorNextNode(&enumerator);

      c = [NSMutableArray arrayWithCapacity: _localObjects->nodeCount];
      while (node != 0)
	{
	  [c addObject: node->key.obj];
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
    }
  else
    {
      c = [NSArray array];
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

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  if (_remoteProxies != 0)
    {
      GSIMapEnumerator_t	enumerator;
      GSIMapNode 		node;

      enumerator = GSIMapEnumeratorForMap(_remoteProxies);
      node = GSIMapEnumeratorNextNode(&enumerator);

      c = [NSMutableArray arrayWithCapacity: _remoteProxies->nodeCount];
      while (node != 0)
	{
	  [c addObject: node->key.obj];
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
    }
  else
    {
      c = [NSMutableArray array];
    }
  M_UNLOCK(_proxiesGate);
  return c;
}

- (void) removeRequestMode: (NSString*)mode
{
  M_LOCK(_refGate);
  if (_requestModes != nil && [_requestModes containsObject: mode])
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
  M_LOCK(_refGate);
  if (_runLoops != nil)
    {
      unsigned	pos = [_runLoops indexOfObjectIdenticalTo: loop];

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
    }
  M_UNLOCK(_refGate);
}

- (NSTimeInterval) replyTimeout
{
  return _replyTimeout;
}

- (NSArray*) requestModes
{
  NSArray	*c;

  M_LOCK(_refGate);
  c = AUTORELEASE([_requestModes copy]);
  M_UNLOCK(_refGate);
  return c;
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

  /*
   * If this is a server connection without a remote end, its root proxy
   * is the same as its root object.
   */
  if (_receivePort == _sendPort)
    {
      return [self rootObject];
    }
  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];
  [self _sendOutRmc: op type: ROOTPROXY_REQUEST];

  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(id) at: &newProxy];
  [self _doneInRmc: ip];
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
  if (_requestModes != nil)
    {
      while ([_requestModes count] > 0
	&& [_requestModes objectAtIndex: 0] != mode)
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
  o = [NSNumber numberWithUnsignedInt:
    _localTargets ? _localTargets->nodeCount : 0];
  [d setObject: o forKey: NSConnectionLocalCount];
  o = [NSNumber numberWithUnsignedInt:
    _remoteProxies ? _remoteProxies->nodeCount : 0];
  [d setObject: o forKey: NSConnectionProxyCount];
  o = [NSNumber numberWithUnsignedInt:
    _replyMap ? _replyMap->nodeCount : 0];
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
      GSIMapEnumerator_t	enumerator;
      GSIMapNode 		node;

      enumerator = GSIMapEnumeratorForMap(_replyMap);
      node = GSIMapEnumeratorNextNode(&enumerator);

      while (node != 0)
	{
	  if (node->key.obj != dummyObject)
	    {
	      RELEASE(node->key.obj);
	    }
	  node = GSIMapEnumeratorNextNode(&enumerator);
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

#ifdef BROKEN_NESTED_FUNCTIONS
typedef struct _NSConnection_t {
  @defs(NSConnection)
} NSConnection_t;
static NSConnection_t *c_self_t;
static NSPortCoder *op = nil;
static NSPortCoder *ip = nil;
static NSConnection *c_self;
static BOOL         is_exception = NO;
static BOOL         second_decode = NO;
static int	    seq_num;

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

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  c_self_t = (NSConnection_t *)c_self;
	  if (type == 0)
	    {
	      if (ip != nil)
		{
		  [c_self _doneInRmc: ip];
		  /* this must be here to avoid trashing alloca'ed retframe */
		  ip = (id)-1;
		  c_self_t->_repInCount++;	/* received a reply */
		}
	      return;
	    }
	  /* If we didn't get the reply packet yet, get it now. */
	  if (ip == nil)
	    {
	      if (c_self_t->_isValid == NO)
		{
		  [NSException raise: NSGenericException
		    format: @"connection waiting for request was shut down"];
		}
	      ip = [c_self _getReplyRmc: seq_num];
	      /*
	       * Find out if the server is returning an exception instead
	       * of the return values.
	       */
	      [ip decodeValueOfObjCType: @encode(BOOL) at: &is_exception];
	      if (is_exception == YES)
		{
		  /* Decode the exception object, and raise it. */
		  id exc;
		  [ip decodeValueOfObjCType: @encode(id) at: &exc];
		  [c_self _doneInRmc: ip];
		  ip = (id)-1;
		  /* xxx Is there anything else to clean up in
		     dissect_method_return()? */
		  [exc raise];
		}
	    }
	  if (*type == _C_PTR)
	  else
	    [ip decodeValueOfObjCType: type+1 at: datum];
	    [ip decodeValueOfObjCType: type at: datum];
	  /* -decodeValueOfObjCType:at: malloc's new memory
	     for pointers.  We need to make sure it gets freed eventually
	     so we don't have a memory leak.  Request here that it be
	     autorelease'ed. Also autorelease created objects. */
	  if (second_decode == NO)
	    {
	      if ((*type == _C_CHARPTR || *type == _C_PTR) && *(void**)datum != 0)
		[NSData dataWithBytesNoCopy: *(void**)datum length: 1];
	    }
	  else if (*type == _C_ID)
	    AUTORELEASE(*(id*)datum);
	}
#endif

static void retDecoder(DOContext *ctxt)
{
  NSPortCoder	*coder = ctxt->decoder;
  const char	*type = ctxt->type;

  if (type == 0)
    {
      if (coder != nil)
	{
	  ctxt->decoder = nil;
	  [ctxt->connection _doneInReply: coder];
	}
      return;
    }
  /* If we didn't get the reply packet yet, get it now. */
  if (coder == nil)
    {
      BOOL	is_exception;

      if ([ctxt->connection isValid] == NO)
	{
	  [NSException raise: NSGenericException
	    format: @"connection waiting for request was shut down"];
	}
      ctxt->decoder = [ctxt->connection _getReplyRmc: ctxt->seq];
      coder = ctxt->decoder;
      /*
       * Find out if the server is returning an exception instead
       * of the return values.
       */
      [coder decodeValueOfObjCType: @encode(BOOL) at: &is_exception];
      if (is_exception == YES)
	{
	  /* Decode the exception object, and raise it. */
	  id exc;
	  [coder decodeValueOfObjCType: @encode(id) at: &exc];
	  ctxt->decoder = nil;
	  [ctxt->connection _doneInRmc: coder];
	  [exc raise];
	}
    }
  [coder decodeValueOfObjCType: type at: ctxt->datum];
  if (*type == _C_ID)
    {
      AUTORELEASE(*(id*)ctxt->datum);
    }
}

static void retEncoder (DOContext *ctxt)
{
  switch (*ctxt->type)
    {
    case _C_ID: 
      if (ctxt->flags & _F_BYCOPY)
	[ctxt->encoder encodeBycopyObject: *(id*)ctxt->datum];
#ifdef	_F_BYREF
      else if (ctxt->flags & _F_BYREF)
	[ctxt->encoder encodeByrefObject: *(id*)ctxt->datum];
#endif
      else
	[ctxt->encoder encodeObject: *(id*)ctxt->datum];
      break;
    default: 
      [ctxt->encoder encodeValueOfObjCType: ctxt->type at: ctxt->datum];
    }
}

/*
 * NSDistantObject's -forward: : method calls this to send the message
 * over the wire.
 */
- (retval_t) forwardForProxy: (NSDistantObject*)object
		    selector: (SEL)sel
                    argFrame: (arglist_t)argframe
{
  BOOL		outParams;
  BOOL		needsResponse;
  const char	*type;
  retval_t	retframe;
  DOContext	ctxt;

  memset(&ctxt, 0, sizeof(ctxt));
  ctxt.connection = self;
  
  /* Encode the method on an RMC, and send it. */

  NSParameterAssert (_isValid);

  /* get the method types from the selector */
#if NeXT_RUNTIME
  [NSException
    raise: NSGenericException
    format: @"Sorry, distributed objects does not work with NeXT runtime"];
  /* type = [object selectorTypeForProxy: sel]; */
#else
  type = sel_get_type(sel);
  if (type == 0 || *type == '\0')
    {
      type = [[object methodSignatureForSelector: sel] methodType];
      if (type)
	{
	  sel_register_typed_name(sel_get_name(sel), type);
	}
    }
#endif
  NSParameterAssert(type);
  NSParameterAssert(*type);

  ctxt.encoder = [self _makeOutRmc: 0 generate: &ctxt.seq reply: YES];

  if (debug_connection > 4)
    NSLog(@"building packet seq %d", ctxt.seq);

  /* Send the types that we're using, so that the performer knows
     exactly what qualifiers we're using.
     If all selectors included qualifiers, and if I could make
     sel_types_match() work the way I wanted, we wouldn't need to do
     this. */
  [ctxt.encoder encodeValueOfObjCType: @encode(char*) at: &type];

  /* xxx This doesn't work with proxies and the NeXT runtime because
     type may be a method_type from a remote machine with a
     different architecture, and its argframe layout specifiers
     won't be right for this machine! */
  outParams = mframe_dissect_call (argframe, type, retEncoder, &ctxt);

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

  [self _sendOutRmc: ctxt.encoder type: METHOD_REQUEST];
  ctxt.encoder = nil;
  NSDebugMLLog(@"NSConnection", @"Sent message to 0x%x", (gsaddr)self);

  if (needsResponse == NO)
    {
      GSIMapNode	node;

      /*
       * Since we don't need a response, we can remove the placeholder from
       * the _replyMap.  However, in case the other end has already sent us
       * a response, we must check for it and scrap it if necessary.
       */
      M_LOCK(_refGate);
      node = GSIMapNodeForKey(_replyMap, (GSIMapKey)ctxt.seq);
      if (node != 0 && node->value.obj != dummyObject)
	{
	  BOOL	is_exception = NO;

	  [node->value.obj decodeValueOfObjCType: @encode(BOOL)
					      at: &is_exception];
	  if (is_exception == YES)
	    NSLog(@"Got exception with %@", NSStringFromSelector(sel));
	  else
	    NSLog(@"Got response with %@", NSStringFromSelector(sel));
	  [self _doneInRmc: node->value.obj];
	}
      GSIMapRemoveKey(_replyMap, (GSIMapKey)ctxt.seq);
      M_UNLOCK(_refGate);
      retframe = alloca(sizeof(void*));	 /* Dummy value for void return. */
    }
  else
    {
      retframe = mframe_build_return (argframe, type, outParams,
	retDecoder, &ctxt);
      /* Make sure we processed all arguments, and dismissed the IP.
	 IP is always set to -1 after being dismissed; the only places
	 this is done is in this function DECODER().  IP will be nil
	 if mframe_build_return() never called DECODER(), i.e. when
	 we are just returning (void).*/
      NSAssert(ctxt.decoder == nil, NSInternalInconsistencyException);
    }
  return retframe;
}

/*
 * NSDistantObject's -forwardInvocation: method calls this to send the message
 * over the wire.
 */
- (void) forwardInvocation: (NSInvocation *)inv 
		  forProxy: (NSDistantObject*)object 
{
  NSPortCoder	*op;
  BOOL		outParams;
  BOOL		needsResponse;
  const char	*type;
  DOContext	ctxt;

  /* Encode the method on an RMC, and send it. */

  NSParameterAssert (_isValid);

  /* get the method types from the selector */
  type = [[inv methodSignature] methodType];
  if (type == 0 || *type == '\0')
    {
      type = [[object methodSignatureForSelector: [inv selector]] methodType];
      if (type)
	{
	  sel_register_typed_name(sel_get_name([inv selector]), type);
	}
    }
  NSParameterAssert(type);
  NSParameterAssert(*type);

  memset(&ctxt, 0, sizeof(ctxt));
  ctxt.connection = self;

  op = [self _makeOutRmc: 0 generate: &ctxt.seq reply: YES];

  if (debug_connection > 4)
    NSLog(@"building packet seq %d", ctxt.seq);

  outParams = [inv encodeWithDistantCoder: op passPointers: NO];

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
      GSIMapNode	node;

      /*
       * Since we don't need a response, we can remove the placeholder from
       * the _replyMap.  However, in case the other end has already sent us
       * a response, we must check for it and scrap it if necessary.
       */
      M_LOCK(_refGate);
      node = GSIMapNodeForKey(_replyMap, (GSIMapKey)ctxt.seq);
      if (node != 0 && node->value.obj != dummyObject)
	{
	  BOOL	is_exception = NO;
	  SEL	sel = [inv selector];

	  [node->value.obj decodeValueOfObjCType: @encode(BOOL)
					      at: &is_exception];
	  if (is_exception == YES)
	    NSLog(@"Got exception with %@", NSStringFromSelector(sel));
	  else
	    NSLog(@"Got response with %@", NSStringFromSelector(sel));
	  [self _doneInRmc: node->value.obj];
	}
      GSIMapRemoveKey(_replyMap, (GSIMapKey)ctxt.seq);
      M_UNLOCK(_refGate);
    }
  else
    {
#ifdef USE_FFCALL
      callframe_build_return (inv, type, outParams, retDecoder, &ctxt);
#endif
      /* Make sure we processed all arguments, and dismissed the IP.
	 IP is always set to -1 after being dismissed; the only places
	 this is done is in this function DECODER().  IP will be nil
	 if mframe_build_return() never called DECODER(), i.e. when
	 we are just returning (void).*/
      NSAssert(ctxt.decoder == nil, NSInternalInconsistencyException);
    }
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
  [self _doneInRmc: ip];
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
  if (debug_connection > 4)
    {
      NSLog(@"  connection is %x:%x", conn, [NSThread currentThread]);
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
  if (debug_connection > 5)
    {
      NSLog(@"made rmc 0x%x for %d", rmc, type);
    }

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
	      NSDebugMLLog(@"NSConnection", @"Ignoring reply RMC %d on %x",
		sequence, conn);
	      [self _doneInRmc: rmc];
	    }
	  else if (node->value.obj == dummyObject)
	    {
	      NSDebugMLLog(@"NSConnection", @"Saving reply RMC %d on %x",
		sequence, conn);
	      node->value.obj = rmc;
	    }
	  else
	    {
	      NSDebugMLLog(@"NSConnection", @"Replace reply RMC %d on %x",
		sequence, conn);
	      [self _doneInRmc: node->value.obj];
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

static void callDecoder (DOContext *ctxt)
{
  const char	*type = ctxt->type;
  void		*datum = ctxt->datum;
  NSPortCoder	*coder = ctxt->decoder;

  /*
   * We need this "dismiss" to happen here and not later so that Coder
   * "-awake..." methods will get sent before the method using the
   * objects is invoked.  We clear the 'decoder' field in the context to
   * show that it is no longer valid.
   */
  if (datum == 0 && type == 0)
    {
      ctxt->decoder = nil;
      [ctxt->connection _doneInRmc: coder];
      return;
    }

  [coder decodeValueOfObjCType: type at: datum];
#ifdef USE_FFCALL
  if (*type == _C_ID)
#else
  /* -decodeValueOfObjCType: at: malloc's new memory
     for char*'s.  We need to make sure it gets freed eventually
     so we don't have a memory leak.  Request here that it be
     autorelease'ed. Also autorelease created objects. */
  if ((*type == _C_CHARPTR || *type == _C_PTR) && *(void**)datum != 0)
    {
      [NSData dataWithBytesNoCopy: *(void**)datum length: 1];
    }
  else if (*type == _C_ID)
#endif
    {
      AUTORELEASE(*(id*)datum);
    }
}

static void callEncoder (DOContext *ctxt)
{
  const char		*type = ctxt->type;
  void			*datum = ctxt->datum;
  int			flags = ctxt->flags;
  NSPortCoder		*coder = ctxt->encoder;

  if (coder == nil)
    {
      BOOL is_exception = NO;

      /*
       * It is possible that our connection died while the method was
       * being called - in this case we mustn't try to send the result
       * back to the remote application!
       */
      if ([ctxt->connection isValid] == NO)
	{
	  return;
	}

      /*
       * We create a new coder object and set it in the context for
       * later use if/when we are called again.  We encode a flag to
       * say that this is not an exception.
       */
      coder = [ctxt->connection _makeOutRmc: ctxt->seq
				   generate: 0
				      reply: NO];
      ctxt->encoder = coder;
      [coder encodeValueOfObjCType: @encode(BOOL) at: &is_exception];
    }

  switch (*type)
    {
      case _C_ID: 
	if (flags & _F_BYCOPY)
	  [coder encodeBycopyObject: *(id*)datum];
#ifdef	_F_BYREF
	else if (flags & _F_BYREF)
	  [coder encodeByrefObject: *(id*)datum];
#endif
	else
	  [coder encodeObject: *(id*)datum];
	break;
      default: 
	[coder encodeValueOfObjCType: type at: datum];
    }
}


/* NSConnection calls this to service the incoming method request. */
- (void) _service_forwardForProxy: (NSPortCoder*)aRmc
{
  char		*forward_type = 0;
  DOContext	ctxt;

  memset(&ctxt, 0, sizeof(ctxt));
  ctxt.connection = self;
  ctxt.decoder = aRmc;

  /*
   * Make sure don't let exceptions caused by servicing the client's
   * request cause us to crash.
   */
  NS_DURING
    {
      NSParameterAssert (_isValid);

      /* Save this for later */
      [aRmc decodeValueOfObjCType: @encode(int) at: &ctxt.seq];

      /*
       * Get the types that we're using, so that we know
       * exactly what qualifiers the forwarder used.
       * If all selectors included qualifiers and I could make
       * sel_types_match() work the way I wanted, we wouldn't need
       * to do this.
       */
      [aRmc decodeValueOfObjCType: @encode(char*) at: &forward_type];
      ctxt.type = forward_type;

      if (debug_connection > 1)
	{
	  NSLog(@"Handling message from 0x%x", (gsaddr)self);
	}
      _reqInCount++;	/* Handling an incoming request. */

#if defined(USE_LIBFFI)
      cifframe_do_call (&ctxt, callDecoder, callEncoder);
#elif defined(USE_FFCALL)
      callframe_do_call (&ctxt, callDecoder, callEncoder);
#else
      mframe_do_call (&ctxt, callDecoder, callEncoder);
#endif
      if (ctxt.encoder != nil)
	{
	  [self _sendOutRmc: ctxt.encoder type: METHOD_REPLY];
	}
    }
  NS_HANDLER
    {
      /* Send the exception back to the client. */
      if (_isValid == YES)
	{
	  BOOL is_exception = YES;

	  NS_DURING
	    {
	      NSPortCoder	*op;

	      if (ctxt.decoder != nil)
		{
		  [self _failInRmc: ctxt.decoder];
		}
	      if (ctxt.encoder != nil)
		{
		  [self _failOutRmc: ctxt.encoder];
		}
	      op = [self _makeOutRmc: ctxt.seq generate: 0 reply: NO];
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
	  [self removeLocalObject: ((ProxyStruct*)prox)->_object];
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
      counter = NSMapGet (targetToCounter, (void*)target);
      if (counter == nil)
	{
	  /*
	   *	If the target doesn't exist for any connection, but still
	   *	persists in the cache (ie it was recently released) then
	   *	we move it back from the cache to the main maps so we can
	   *	retain it on this connection.
	   */
	  counter = NSMapGet (targetToCached, (void*)target);
	  if (counter)
	    {
	      unsigned	t = counter->target;
	      id	o = counter->object;

	      NSMapInsert(objectToCounter, (void*)o, counter);
	      NSMapInsert(targetToCounter, (void*)t, counter);
	      NSMapRemove(targetToCached, (void*)t);
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
  o = ((ProxyStruct*)p)->_object;

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
  NSPortCoder		*rmc;
  GSIMapNode		node;
  NSDate		*timeout_date = nil;
  NSTimeInterval	delay_interval = 0.0001;
  NSDate		*delay_date = nil;
  NSRunLoop		*runLoop = [runLoopClass currentRunLoop];

  if (debug_connection > 5)
    NSLog(@"Waiting for reply sequence %d on %x:%x",
      sn, self, [NSThread currentThread]);
  M_LOCK(_queueGate);
  while ((node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn)) != 0
    && node->value.obj == dummyObject)
    {
      M_UNLOCK(_queueGate);
      if (timeout_date == nil)
	{
	  timeout_date = [dateClass allocWithZone: NSDefaultMallocZone()];
	  timeout_date
	    = [timeout_date initWithTimeIntervalSinceNow: _replyTimeout];
	}
      if (_multipleThreads == YES)
	{
	  NSDate	*limit_date;

	  /*
	   * If multiple threads are using this connections, another
	   * thread may read the reply we are waiting for - so we must
	   * break out of the runloop frequently to check.  We do this
	   * by setting a small delay and increasing it each time round
	   * so that this semi-busy wait doesn't consume too much
	   * processor time (I hope).
	   */
	  RELEASE(delay_date);
	  delay_date = [dateClass allocWithZone: NSDefaultMallocZone()];
	  delay_interval *= 2;
	  delay_date
	    = [delay_date initWithTimeIntervalSinceNow: delay_interval];

	  /*
	   * We must not set a delay date that is further in the future
	   * than the timeout date for the response to be returned.
	   */
	  if ([timeout_date earlierDate: delay_date] == timeout_date)
	    {
	      limit_date = timeout_date;
	    }
	  else
	    {
	      limit_date = delay_date;
	    }

	  /*
	   * If the runloop returns without having done anything, AND we
	   * were waiting for the final timeout, then we must break out
	   * of the loop.
	   */
	  if ([runLoop runMode: NSConnectionReplyMode
		    beforeDate: limit_date] == NO)
	    {
	      if (limit_date == timeout_date)
		{
		  M_LOCK(_queueGate);
		  node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn);
		  break;
		}
	    }
	}
      else
	{
	  /*
	   * Normal operation - wait for data to be recieved or for a timeout.
	   */
	  if ([runLoop runMode: NSConnectionReplyMode
		    beforeDate: timeout_date] == NO)
	    {
	      M_LOCK(_queueGate);
	      node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn);
	      break;
	    }
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
  TEST_RELEASE(delay_date);
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
  NSDebugMLLog(@"NSConnection", @"Consuming reply RMC %d on %x", sn, self);
  return rmc;
}

- (void) _doneInReply: (NSPortCoder*)c
{
  [self _doneInRmc: c];
  _repInCount++;
}

- (void) _doneInRmc: (NSPortCoder*)c
{
  M_LOCK(_refGate);
  if (debug_connection > 5)
    {
      NSLog(@"done rmc 0x%x", c);
    }
  if (cacheCoders == YES && _cachedDecoders != nil)
    {
      [_cachedDecoders addObject: c];
    }
  [c dispatch];	/* Tell NSPortCoder to release the connection.	*/
  RELEASE(c);
  M_UNLOCK(_refGate);
}

/*
 * This method called if an exception occurred, and we don't know
 * whether we have already tidied the NSPortCoder object up or not.
 */
- (void) _failInRmc: (NSPortCoder*)c
{
  M_LOCK(_refGate);
  if (cacheCoders == YES && _cachedDecoders != nil
    && [_cachedDecoders indexOfObjectIdenticalTo: c] == NSNotFound)
    {
      [_cachedDecoders addObject: c];
    }
  if (debug_connection > 5)
    {
      NSLog(@"fail rmc 0x%x", c);
    }
  [c dispatch];	/* Tell NSPortCoder to release the connection.	*/
  RELEASE(c);
  M_UNLOCK(_refGate);
}

/*
 * This method called if an exception occurred, and we don't know
 * whether we have already tidied the NSPortCoder object up or not.
 */
- (void) _failOutRmc: (NSPortCoder*)c
{
  M_LOCK(_refGate);
  if (cacheCoders == YES && _cachedEncoders != nil
    && [_cachedEncoders indexOfObjectIdenticalTo: c] == NSNotFound)
    {
      [_cachedEncoders addObject: c];
    }
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
  if (cacheCoders == YES && _cachedDecoders != nil
    && (count = [_cachedDecoders count]) > 0)
    {
      coder = [_cachedDecoders objectAtIndex: --count];
      RETAIN(coder);
      [_cachedDecoders removeObjectAtIndex: count];
    }
  else
    {
      coder = [recvCoderClass allocWithZone: NSDefaultMallocZone()];
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
  if (cacheCoders == YES && _cachedEncoders != nil
    && (count = [_cachedEncoders count]) > 0)
    {
      coder = [_cachedEncoders objectAtIndex: --count];
      RETAIN(coder);
      [_cachedEncoders removeObjectAtIndex: count];
    }
  else
    {
      coder = [sendCoderClass allocWithZone: NSDefaultMallocZone()];
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

  if (debug_connection > 5)
    NSLog(@"Sending %@ on %x", stringFromMsgType(msgid), self);

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
  if (cacheCoders == YES && _cachedEncoders != nil)
    {
      [_cachedEncoders addObject: c];
    }
  [c dispatch];	/* Tell NSPortCoder to release the connection.	*/
  RELEASE(c);
  M_UNLOCK(_refGate);

  if (sent == NO)
    {
      NSString	*text = stringFromMsgType(msgid);

      if ([_sendPort isValid] == NO)
	{
	  text = [text stringByAppendingFormat: @" - port was invalidated"];
	}
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
- (void) addLocalObject: (NSDistantObject*)anObj
{
  id			object;
  unsigned		target;
  GSLocalCounter	*counter;
  GSIMapNode    	node;

  M_LOCK(_proxiesGate);
  M_LOCK(global_proxies_gate);
  NSParameterAssert (_isValid);

  /*
   * Record the value in the _localObjects map, retaining it.
   */
  object = ((ProxyStruct*)anObj)->_object;
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)object);
  IF_NO_GC(RETAIN(anObj));
  if (node == 0)
    {
      GSIMapAddPair(_localObjects, (GSIMapKey)object, (GSIMapVal)anObj);
    }
  else
    {
      RELEASE(node->value.obj);
      node->value.obj = anObj;
    }

  /*
   *	Keep track of local objects accross all connections.
   */
  counter = NSMapGet(objectToCounter, (void*)object);
  if (counter)
    {
      counter->ref++;
      target = counter->target;
    }
  else
    {
      counter = [localCounterClass newWithObject: object];
      target = counter->target;
      NSMapInsert(objectToCounter, (void*)object, counter);
      NSMapInsert(targetToCounter, (void*)target, counter);
      RELEASE(counter);
    }
  ((ProxyStruct*)anObj)->_handle = target;
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
  target = ((ProxyStruct*)prox)->_handle;

  /*
   *	If all references to a local proxy have gone - remove the
   *	global reference as well.
   */
  counter = NSMapGet(objectToCounter, (void*)anObj);
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
	      NSMapInsert(targetToCached, (void*)target, item);
	      RELEASE(item);
	      if (debug_connection > 3)
		NSLog(@"placed local object (0x%x) target (0x%x) in cache",
			    (gsaddr)anObj, target);
	    }
	  NSMapRemove(objectToCounter, (void*)anObj);
	  NSMapRemove(targetToCounter, (void*)target);
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
      if (_receivePort != nil && _isValid == YES && number > 0)
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
	  [self _doneInRmc: ip];
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
  M_LOCK(_proxiesGate);
  if (_isValid == YES)
    {
      unsigned		target;
      GSIMapNode	node;

      target = ((ProxyStruct*)aProxy)->_handle;
      node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);
      if (node != 0)
	{
	  RELEASE(node->value.obj);
	  GSIMapRemoveKey(_remoteProxies, (GSIMapKey)target);
	}
      /*
       * Tell the remote application that we have removed our proxy and
       * it can release it's local object.
       */
      [self _release_targets: &target count: 1];
    }
  M_UNLOCK(_proxiesGate);
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
  unsigned	target;
  GSIMapNode	node;

  M_LOCK(_proxiesGate);
  NSParameterAssert(_isValid);
  NSParameterAssert(aProxy->isa == distantObjectClass);
  NSParameterAssert([aProxy connectionForProxy] == self);
  target = ((ProxyStruct*)aProxy)->_handle;
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
  ret = NSMapGet(targetToCounter, (void*)target);
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

