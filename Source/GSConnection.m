/* Implementation of connection object for remote object messaging
   Copyright (C) 1994, 1995, 1996, 1997, 2000 Free Software Foundation, Inc.

   Created by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   Minor rewrite for OPENSTEP by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: August 1997
   Major rewritre for MACOSX by: Richard Frith-Macdonald <rfm@gnu.org>
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

#include <Foundation/DistributedObjects.h>
#include <Foundation/GSTcpPort.h>
#include <Foundation/GSConnection.h>
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

NSString* NSConnectionReplyMode = @"NSConnectionReplyMode";

/*
 *      Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
NSString *NSConnectionRepliesReceived = @"NSConnectionRepliesReceived";
NSString *NSConnectionRepliesSent = @"NSConnectionRepliesSent";
NSString *NSConnectionRequestsReceived = @"NSConnectionRequestsReceived";
NSString *NSConnectionRequestsSent = @"NSConnectionRequestsSent";
/* These Are GNUstep extras */
NSString *NSConnectionLocalCount = @"NSConnectionLocalCount";
NSString *NSConnectionProxyCount = @"NSConnectionProxyCount";

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


@interface NSConnection (GettingCoderInterface)
- (void) _handleRmc: rmc;
- (void) _handleQueuedRmcRequests;
- _getReceivedReplyRmcWithSequenceNumber: (int)n;
- newSendingReplyRmcWithSequenceNumber: (int)n;
- (int) _newMsgNumber;
@end

@interface NSConnection (Private)
+ (void) handlePortMessage: (NSPortMessage*)msg;
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

  for (class = self; class != Nil; class = class_get_super_class(class))
    if (class == aClassObject)
      return YES;
  return NO;
}

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

  [connection_table_gate lock];
  enumerator = NSEnumerateHashTable(connection_table);
  while ((c = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      if ((sendPort == nil || [sendPort isEqual: [con sendPort]])
        && (receivePort == nil || [receivePort isEqual: [con receivePort]])
	{
	  /*
	   * We don't want this connection to be destroyed by another thread
	   * between now and when it's returned from this function and used!
	   */
	  AUTORELEASE(RETAIN(c));
	  break;
	}
    }
  [connection_table_gate unlock];
  return c;
}

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

+ (NSConnection*) connectionWithReceivePort: (NSPort*)r
				   sendPort: (NSPort*)s
{
  NSConnection	*c = existingConnection(r, s);

  if (c == nil)
    {
      c = [self allocWithZone: NSDefaultMallocZone()];
      c = [self initWithReceivePort: r sendPort: s];
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
  if ([self isValid] == YES)
    {
      if ([request_modes containsObject: mode] == NO)
	{
	  unsigned	c = [run_loops count];

	  while (c-- > 0)
	    {
	      NSRunLoop	*loop = [run_loops objectAtIndex: c];

	      [loop addPort: receive_port forMode: mode];
	    }
	  [request_modes addObject: mode];
	}
    }
}

- (void) addRunLoop: (NSRunLoop*)loop
{
  if ([self isValid] == YES)
    {
      if ([run_loops indexOfObjectIdenticalTo: loop] == NSNotFound)
	{
	  unsigned	c = [request_modes count];

	  while (c-- > 0)
	    {
	      NSString	*mode = [request_modes objectAtIndex: c];

	      [loop addPort: receive_port forMode: mode];
	    }
	  [run_loops addObject: loop];
	}
    }
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

- (void) enableMultipleThreads
{
  [self notImplemented: _cmd];
}

- (BOOL) independentConversationQueueing
{
  return independent_queueing;
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

  [connection_table_gate lock];

  /*
   * If the send and receive ports match an existing connection
   * deallocate the new one and retain and return the old one.
   */
  conn = existingConnection(r, s);
  if (conn != nil)
    {
      RELEASE(self);
      self = RETAIN(conn);
      [connection_table_gate unlock];
      if (debug_connection > 2)
	{
	  NSLog(@"Found existing connection (0x%x) for \n\t%@\n\t%@",
	    (gsaddr)conn, r, s);
	}
      return self;
    }

  if (debug_connection)
    {
      NSLog(@"Initialising new connection 0x%x\n\t%@\n\t%@\n",
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

  /*
   * Some attributes are inherited from the parent if possible.
   */
  parent = existingConnection(r, r);
  if (parent != nil)
    {
      independent_queueing = parent->independent_queueing;
      reply_timeout = parent->reply_timeout;
      request_timeout = parent->request_timeout;
    }
  else
    {
      independent_queueing = NO;
      reply_timeout = CONNECTION_DEFAULT_TIMEOUT;
      request_timeout = CONNECTION_DEFAULT_TIMEOUT;
    }

  request_depth = 0;
  delegate = nil;
  /*
   *	Set up request modes array and make sure the receiving port is
   *	added to the run loop to get data.
   */
  loop = [NSRunLoop currentRunLoop];
  run_loops = [[NSMutableArray alloc] initWithObject: loop];
  request_modes = [[NSMutableArray alloc] initWithCapacity: 2];
  [self addRequestMode: NSDefaultRunLoopMode]; 
  [self addRequestMode: NSConnectionReplyMode]; 

  /* Ask the delegate for permission, (OpenStep-style and GNUstep-style). */

  /* Preferred MacOS-X version, which just allows the returning of BOOL */
  del = [parent delegate];
  if ([del respondsTo: @selector(connection:shouldMakeNewConnection:)])
    {
      if ([del connection: parent shouldMakeNewConnection: self] == NO)
	{
	  [connection_table_gate unlock];
	  RELEASE(self);
	  return nil;
	}
    }
  /* Deprecated OpenStep version, which just allows the returning of BOOL */
  if ([del respondsTo: @selector(makeNewConnection:sender:)])
    {
      if (![del makeNewConnection: self sender: parent])
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
  [connection_table_gate unlock];

  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSConnectionDidInitializeNotification
		  object: self];

  return self;
}

/* xxx This needs locks */
- (void) invalidate
{
  if (is_valid == NO)
    return;

  is_valid = NO;

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

- (NSArray*) localObjects
{
  NSArray	*c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues(local_objects);
  [proxiesHashGate unlock];
  return c;
}

- (BOOL) multipleThreadsEnabled
{
  [self notImplemented: _cmd];
  return NO;
}

- (NSPort*) receivePort
{
  return receive_port;
}

- (BOOL) registerName: (NSString*)name
{
  NSPortNameServer	*svr = [NSPortNameServer defaultPortNameServer];
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
  NSArray	*c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues(remote_proxies);
  [proxiesHashGate unlock];
  return c;
}

- (void) removeRequestMode: (NSString*)mode
{
  if ([request_modes containsObject: mode])
    {
      unsigned	c = [run_loops count];

      while (c-- > 0)
	{
	  NSRunLoop	*loop = [run_loops objectAtIndex: c];

	  [loop removePort: receive_port forMode: mode];
	}
      [request_modes removeObject: mode];
    }
}

- (void) removeRunLoop: (NSRunLoop*)runloop
{
  unsigned	pos;

  pos = [run_loops indexOfObjectIdenticalTo: loop];
  if (pos != NSNotFound)
    {
      unsigned	c = [request_modes count];

      while (c-- > 0)
	{
	  NSString	*mode = [request_modes objectAtIndex: c];

	  [loop removePort: receive_port forMode: mode];
	}
      [run_loops removeObjectAtIndex: pos];
    }
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

- (void) runInNewThread
{
  [self notImplemented: _cmd];
}

- (NSPort*) sendPort
{
  return send_port;
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
  [connection_table_gate lock];
  NSHashRemove(connection_table, self);
  [timer invalidate];
  timer = nil;
  [connection_table_gate unlock];

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
  RELEASE(run_loops);

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
  id port;
  id newConn;

  port = [NSPort port];
  newConn = [self alloc];
  newConn = [newConn initWithReceivePort: port sendPort: nil];
  [newConn setRootObject: anObj];
  if ([newConn registerName: n] == NO)
    {
      DESTROY(newConn);
    }
  return newConn;
}

@end





@implementation	NSConnection (Private)

- (void) handlePortMessage: (NSPortMessage*)msg
{
  NSConnection	*conn = existingConnection([msg receivePort], [msg sendPort]);

  conn = [self connectionWithReceivePort: [msg receivePort]
				sendPort: [msg sendPort]];
  if (conn == nil)
    {
    }
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
    BOOL		out_parameters;
    BOOL		sendOk;
    const char		*type;
    int			seq_num;
    NSPortMessage	*message;
    NSData		*limit;
    retval_t		retframe;

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

    op = [[NSPortCoder alloc] initWithReceivePort: [self receivePort]
					 sendPort: [self sendPort]
				       components: nil];
    seq_num = [self _newMsgNumber];
    [op encodeValueOfObjCType: @encode(int) at: &seq_num];

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
    message = [[NSPortMessage alloc] initWithSendPort: [self sendPort]
					  receivePort: [self receivePort]
					   components: [op _components]]; 
    RELEASE(op);
    [message setMsgId: METHOD_REQUEST];
    limit = [NSDate dateWithTimeIntervalSinceNow: [self requestTimeout]];
    sendOk = [message sendBeforeDate: limit];
    RELEASE(message);
    if (sendOk == NO)
      {
	[NSException raise: NSPortTimeoutException
		    format: @"request send timed out"];
      }

    if (debug_connection > 1)
      NSLog(@"Sent message to 0x%x\n", (gsaddr)self);
    req_out_count++;	/* Sent a request.	*/

    /* Get the reply rmc, and decode it. */
    {
      NSPortCoder	*ip = nil;
      BOOL		is_exception = NO;

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



/* Notification Strings. */

NSString *NSConnectionDidDieNotification
= @"NSConnectionDidDieNotification";

NSString *NSConnectionDidInitializeNotification
= @"NSConnectionDidInitializeNotification";

