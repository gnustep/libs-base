/* Implementation of connection object for remote object messaging
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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
   Integrate with NSRunLoop
   Pass exceptions back to client.
   Find bug with proxies of invalidated connections.
   Make it thread-safe.
   Support @"*" hostname.
   */

/* RMC == Remote Method Coder, or Remote Method Call.
   It's an instance of ConnectedEncoder or ConnectedDecoder. */

#include <gnustep/base/preface.h>
#include <gnustep/base/Connection.h>
#include <gnustep/base/Proxy.h>
#include <gnustep/base/ConnectedCoder.h>
#include <gnustep/base/TcpPort.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Dictionary.h>
#include <gnustep/base/Queue.h>
#include <gnustep/base/mframe.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/RunLoop.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <assert.h>

@interface Connection (GettingCoderInterface)
- (void) _handleRmc: rmc;
- (void) _handleQueuedRmcRequests;
- _getReceivedReplyRmcWithSequenceNumber: (int)n;
- newSendingRequestRmc;
- newSendingReplyRmcWithSequenceNumber: (int)n;
- (int) _newMsgNumber;
@end

@interface Connection (Private)
- _superInit;
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
static id default_in_port_class;
static id default_out_port_class;
static id default_proxy_class;
static id default_encoding_class;
static id default_decoding_class;
static int default_in_timeout;
static int default_out_timeout;

static int debug_connection = 0;

/* Perhaps this should be a hashtable, keyed by remote port.
   But we may also need to include the local port---even though 
   when receiving the local port is fixed, there may be more than
   one registered connection (with different in ports) in the
   application. */
/* We could write -hash and -isEqual implementations for Connection */
static Array *connection_array;
static Lock *connection_array_gate;

static Dictionary *root_object_dictionary;
static Lock *root_object_dictionary_gate;

static NSMapTable *in_port_2_ancestor;

static NSMapTable *all_connections_local_targets = NULL;

/* rmc handling */
static Queue *received_request_rmc_queue;
static Lock *received_request_rmc_queue_gate;
static Queue *received_reply_rmc_queue;
static Lock *received_reply_rmc_queue_gate;

static int messages_received_count;

@implementation Connection

+ (void) initialize
{
  connection_array = [[Array alloc] init];
  connection_array_gate = [Lock new];
  /* xxx When NSHashTable's are working, change this. */
  all_connections_local_targets =
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  received_request_rmc_queue = [[Queue alloc] init];
  received_request_rmc_queue_gate = [Lock new];
  received_reply_rmc_queue = [[Queue alloc] init];
  received_reply_rmc_queue_gate = [Lock new];
  root_object_dictionary = [[Dictionary alloc] init];
  root_object_dictionary_gate = [Lock new];
  in_port_2_ancestor = 
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  messages_received_count = 0;
  default_in_port_class = [TcpInPort class];
  default_out_port_class = [TcpOutPort class];
  default_proxy_class = [Proxy class];
  default_encoding_class = [ConnectedEncoder class];
  default_decoding_class = [ConnectedDecoder class];
  default_in_timeout = CONNECTION_DEFAULT_TIMEOUT;
  default_out_timeout = CONNECTION_DEFAULT_TIMEOUT;
}


/* Getting and setting class variables */

+ (void) setDefaultInPortClass: (Class)aClass
{
  default_in_port_class = aClass;
}

+ (Class) defaultInPortClass
{
  return default_in_port_class;
}

+ (void) setDefaultOutPortClass: (Class)aClass
{
  default_out_port_class = aClass;
}

+ (Class) defaultOutPortClass
{
  return default_out_port_class;
}

+ (void) setDefaultProxyClass: (Class)aClass
{
  default_proxy_class = aClass;
}

+ (Class) defaultProxyClass
{
  return default_proxy_class;
}

+ (void) setDefaultDecodingClass: (Class) aClass
{
  default_decoding_class = aClass;
}

+ (Class) default_decoding_class
{
  return default_decoding_class;
}

+ (int) defaultOutTimeout
{
  return default_out_timeout;
}

+ (void) setDefaultOutTimeout: (int)to
{
  default_out_timeout = to;
}

+ (int) defaultInTimeout
{
  return default_in_timeout;
}

+ (void) setDefaultInTimeout: (int)to
{
  default_in_timeout = to;
}


/* Class-wide stats and collections. */

+ (int) messagesReceived
{
  return messages_received_count;
}

+ (id <Collecting>) allConnections
{
  return [connection_array copy];
}

+ (unsigned) connectionsCount
{
  return [connection_array count];
}

+ (unsigned) connectionsCountWithInPort: (InPort*)aPort
{
  unsigned count = 0;
  id o;
  [connection_array_gate lock];
  FOR_ARRAY (connection_array, o)
    {
      if ([aPort isEqual: [o inPort]])
	count++;
    }
  END_FOR_ARRAY (connection_array);
  [connection_array_gate unlock];
  return count;
}


/* Creating and initializing connections. */

- init
{
  id newPort = [default_in_port_class newForReceiving];
  id newConn = 
    [Connection newForInPort:newPort outPort:nil ancestorConnection:nil];
  [self release];
  return newConn;
}

+ new
{
  id newPort = [default_in_port_class newForReceiving];
  id newConn = 
    [Connection newForInPort:newPort outPort:nil ancestorConnection:nil];
  return newConn;
}

+ (Connection*) newWithRootObject: anObj;
{
  id newPort;
  id newConn;

  newPort = [default_in_port_class newForReceiving];
  newConn = [self newForInPort:newPort outPort:nil
		  ancestorConnection:nil];
  [self setRootObject:anObj forInPort:newPort];
  return newConn;
}

/* I want this method name to clearly indicate that we're not connecting
   to a pre-existing registration name, we're registering a new name,
   and this method will fail if that name has already been registered. 
   This is why I don't like "newWithRegisteredName:" --- it's unclear 
   if we're connecting to another Connection that already registered 
   with that name. */

+ (Connection*) newRegisteringAtName: (id <String>)n withRootObject: anObj
{
  id newPort;
  id newConn;

  newPort = [default_in_port_class newForReceivingFromRegisteredName: n];
  newConn = [self newForInPort:newPort outPort:nil
		  ancestorConnection:nil];
  [self setRootObject:anObj forInPort:newPort];
  return newConn;
}

+ (Proxy*) rootProxyAtName: (id <String>)n
{
  return [self rootProxyAtName: n onHost: @""];
}

+ (Proxy*) rootProxyAtName: (id <String>)n onHost: (id <String>)h
{
  id p = [default_out_port_class newForSendingToRegisteredName: n onHost: h];
  return [self rootProxyAtPort: p];
}

+ (Proxy*) rootProxyAtPort: (OutPort*)anOutPort
{
  id newInPort = [default_in_port_class newForReceiving];
  return [self rootProxyAtPort: anOutPort withInPort: newInPort];
}

+ (Proxy*) rootProxyAtPort: (OutPort*)anOutPort withInPort: (InPort*)anInPort
{
  Connection *newConn = [self newForInPort:anInPort
				outPort:anOutPort
				ancestorConnection:nil];
  Proxy *newRemote;

  newRemote = [newConn rootProxy];
  return newRemote;
}



/* This is the designated initializer for Connection */

+ (Connection*) newForInPort: (InPort*)ip outPort: (OutPort*)op
   ancestorConnection: ancestor
{
  Connection *newConn;
  int i, count;
  id newConnInPort, newConnOutPort;
 
  NSParameterAssert (ip);

  [connection_array_gate lock];

  /* Find previously existing connection if there */
  /* xxx Clean this up */
  count = [connection_array count];
  for (i = 0; i < count; i++)
    {
      newConn = [connection_array objectAtIndex: i];
      newConnInPort = [newConn inPort];
      newConnOutPort = [newConn outPort];
      if ([newConnInPort isEqual: ip]
	  && [newConnOutPort isEqual: op])
	{
	  [connection_array_gate unlock];
	  return newConn;
	}
    }

  newConn = [[Connection alloc] _superInit];
  if (debug_connection)
    fprintf(stderr, "Created new connection 0x%x\n\t%s\n\t%s\n", 
	    (unsigned)newConn, 
	    [[ip description] cStringNoCopy], 
	    [[op description] cStringNoCopy]);
  newConn->is_valid = 1;
  newConn->in_port = ip;
  [ip retain];
  newConn->out_port = op;
  [op retain];
  newConn->message_count = 0;

  /* This maps (void*)obj to (id)obj.  The obj's are retained.
     We use this instead of an NSHashTable because we only care about
     the object's address, and don't want to send the -hash message to it. */
  newConn->local_targets = 
    NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

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

  newConn->in_timeout = [self defaultInTimeout];
  newConn->out_timeout = [self defaultOutTimeout];
  newConn->encoding_class = default_encoding_class;

  /* xxx ANCESTOR argument is currently ignored; in the future it
     will be removed. */
  /* xxx It this the correct behavior? */
  if (!(ancestor = NSMapGet (in_port_2_ancestor, ip)))
    {
      NSMapInsert (in_port_2_ancestor, ip, newConn);
      [[RunLoop currentInstance] addPort: ip 
				 forMode: RunLoopDefaultMode];
      [[RunLoop currentInstance] addPort: ip 
				 forMode: RunLoopConnectionReplyMode];
      /* This will cause the connection with the registered name
	 to receive the -invokeWithObject: from the IN_PORT.
	 This ends up being the ancestor of future new Connections
	 on this in port. */
      /* xxx Could it happen that this connection was invalidated, but
	 the others would still be OK?  That would cause problems.
	 No.  I don't think that can happen. */
      [ip setReceivedPacketInvocation: (id)[self class]];
    }

  if (ancestor)
    {
      newConn->in_port_class = [ancestor inPortClass];
      newConn->out_port_class = [ancestor outPortClass];
    }
  else
    {
      newConn->in_port_class = default_in_port_class;
      newConn->out_port_class = default_out_port_class;
    }
  newConn->delay_dialog_interruptions = YES;
  newConn->reply_depth = 0;
  newConn->delegate = nil;

  /* Here ask the delegate for permission. */
  /* delegate is responsible for freeing newConn if it returns something
     different. */
  if ([[ancestor delegate] respondsTo:@selector(connection:didConnect:)])
    newConn = [[ancestor delegate] connection:ancestor
	       didConnect:newConn];

  /* Register outselves for invalidation notification when the 
     ports become invalid. */
  [NotificationDispatcher addObserver: newConn
			  selector: @selector(portIsInvalid:)
			  name: PortBecameInvalidNotification
			  object: ip];
  if (op)
    [NotificationDispatcher addObserver: newConn
			    selector: @selector(portIsInvalid:)
			    name: PortBecameInvalidNotification
			    object: op];
  /* if OP is nil, making this notification request would have 
     registered us to receive all PortBecameInvalidNotification
     requests, independent of which port posted them.  This isn't 
     what we want. */

  /* xxx This is weird, though.  When will newConn ever get dealloc'ed?
     connectionArray will retain it, but connectionArray will never get
     deallocated.  This sort of retain/release cirularity must be common
     enough.  Think about this and fix it. */
  [connection_array addObject: newConn];

  [connection_array_gate unlock];

  [NotificationDispatcher 
    postNotificationName: ConnectionWasCreatedNotification
    object: newConn];

  return newConn;
}

- _superInit
{
  [super init];
  return self;
}


/* Creating new rmc's for encoding requests and replies */

/* Create a new, empty rmc, which will be filled with a request. */
- newSendingRequestRmc
{
  id rmc;

  NSParameterAssert(in_port);
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

/* Proxy's -forward:: method calls this to the the message over the wire. */
- (retval_t) forwardForProxy: (Proxy*)object 
		    selector: (SEL)sel 
                    argFrame: (arglist_t)argframe
{
  ConnectedEncoder *op;

  /* The callback for encoding the args of the method call. */
  void encoder (int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_ARGNAME @"argument value"
      switch (*type)
	{
	case _C_ID:
	  if (flags & _F_BYCOPY)
	    [op encodeBycopyObject: *(id*)datum withName: ENCODED_ARGNAME];
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
    op = [self newSendingRequestRmc];
    seq_num = [op sequenceNumber];

    /* get the method types from the selector */
#if NeXT_runtime
    [NSException 
      raise: NSGenericException
      format: @"Sorry, distributed objects does not work with NeXT runtime"];
    /* type = [object selectorTypeForProxy:sel]; */
#else
    type = sel_get_type(sel);
#endif
    NSParameterAssert(type);
    NSParameterAssert(*type);

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
    
    /* Get the reply rmc, and decode it. */
    {
      ConnectedDecoder *ip = nil;
      int last_argnum;
      BOOL is_exception;

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  NSParameterAssert(ip != (id)-1);
	  /* If we didn't get the reply packet yet, get it now. */
	  if (!ip)
	    {
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
		  /* xxx Is there anything else to clean up in
		     dissect_method_return()? */
		  [exc raise];
		}
	    }
	  [ip decodeValueOfObjCType: type at: datum withName: NULL];
	  /* -decodeValueOfCType:at:withName: malloc's new memory
	     for char*'s.  We need to make sure it gets freed eventually
	     so we don't have a memory leak.  Request here that it be
	     autorelease'ed. */
	  if (*type == _C_CHARPTR)
	    [MallocAddress autoreleaseMallocAddress: *(char**)datum];
	  if (argnum == last_argnum)
	    {
	      /* this must be here to avoid trashing alloca'ed retframe */
	      [ip dismiss]; 	
	      ip = (id)-1;
	    }
	}

      last_argnum = type_get_number_of_arguments(type) - 1;
      retframe = mframe_build_return (argframe, type, out_parameters,
				      decoder);
      return retframe;
    }
  }
}

/* Connection calls this to service the incoming method request. */
- (void) _service_forwardForProxy: aRmc
{
  char *forward_type;
  id op = nil;
  int reply_sequence_number;
  int numargs;

  void decoder (int argnum, void *datum, const char *type)
    {
      [aRmc decodeValueOfObjCType:type
	    at:datum
	    withName:NULL];
      /* -decodeValueOfCType:at:withName: malloc's new memory
	 for char*'s.  We need to make sure it gets freed eventually
	 so we don't have a memory leak.  Request here that it be
	 autorelease'ed. */
      if (*type == _C_CHARPTR)
	[MallocAddress autoreleaseMallocAddress: *(char**)datum];
      /* We need this "dismiss" to happen here and not later so that Coder
	 "-awake..." methods will get sent before the __builtin_apply! */
      if (argnum == numargs-1)
	[aRmc dismiss];
    }

  void encoder (int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_RETNAME @"return value"
      if (op == nil)
	{
	  BOOL is_exception = NO;
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

      numargs = type_get_number_of_arguments(forward_type);
      
      mframe_do_call (forward_type, decoder, encoder);
      [op dismiss];
    }

  /* Make sure we pass all exceptions back to the requestor. */
  NS_HANDLER
    {
      BOOL is_exception = YES;
      /* Try to clean up a little. */
      if (op)
	[op release];

      /* Send the exception back to the client. */
      op = [self newSendingReplyRmcWithSequenceNumber: reply_sequence_number];
      [op encodeValueOfCType: @encode(BOOL)
	  at: &is_exception
	  withName: @"Exceptional reply flag"];
      [op encodeBycopyObject: localException
	  withName: @"Exception object"];
      [op dismiss];
    }
  NS_ENDHANDLER;

  if (forward_type)
    (*objc_free) (forward_type);
}

- (Proxy*) rootProxy
{
  id op, ip;
  Proxy *newProxy;
  int seq_num = [self _newMsgNumber];

  NSParameterAssert(in_port);
  NSParameterAssert (is_valid);
  op = [[self encodingClass]
	newForWritingWithConnection: self
	sequenceNumber: seq_num
	identifier: ROOTPROXY_REQUEST];
  [op dismiss];
  ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
  [ip decodeObjectAt: &newProxy withName: NULL];
  NSParameterAssert (class_is_kind_of (newProxy->isa, objc_get_class ("Proxy")));
  [ip dismiss];
  return newProxy;
}

- (void) _service_rootObject: rmc
{
  id rootObject = [Connection rootObjectForInPort:in_port];
  ConnectedEncoder* op = [[self encodingClass]
			newForWritingWithConnection: [rmc connection]
			sequenceNumber: [rmc sequenceNumber]
			identifier: ROOTPROXY_REPLY];
  NSParameterAssert (in_port);
  NSParameterAssert (is_valid);
  /* Perhaps we should turn this into a class method. */
  NSParameterAssert([rmc connection] == self);
  [op encodeObject: rootObject withName: @"root object"];
  [op dismiss];
}

- (void) shutdown
{
  id op;

  NSParameterAssert(in_port);
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
  [self dealloc];		// xxx release instead?  YES!!
  [rmc dismiss];
}

- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target
{
  id op, ip;
  char *type;
  int seq_num;

  NSParameterAssert(in_port);
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
  ConnectedEncoder* op;
  unsigned target;
  SEL sel;
  const char *type;
  struct objc_method* m;

  NSParameterAssert(in_port);
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
  /* xxx We should make sure that TARGET is a valid object. */
  /* Not actually a Proxy, but we avoid the warnings "id" would have made. */
  m = class_get_instance_method(((Proxy*)target)->isa, sel);
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
}


/* Running the connection, getting/sending requests/replies. */

- (void) runConnectionUntilDate: date
{
  [RunLoop runUntilDate: date];
}

- (void) runConnection
{
  [self runConnectionUntilDate: [NSDate distantFuture]];
}

- (void) _handleRmc: rmc
{
  switch ([rmc identifier])
    {
    case ROOTPROXY_REQUEST:
      /* It won't take much time to handle this, so go ahead and service
	 it, even if we are waiting for a reply. */
      [[rmc connection] _service_rootObject: rmc];
      [rmc dismiss];
      break;
    case METHODTYPE_REQUEST:
      /* It won't take much time to handle this, so go ahead and service
	 it, even if we are waiting for a reply. */
      [[rmc connection] _service_typeForSelector: rmc];
      [rmc dismiss];
      break;
    case METHOD_REQUEST:
      /* We just got a new request; we need to decide whether to queue
	 it or service it now.
	 If the REPLY_DEPTH is 0, then we aren't in the middle of waiting
	 for a reply, we are waiting for requests---so service it now.
	 If REPLY_DEPTH is non-zero, we may still want to service it now
	 if it is a request made as a callback from our peer---the request
	 is part of the remote code necessary to finish calculating our
	 reply; we know it's a callback from our peer if the [RMC CONNECTION]
	 is self.
	 If REPLY_DEPTH is non-zero, and the [RMC CONNECTION] is not self,
	 then we may still want to service it now if DELAY_DIALOG_INTERRUPTIONS
	 is false. */
      if (reply_depth == 0
	  || [rmc connection] == self
	  || !delay_dialog_interruptions)
	{
	  [[rmc connection] _service_forwardForProxy: rmc];
	  /* Service any requests that were queued while we
	     were waiting for replies.
	     xxx Is this the right place for this check? */
	  if (reply_depth == 0)
	    [self _handleQueuedRmcRequests];
	}
      else
	{
	  [received_request_rmc_queue_gate lock];
	  [received_request_rmc_queue enqueueObject: rmc];
	  [received_request_rmc_queue_gate unlock];
	}
      break;
    case ROOTPROXY_REPLY:
    case METHOD_REPLY:
    case METHODTYPE_REPLY:
      /* Remember multi-threaded callbacks will have to be handled specially */
      [received_reply_rmc_queue_gate lock];
      [received_reply_rmc_queue enqueueObject: rmc];
      [received_reply_rmc_queue_gate unlock];
      break;
    case CONNECTION_SHUTDOWN:
      {
	[[rmc connection] _service_shutdown: rmc forConnection: self];
	break;
      }
    default:
      [NSException raise: NSGenericException
		   format: @"unrecognized ConnectedDecoder identifier"];
    }
}

- (void) _handleQueuedRmcRequests
{
  id rmc;

  [received_request_rmc_queue_gate lock];
  while ((rmc = [received_request_rmc_queue dequeueObject]))
    {
      [received_request_rmc_queue_gate unlock];
      [self _handleRmc: rmc];
      [received_request_rmc_queue_gate lock];
    }
  [received_request_rmc_queue_gate unlock];
}

/* Deal with an RMC, either by queuing it for later service, or
   by servicing it right away.  This method is called by the
   in_port's received-packet-invocation. */

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
	    printf("Getting received reply from queue\n");
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
   while we run the RunLoop.  Return nil if we don't get anything
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
			 initWithTimeIntervalSinceNow: in_timeout];
      [RunLoop runOnceBeforeDate: timeout_date 
	       forMode: RunLoopConnectionReplyMode];
    }
  reply_depth--;
  return rmc;
}

/* Sneaky, sneaky.  See "sneaky" comment in TcpPort.m.
   This method is called by InPort when it receives a new packet. */
+ (void) invokeWithObject: packet
{
  id rmc = [ConnectedDecoder 
	     newDecodingWithPacket: packet
	     connection: NSMapGet (in_port_2_ancestor, 
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
  NSParameterAssert (is_valid);
  [proxiesHashGate lock];
  /* xxx Do we need to check to make sure it's not already there? */
  /* This retains anObj. */
  NSMapInsert (local_targets, (void*)anObj, anObj);
  /* This does not retain anObj. */
  NSMapInsert (all_connections_local_targets, (void*)anObj, anObj);
  [proxiesHashGate unlock];
}

/* This should get called whenever an object free's itself */
+ (void) removeLocalObject: anObj
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
  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  /* This also releases anObj */
  NSMapRemove (local_targets, (void*)anObj);
  NSMapRemove (all_connections_local_targets, (void*)anObj);
  [proxiesHashGate unlock];
}

- (void) removeProxy: (Proxy*)aProxy
{
  unsigned target = [aProxy targetForProxy];

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  /* This also releases aProxy */
  NSMapRemove (remote_proxies, (void*)target);
  [proxiesHashGate unlock];
}

- (id <Collecting>) localObjects
{
  id c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues (local_targets);
  [proxiesHashGate unlock];
  return c;
}

- (id <Collecting>) proxies
{
  id c;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  c = NSAllMapTableValues (remote_proxies);
  [proxiesHashGate unlock];
  return c;
}

- (Proxy*) proxyForTarget: (unsigned)target
{
  Proxy *p;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  p = NSMapGet (remote_proxies, (void*)target);
  [proxiesHashGate unlock];
  NSParameterAssert(!p || [p connectionForProxy] == self);
  return p;
}

- (void) addProxy: (Proxy*) aProxy
{
  unsigned target = [aProxy targetForProxy];

  NSParameterAssert (is_valid);
  NSParameterAssert(aProxy->isa == [Proxy class]);
  NSParameterAssert([aProxy connectionForProxy] == self);
  [proxiesHashGate lock];
  if (NSMapGet (remote_proxies, (void*)target))
    [NSException raise: NSGenericException
		 format: @"Trying to add the same proxy twice"];
  NSMapInsert (remote_proxies, (void*)target, aProxy);
  [proxiesHashGate unlock];
}

- (BOOL) includesProxyForTarget: (unsigned)target
{
  BOOL ret;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  ret = NSMapGet (remote_proxies, (void*)target) ? YES : NO;
  [proxiesHashGate unlock];
  return ret;
}

- (BOOL) includesLocalObject: anObj
{
  BOOL ret;

  /* Don't assert (is_valid); */
  [proxiesHashGate lock];
  ret = NSMapGet (local_targets, (void*)anObj) ? YES : NO;
  [proxiesHashGate unlock];
  return ret;
}

/* Check all connections.  
   Proxy needs to use this when decoding a local object in order to
   make sure the target address is a valid object.  It is not enough
   for the Proxy to check the Proxy's connection only (using
   -includesLocalObject), because the proxy may have come from a
   triangle connection. */
+ (BOOL) includesLocalObject: anObj
{
  BOOL ret;

  /* Don't assert (is_valid); */
  NSParameterAssert (all_connections_local_targets);
  [proxiesHashGate lock];
  ret = NSMapGet (all_connections_local_targets, (void*)anObj) ? YES : NO;
  [proxiesHashGate unlock];
  return ret;
}


/* Pass nil to remove any reference keyed by aPort. */
+ (void) setRootObject: anObj forInPort: (InPort*)aPort
{
  id oldRootObject = [self rootObjectForInPort: aPort];

  NSParameterAssert ([aPort isValid]);
  /* xxx This retains aPort?  How will aPort ever get dealloc'ed? */
  if (oldRootObject != anObj)
    {
      if (anObj)
	{
	  [root_object_dictionary_gate lock];
	  [root_object_dictionary putObject: anObj atKey: aPort];
	  [root_object_dictionary_gate unlock];
	}
      else /* anObj == nil && oldRootObject != nil */
	{
	  [root_object_dictionary_gate lock];
	  [root_object_dictionary removeObjectAtKey: aPort];
	  [root_object_dictionary_gate unlock];
	}
    }
}  

+ rootObjectForInPort: (InPort*)aPort
{
  id ro;

  [root_object_dictionary_gate lock];
  ro = [root_object_dictionary objectAtKey:aPort];
  [root_object_dictionary_gate unlock];
  return ro;
}

- setRootObject: anObj
{
  [[self class] setRootObject: anObj forInPort: in_port];
  return self;
}

- rootObject
{
  return [[self class] rootObjectForInPort: in_port];
}


/* Accessing ivars */

- (int) outTimeout
{
  return out_timeout;
}

- (int) inTimeout
{
  return in_timeout;
}

- (void) setOutTimeout: (int)to
{
  out_timeout = to;
}

- (void) setInTimeout: (int)to
{
  in_timeout = to;
}

- (Class) inPortClass
{
  return in_port_class;
}

- (Class) outPortClass
{
  return out_port_class;
}

- (void) setInPortClass: (Class) aPortClass
{
  in_port_class = aPortClass;
}

- (void) setOutPortClass: (Class) aPortClass
{
  out_port_class = aPortClass;
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

- outPort
{
  return out_port;
}

- inPort
{
  return in_port;
}

- delegate
{
  return delegate;
}

- (void) setDelegate: anObj
{
  delegate = anObj;
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

/* We register this method with NotificationDispatcher for when a port dies. */
- (void) portIsInvalid: notification
{
  id port = [notification object];

  NSParameterAssert (is_valid);
  if (debug_connection)
    fprintf (stderr, "Received port invalidation notification for "
	     "connection 0x%x\n\t%s\n", (unsigned)self,
	     [[port description] cStringNoCopy]);
  /* We shouldn't be getting any port invalidation notifications,
     except from our own ports; this is how we registered ourselves
     with the NotificationDispatcher in 
     +newForInPort:outPort:ancestorConnection. */
  NSParameterAssert (port == in_port || port == out_port);

  /* xxx This also needs to be done properly in cases where the
     Connection invalidates itself. */
  /* Remove ourselves from the in_port_2_ancestor, if necessary. */
  {
    id ancestor;
    if ([port isKindOfClass: [InPort class]]
	&& (self == (ancestor = NSMapGet (in_port_2_ancestor, port))))
      NSMapRemove (in_port_2_ancestor, port);
  }
  [self invalidate];
  /* xxx Anything else? */
}

/* xxx This needs locks */
- (void) invalidate
{
  if (is_valid)
    {
      is_valid = 0;

      /* xxx Note: this is causing us to send a shutdown message
	 to the connection that shut *us* down.  Don't do that. 
	 Well, perhaps it's a good idea just in case other side didn't really
	 send us the shutdown; this way we let them know we're going away */
#if 0
      [self shutdown];
#endif

      if (debug_connection)
	fprintf(stderr, "Invalidating connection 0x%x\n\t%s\n\t%s\n", 
		(unsigned)self,
		[[in_port description] cStringNoCopy], 
		[[out_port description] cStringNoCopy]);

      [NotificationDispatcher 
	postNotificationName: ConnectionBecameInvalidNotification
	object: self];
      /* xxx Anything else? */
      /* xxx Yes, somehow Proxies of connections with invalid ports
	 are being asked to encode themselves. */
    }
}

- (BOOL) isValid
{
  return is_valid;
}

/* This needs locks */
- (void) dealloc
{
  if (debug_connection)
    printf("deallocating 0x%x\n", (unsigned)self);
  [self invalidate];
  [connection_array removeObject: self];
  /* Remove rootObject from root_object_dictionary
     if this is last connection */
  if (![Connection connectionsCountWithInPort:in_port])
    [Connection setRootObject:nil forInPort:in_port];
  [NotificationDispatcher removeObserver: self];
  [in_port release];
  [out_port release];

  [proxiesHashGate lock];
  NSFreeMapTable (remote_proxies);
  NSFreeMapTable (local_targets);
  NSFreeMapTable (incoming_xref_2_const_ptr);
  NSFreeMapTable (outgoing_const_ptr_2_xref);
  [proxiesHashGate unlock];

  [super dealloc];
}

@end


/* Notification Strings. */

NSString *ConnectionBecameInvalidNotification 
= @"ConnectionBecameInvalidNotification";

NSString *ConnectionWasCreatedNotification 
= @"ConnectionWasCreatedNotification";


/* RunLoop modes */
NSString *RunLoopConnectionReplyMode
= @"RunLoopConnectionReplyMode";
