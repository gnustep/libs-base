/** Implementation of connection object for remote object messaging
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSConnection class reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSLock.h"

/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_RETAIN_KEY(M, X)	
#define	GSI_MAP_RELEASE_KEY(M, X)	
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_HASH(M, X)	((X).uint ^ ((X).uint >> 3))
#define	GSI_MAP_EQUAL(M, X,Y)	((X).ptr == (Y).ptr)
#define	GSI_MAP_NOCLEAN	1

#include "GNUstepBase/GSIMap.h"

#define	_IN_CONNECTION_M
#include "Foundation/NSConnection.h"
#undef	_IN_CONNECTION_M

#include <mframe.h>
#if defined(USE_LIBFFI)
#include "cifframe.h"
#elif defined(USE_FFCALL)
#include "callframe.h"
#endif

#include "Foundation/NSPortCoder.h"
#include "GNUstepBase/DistributedObjects.h"

#include "Foundation/NSHashTable.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSData.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSString.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSException.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSPort.h"
#include "Foundation/NSPortMessage.h"
#include "Foundation/NSPortNameServer.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSDebug.h"
#include "GSInvocation.h"
#include "GSPortPrivate.h"

@interface	NSPortCoder (Private)
- (NSMutableArray*) _components;
@end
@interface	NSPortMessage (Private)
- (NSMutableArray*) _components;
@end

@interface NSConnection (GNUstepExtensions) <GCFinalization>
- (void) gcFinalize;
- (retval_t) forwardForProxy: (NSDistantObject*)object 
		    selector: (SEL)sel 
		    argFrame: (arglist_t)argframe;
- (void) forwardInvocation: (NSInvocation *)inv 
		  forProxy: (NSDistantObject*)object;
- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target;
@end

extern NSRunLoop	*GSRunLoopForThread(NSThread*);

#define F_LOCK(X) {NSDebugFLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define F_UNLOCK(X) {NSDebugFLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}
#define M_LOCK(X) {NSDebugMLLog(@"GSConnection",@"Lock %@",X);[X lock];}
#define M_UNLOCK(X) {NSDebugMLLog(@"GSConnection",@"Unlock %@",X);[X unlock];}

NSString * const NSFailedAuthenticationException =
  @"NSFailedAuthenticationExceptions";
NSString * const NSObjectInaccessibleException =
  @"NSObjectInaccessibleException";

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
 * CachedLocalObject is a trivial class to keep track of local
 * proxies which have been removed from their connections and
 * need to persist a while in case another process needs them.
 */
@interface	CachedLocalObject : NSObject
{
  NSDistantObject	*obj;
  int			time;
}
- (BOOL) countdown;
- (NSDistantObject*) obj;
+ (id) newWithObject: (NSDistantObject*)o time: (int)t;
@end

@implementation	CachedLocalObject

+ (id) newWithObject: (NSDistantObject*)o time: (int)t
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
  GSNOSUPERDEALLOC;
}

- (BOOL) countdown
{
  if (time-- > 0)
    return YES;
  return NO;
}

- (NSDistantObject*) obj
{
  return obj;
}

@end



@interface NSConnection (Private)
- (void) handlePortMessage: (NSPortMessage*)msg;
- (void) _runInNewThread;
+ (void) setDebug: (int)val;

- (void) addLocalObject: (NSDistantObject*)anObj;
- (void) removeLocalObject: (NSDistantObject*)anObj;

- (void) _doneInReply: (NSPortCoder*)c;
- (void) _doneInRmc: (NSPortCoder*)c;
- (void) _failInRmc: (NSPortCoder*)c;
- (void) _failOutRmc: (NSPortCoder*)c;
- (NSPortCoder*) _getReplyRmc: (int)sn;
- (NSPortCoder*) _makeInRmc: (NSMutableArray*)components;
- (NSPortCoder*) _makeOutRmc: (int)sequence generate: (int*)sno reply: (BOOL)f;
- (void) _portIsInvalid: (NSNotification*)notification;
- (void) _sendOutRmc: (NSPortCoder*)c type: (int)msgid;

- (void) _service_forwardForProxy: (NSPortCoder*)rmc;
- (void) _service_release: (NSPortCoder*)rmc;
- (void) _service_retain: (NSPortCoder*)rmc;
- (void) _service_rootObject: (NSPortCoder*)rmc;
- (void) _service_shutdown: (NSPortCoder*)rmc;
- (void) _service_typeForSelector: (NSPortCoder*)rmc;
- (void) _shutdown;
+ (void) _threadWillExit: (NSNotification*)notification;
@end

#define _proxiesGate _refGate
#define _queueGate _refGate


/* class defaults */
static NSTimer		*timer = nil;

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
  NSEndHashTableEnumeration(&enumerator);
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
  rootObject = (id)NSMapGet(root_object_map, (void*)(uintptr_t)aPort);
  F_UNLOCK(root_object_map_gate);
  return rootObject;
}

/* Pass nil to remove any reference keyed by aPort. */
static void
setRootObjectForInPort(id anObj, NSPort *aPort)
{
  id	oldRootObject;

  F_LOCK(root_object_map_gate);
  oldRootObject = (id)NSMapGet(root_object_map, (void*)(uintptr_t)aPort);
  if (oldRootObject != anObj)
    {
      if (anObj != nil)
	{
	  NSMapInsert(root_object_map, (void*)(uintptr_t)aPort,
	    (void*)(uintptr_t)anObj);
	}
      else /* anObj == nil && oldRootObject != nil */
	{
	  NSMapRemove(root_object_map, (void*)(uintptr_t)aPort);
	}
    }
  F_UNLOCK(root_object_map_gate);
}

static NSMapTable *targetToCached = NULL;
static NSLock	*cached_proxies_gate = nil;




/**
 * NSConnection objects are used to manage communications between
 * objects in different processes, in different machines, or in
 * different threads.
 */
@implementation NSConnection

/**
 * Returns an array containing all the NSConnection objects known to
 * the system. These connections will be valid at the time that the
 * array was created, but may be invalidated by other threads
 * before you get to examine the array.
 */
+ (NSArray*) allConnections
{
  NSArray	*a;

  M_LOCK(connection_table_gate);
  a = NSAllHashTableObjects(connection_table);
  M_UNLOCK(connection_table_gate);
  return a;
}

/**
 * Returns a connection initialised using -initWithReceivePort:sendPort:<br />
 * Both ports must be of the same type.
 */
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

/**
 * <p>Returns an NSConnection object whose send port is that of the
 * NSConnection registered under the name n on the host h
 * </p>
 * <p>This method calls +connectionWithRegisteredName:host:usingNameServer:
 * using the default system name server.
 * </p>
 * <p>Use [NSSocketPortNameServer] for connections to remote hosts.
 * </p>
 */
+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
					  host: (NSString*)h
{
  NSPortNameServer	*s;

  s = [NSPortNameServer systemDefaultPortNameServer];
  return [self connectionWithRegisteredName: n
				       host: h
			    usingNameServer: s];
}

/**
 * <p>
 *   Returns an NSConnection object whose send port is that of the
 *   NSConnection registered under <em>name</em> on <em>host</em>.
 * </p>
 * <p>
 *   The nameserver <em>server</em> is used to look up the send
 *   port to be used for the connection.<br />
 *   Use [NSSocketPortNameServer+sharedInstance]
 *   for connections to remote hosts.
 * </p>
 * <p>
 *   If <em>host</em> is <code>nil</code> or an empty string,
 *   the host is taken to be the local machine.
 *   If it is an asterisk ('*') then the nameserver checks all
 *   hosts on the local subnet (unless the nameserver is one
 *   that only manages local ports).
 *   In the GNUstep implementation, the local host is searched before
 *   any other hosts.
 * </p>
 * <p>
 *   If no NSConnection can be found for <em>name</em> and
 *   <em>host</em>host, the method returns <code>nil</code>.
 * </p>
 * <p>
 *   The returned object has the default NSConnection of the
 *   current thread as its parent (it has the same receive port
 *   as the default connection).
 * </p>
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
	  else if (![recvPort isMemberOfClass: [sendPort class]])
	    {
	      /*
	      We can only use the port of the default connection for
	      connections using the same port class. For other port classes,
	      we must use a receiving port of the same class as the sending
	      port, so we allocate one here.
	      */
	      recvPort = [[sendPort class] port];
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

/**
 * Return the current conversation ... not implemented in GNUstep
 */
+ (id) currentConversation
{
  return nil;
}

/**
 * Returns the default connection for a thread.<br />
 * Creates a new instance if necessary.<br />
 * The default connection has a single NSPort object used for
 * both sending and receiving - this it can't be used to
 * connect to a remote process, but can be used to vend objects.<br />
 * Possible problem - if the connection is invalidated, it won't be
 * cleaned up until this thread calls this method again.  The connection
 * and it's ports could hang around for a very long time.
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
      NSNotificationCenter	*nc;

      connectionClass = self;
      dateClass = [NSDate class];
      distantObjectClass = [NSDistantObject class];
      sendCoderClass = [NSPortCoder class];
      recvCoderClass = [NSPortCoder class];
      runLoopClass = [NSRunLoop class];

      dummyObject = [NSObject new];

      connection_table =
	NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 0);

      targetToCached =
	NSCreateMapTable(NSIntMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);

      root_object_map =
	NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);

      if (connection_table_gate == nil)
	{
	  connection_table_gate = [GSLazyRecursiveLock new];
	}
      if (cached_proxies_gate == nil)
	{
	  cached_proxies_gate = [GSLazyLock new];
	}
      if (root_object_map_gate == nil)
	{
	  root_object_map_gate = [GSLazyLock new];
	}

      /*
       * When any thread exits, we must check to see if we are using its
       * runloop, and remove ourselves from it if necessary.
       */
      nc = [NSNotificationCenter defaultCenter];
      [nc addObserver: self
	     selector: @selector(_threadWillExit:)
		 name: NSThreadWillExitNotification
	       object: nil];
    }
}

/**
 * Undocumented feature for compatibility with OPENSTEP/MacOS-X
 * +new returns the default connection.
 */
+ (id) new
{
  return RETAIN([self defaultConnection]);
}

/**
 * This method calls
 * +rootProxyForConnectionWithRegisteredName:host:usingNameServer:
 * to return a proxy for a root object on the remote connection with
 * the send port registered under name n on host h.
 */
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

/**
 * This method calls
 * +connectionWithRegisteredName:host:usingNameServer:
 * to get a connection, then sends it a -rootProxy message to get
 * a proxy for the root object being vended by the remote connection.
 * Returns the proxy or nil if it couldn't find a connection or if
 * the root object for the connection has not been set.<br />
 * Use [NSSocketPortNameServer+sharedInstance]
 * for connections to remote hosts.
 */
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

  M_LOCK(cached_proxies_gate);
  cached_locals = NSAllMapTableValues(targetToCached);
  for (i = [cached_locals count]; i > 0; i--)
    {
      CachedLocalObject *item = [cached_locals objectAtIndex: i-1];

      if ([item countdown] == NO)
	{
	  NSDistantObject	*obj = [item obj];

	  NSMapRemove(targetToCached,
	    (void*)(uintptr_t)((ProxyStruct*)obj)->_handle);
	}
    }
  if ([cached_locals count] == 0)
    {
      [t invalidate];
      timer = nil;
    }
  M_UNLOCK(cached_proxies_gate);
}

/**
 * Adds mode to the run loop modes that the NSConnection
 * will listen to for incoming messages.
 */
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

	      [_receivePort addConnection: self toRunLoop: loop forMode: mode];
	    }
	  [_requestModes addObject: mode];
	}
    }
  M_UNLOCK(_refGate);
}

/**
 * Adds loop to the set of run loops that the NSConnection
 * will listen to for incoming messages.
 */
- (void) addRunLoop: (NSRunLoop*)loop
{
  M_LOCK(_refGate);
  if ([self isValid] == YES)
    {
      if ([_runLoops indexOfObjectIdenticalTo: loop] == NSNotFound)
	{
	  unsigned		c = [_requestModes count];

	  while (c-- > 0)
	    {
	      NSString	*mode = [_requestModes objectAtIndex: c];

	      [_receivePort addConnection: self toRunLoop: loop forMode: mode];
	    }
	  [_runLoops addObject: loop];
	}
    }
  M_UNLOCK(_refGate);
}

- (void) dealloc
{
  if (debug_connection)
    NSLog(@"deallocating %@", self);
  [self gcFinalize];
  [super dealloc];
}

/**
 * Returns the delegate of the NSConnection.
 */
- (id) delegate
{
  return GS_GC_UNHIDE(_delegate);
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"%@ recv: 0x%x send 0x%x",
    [super description], (uintptr_t)[self receivePort], (uintptr_t)[self sendPort]];
}

/**
 * Sets the NSConnection configuration so that multiple threads may
 * use the connection to send requests to the remote connection.<br />
 * This option is inherited by child connections.<br />
 * NB. A connection with multiple threads enabled will run slower than
 * a normal connection.
 */
- (void) enableMultipleThreads
{
  _multipleThreads = YES;
}

/**
 * Returns YES if the NSConnection is configured to
 * handle remote messages atomically, NO otherwise.<br />
 * This option is inherited by child connections.
 */
- (BOOL) independentConversationQueueing
{
  return _independentQueueing;
}

/**
 * Return a connection able to act as a server receive incoming requests.
 */
- (id) init
{
  NSPort	*port = [NSPort port];

  self = [self initWithReceivePort: port sendPort: nil];
  return self;
}

/** <init />
 * Initialises an NSConnection with the receive port r and the
 * send port s.<br />
 * Behavior varies with the port values as follows -
 * <deflist>
 *   <term>r is <code>nil</code></term>
 *   <desc>
 *     The NSConnection is released and the method returns
 *     <code>nil</code>.
 *   </desc>
 *   <term>s is <code>nil</code></term>
 *   <desc>
 *     The NSConnection uses r as the send port as
 *     well as the receive port.
 *   </desc>
 *   <term>s is the same as r</term>
 *   <desc>
 *     The NSConnection is usable only for vending objects.
 *   </desc>
 *   <term>A connection with the same ports exists</term>
 *   <desc>
 *     The new connection is released and the old connection
 *     is retained and returned.
 *   </desc>
 *   <term>A connection with the same ports (swapped) exists</term>
 *   <desc>
 *     The new connection is initialised as normal, and will
 *     communicate with the old connection.
 *   </desc>
 * </deflist>
 * <p>
 *   If a connection exists whose send and receive ports are
 *   both the same as the new connections receive port, that
 *   existing connection is deemed to be the parent of the
 *   new connection.  The new connection inherits configuration
 *   information from the parent, and the delegate of the
 *   parent has a chance to adjust the configuration of the
 *   new connection or veto its creation.
 *   <br/>
 *   NSConnectionDidInitializeNotification is posted once a new
 *   connection is initialised.
 * </p>
 */
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
	  NSLog(@"Found existing connection (%@) for \n\t%@\n\t%@",
	    conn, r, s);
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
      NSLog(@"Initialising new connection with parent %@, %@\n  "
	@"Send: %@\n  Recv: %@", parent, self, s, r);
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
  _refGate = [GSLazyRecursiveLock new];

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
      _replyTimeout = 1.0E12;
      _requestTimeout = 1.0E12;
      /*
       * Set up request modes array and make sure the receiving port
       * is added to the run loop to get data.
       */
      loop = GSRunLoopForThread(nil);
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
    {
      self = [del connection: parent didConnect: self];
    }

  nCenter = [NSNotificationCenter defaultCenter];
  /*
   * Register ourselves for invalidation notification when the
   * ports become invalid.
   */
  [nCenter addObserver: self
	      selector: @selector(_portIsInvalid:)
		  name: NSPortDidBecomeInvalidNotification
		object: r];
  if (s != nil)
    {
      [nCenter addObserver: self
		  selector: @selector(_portIsInvalid:)
		      name: NSPortDidBecomeInvalidNotification
		    object: s];
    }

  /* In order that connections may be deallocated - there is an
     implementation of [-release] to automatically remove the connection
     from this array when it is the only thing retaining it. */
  NSHashInsert(connection_table, (void*)self);
  M_UNLOCK(connection_table_gate);

  [nCenter postNotificationName: NSConnectionDidInitializeNotification
			 object: self];

  return self;
}

/**
 * Marks the receiving NSConnection as invalid.
 * <br />
 * Removes the NSConnections ports from any run loops.
 * <br />
 * Posts an NSConnectionDidDieNotification.
 * <br />
 * Invalidates all remote objects and local proxies.
 */
- (void) invalidate
{
  M_LOCK(_refGate);
  if (_isValid == NO)
    {
      M_UNLOCK(_refGate);
      return;
    }
  if (_shuttingDown == NO)
    {
      _shuttingDown = YES;
      /*
       * Not invalidated as a result of a shutdown from the other end,
       * so tell the other end it must shut down.
       */
      //[self _shutdown];
    }
  _isValid = NO;
  M_LOCK(connection_table_gate);
  NSHashRemove(connection_table, self);
  M_UNLOCK(connection_table_gate);

  M_UNLOCK(_refGate);

  /*
   * Don't need notifications any more - so remove self as observer.
   */
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  /*
   * Make sure we are not registered.
   */
#if	!defined(__MINGW32__)
  if ([_receivePort isKindOfClass: [NSMessagePort class]])
    {
      [self registerName: nil
	  withNameServer: [NSMessagePortNameServer sharedInstance]];
    }
  else
#endif
  if ([_receivePort isKindOfClass: [NSSocketPort class]])
    {
      [self registerName: nil
	  withNameServer: [NSSocketPortNameServer sharedInstance]];
    }
  else
    {
      [self registerName: nil];
    }

  /*
   * Withdraw from run loops.
   */
  [self setRequestMode: nil];

  RETAIN(self);

  if (debug_connection)
    {
      NSLog(@"Invalidating connection %@", self);
    }
  /*
   * We need to notify any watchers of our death - but if we are already
   * in the deallocation process, we can't have a notification retaining
   * and autoreleasing us later once we are deallocated - so we do the
   * notification with a local autorelease pool to ensure that any release
   * is done before the deallocation completes.
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
      NSMutableArray		*targets;
      unsigned	 		i = _localTargets->nodeCount;
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
	  [self removeLocalObject: [targets objectAtIndex: i]];
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

  /*
   * If we are invalidated, we shouldn't be receiving any event and
   * should not need to be in any run loops.
   */
  while ([_runLoops count] > 0)
    {
      [self removeRunLoop: [_runLoops lastObject]];
    }

  /*
   * Invalidate the current conversation so we don't leak.
   */
  if ([_sendPort isValid] == YES)
    {
      [[_sendPort conversation: _receivePort] invalidate];
    }

  RELEASE(self);
}

/**
 * Returns YES if the connection is valid, NO otherwise.
 * A connection is valid until it has been sent an -invalidate message.
 */
- (BOOL) isValid
{
  return _isValid;
}

/**
 * Returns an array of all the local objects that have proxies at the
 * remote end of the connection because they have been sent over the
 * connection and not yet released by the far end.
 */
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

/**
 * Returns YES if the connection permits multiple threads to use it to
 * send requests, NO otherwise.<br />
 * See the -enableMultipleThreads method.
 */
- (BOOL) multipleThreadsEnabled
{
  return _multipleThreads;
}

/**
 * Returns the NSPort object on which incoming messages are received.
 */
- (NSPort*) receivePort
{
  return _receivePort;
}

/**
 * Simply invokes -registerName:withNameServer:
 * passing it the default system nameserver.
 */
- (BOOL) registerName: (NSString*)name
{
  NSPortNameServer	*svr = [NSPortNameServer systemDefaultPortNameServer];

  return [self registerName: name withNameServer: svr];
}

/**
 * Registers the receive port of the NSConnection as name and
 * unregisters the previous value (if any).<br />
 * Returns YES on success, NO on failure.<br />
 * On failure, the connection remains registered under the
 * previous name.<br />
 * Supply nil as name to unregister the NSConnection.
 */
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
  /* We lock the connection table while checking, to prevent
   * another thread from grabbing this connection while we are
   * checking it.
   * If we are going to deallocate the object, we first remove
   * it from the table so that no other thread will find it
   * and try to use it while it is being deallocated.
   */
  M_LOCK(connection_table_gate);
  if (NSDecrementExtraRefCountWasZero(self))
    {
      NSHashRemove(connection_table, self);
      M_UNLOCK(connection_table_gate);
      [self dealloc];
    }
  else
    {
      M_UNLOCK(connection_table_gate);
    }
}

/**
 * Returns an array of proxies to all the remote objects known to
 * the NSConnection.
 */
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

/**
 * Removes mode from the run loop modes used to receive incoming messages.
 */
- (void) removeRequestMode: (NSString*)mode
{
  M_LOCK(_refGate);
  if (_requestModes != nil && [_requestModes containsObject: mode])
    {
      unsigned	c = [_runLoops count];

      while (c-- > 0)
	{
	  NSRunLoop	*loop = [_runLoops objectAtIndex: c];

	  [_receivePort removeConnection: self
			     fromRunLoop: loop
				 forMode: mode];
	}
      [_requestModes removeObject: mode];
    }
  M_UNLOCK(_refGate);
}

/**
 * Removes loop from the run loops used to receive incoming messages.
 */
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

	      [_receivePort removeConnection: self
				 fromRunLoop: [_runLoops objectAtIndex: pos]
				     forMode: mode];
	    }
	  [_runLoops removeObjectAtIndex: pos];
	}
    }
  M_UNLOCK(_refGate);
}

/**
 * Returns the timeout interval used when waiting for a reply to
 * a request sent on the NSConnection.  This value is inherited
 * from the parent connection or may be set using the -setReplyTimeout:
 * method.<br />
 * The default value is the maximum delay (effectively infinite).
 */
- (NSTimeInterval) replyTimeout
{
  return _replyTimeout;
}

/**
 * Returns an array of all the run loop modes that the NSConnection
 * uses when waiting for an incoming request.
 */
- (NSArray*) requestModes
{
  NSArray	*c;

  M_LOCK(_refGate);
  c = AUTORELEASE([_requestModes copy]);
  M_UNLOCK(_refGate);
  return c;
}

/**
 * Returns the timeout interval used when trying to send a request
 * on the NSConnection.  This value is inherited from the parent
 * connection or may be set using the -setRequestTimeout: method.<br />
 * The default value is the maximum delay (effectively infinite).
 */
- (NSTimeInterval) requestTimeout
{
  return _requestTimeout;
}

/**
 * Returns the object that is made available by this connection
 * or by its parent (the object is associated with the receive port).<br />
 * Returns nil if no root object has been set.
 */
- (id) rootObject
{
  return rootObjectForInPort(_receivePort);
}

/**
 * Returns the proxy for the root object of the remote NSConnection.<br />
 * Generally you will wish to call [NSDistantObject-setProtocolForProxy:]
 * immediately after obtaining such a root proxy.
 */
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

/**
 * Removes the NSConnection from the current threads default
 * run loop, then creates a new thread and runs the NSConnection in it.
 */
- (void) runInNewThread
{
  [self removeRunLoop: GSRunLoopForThread(nil)];
  [NSThread detachNewThreadSelector: @selector(_runInNewThread)
			   toTarget: self
			 withObject: nil];
}

/**
 * Returns the port on which the NSConnection sends messages.
 */
- (NSPort*) sendPort
{
  return _sendPort;
}

/**
 * Sets the NSConnection's delegate (without retaining it).<br />
 * The delegate is able to control some of the NSConnection's
 * behavior by implementing methods in an informal protocol.
 */
- (void) setDelegate: (id)anObj
{
  _delegate = GS_GC_HIDE(anObj);
  _authenticateIn =
    [anObj respondsToSelector: @selector(authenticateComponents:withData:)];
  _authenticateOut =
    [anObj respondsToSelector: @selector(authenticationDataForComponents:)];
}

/**
 * Sets whether or not the NSConnection should handle requests
 * arriving from the remote NSConnection atomically.<br />
 * By default, this is set to NO ... if set to YES then any messages
 * arriving while one message is being dealt with, will be queued.<br />
 * NB. careful - use of this option can cause deadlocks.
 */
- (void) setIndependentConversationQueueing: (BOOL)flag
{
  _independentQueueing = flag;
}

/**
 * Sets the time interval that the NSConnection will wait for a
 * reply for one of its requests before raising an
 * NSPortTimeoutException.<br />
 * NB. In GNUstep you may also get such an exception if the connection
 * becomes invalidated while waiting for a reply to a request.
 */
- (void) setReplyTimeout: (NSTimeInterval)to
{
  if (to <= 0.0 || to > 1.0E12) to = 1.0E12;
  _replyTimeout = to;
}

/**
 * Sets the runloop mode in which requests will be sent to the remote
 * end of the connection.  Normally this is NSDefaultRunloopMode
 */
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

/**
 * Sets the time interval that the NSConnection will wait to send
 * one of its requests before raising an NSPortTimeoutException.
 */
- (void) setRequestTimeout: (NSTimeInterval)to
{
  if (to <= 0.0 || to > 1.0E12) to = 1.0E12;
  _requestTimeout = to;
}

/**
 * Sets the root object that is vended by the connection.
 */
- (void) setRootObject: (id)anObj
{
  setRootObjectForInPort(anObj, _receivePort);
}

/**
 * Returns an object containing various statistics for the
 * NSConnection.
 * <br />
 * On GNUstep the dictionary contains -
 * <deflist>
 *   <term>NSConnectionRepliesReceived</term>
 *   <desc>
 *     The number of messages replied to by the remote NSConnection.
 *   </desc>
 *   <term>NSConnectionRepliesSent</term>
 *   <desc>
 *     The number of replies sent to the remote NSConnection.
 *   </desc>
 *   <term>NSConnectionRequestsReceived</term>
 *   <desc>
 *     The number of messages received from the remote NSConnection.
 *   </desc>
 *   <term>NSConnectionRequestsSent</term>
 *   <desc>
 *     The number of messages sent to the remote NSConnection.
 *   </desc>
 *   <term>NSConnectionLocalCount</term>
 *   <desc>
 *     The number of local objects currently vended.
 *   </desc>
 *   <term>NSConnectionProxyCount</term>
 *   <desc>
 *     The number of remote objects currently in use.
 *   </desc>
 * </deflist>
 */
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

  GSOnceMLog(@"This method is deprecated, use standard initialisation");

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
    NSLog(@"finalising %@", self);

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
	  if (node->value.obj != dummyObject)
	    {
	      RELEASE(node->value.obj);
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
	  id exc = [coder decodeObject];

	  ctxt->decoder = nil;
	  [ctxt->connection _doneInReply: coder];
	  if (ctxt->datToFree != 0)
	    {
	      NSZoneFree(NSDefaultMallocZone(), ctxt->datToFree);
	      ctxt->datToFree = 0;
	    }
	  [exc raise];
	}
    }
  if (*type == _C_ID)
    {
      *(id*)ctxt->datum = [coder decodeObject];
    }
  else
    {
      [coder decodeValueOfObjCType: type at: ctxt->datum];
    }
}

static void retEncoder (DOContext *ctxt)
{
  switch (*ctxt->type)
    {
    case _C_ID:
      if (ctxt->flags & _F_BYCOPY)
	{
	  [ctxt->encoder encodeBycopyObject: *(id*)ctxt->datum];
	}
#ifdef	_F_BYREF
      else if (ctxt->flags & _F_BYREF)
	{
	  [ctxt->encoder encodeByrefObject: *(id*)ctxt->datum];
	}
#endif
      else
	{
	  [ctxt->encoder encodeObject: *(id*)ctxt->datum];
	}
      break;
    default:
      [ctxt->encoder encodeValueOfObjCType: ctxt->type at: ctxt->datum];
    }
}

/*
 * NSDistantObject's -forward:: method calls this to send the message
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
  NSThread	*thread = GSCurrentThread();
  NSRunLoop	*runLoop = GSRunLoopForThread(thread);

  memset(&ctxt, 0, sizeof(ctxt));
  ctxt.connection = self;

  /* Encode the method on an RMC, and send it. */

  NSParameterAssert (_isValid);

  if ([_runLoops indexOfObjectIdenticalTo: runLoop] == NSNotFound)
    {
      if (_multipleThreads == NO)
	{
	  [NSException raise: NSObjectInaccessibleException
		      format: @"Forwarding message in wrong thread"];
	}
      else
	{
	  [self addRunLoop: runLoop];
	}
    }

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
	  sel_register_typed_name(GSNameFromSelector(sel), type);
	}
    }
#endif
  NSParameterAssert(type);
  NSParameterAssert(*type);

  ctxt.encoder = [self _makeOutRmc: 0 generate: (int*)&ctxt.seq reply: YES];

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
  NSDebugMLLog(@"NSConnection", @"Sent message (%s) to 0x%x",
    GSNameFromSelector(sel), (uintptr_t)self);

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
- (void) forwardInvocation: (NSInvocation*)inv
		  forProxy: (NSDistantObject*)object
{
  NSPortCoder	*op;
  BOOL		outParams;
  BOOL		needsResponse;
  const char	*type;
  DOContext	ctxt;
  NSThread	*thread = GSCurrentThread();
  NSRunLoop	*runLoop = GSRunLoopForThread(thread);

  if ([_runLoops indexOfObjectIdenticalTo: runLoop] == NSNotFound)
    {
      if (_multipleThreads == NO)
	{
	  [NSException raise: NSObjectInaccessibleException
		      format: @"Forwarding message in wrong thread"];
	}
      else
	{
	  [self addRunLoop: runLoop];
	}
    }

  /* Encode the method on an RMC, and send it. */

  NSParameterAssert (_isValid);

  /* get the method types from the selector */
  type = [[inv methodSignature] methodType];
  if (type == 0 || *type == '\0')
    {
      type = [[object methodSignatureForSelector: [inv selector]] methodType];
      if (type)
	{
	  sel_register_typed_name(GSNameFromSelector([inv selector]), type);
	}
    }
  NSParameterAssert(type);
  NSParameterAssert(*type);

  memset(&ctxt, 0, sizeof(ctxt));
  ctxt.connection = self;

  op = [self _makeOutRmc: 0 generate: (int*)&ctxt.seq reply: YES];

  if (debug_connection > 4)
    NSLog(@"building packet seq %d", ctxt.seq);

  [inv setTarget: object];
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
  NSDebugMLLog(@"NSConnection", @"Sent message to 0x%x", (uintptr_t)self);

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
#ifdef USE_LIBFFI
      cifframe_build_return (inv, type, outParams, retDecoder, &ctxt);
#elif defined(USE_FFCALL)
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
  NSData *data;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  op = [self _makeOutRmc: 0 generate: &seq_num reply: YES];
  [op encodeValueOfObjCType: ":" at: &sel];
  [op encodeValueOfObjCType: @encode(unsigned) at: &target];
  [self _sendOutRmc: op type: METHODTYPE_REQUEST];
  ip = [self _getReplyRmc: seq_num];
  [ip decodeValueOfObjCType: @encode(char*) at: &type];
  data = type ? [NSData dataWithBytes: type length: strlen(type)+1] : nil;
  [self _doneInRmc: ip];
  return (const char*)[data bytes];
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
  NSEndHashTableEnumeration(&enumerator);
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
      NSLog(@"  connection is %@", conn);
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
	    [conn _service_forwardForProxy: rmc];	// Catches exceptions
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
	    [conn _service_forwardForProxy: rmc];	// Catches exceptions
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
	      NSDebugMLLog(@"NSConnection", @"Ignoring reply RMC %d on %@",
		sequence, conn);
	      [self _doneInRmc: rmc];
	    }
	  else if (node->value.obj == dummyObject)
	    {
	      NSDebugMLLog(@"NSConnection", @"Saving reply RMC %d on %@",
		sequence, conn);
	      node->value.obj = rmc;
	    }
	  else
	    {
	      NSDebugMLLog(@"NSConnection", @"Replace reply RMC %d on %@",
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
  NSRunLoop	*loop = GSRunLoopForThread(nil);

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

  /*
   * We need this "dismiss" to happen here and not later so that Coder
   * "-awake..." methods will get sent before the method using the
   * objects is invoked.  We clear the 'decoder' field in the context to
   * show that it is no longer valid.
   */
  if (type == 0)
    {
      NSPortCoder	*coder = ctxt->decoder;

      ctxt->decoder = nil;
      [ctxt->connection _doneInRmc: coder];
      return;
    }

  /*
   * The coder may have an optimised method for decoding objects
   * so we use that one if we are expecting an object, otherwise
   * we use thegeneric method.
   */
  if (*type == _C_ID)
    {
      *(id*)ctxt->datum = [ctxt->decoder decodeObject];
    }
  else
    {
      [ctxt->decoder decodeValueOfObjCType: type at: ctxt->datum];
    }
}

static void callEncoder (DOContext *ctxt)
{
  const char		*type = ctxt->type;
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
      ctxt->encoder = [ctxt->connection _makeOutRmc: ctxt->seq
					   generate: 0
					      reply: NO];
      coder = ctxt->encoder;
      [coder encodeValueOfObjCType: @encode(BOOL) at: &is_exception];
    }

  if (*type == _C_ID)
    {
      int	flags = ctxt->flags;

      if (flags & _F_BYCOPY)
	{
	  [coder encodeBycopyObject: *(id*)ctxt->datum];
	}
#ifdef	_F_BYREF
      else if (flags & _F_BYREF)
	{
	  [coder encodeByrefObject: *(id*)ctxt->datum];
	}
#endif
      else
	{
	  [coder encodeObject: *(id*)ctxt->datum];
	}
    }
  else
    {
      [coder encodeValueOfObjCType: type at: ctxt->datum];
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
      NSThread	*thread = GSCurrentThread();
      NSRunLoop	*runLoop = GSRunLoopForThread(thread);

      NSParameterAssert (_isValid);
      if ([_runLoops indexOfObjectIdenticalTo: runLoop] == NSNotFound)
	{
	  if (_multipleThreads == YES)
	    {
	      [self addRunLoop: runLoop];
	    }
	  else
	    {
	      [NSException raise: NSObjectInaccessibleException
			  format: @"Message received in wrong thread"];
	    }
	}

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
	  NSLog(@"Handling message from %@", (uintptr_t)self);
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
      if (debug_connection > 3)
	NSLog(@"forwarding exception for (%@) - %@", self, localException);

      /* Send the exception back to the client. */
      if (_isValid == YES)
	{
	  BOOL is_exception = YES;

	  NS_DURING
	    {
	      NSPortCoder	*op;

	      if (ctxt.datToFree != 0)
		{
		  NSZoneFree(NSDefaultMallocZone(), ctxt.datToFree);
		  ctxt.datToFree = 0;
		}
	      if (ctxt.objToFree != nil)
		{
		  NSDeallocateObject(ctxt.objToFree);
		  ctxt.objToFree = nil;
		}
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
	    NSLog(@"releasing object with target (0x%x) on (%@) counter %d",
		target, self, ((ProxyStruct*)prox)->_counter);
#if 1
	  // FIXME thread safety
	  if (--(((ProxyStruct*)prox)->_counter) == 0)
	    {
	      [self removeLocalObject: prox];
	    }
#else
	  [self removeLocalObject: prox];
#endif
	}
      else if (debug_connection > 3)
	NSLog(@"releasing object with target (0x%x) on (%@) - nothing to do",
		target, self);
    }
  [self _doneInRmc: rmc];
}

- (void) _service_retain: (NSPortCoder*)rmc
{
  unsigned		target;
  NSPortCoder		*op;
  int			sequence;
  NSDistantObject	*local;
  NSString		*response = nil;

  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeOutRmc: sequence generate: 0 reply: NO];

  [rmc decodeValueOfObjCType: @encode(typeof(target)) at: &target];
  [self _doneInRmc: rmc];

  if (debug_connection > 3)
    NSLog(@"looking to retain local object with target (0x%x) on (%@)",
      target, self);

  M_LOCK(_proxiesGate);
  local = [self locateLocalTarget: target];
  if (local == nil)
    {
      response = @"target not found anywhere";
    }
  else
    {
      ((ProxyStruct*)local)->_counter++;	// Vended on connection.
    }
  M_UNLOCK(_proxiesGate);

  [op encodeObject: response];
  [self _sendOutRmc: op type: RETAIN_REPLY];
}

- (void) _shutdown
{
  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);
  NS_DURING
    {
      NSPortCoder	*op;
      int		sno;

      op = [self _makeOutRmc: 0 generate: &sno reply: NO];
      [self _sendOutRmc: op type: CONNECTION_SHUTDOWN];
    }
  NS_HANDLER
  NS_ENDHANDLER
}

- (void) _service_shutdown: (NSPortCoder*)rmc
{
  NSParameterAssert (_isValid);
  _shuttingDown = YES;		// Prevent shutdown being sent back to other end
  [self _doneInRmc: rmc];
  [self invalidate];
}

- (void) _service_typeForSelector: (NSPortCoder*)rmc
{
  NSPortCoder	*op;
  unsigned	target;
  NSDistantObject *p;
  int		sequence;
  id		o;
  SEL		sel;
  const char	*type;
  struct objc_method* m;

  NSParameterAssert(_receivePort);
  NSParameterAssert (_isValid);

  [rmc decodeValueOfObjCType: @encode(int) at: &sequence];
  op = [self _makeOutRmc: sequence generate: 0 reply: NO];

  [rmc decodeValueOfObjCType: ":" at: &sel];
  [rmc decodeValueOfObjCType: @encode(unsigned) at: &target];
  [self _doneInRmc: rmc];
  p = [self includesLocalTarget: target];
  o = (p != nil) ? ((ProxyStruct*)p)->_object : nil;

  /* xxx We should make sure that TARGET is a valid object. */
  /* Not actually a Proxy, but we avoid the warnings "id" would have made. */
  m = GSGetMethod(((NSDistantObject*)o)->isa, sel, YES, YES);
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
- (NSPortCoder*) _getReplyRmc: (int)sn
{
  NSPortCoder		*rmc;
  GSIMapNode		node = 0;
  NSDate		*timeout_date = nil;
  NSTimeInterval	last_interval = 0.0001;
  NSTimeInterval	delay_interval = last_interval;
  NSDate		*delay_date = nil;
  NSThread		*thread = GSCurrentThread();
  NSRunLoop		*runLoop = GSRunLoopForThread(thread);
  BOOL			isLocked = NO;

  /*
   * If we have sent out a request on a run loop that we don't already
   * know about, it must be on a new thread - so if we have multipleThreads
   * enabled, we must add the run loop of the new thread so that we can
   * get the reply in this thread.
   */
  if ([_runLoops indexOfObjectIdenticalTo: runLoop] == NSNotFound)
    {
      if (_multipleThreads == YES)
	{
	  [self addRunLoop: runLoop];
	}
      else
	{
	  [NSException raise: NSObjectInaccessibleException
		      format: @"Waiting for reply in wrong thread"];
	}
    }

  NS_DURING
    {
      if (debug_connection > 5)
	NSLog(@"Waiting for reply sequence %d on %@",
	  sn, self);
      M_LOCK(_queueGate); isLocked = YES;
      while (_isValid == YES
	&& (node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn)) != 0
	&& node->value.obj == dummyObject)
	{
	  M_UNLOCK(_queueGate); isLocked = NO;
	  if (timeout_date == nil)
	    {
	      timeout_date = [dateClass allocWithZone: NSDefaultMallocZone()];
	      timeout_date
		= [timeout_date initWithTimeIntervalSinceNow: _replyTimeout];
	    }
	  if (_multipleThreads == YES)
	    {
	      NSDate		*limit_date;
	      NSTimeInterval	next_interval;

	      /*
	       * If multiple threads are using this connections, another
	       * thread may read the reply we are waiting for - so we must
	       * break out of the runloop frequently to check.  We do this
	       * by setting a small delay and increasing it each time round
	       * so that this semi-busy wait doesn't consume too much
	       * processor time (I hope).
	       * We set an upper limit on the delay to avoid responsiveness
	       * problems.
	       */
	      RELEASE(delay_date);
	      delay_date = [dateClass allocWithZone: NSDefaultMallocZone()];
	      if (delay_interval < 1.0)
		{
		  next_interval = last_interval + delay_interval;
		  last_interval = delay_interval;
		  delay_interval = next_interval;
		}
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
			beforeDate: limit_date] == NO
		|| [timeout_date timeIntervalSinceNow] <= 0.0)
		{
		  if (limit_date == timeout_date)
		    {
		      M_LOCK(_queueGate); isLocked = YES;
		      node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn);
		      break;
		    }
		}
	    }
	  else
	    {
	      /*
	       * Normal operation - wait for data or for a timeout.
	       */
	      if ([runLoop runMode: NSConnectionReplyMode
			beforeDate: timeout_date] == NO
		|| [timeout_date timeIntervalSinceNow] <= 0.0)
		{
		  M_LOCK(_queueGate); isLocked = YES;
		  node = GSIMapNodeForKey(_replyMap, (GSIMapKey)sn);
		  break;
		}
	    }
	  M_LOCK(_queueGate); isLocked = YES;
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
      M_UNLOCK(_queueGate); isLocked = NO;
      TEST_RELEASE(delay_date);
      TEST_RELEASE(timeout_date);
      if (rmc == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"no reply message available"];
	}
      if (rmc == dummyObject)
	{
	  if (_isValid == YES)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out waiting for reply"];
	    }
	  else
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"invalidated while awaiting reply"];
	    }
	}
    }
  NS_HANDLER
    {
      if (isLocked == YES)
	{
	  M_UNLOCK(_queueGate);
	}
      [localException raise];
    }
  NS_ENDHANDLER

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
    NSLog(@"Sending %@ on %@", stringFromMsgType(msgid), self);

  limit = [dateClass dateWithTimeIntervalSinceNow: _requestTimeout];
  sent = [_sendPort sendBeforeDate: limit
			     msgid: msgid
			components: components
			      from: _receivePort
			  reserved: [_sendPort reservedSpaceLength]];

  M_LOCK(_refGate);

  /*
   * We replace the coder we have just used in the cache, and tell it not to
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
  static unsigned	local_object_counter = 0;
  id			object;
  unsigned		target;
  GSIMapNode    	node;

  M_LOCK(_proxiesGate);
  NSParameterAssert (_isValid);

  object = ((ProxyStruct*)anObj)->_object;
  target = ((ProxyStruct*)anObj)->_handle;

  /*
   * If there is no target allocated to the proxy, we add one.
   */
  if (target == 0)
    {
      ((ProxyStruct*)anObj)->_handle = target = ++local_object_counter;
    }

  /*
   * Record the value in the _localObjects map, retaining it.
   */
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)object);
  NSAssert(node == 0, NSInternalInconsistencyException);
  node = GSIMapNodeForKey(_localTargets, (GSIMapKey)target);
  NSAssert(node == 0, NSInternalInconsistencyException);

  RETAIN(anObj);
  GSIMapAddPair(_localObjects, (GSIMapKey)object, (GSIMapVal)((id)anObj));
  GSIMapAddPair(_localTargets, (GSIMapKey)target, (GSIMapVal)((id)anObj));

  if (debug_connection > 2)
    NSLog(@"add local object (0x%x) target (0x%x) "
	  @"to connection (%@)", (uintptr_t)object, target, self);

  M_UNLOCK(_proxiesGate);
}

- (NSDistantObject*) retainOrAddLocal: (NSDistantObject*)proxy
			    forObject: (id)object
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
      RETAIN(p);
      DESTROY(proxy);
    }
  if (p == nil && proxy != nil)
    {
      p = proxy;
      [self addLocalObject: p];
    }
  M_UNLOCK(_proxiesGate);
  return p;
}

- (void) removeLocalObject: (NSDistantObject*)prox
{
  id		anObj;
  unsigned	target;
  unsigned	val = 0;
  GSIMapNode	node;

  M_LOCK(_proxiesGate);
  anObj = ((ProxyStruct*)prox)->_object;
  node = GSIMapNodeForKey(_localObjects, (GSIMapKey)anObj);

  /*
   * The NSDistantObject concerned may not belong to this connection,
   * so we need to check that any matching proxy is identical to the
   * argument we were given.
   */
  if (node != 0 && node->value.obj == prox)
    {
      target = ((ProxyStruct*)prox)->_handle;

      /*
       * If this proxy has been vended onwards to another process
       * which has not myet released it, we need to keep a reference
       * to the local object around for a while in case that other
       * process needs it.
       */
      if ((((ProxyStruct*)prox)->_counter) != 0)
	{
	  CachedLocalObject	*item;

	  (((ProxyStruct*)prox)->_counter) = 0;
	  M_LOCK(cached_proxies_gate);
	  if (timer == nil)
	    {
	      timer = [NSTimer scheduledTimerWithTimeInterval: 1.0
		target: connectionClass
		selector: @selector(_timeout:)
		userInfo: nil
		repeats: YES];
	    }
	  item = [CachedLocalObject newWithObject: prox time: 5];
	  NSMapInsert(targetToCached, (void*)(uintptr_t)target, item);
	  M_UNLOCK(cached_proxies_gate);
	  RELEASE(item);
	  if (debug_connection > 3)
	    NSLog(@"placed local object (0x%x) target (0x%x) in cache",
			(uintptr_t)anObj, target);
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
	NSLog(@"removed local object (0x%x) target (0x%x) "
	  @"from connection (%@) (ref %d)", (uintptr_t)anObj, target, self, val);
    }
  M_UNLOCK(_proxiesGate);
}

- (void) _release_target: (unsigned)target count: (unsigned)number
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
	      [op encodeValueOfObjCType: @encode(unsigned) at: &target];
	      if (debug_connection > 3)
		NSLog(@"sending release for target (0x%x) on (%@)",
		  target, self);
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

- (NSDistantObject*) locateLocalTarget: (unsigned)target
{
  NSDistantObject	*proxy = nil;
  GSIMapNode		node;

  M_LOCK(_proxiesGate);

  /*
   * Try a quick lookup to see if the target references a local object
   * belonging to the receiver ... usually it should.
   */
  node = GSIMapNodeForKey(_localTargets, (GSIMapKey)target);
  if (node != 0)
    {
      proxy = node->value.obj;
    }

  /*
   * If the target doesn't exist in the receiver, but still
   * persists in the cache (ie it was recently released) then
   * we move it back from the cache to the receiver.
   */
  if (proxy == nil)
    {
      CachedLocalObject	*cached;

      M_LOCK(cached_proxies_gate);
      cached = NSMapGet (targetToCached, (void*)(uintptr_t)target);
      if (cached != nil)
	{
	  proxy = [cached obj];
	  /*
	   * Found in cache ... add to this connection as the object
	   * is no longer in use by any connection.
	   */
	  ASSIGN(((ProxyStruct*)proxy)->_connection, self);
	  [self addLocalObject: proxy];
	  NSMapRemove(targetToCached, (void*)(uintptr_t)target);
	  if (debug_connection > 3)
	    NSLog(@"target (0x%x) moved from cache", target);
	}
      M_UNLOCK(cached_proxies_gate);
    }

  /*
   * If not found in the current connection or the cache of local references
   * of recently invalidated connections, try all other existing connections.
   */
  if (proxy == nil)
    {
      NSHashEnumerator	enumerator;
      NSConnection	*c;

      M_LOCK(connection_table_gate);
      enumerator = NSEnumerateHashTable(connection_table);
      while (proxy == nil
	&& (c = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
	{
	  if (c != self && [c isValid] == YES)
	    {
	      M_LOCK(c->_proxiesGate);
	      node = GSIMapNodeForKey(c->_localTargets, (GSIMapKey)target);
	      if (node != 0)
		{
		  id		local;
		  unsigned	nTarget;

		  /*
		   * We found the local object in use in another connection
		   * so we create a new reference to the same object and
		   * add it to our connection, adjusting the target of the
		   * new reference to be the value we need.
		   *
		   * We don't want to just share the NSDistantObject with
		   * the other connection, since we might want to keep
		   * track of information on a per-connection basis in
		   * order to handle connection shutdown cleanly.
		   */
		  proxy = node->value.obj;
		  local = RETAIN(((ProxyStruct*)proxy)->_object);
		  proxy = [NSDistantObject proxyWithLocal: local
					       connection: self];
		  nTarget = ((ProxyStruct*)proxy)->_handle;
		  GSIMapRemoveKey(_localTargets, (GSIMapKey)nTarget);
		  ((ProxyStruct*)proxy)->_handle = target;
		  GSIMapAddPair(_localTargets, (GSIMapKey)target,
		    (GSIMapVal)((id)proxy));
		}
	      M_UNLOCK(c->_proxiesGate);
	    }
	}
      NSEndHashTableEnumeration(&enumerator);
      M_UNLOCK(connection_table_gate);
    }

  M_UNLOCK(_proxiesGate);

  if (proxy == nil)
    {
      if (debug_connection > 3)
	NSLog(@"target (0x%x) not found anywhere", target);
    }
  return proxy;
}

- (void) vendLocal: (NSDistantObject*)aProxy
{
  M_LOCK(_proxiesGate);
  ((ProxyStruct*)aProxy)->_counter++;
  M_UNLOCK(_proxiesGate);
}

- (void) acquireProxyForTarget: (unsigned)target
{
  NSDistantObject	*found;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);
  if (node == 0)
    {
      found = nil;
    }
  else
    {
      found = node->value.obj;
    }
  M_UNLOCK(_proxiesGate);
  if (found == nil)
    {
      NS_DURING
	{
	  /*
	   * Tell the remote app that it must retain the local object
	   * for the target on this connection.
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
	      else if (debug_connection > 3)
		NSLog(@"sending retain for target - %u", target);
	    }
	}
      NS_HANDLER
	{
	  NSLog(@"failed to retain target - %@", localException);
	}
      NS_ENDHANDLER
    }
}

- (id) retain
{
  return [super retain];
}

- (void) removeProxy: (NSDistantObject*)aProxy
{
  M_LOCK(_proxiesGate);
  if (_isValid == YES)
    {
      unsigned		target;
      unsigned		count = 1;
      GSIMapNode	node;

      target = ((ProxyStruct*)aProxy)->_handle;
      node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)target);

      /*
       * Only remove if the proxy for the target is the same as the
       * supplied argument.
       */
      if (node != 0 && node->value.obj == aProxy)
	{
	  count = ((ProxyStruct*)aProxy)->_counter;
	  GSIMapRemoveKey(_remoteProxies, (GSIMapKey)target);
	  /*
	   * Tell the remote application that we have removed our proxy and
	   * it can release it's local object.
	   */
	  [self _release_target: target count: count];
	}
    }
  M_UNLOCK(_proxiesGate);
}


/**
 * Private method used only when a remote process/thread has sent us a
 * target which we are decoding into a proxy in this process/thread.
 * <p>The argument aProxy may be nil, in which case an existing proxy
 * matching aTarget is retrieved retained, and returned (this is done
 * when a proxy target is sent to us by a remote process).
 * </p>
 * <p>If aProxy is not nil, but a proxy with the same target already
 * exists, then aProxy is released and the existing proxy is returned
 * as in the case where aProxy was nil.
 * </p>
 * <p>If aProxy is not nil and there was no prior proxy with the same
 * target, aProxy is added to the receiver and returned.
 * </p>
 */
- (NSDistantObject*) retainOrAddProxy: (NSDistantObject*)aProxy
			    forTarget: (unsigned)aTarget
{
  NSDistantObject	*p;
  GSIMapNode		node;

  /* Don't assert (_isValid); */
  NSParameterAssert(aTarget > 0);
  NSParameterAssert(aProxy==nil || aProxy->isa == distantObjectClass);
  NSParameterAssert(aProxy==nil || [aProxy connectionForProxy] == self);
  NSParameterAssert(aProxy==nil || aTarget == ((ProxyStruct*)aProxy)->_handle);

  M_LOCK(_proxiesGate);
  node = GSIMapNodeForKey(_remoteProxies, (GSIMapKey)aTarget);
  if (node == 0)
    {
      p = nil;
    }
  else
    {
      p = node->value.obj;
      RETAIN(p);
      DESTROY(aProxy);
    }
  if (p == nil && aProxy != nil)
    {
      p = aProxy;
      GSIMapAddPair(_remoteProxies, (GSIMapKey)aTarget, (GSIMapVal)((id)p));
    }
  /*
   * Whether this is a new proxy or an existing proxy, this method is
   * only called for an object being vended by a remote process/thread.
   * We therefore need to increment the count of the number of times
   * the proxy has been vended.
   */
  if (p != nil)
    {
      ((ProxyStruct*)p)->_counter++;
    }
  M_UNLOCK(_proxiesGate);
  return p;
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

- (NSDistantObject*) includesLocalTarget: (unsigned)target
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

/*
 *	We register this method for a notification when a port dies.
 *	NB. It is possible that the death of a port could be notified
 *	to us after we are invalidated - in which case we must ignore it.
 */
- (void) _portIsInvalid: (NSNotification*)notification
{
  if (_isValid)
    {
      id port = [notification object];

      if (debug_connection)
	{
	  NSLog(@"Received port invalidation notification for "
	      @"connection %@\n\t%@", self, port);
	}

      /* We shouldn't be getting any port invalidation notifications,
	  except from our own ports; this is how we registered ourselves
	  with the NSNotificationCenter in
	  +newForInPort: outPort: ancestorConnection. */
      NSParameterAssert (port == _receivePort || port == _sendPort);

      [self invalidate];
    }
}

/**
 * On thread exit, we need all connections to be removed from the runloop
 * of the thread or they will retain that and cause a memory leak.
 */
+ (void) _threadWillExit: (NSNotification*)notification
{
  NSRunLoop *runLoop = GSRunLoopForThread ([notification object]);

  if (runLoop != nil)
    {
      NSEnumerator	*enumerator;
      NSConnection	*c;

      M_LOCK (connection_table_gate);
      enumerator = [NSAllHashTableObjects(connection_table) objectEnumerator];
      M_UNLOCK (connection_table_gate);

      /*
       * We enumerate an array copy of the contents of the hash table
       * as we know we can do that safely outside the locked region.
       * The temporary array and the enumerator are autoreleased and
       * will be deallocated with the threads autorelease pool. 
       */
      while ((c = [enumerator nextObject]) != nil)
	{
	  [c removeRunLoop: runLoop];
	}
    }
}
@end

