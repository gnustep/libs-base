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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
#include <base/NotificationDispatcher.h>
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
- (BOOL) isVended;
- (id) localForProxy;
- (void) setProxyTarget: (unsigned)target;
- (void) setVended;
- (unsigned) targetForProxy;
@end

@implementation	NSDistantObject (NSConnection)
- (BOOL) isVended
{
  return _isVended;
}
- (id) localForProxy
{
  return _object;
}
- (void) setProxyTarget: (unsigned)target
{
  _handle = target;
}
- (void) setVended
{
  _isVended = YES;
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
  counter->object = obj;
  counter->target = ++local_object_counter;
  return counter;
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

  item->obj = [o retain];
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
+ setDebug: (int)val;
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

static int
type_get_number_of_arguments (const char *type)
{
  int i = 0;
  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
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

/* Perhaps this should be a hashtable, keyed by remote port.
   But we may also need to include the local port---even though
   when receiving the local port is fixed, there may be more than
   one registered connection (with different in ports) in the
   application. */
/* We could write -hash and -isEqual implementations for NSConnection */
static NSMutableArray *connection_array;
static NSMutableArray *not_owned;
static NSLock *connection_array_gate;

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
  int	count = [connection_array count];
  id	cons[count];

  [connection_array getObjects: cons];
  return [NSArray arrayWithObjects: cons count: count];
}

+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
					  host: (NSString*)h
{
    NSDistantObject	*proxy;

    proxy = [self rootProxyForConnectionWithRegisteredName:n host:h];
    if (proxy) {
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
  static NSString*	tkey = @"NSConnectionThreadKey";
  NSConnection*	c;
  NSThread*	t;

  t = [NSThread currentThread];
  c = (NSConnection*)[[t threadDictionary] objectForKey:tkey];
  if (c != nil && [c isValid] == NO) {
    /*
     *	If the default connection for this thread has been invalidated -
     *	release it and create a new one.
     */
    [[t threadDictionary] removeObjectForKey:tkey];
    c = nil;
  }
  if (c == nil) {
    c = [NSConnection new];
    [[t threadDictionary] setObject:c forKey:tkey];
    [c release];	/* retained in dictionary.	*/
  }
  return c;
}

+ (void) initialize
{
  not_owned = [[NSMutableArray alloc] initWithCapacity:8];
  connection_array = [[NSMutableArray alloc] initWithCapacity:8];
  connection_array_gate = [NSLock new];
  /* xxx When NSHashTable's are working, change this. */
  all_connections_local_objects =
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  all_connections_local_targets =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  all_connections_local_cached =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  received_request_rmc_queue = [[NSMutableArray alloc] initWithCapacity:32];
  received_request_rmc_queue_gate = [NSLock new];
  received_reply_rmc_queue = [[NSMutableArray alloc] initWithCapacity:32];
  received_reply_rmc_queue_gate = [NSLock new];
  root_object_dictionary = [[NSMutableDictionary alloc] initWithCapacity:8];
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

+ new
{
  id newPort = [[default_receive_port_class newForReceiving] autorelease];
  id newConn = [NSConnection newForInPort:newPort
				  outPort:nil
		       ancestorConnection:nil];
  return newConn;
}

+ (id)currentConversation
{
  [self notImplemented: _cmd];
  return self;
}

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
						         host: (NSString*)h
{
    id p = [default_send_port_class newForSendingToRegisteredName: n onHost: h];
    if (p == nil) {
	return nil;
    }
    return [self rootProxyAtPort: [p autorelease]];
}

+ (void) _timeout: (NSTimer*)t
{
    NSArray	*cached_locals;
    int	i;

    cached_locals = NSAllMapTableValues(all_connections_local_cached);
    for (i = [cached_locals count]; i > 0; i--) {
	CachedLocalObject *item = [cached_locals objectAtIndex: i-1];

	if ([item countdown] == NO) {
	    GSLocalCounter	*counter = [item obj];
	    NSMapRemove(all_connections_local_cached, (void*)counter->target);
	}
    }
    if ([cached_locals count] == 0) {
	[t invalidate];
	timer = nil;
    }
}

- (void) addRequestMode: (NSString*)mode
{
    if (![request_modes containsObject:mode]) {
	[request_modes addObject:mode];
        [[NSRunLoop currentRunLoop] addPort: receive_port forMode: mode];
    }
}

/* This needs locks */
- (void) dealloc
{
  if (debug_connection)
    NSLog(@"deallocating 0x%x\n", (unsigned)self);
  [self invalidate];

  /* Remove rootObject from root_object_dictionary
     if this is last connection */
  if (![NSConnection connectionsCountWithInPort:receive_port])
    [NSConnection setRootObject:nil forInPort:receive_port];

  /* Remove receive port from run loop. */
  [self setRequestMode: nil];
  [[NSRunLoop currentRunLoop] removePort: receive_port
				 forMode: NSConnectionReplyMode];
  [request_modes release];

  /* Finished with ports - releasing them may generate a notification */
  [receive_port release];
  [send_port release];

  /* Don't need notifications any more - so remove self as observer. */
  [NotificationDispatcher removeObserver: self];

  [proxiesHashGate lock];
  NSFreeMapTable (remote_proxies);
  NSFreeMapTable (local_objects);
  NSFreeMapTable (local_targets);
  NSFreeMapTable (incoming_xref_2_const_ptr);
  NSFreeMapTable (outgoing_const_ptr_2_xref);
  [proxiesHashGate unlock];

  [super dealloc];
}

- (id) delegate
{
  return delegate;
}

- (BOOL) independantConversationQueueing
{
    return independant_queueing;
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
  id newPort = [[default_receive_port_class newForReceiving] autorelease];
  id newConn = [NSConnection newForInPort:newPort
				  outPort:nil
		       ancestorConnection:nil];
  [self release];
  return newConn;
}

/* xxx This method is an anomaly, just until we get a proper name
   server for port objects.  Richard Frith-MacDonald is working on a
   name server. */
- (BOOL) registerName: (NSString*)name
{
  id old_receive_port = receive_port;
  receive_port = [default_receive_port_class newForReceivingFromRegisteredName: name];
  [old_receive_port release];
  return YES;
}


/*
 *	Keep track of connections created by DO system but not necessarily
 *	ever retained by users code.  These must be retained now for later
 *	release when invalidated.
 */
- (void) setNotOwned
{
  if (![not_owned containsObject:self]) {
    [not_owned addObject:self];
  }
}

/* xxx This needs locks */
- (void) invalidate
{
  if (is_valid)
    {
      is_valid = 0;

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
	targets = [NSAllMapTableValues(local_targets) retain];
	for (i = 0; i < [targets count]; i++)
	  {
	    id	t = [[targets objectAtIndex:i] localForProxy];

	    [self removeLocalObject:t];
	  }
	[targets release];
	[proxiesHashGate unlock];
      }
      /* xxx Note: this is causing us to send a shutdown message
	 to the connection that shut *us* down.  Don't do that.
	 Well, perhaps it's a good idea just in case other side didn't really
	 send us the shutdown; this way we let them know we're going away */
#if 0
      [self shutdown];
#endif

      if (debug_connection)
	NSLog(@"Invalidating connection 0x%x\n\t%@\n\t%@\n", (unsigned)self,
		[receive_port description], [send_port description]);

      [NotificationDispatcher
	postNotificationName: NSConnectionDidDieNotification
	object: self];

      [not_owned removeObjectIdenticalTo:self];
    }
}

- (BOOL) isValid
{
  return is_valid;
}

- (void) release
{
    /*
     *	In order that connections may be deallocated - we check to see if
     *	the only thing still retaining us is the connection_array.
     *	if so (we assume a retain count of 2 means this) we remove self
     *	from the connection array.
     *	NB. bracket this operation with retain and release so that we don't
     *	suffer problems with recursion.
     */
    if ([self retainCount] == 2) {
	[super retain];
	[connection_array_gate lock];
	[connection_array removeObject: self];
	[timer invalidate];
	timer = nil;
	NSResetMapTable(all_connections_local_cached);
	[connection_array_gate unlock];
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
    if ([request_modes containsObject:mode]) {
	[request_modes removeObject:mode];
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
    return [request_modes copy];
}

- (NSTimeInterval) requestTimeout
{
  return request_timeout;
}

- (id) retain
{
    return [super retain];
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

- (void) setIndependantConversationQueueing: (BOOL)flag
{
    independant_queueing = flag;
}

- (void) setReplyTimeout: (NSTimeInterval)to
{
  reply_timeout = to;
}

- (void) setRequestMode: (NSString*)mode
{
    while ([request_modes count]>0 && [request_modes objectAtIndex:0]!=mode) {
	[self removeRequestMode:[request_modes objectAtIndex:0]];
    }
    while ([request_modes count]>1) {
	[self removeRequestMode:[request_modes objectAtIndex:1]];
    }
    if (mode != nil && [request_modes count] == 0) {
	[self addRequestMode:mode];
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
    NSMutableDictionary*	d;
    id				o;

    d = [NSMutableDictionary dictionaryWithCapacity:8];

    /*
     *	These are in OPENSTEP 4.2
     */
    o = [NSNumber numberWithUnsignedInt:rep_in_count];
    [d setObject:o forKey:NSConnectionRepliesReceived];
    o = [NSNumber numberWithUnsignedInt:rep_out_count];
    [d setObject:o forKey:NSConnectionRepliesSent];
    o = [NSNumber numberWithUnsignedInt:req_in_count];
    [d setObject:o forKey:NSConnectionRequestsReceived];
    o = [NSNumber numberWithUnsignedInt:req_out_count];
    [d setObject:o forKey:NSConnectionRequestsSent];

    /*
     *	These are GNUstep extras
     */
    o = [NSNumber numberWithUnsignedInt:NSCountMapTable(local_targets)];
    [d setObject:o forKey:NSConnectionLocalCount];
    o = [NSNumber numberWithUnsignedInt:NSCountMapTable(remote_proxies)];
    [d setObject:o forKey:NSConnectionProxyCount];

    return d;
}

@end



@implementation	NSConnection (GNUstepExtensions)

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
  return [connection_array count];
}

+ (unsigned) connectionsCountWithInPort: (NSPort*)aPort
{
    unsigned	count = 0;
    unsigned	pos;

    [connection_array_gate lock];
    count = [connection_array count];
    for (pos = 0; pos < [connection_array count]; pos++) {
	id	o = [connection_array objectAtIndex:pos];

        if ([aPort isEqual: [o receivePort]]) {
	    count++;
	}
    }
    [connection_array_gate unlock];

    return count;
}


/* Creating and initializing connections. */

+ (NSConnection*) newWithRootObject: anObj;
{
  id newPort;
  id newConn;

  newPort = [[default_receive_port_class newForReceiving] autorelease];
  newConn = [self newForInPort:newPort outPort:nil
		  ancestorConnection:nil];
  [self setRootObject:anObj forInPort:newPort];
  return newConn;
}

/* I want this method name to clearly indicate that we're not connecting
   to a pre-existing registration name, we're registering a new name,
   and this method will fail if that name has already been registered.
   This is why I don't like "newWithRegisteredName:" --- it's unclear
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

  newPort = [default_receive_port_class newForReceivingFromRegisteredName: n
								 fromPort: p];
  newConn = [self newForInPort: [newPort autorelease]
		       outPort: nil
	    ancestorConnection: nil];
  [self setRootObject: anObj forInPort: newPort];
  return newConn;
}

+ (NSDistantObject*) rootProxyAtName: (NSString*)n
{
  return [self rootProxyAtName: n onHost: @""];
}

+ (NSDistantObject*) rootProxyAtName: (NSString*)n onHost: (NSString*)h
{
  return [self rootProxyForConnectionWithRegisteredName:n host:h];
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
  NSConnection *newConn = [self newForInPort:anInPort
				outPort:anOutPort
				ancestorConnection:nil];
  NSDistantObject *newRemote;

  newRemote = [newConn rootProxy];
  [newConn autorelease];
  return newRemote;
}


/* This is the designated initializer for NSConnection */

+ (NSConnection*) newForInPort: (NSPort*)ip outPort: (NSPort*)op
   ancestorConnection: ancestor
{
  NSConnection *newConn;

  NSParameterAssert (ip);

  /* Find previously existing connection if there */
  newConn = [[self connectionByInPort: ip outPort: op] retain];
  if (newConn)
    return newConn;

  [connection_array_gate lock];

  newConn = [[NSConnection alloc] _superInit];
  if (debug_connection)
    NSLog(@"Created new connection 0x%x\n\t%@\n\t%@\n",
	    (unsigned)newConn, [ip description], [op description]);
  newConn->is_valid = 1;
  newConn->receive_port = ip;
  [ip retain];
  newConn->send_port = op;
  [op retain];
  newConn->message_count = 0;
  newConn->rep_out_count = 0;
  newConn->req_out_count = 0;
  newConn->rep_in_count = 0;
  newConn->req_in_count = 0;

  /* This maps (void*)obj to (id)obj.  The obj's are retained.
     We use this instead of an NSHashTable because we only care about
     the object's address, and don't want to send the -hash message to it. */
  newConn->local_objects =
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /* This maps handles for local objects to their local proxies. */
  newConn->local_targets =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /* This maps [proxy targetForProxy] to proxy.  The proxy's are retained. */
  newConn->remote_proxies =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  newConn->incoming_xref_2_const_ptr =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  newConn->outgoing_const_ptr_2_xref =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  newConn->reply_timeout = [self defaultInTimeout];
  newConn->request_timeout = [self defaultOutTimeout];
  newConn->encoding_class = default_encoding_class;

  /* xxx ANCESTOR argument is currently ignored; in the future it
     will be removed. */
  /* xxx It this the correct behavior? */
  if (!(ancestor = NSMapGet (receive_port_2_ancestor, ip)))
    {
      NSMapInsert (receive_port_2_ancestor, ip, newConn);
      /* This will cause the connection with the registered name
	 to receive the -invokeWithObject: from the IN_PORT.
	 This ends up being the ancestor of future new NSConnections
	 on this in port. */
      /* xxx Could it happen that this connection was invalidated, but
	 the others would still be OK?  That would cause problems.
	 No.  I don't think that can happen. */
      [(InPort*)ip setReceivedPacketInvocation: (id)[self class]];
    }

  if (ancestor)
    {
      newConn->receive_port_class = [ancestor receivePortClass];
      newConn->send_port_class = [ancestor sendPortClass];
    }
  else
    {
      newConn->receive_port_class = default_receive_port_class;
      newConn->send_port_class = default_send_port_class;
    }
  newConn->independant_queueing = NO;
  newConn->reply_depth = 0;
  newConn->delegate = nil;
  /*
   *	Set up request modes array and make sure the receiving port is
   *	added to the run loop to get data.
   */
  newConn->request_modes = [[NSMutableArray arrayWithObject:
		NSDefaultRunLoopMode] retain];
  [[NSRunLoop currentRunLoop] addPort: (NSPort*)ip
			      forMode: NSDefaultRunLoopMode];
  [[NSRunLoop currentRunLoop] addPort: (NSPort*)ip
			      forMode: NSConnectionReplyMode];

  /* Ssk the delegate for permission, (OpenStep-style and GNUstep-style). */

  /* Preferred OpenStep version, which just allows the returning of BOOL */
  if ([[ancestor delegate] respondsTo:@selector(connection:shouldMakeNewConnection:)])
    {
      if (![[ancestor delegate] connection: ancestor
		   shouldMakeNewConnection: (NSConnection*)newConn])
	{
	  [connection_array_gate unlock];
	  [newConn release];
	  return nil;
	}
    }
  /* Deprecated OpenStep version, which just allows the returning of BOOL */
  if ([[ancestor delegate] respondsTo:@selector(makeNewConnection:sender:)])
    {
      if (![[ancestor delegate] makeNewConnection: (NSConnection*)newConn
				sender: ancestor])
	{
	  [connection_array_gate unlock];
	  [newConn release];
	  return nil;
	}
    }
  /* Here is the GNUstep version, which allows the delegate to specify
     a substitute.  Note: The delegate is responsible for freeing
     newConn if it returns something different. */
  if ([[ancestor delegate] respondsTo:@selector(connection:didConnect:)])
    newConn = [[ancestor delegate] connection:ancestor
	       didConnect:newConn];

  /* Register ourselves for invalidation notification when the
     ports become invalid. */
  [NotificationDispatcher addObserver: newConn
			  selector: @selector(portIsInvalid:)
			  name: NSPortDidBecomeInvalidNotification
			  object: ip];
  if (op)
    [NotificationDispatcher addObserver: newConn
			    selector: @selector(portIsInvalid:)
			    name: NSPortDidBecomeInvalidNotification
			    object: op];
  /* if OP is nil, making this notification request would have
     registered us to receive all NSPortDidBecomeInvalidNotification
     requests, independent of which port posted them.  This isn't
     what we want. */

  /* In order that connections may be deallocated - there is an
     implementation of [-release] to automatically remove the connection
     from this array when it is the only thing retaining it. */
  [connection_array addObject: newConn];
  [connection_array_gate unlock];

  [NotificationDispatcher
    postNotificationName: NSConnectionDidInitializeNotification
    object: newConn];

  return newConn;
}

+ (NSConnection*) connectionByInPort: (NSPort*)ip
			     outPort: (NSPort*)op
{
  int count;
  int i;

  NSParameterAssert (ip);

  [connection_array_gate lock];
  count = [connection_array count];
  for (i = 0; i < count; i++)
    {
      id newConnInPort;
      id newConnOutPort;
      NSConnection *newConn;

      newConn = [connection_array objectAtIndex: i];
      newConnInPort = [newConn receivePort];
      newConnOutPort = [newConn sendPort];
      if ([newConnInPort isEqual: ip]
	  && [newConnOutPort isEqual: op])
	{
	  [connection_array_gate unlock];
	  return newConn;
	}
    }
  [connection_array_gate unlock];
  return nil;
}

+ (NSConnection*) connectionByOutPort: (NSPort*)op
{
  int i, count;

  NSParameterAssert (op);

  [connection_array_gate lock];

  count = [connection_array count];
  for (i = 0; i < count; i++)
    {
      id newConnOutPort;
      NSConnection *newConn;

      newConn = [connection_array objectAtIndex: i];
      newConnOutPort = [newConn sendPort];
      if ([newConnOutPort isEqual: op])
	{
	  [connection_array_gate unlock];
	  return newConn;
	}
    }
  [connection_array_gate unlock];
  return nil;
}

- _superInit
{
  [super init];
  return self;
}

+ setDebug: (int)val
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

/* NSDistantObject's -forward:: method calls this to the the message over the wire. */
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
    [[self retain] autorelease];

    /* get the method types from the selector */
#if NeXT_runtime
    [NSException
      raise: NSGenericException
      format: @"Sorry, distributed objects does not work with NeXT runtime"];
    /* type = [object selectorTypeForProxy:sel]; */
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
      NSLog(@"Sent message to 0x%x\n", (unsigned)self);
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
	      ip = [self _getReceivedReplyRmcWithSequenceNumber:seq_num];
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
	  /* -decodeValueOfCType:at:withName: malloc's new memory
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
  char *forward_type;
  id op = nil;
  int reply_sequence_number;

  void decoder (int argnum, void *datum, const char *type)
    {
      /* We need this "dismiss" to happen here and not later so that Coder
	 "-awake..." methods will get sent before the __builtin_apply! */
      if (argnum == -1 && datum == 0 && type == 0)
	{
	  [aRmc dismiss];
	  return;
	}

      [aRmc decodeValueOfObjCType:type
	    at:datum
	    withName:NULL];
      /* -decodeValueOfCType:at:withName: malloc's new memory
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
	    [op encodeBycopyObject:*(id*)datum withName:ENCODED_RETNAME];
#ifdef	_F_BYREF
	  else if (flags & _F_BYREF)
	    [op encodeByrefObject: *(id*)datum withName: ENCODED_ARGNAME];
#endif
	  else
	    [op encodeObject:*(id*)datum withName:ENCODED_RETNAME];
	  break;
	default:
	  [op encodeValueOfObjCType:type at:datum withName:ENCODED_RETNAME];
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
      [aRmc decodeValueOfCType:@encode(char*)
	    at:&forward_type
	    withName:NULL];

      if (debug_connection > 1)
        NSLog(@"Handling message from 0x%x\n", (unsigned)self);
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
      if (op)
	[op release];

      /* Send the exception back to the client. */
      if (is_valid)
	{
	  op=[self newSendingReplyRmcWithSequenceNumber: reply_sequence_number];
	  [op encodeValueOfCType: @encode(BOOL)
	      at: &is_exception
	      withName: @"Exceptional reply flag"];
	  [op encodeBycopyObject: localException
	      withName: @"Exception object"];
	  [op dismiss];
	}
    }
  NS_ENDHANDLER;

  if (forward_type)
    objc_free (forward_type);
}

- (void) _service_rootObject: rmc
{
  id rootObject = [NSConnection rootObjectForInPort:receive_port];
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
      [NSException raise: @"ProxyDecodedBadTarget"
		  format: @"request to release object on bad connection"];
    }

  [rmc decodeValueOfCType: @encode(typeof(count))
		       at: &count
		 withName: NULL];

  for (pos = 0; pos < count; pos++)
    {
      unsigned		target;
      char		vended;
      NSDistantObject	*prox;

      [rmc decodeValueOfCType: @encode(typeof(target))
			   at: &target
		     withName: NULL];

      [rmc decodeValueOfCType: @encode(typeof(char))
			   at: &vended
		     withName: NULL];

      prox = (NSDistantObject*)[self includesLocalTarget: target];
      if (prox != nil)
	{
	  if (vended)
	    {
	      [prox setVended];
	    }
	  [self removeLocalObject: [prox localForProxy]];
	}
    }

  [rmc dismiss];
}

- (void) _service_retain: rmc forConnection: receiving_connection
{
  unsigned target;

  NSParameterAssert (is_valid);

  if ([rmc connection] != self)
    {
      [NSException raise: @"ProxyDecodedBadTarget"
		  format: @"request to retain object on bad connection"];
    }

  [rmc decodeValueOfCType: @encode(typeof(target))
		       at: &target
		 withName: NULL];

  if ([self includesLocalTarget: target] == nil)
    {
      GSLocalCounter	*counter;

      counter = (GSLocalCounter*)[[self class] includesLocalTarget: target];
      if (counter != nil)
	[NSDistantObject proxyWithLocal: counter->object connection: self];
    }

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
  [op encodeValueOfObjCType:":"
      at:&sel
      withName:NULL];
  [op encodeValueOfCType:@encode(unsigned)
      at:&target
      withName:NULL];
  [op dismiss];
  ip = [self _getReceivedReplyRmcWithSequenceNumber:seq_num];
  [ip decodeValueOfCType:@encode(char*)
      at:&type
      withName:NULL];
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

  [rmc decodeValueOfObjCType:":"
       at:&sel
       withName:NULL];
  [rmc decodeValueOfCType:@encode(unsigned)
       at:&target
       withName:NULL];
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
  [op encodeValueOfCType:@encode(char*)
      at:&type
      withName:@"Requested Method Type for Target"];
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
  NSConnection*	conn = [[rmc connection] retain];

  switch ([rmc identifier])
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
	 if independant_queuing is NO. */
      if (reply_depth == 0 || independant_queueing == NO)
	{
	  [self retain];
	  [conn _service_forwardForProxy: rmc];
	  /* Service any requests that were queued while we
	     were waiting for replies.
	     xxx Is this the right place for this check? */
	  if (reply_depth == 0)
	    [self _handleQueuedRmcRequests];
	  [self release];
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
      [conn release];
      [NSException raise: NSGenericException
		   format: @"unrecognized NSPortCoder identifier"];
    }
  [conn release];
}

- (void) _handleQueuedRmcRequests
{
  id rmc;

  [received_request_rmc_queue_gate lock];
  while (is_valid && ([received_request_rmc_queue count] > 0))
    {
      rmc = [received_request_rmc_queue objectAtIndex: 0];
      [received_request_rmc_queue removeObjectAtIndex: 0];
      [received_request_rmc_queue_gate unlock];
      [self _handleRmc: rmc];
      [received_request_rmc_queue_gate lock];
    }
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

  reply_depth++;
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
  reply_depth--;
  if (rmc == nil)
    [NSException raise: NSPortTimeoutException
		 format: @"timed out waiting for reply"];
  return rmc;
}

/* Sneaky, sneaky.  See "sneaky" comment in TcpPort.m.
   This method is called by InPort when it receives a new packet. */
+ (void) invokeWithObject: packet
{
  id rmc = [NSPortCoder
	     newDecodingWithPacket: packet
	     connection: NSMapGet (receive_port_2_ancestor,
				   [packet receivingInPort])];
  [[rmc connection] _handleRmc: rmc];
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
  /* This retains anObj. */
  NSMapInsert(local_objects, (void*)object, anObj);

  /*
   *	Keep track of local objects accross all connections.
   */
  counter = NSMapGet(all_connections_local_targets, (void*)target);
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
    NSLog(@"add local object (0x%x) to connection (0x%x) (ref %d)\n",
		(unsigned)object, (unsigned) self, counter->ref);
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
  id c;
  int i, count = [connection_array count];

  /* Don't assert (is_valid); */
  for (i = 0; i < count; i++)
    {
      c = [connection_array objectAtIndex:i];
      [c removeLocalObject: anObj];
      [c removeProxy: anObj];
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
	  NSMapRemove(all_connections_local_objects, (void*)anObj);
	  NSMapRemove(all_connections_local_targets, (void*)target);
	  /*
	   *	If this proxy has been vended onwards by another process, we
	   *	need to keep a reference to the local object around for a
	   *	while in case that other process needs it.
	   */
	  if ([prox isVended])
	    {
	      id	item;
	      if (timer == nil)
		{
		  timer = [NSTimer scheduledTimerWithTimeInterval: 1.0
					 target: [NSConnection class]
					 selector: @selector(_timeout:)
					 userInfo: nil
					  repeats: YES];
		}
	      item = [CachedLocalObject itemWithObject: counter time: 30];
	      NSMapInsert(all_connections_local_cached, (void*)target, item);
	    }
	}
    }

  NSMapRemove(local_objects, (void*)anObj);
  NSMapRemove(local_targets, (void*)target);

  if (debug_connection > 2)
    NSLog(@"remove local object (0x%x) to connection (0x%x) (ref %d)\n",
		(unsigned)anObj, (unsigned) self, val);

  [proxiesHashGate unlock];
}

- (void) _release_targets: (NSDistantObject**)list count:(unsigned int)number
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
	  unsigned int 	i;

	  op = [[self encodingClass]
		  newForWritingWithConnection: self
			       sequenceNumber: [self _newMsgNumber]
				   identifier: PROXY_RELEASE];

	  [op encodeValueOfCType: @encode(typeof(number))
			      at: &number
			withName: NULL];

	  for (i = 0; i < number; i++) {
	      unsigned	target = [list[i] targetForProxy];
	      char	vended = [list[i] isVended];

	      [op encodeValueOfCType: @encode(typeof(target))
				  at: &target
			    withName: NULL];
	      [op encodeValueOfCType: @encode(char)
				  at: &vended
			    withName: NULL];
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
	  unsigned int 	i;
	  int seq_num = [self _newMsgNumber];

	  op = [[self encodingClass]
		  newForWritingWithConnection: self
			       sequenceNumber: seq_num
				   identifier: PROXY_RETAIN];

	  [op encodeValueOfCType: @encode(typeof(target))
			      at: &target
			withName: NULL];

	  [op dismiss];
	}
    }
  NS_HANDLER
    {
      if (debug_connection)
        NSLog(@"failed to retain target - %@\n", [localException name]);
    }
  NS_ENDHANDLER
}

- (void) removeProxy: (NSDistantObject*)aProxy
{
    unsigned target = (unsigned)[aProxy targetForProxy];

    /* Don't assert (is_valid); */
    [proxiesHashGate lock];
    /* This also releases aProxy */
    NSMapRemove (remote_proxies, (void*)target);
    [proxiesHashGate unlock];

    /*
     *	Tell the remote application that we have removed our proxy and
     *	it can release it's local object.
     */
    [self _release_targets:&aProxy count:1];
}

- (NSArray *) localObjects
{
  id c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues (local_objects);
  [proxiesHashGate unlock];
  return c;
}

- (NSArray *) proxies
{
  id c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues (remote_proxies);
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
    [NSException raise: NSGenericException
		 format: @"Trying to add the same proxy twice"];
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
  if (ret == nil) {
    ret = NSMapGet (all_connections_local_cached, (void*)target);
  }
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
  ro = [root_object_dictionary objectForKey:aPort];
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


/* Support for cross-connection const-ptr cache. */

- (unsigned) _encoderCreateReferenceForConstPtr: (const void*)ptr
{
  unsigned xref;

  NSParameterAssert (is_valid);
  /* This must match the assignment of xref in _decoderCreateRef... */
  xref = NSCountMapTable (outgoing_const_ptr_2_xref) + 1;
  NSParameterAssert (! NSMapGet (outgoing_const_ptr_2_xref, (void*)xref));
  NSMapInsert (outgoing_const_ptr_2_xref, ptr, (void*)xref);
  return xref;
}

- (unsigned) _encoderReferenceForConstPtr: (const void*)ptr
{
  NSParameterAssert (is_valid);
  return (unsigned) NSMapGet (outgoing_const_ptr_2_xref, ptr);
}

- (unsigned) _decoderCreateReferenceForConstPtr: (const void*)ptr
{
  unsigned xref;

  NSParameterAssert (is_valid);
  /* This must match the assignment of xref in _encoderCreateRef... */
  xref = NSCountMapTable (incoming_xref_2_const_ptr) + 1;
  NSMapInsert (incoming_xref_2_const_ptr, (void*)xref, ptr);
  return xref;
}

- (const void*) _decoderConstPtrAtReference: (unsigned)xref
{
  NSParameterAssert (is_valid);
  return NSMapGet (incoming_xref_2_const_ptr, (void*)xref);
}



/* Prevent trying to encode the connection itself */

- (void) encodeWithCoder: anEncoder
{
  [self shouldNotImplement:_cmd];
}

+ newWithCoder: aDecoder;
{
  [self shouldNotImplement:_cmd];
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
    if (is_valid) {
	id port = [notification object];

	if (debug_connection)
	    NSLog(@"Received port invalidation notification for "
		@"connection 0x%x\n\t%@\n", (unsigned)self,
		[port description]);

	/* We shouldn't be getting any port invalidation notifications,
	    except from our own ports; this is how we registered ourselves
	    with the NotificationDispatcher in
	    +newForInPort:outPort:ancestorConnection. */
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

    c = [self newForInPort:r outPort:s ancestorConnection:nil];
    return [c autorelease];
}

- initWithReceivePort: (NSPort*)r
	     sendPort: (NSPort*)s
{
    [self dealloc];
    return [NSConnection newForInPort:r outPort:s ancestorConnection:nil];
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


/* Notification Strings. */

NSString *NSConnectionDidDieNotification
= @"NSConnectionDidDieNotification";

NSString *NSConnectionDidInitializeNotification
= @"NSConnectionDidInitializeNotification";

