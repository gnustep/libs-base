/* Implementation of connection object for remote object messaging
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
   This file is part of the GNU Objective C Class Library.

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

/* RMC == Remote Method Coder, or Remote Method Call.
   It's an instance of ConnectedCoder. */

#include <objects/stdobjects.h>
#include <objects/Connection.h>
#include <objects/Proxy.h>
#include <objects/ConnectedCoder.h>
#include <objects/SocketPort.h>
#include <objects/Array.h>
#include <objects/Dictionary.h>
#include <objects/Queue.h>
#include <objects/mframe.h>
#include <foundation/NSString.h>
#include <assert.h>

@interface Connection (GettingCoderInterface)
- doReceivedRequestsWithTimeout: (int)to;
- newReceivedReplyRmcWithSequenceNumber: (int)n;
- newSendingRequestRmc;
- newSendingReplyRmcWithSequenceNumber: (int)n;
- (int) _newMsgNumber;
@end

#define proxiesHashGate refGate
#define sequenceNumberGate refGate

static inline BOOL class_is_kind_of(Class self, Class aClassObject)
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

static elt
exc_func_return_nil (arglist_t af) { return nil; }

/* class defaults */
static id default_port_class;
static id defaultProxyClass;
static id defaultCoderClass;
static int default_in_timeout;
static int default_out_timeout;

static BOOL debug_connection = NO;

/* Perhaps this should be a hashtable, keyed by remote port.
   But we may also need to include the local port---even though 
   when receiving the local port is fixed, there may be more than
   one registered connection (with different in ports) in the
   application. */
/* We could write -hash and -isEqual implementations for Connection */
static Array *connectionArray;
static Lock *connectionArrayGate;

static Dictionary *rootObjectDictionary;
static Lock *rootObjectDictionaryGate;

/* rmc handling */
static Queue *receivedRequestRmcQueue;
static Lock *receivedRequestRmcQueueGate;
static Queue *receivedReplyRmcQueue;
static Lock *receivedReplyRmcQueueGate;

static int messagesReceivedCount;

@implementation Connection

+ (void) initialize
{
  connectionArray = [[Array alloc] init];
  connectionArrayGate = [Lock new];
  receivedRequestRmcQueue = [[Queue alloc] init];
  receivedRequestRmcQueueGate = [Lock new];
  receivedReplyRmcQueue = [[Queue alloc] init];
  receivedReplyRmcQueueGate = [Lock new];
  rootObjectDictionary = [[Dictionary alloc] init];
  rootObjectDictionaryGate = [Lock new];
  messagesReceivedCount = 0;
  default_port_class = [SocketPort class];
  defaultProxyClass = [Proxy class];
  defaultCoderClass = [ConnectedCoder class];
  default_in_timeout = CONNECTION_DEFAULT_TIMEOUT;
  default_out_timeout = CONNECTION_DEFAULT_TIMEOUT;
}

+ setDefaultPortClass: aClass
{
  default_port_class = aClass;
  return self;
}

+ setDefaultProxyClass: aClass
{
  defaultProxyClass = aClass;
  return self;
}

+ defaultProxyClass
{
  return defaultProxyClass;
}

+ setDefaultCoderClass: aClass
{
  defaultCoderClass = aClass;
  return self;
}

+ defaultCoderClass
{
  return defaultCoderClass;
}

+ (int) defaultOutTimeout
{
  return default_out_timeout;
}

+ setDefaultOutTimeout: (int)to
{
  default_out_timeout = to;
  return self;
}

+ (int) defaultInTimeout
{
  return default_in_timeout;
}

+ setDefaultInTimeout: (int)to
{
  default_in_timeout = to;
  return self;
}

+ (int) messagesReceived
{
  return messagesReceivedCount;
}

/* For encoding and decoding the method arguments, we have to know where
   to find things in the "argframe" as returned by __builtin_apply_args.

   For some situations this is obvious just from the selector type 
   encoding, but structures passed by value cause a problem because some
   architectures actually pass these by reference, i.e. use the
   structure-value-address mentioned in the gcc/config/_/_.h files.

   These differences are not encoded in the selector types.

   Below is my current guess for which architectures do this.

   I've also been told that some architectures may pass structures with
   sizef(structure) > sizeof(void*) by reference, but pass smaller ones by
   value.  The code doesn't currently handle that case.
   */

/* Do we need separate _PASSED_BY_REFERENCE and _RETURNED_BY_REFERENCE? */

#if (sparc) || (hppa) || (AM29K)
#define CONNECTION_STRUCTURES_PASSED_BY_REFERENCE 1
#else
#define CONNECTION_STRUCTURES_PASSED_BY_REFERENCE 0
#endif

/* Float and double return values are stored at retframe + 8 bytes
   by __builtin_return() 

   The retframe consists of 16 bytes.  The first 4 are used for ints, 
   longs, chars, etc.  The last 8 are used for floats and doubles.

   xxx This is disgusting.  I should get this info from the gcc config 
   machine description files. xxx
   */
#define FLT_AND_DBL_RETFRAME_OFFSET 8


- (retval_t) connectionForward: (Proxy*)object : (SEL)sel : (arglist_t)argframe
{
  ConnectedCoder *op;

  void encoder(int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_ARGNAME "argument value"
      switch (*type)
	{
	case _C_ID:
	  if (flags & _F_BYCOPY)
	    [op encodeObjectBycopy:*(id*)datum withName:ENCODED_ARGNAME];
	  else
	    [op encodeObject:*(id*)datum withName:ENCODED_ARGNAME];
	  break;
	default:
	  [op encodeValueOfType:type at:datum withName:ENCODED_ARGNAME];
	}
    }

  {
    BOOL out_parameters;
    const char *type;
    retval_t retframe;
    int seq_num;
  
    op = [self newSendingRequestRmc];
    seq_num = [op sequenceNumber];

    /* get the method types from the selector */
#if NeXT_runtime
    [self error:
	  "sorry, distributed objects does not work with the NeXT runtime"];
    /* type = [object selectorTypeForProxy:sel]; */
#else
    type = sel_get_type(sel);
#endif
    assert(type);
    assert(*type);

    /* Send the types that we're using, so that the performer knows
       exactly what qualifiers we're using.
       If all selectors included qualifiers and I could make sel_types_match() 
       work the way I wanted, we wouldn't need to do this. */
    [op encodeValueOfSimpleType:@encode(char*) 
	at:&type 
	withName:"selector type"];

    /* xxx This doesn't work with proxies and the NeXT runtime because
       type may be a method_type from a remote machine with a
       different architecture, and its argframe layout specifiers
       won't be right for this machine! */
    out_parameters = dissect_method_call(argframe, type, encoder);
    [op dismiss];
    
    {
      ConnectedCoder *ip = nil;
      int last_argnum;

      void decoder(int argnum, void *datum, const char *type, int flags)
	{
	  assert(ip != (id)-1);
	  if (!ip)
	    ip = [self newReceivedReplyRmcWithSequenceNumber:seq_num];
	  [ip decodeValueOfType:type at:datum withName:NULL];
	  if (argnum == last_argnum)
	    {
	      /* this must be here to avoid trashing alloca'ed retframe */
	      [ip dismiss]; 	
	      ip = (id)-1;
	    }
	}

      last_argnum = type_get_number_of_arguments(type) - 1;
      retframe = dissect_method_return(argframe, type, out_parameters,
				       decoder);
      return retframe;
    }
  }
}

- connectionPerformAndDismissCoder: aRmc
{
  char *forward_type;
  id op = nil;
  int reply_sequence_number;
  int numargs;

  void decoder (int argnum, void *datum, const char *type)
    {
      [aRmc decodeValueOfType:type
	    at:datum
	    withName:NULL];
      /* We need this "dismiss" to happen here and not later so that Coder
	 "-awake..." methods will get sent before the __builtin_apply! */
      if (argnum == numargs-1)
	[aRmc dismiss];
    }
  void encoder (int argnum, void *datum, const char *type, int flags)
    {
#define ENCODED_RETNAME "return value"
      if (op == nil)
	op = [self newSendingReplyRmcWithSequenceNumber:
		   reply_sequence_number];
      switch (*type)
	{
	case _C_ID:
	  if (flags & _F_BYCOPY)
	    [op encodeObjectBycopy:*(id*)datum withName:ENCODED_RETNAME];
	  else
	    [op encodeObject:*(id*)datum withName:ENCODED_RETNAME];
	  break;
	default:
	  [op encodeValueOfType:type at:datum withName:ENCODED_RETNAME];
	}
    }

  /* Save this for later */
  reply_sequence_number = [aRmc sequenceNumber];
  
  /* Get the types that we're using, so that we know
     exactly what qualifiers the forwarder used.
     If all selectors included qualifiers and I could make sel_types_match() 
     work the way I wanted, we wouldn't need to do this. */
  [aRmc decodeValueOfSimpleType:@encode(char*) 
	at:&forward_type 
	withName:NULL];

  numargs = type_get_number_of_arguments(forward_type);

  make_method_call(forward_type, decoder, encoder);
  [op dismiss];

  (*objc_free)(forward_type);
  return self;
}

+ (id <Collecting>) allConnections
{
  return [connectionArray copy];
}

+ (unsigned) connectionsCount
{
  return [connectionArray count];
}

+ (unsigned) connectionsCountWithInPort: (Port*)aPort
{
  unsigned count = 0;
  elt e;
  [connectionArrayGate lock];
  FOR_ARRAY(connectionArray, e)
    {
      if ([aPort isEqual:[e.id_u inPort]])
	count++;
    }
  FOR_ARRAY_END;
  [connectionArrayGate unlock];
  return count;
}

/* This should get called whenever an object free's itself */
+ removeObject: anObj
{
  id c;
  int i, count = [connectionArray count];
  for (i = 0; i < count; i++)
    {
      c = [connectionArray objectAtIndex:i];
      [c removeLocalObject:anObj];
      [c removeProxy:anObj];
    }
  return self;
}

+ unregisterForInvalidationNotification: anObj
{
  int i, count = [connectionArray count];
  for (i = 0; i < count; i++)
    {
      [[connectionArray objectAtIndex:i] 
       unregisterForInvalidationNotification:anObj];
    }
  return self;
}

- init
{
  id newPort = [default_port_class newPort];
  id newConn = 
    [Connection newForInPort:newPort outPort:nil ancestorConnection:nil];
  [self release];
  return newConn;
}

+ new
{
  id newPort = [default_port_class newPort];
  id newConn = 
    [Connection newForInPort:newPort outPort:nil ancestorConnection:nil];
  return newConn;
}

+ (Connection*) newWithRootObject: anObj;
{
  id newPort;
  id newConn;

  newPort = [default_port_class newPort];
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

  newPort = [default_port_class newRegisteredPortWithName:n];
  newConn = [self newForInPort:newPort outPort:nil
		  ancestorConnection:nil];
  [self setRootObject:anObj forInPort:newPort];
  return newConn;
}

+ (Proxy*) rootProxyAtName: (id <String>)n
{
  return [self rootProxyAtName:n onHost:@""];
}

+ (Proxy*) rootProxyAtName: (id <String>)n onHost: (id <String>)h
{
  id p = [default_port_class newPortFromRegisterWithName:n onHost:h];
  return [self rootProxyAtPort:p];
}

+ (Proxy*) rootProxyAtPort: (Port*)anOutPort
{
  id newInPort = [default_port_class newPort];
  return [self rootProxyAtPort: anOutPort withInPort:newInPort];
}

+ (Proxy*) rootProxyAtPort: (Port*)anOutPort withInPort: (Port*)anInPort
{
  Connection *newConn = [self newForInPort:anInPort
				outPort:anOutPort
				ancestorConnection:nil];
  Proxy *newRemote;

  newRemote = [newConn rootProxy];
  return newRemote;
}


- _superInit
{
  [super init];
  return self;
}

/* This is the designated initializer for Connection */

+ (Connection*) newForInPort: (Port*)ip outPort: (Port*)op
   ancestorConnection: (Connection*)ancestor;
{
  Connection *newConn;
  int i, count;
  id newConnInPort, newConnOutPort;

  [connectionArrayGate lock];

  /* Find previously existing connection if there */
  /* xxx Clean this up */
  count = [connectionArray count];
  for (i = 0; i < count; i++)
    {
      newConn = [connectionArray objectAtIndex:i];
      newConnInPort = [newConn inPort];
      newConnOutPort = [newConn outPort];
      if ([newConnInPort isEqual:ip]
	  && [newConnOutPort isEqual:op])
	{
	  [connectionArrayGate unlock];
	  return newConn;
	}
    }

  newConn = [[Connection alloc] _superInit];
  if (debug_connection)
    printf("new connection 0x%x, inPort 0x%x outPort 0x%x\n", 
	   (unsigned)newConn, (unsigned)ip, (unsigned)op);
  newConn->in_port = ip;
  [ip retain];
  newConn->out_port = op;
  [op retain];
  newConn->message_count = 0;

  /* Careful: We might want to use (void*) encoding because we
     don't want Dictionary to send -isEqual messages to the proxy's
     that are in the Dictionary.  YES. */
  newConn->local_targets = [[Dictionary alloc] 
			   initWithType:@encode(id)
			   keyType:@encode(unsigned)];
  newConn->remote_proxies = [[Dictionary alloc] 
			    initWithType:@encode(void*)
			    keyType:@encode(unsigned)];
  newConn->incoming_const_ptrs = [[Dictionary alloc] 
				initWithType:@encode(void*)
				keyType:@encode(unsigned)];
  newConn->outgoing_const_ptrs = [[Dictionary alloc] 
				initWithType:@encode(void*)
				keyType:@encode(unsigned)];
  newConn->in_timeout = [self defaultInTimeout];
  newConn->out_timeout = [self defaultOutTimeout];
  newConn->port_class = [ancestor portClass];
  newConn->queue_dialog_interruptions = YES;
  newConn->delegate = nil;

  /* Here ask the delegate for permission. */
  /* delegate is responsible for freeing newConn if it returns something
     different. */
  if ([[ancestor delegate] respondsTo:@selector(connection:didConnect:)])
    newConn = [[ancestor delegate] connection:ancestor
	       didConnect:newConn];

  [ip registerForInvalidationNotification:newConn];
  [op registerForInvalidationNotification:newConn];

  [connectionArray addObject:newConn];
  [connectionArrayGate unlock];

  return newConn;
}

/* This needs locks */
- (void) dealloc
{
  if (debug_connection)
    printf("deallocating 0x%x\n", (unsigned)self);
  [self invalidate];
  [connectionArray removeObject:self];
  /* Remove rootObject from rootObjectDictionary if this is last connection */
  if (![Connection connectionsCountWithInPort:in_port])
    [Connection setRootObject:nil forInPort:in_port];
  [in_port unregisterForInvalidationNotification:self];
  [out_port unregisterForInvalidationNotification:self];
  [in_port release];
  [out_port release];
  {
    void deallocObj (elt o)
      {
	[o.id_u dealloc];
      }
    [proxiesHashGate lock];
    [remote_proxies withElementsCall:deallocObj];
    [remote_proxies release];
    [local_targets release];
    [incoming_const_ptrs release];
    [outgoing_const_ptrs release];
    [proxiesHashGate unlock];
  }
  [super dealloc];
  return;
}

/* to < 0 will never time out */
- (void) runConnectionWithTimeout: (int)to
{
  [self doReceivedRequestsWithTimeout:to];
}

- (void) runConnection
{
  [self runConnectionWithTimeout:-1];
}

- (Proxy*) rootProxy
{
  id op, ip;
  Proxy *newProxy;
  int seq_num = [self _newMsgNumber];

  assert(in_port);
  op = [[self coderClass]
	newEncodingWithConnection:self
	sequenceNumber:seq_num
	identifier:ROOTPROXY_REQUEST];
  [op dismiss];
  ip = [self newReceivedReplyRmcWithSequenceNumber:seq_num];
  [ip decodeObjectAt:&newProxy withName:NULL];
  assert(class_is_kind_of(newProxy->isa, objc_get_class("Proxy")));
  [ip dismiss];
  return newProxy;
}

- _sendShutdown
{
  id op;

  assert(in_port);
  op = [[self coderClass]
	newEncodingWithConnection:self
	sequenceNumber:[self _newMsgNumber]
	identifier:CONNECTION_SHUTDOWN];
  [op dismiss];
  return self;
}

- (const char *) _typeForSelector: (SEL)sel remoteTarget: (unsigned)target
{
  id op, ip;
  char *type;
  int seq_num;

  assert(in_port);
  seq_num = [self _newMsgNumber];
  op = [[self coderClass]
	newEncodingWithConnection:self
	sequenceNumber:seq_num
	identifier:METHODTYPE_REQUEST];
  [op encodeValueOfType:":"
      at:&sel
      withName:NULL];
  [op encodeValueOfSimpleType:@encode(unsigned) 
      at:&target
      withName:NULL];
  [op dismiss];
  ip = [self newReceivedReplyRmcWithSequenceNumber:seq_num];
  [ip decodeValueOfSimpleType:@encode(char*) 
      at:&type
      withName:NULL];
  [ip dismiss];
  return type;
}

- _handleMethodTypeRequest: rmc
{
  ConnectedCoder* op;
  unsigned target;
  SEL sel;
  const char *type;
  struct objc_method* m;

  assert(in_port);
  assert([rmc connection] == self);
  op = [[self coderClass]
	newEncodingWithConnection:[rmc connection]
	sequenceNumber:[rmc sequenceNumber]
	identifier:METHODTYPE_REPLY];

  [rmc decodeValueOfType:":"
       at:&sel
       withName:NULL];
  [rmc decodeValueOfSimpleType:@encode(unsigned)
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
  [op encodeValueOfSimpleType:@encode(char*)
      at:&type
      withName:"Requested Method Type for Target"];
  [op dismiss];
  return self;
}

- _handleRemoteRootObject: rmc
{
  id rootObject = [Connection rootObjectForInPort:in_port];
  ConnectedCoder* op = [[self coderClass]
			newEncodingWithConnection:[rmc connection]
			sequenceNumber:[rmc sequenceNumber]
			identifier:ROOTPROXY_REPLY];
  assert(in_port);
  /* Perhaps we should turn this into a class method. */
  assert([rmc connection] == self);
  [op encodeObject:rootObject withName:"root object"];
  [op dismiss];
  return self;
}

- _newReceivedRmcWithTimeout: (int)to
{
  id rmc;

  rmc = [[self coderClass] newDecodingWithConnection:self
			   timeout:to];
  /* if (!rmc) [self error:"received timed out"]; */
  assert((!rmc) || [rmc isDecoding]);
  return rmc;
}

- (int) _newMsgNumber
{
  int n;

  [sequenceNumberGate lock];
  n = message_count++;
  [sequenceNumberGate unlock];
  return n;
}

- doReceivedRequestsWithTimeout: (int)to
{
  id rmc;
  unsigned count;

  for (;;)
    {
      if (debug_connection)
	printf("%s\n", sel_get_name(_cmd));

      /* Get a rmc */
      [receivedRequestRmcQueueGate lock];
      count = [receivedRequestRmcQueue count];
      if (count)
	{
	  if (debug_connection)
	    printf("Getting received request from queue\n");
	  rmc = [receivedRequestRmcQueue dequeueObject];
	  [receivedRequestRmcQueueGate unlock];
	}
      else
	{
	  [receivedRequestRmcQueueGate unlock];
	  rmc = [self _newReceivedRmcWithTimeout:to];
	}
      
      if (!rmc) return self;		/* timed out */
      assert([rmc isDecoding]);

      /* Process the rmc */
      switch ([rmc identifier])
	{
	case ROOTPROXY_REQUEST:
	  [[rmc connection] _handleRemoteRootObject:rmc];
	  [rmc dismiss];
	  break;
	case ROOTPROXY_REPLY:
	  [self error:"Got ROOTPROXY reply when looking for request"];
	  break;
	case METHOD_REQUEST:
	  {
	    assert([rmc isDecoding]);
	    [[rmc connection] connectionPerformAndDismissCoder:rmc];
	    break;
	  }
	case METHOD_REPLY:
	  /* Will this ever happen?
	     Yes, with multi-threaded callbacks */
	  [receivedReplyRmcQueueGate lock];
	  [receivedReplyRmcQueue enqueueObject:rmc];
	  [receivedReplyRmcQueueGate unlock];
	  break;
	case METHODTYPE_REQUEST:
	  [[rmc connection] _handleMethodTypeRequest:rmc];
	  [rmc dismiss];
	  break;
	case METHODTYPE_REPLY:
	  /* Will this ever happen?
	     Yes, with multi-threaded callbacks */
	  [receivedReplyRmcQueueGate lock];
	  [receivedReplyRmcQueue enqueueObject:rmc];
	  [receivedReplyRmcQueueGate unlock];
	  break;
	case CONNECTION_SHUTDOWN:
	  {
	    id c = [rmc connection];
	    [c invalidate];
	    if (c == self)
	      [self error:"connection waiting for request was shut down"];
	    [c dealloc];
	    break;
	  }
	default:
	  [self error:"unrecognized ConnectedCoder identifier"];
	}
    }
  return self;			/* we never get here */
}

- newReceivedReplyRmcWithSequenceNumber: (int)n
{
  id rmc, aRmc;
  unsigned count, i;

 again:

  /* Get a rmc */
  rmc = nil;
  [receivedReplyRmcQueueGate lock];
  count = [receivedReplyRmcQueue count];
  /* There should be a per-thread queue of rmcs so we can do
     callbacks when multi-threaded. */
  for (i = 0; i < count; i++)
    {
      aRmc = [receivedReplyRmcQueue objectAtIndex:i];
      if ([aRmc connection] == self
	  && [aRmc sequenceNumber] == n)
        {
	  if (debug_connection)
	    printf("Getting received reply from queue\n");
          [receivedReplyRmcQueue removeObjectAtIndex:i];
          rmc = aRmc;
          break;
        }
    }
  [receivedReplyRmcQueueGate unlock];
  if (rmc == nil)
    rmc = [self _newReceivedRmcWithTimeout:in_timeout];
  if (rmc == nil)
    {
      /* We timed out */
      [self error:"connection timed out after waiting %d milliseconds "
	    "for a reply",
	    in_timeout];
      /* Eventually we need to change this from crashing to 
	 connection invalidating?  I want to use gcc exceptions for this. */
    }

  /* Process the rmc we got */
  switch ([rmc identifier])
    {
    case ROOTPROXY_REQUEST:
      [self _handleRemoteRootObject: rmc];
      [rmc dismiss];
      break;
    case METHODTYPE_REQUEST:
      [self _handleMethodTypeRequest:rmc];
      [rmc dismiss];
      break;
    case ROOTPROXY_REPLY:
    case METHOD_REPLY:
    case METHODTYPE_REPLY:
      if ([rmc connection] != self)
	{
	  [receivedReplyRmcQueueGate lock];
	  [receivedReplyRmcQueue enqueueObject:rmc];
	  [receivedReplyRmcQueueGate unlock];
	}
      else
	{
	  if ([rmc sequenceNumber] != n)
	    [self error:"sequence number mismatch %d != %d\n",
		  [rmc sequenceNumber], n];
	  if (debug_connection)
	    printf("received reply number %d\n", n);
	  return rmc;
	}
      break;
    case METHOD_REQUEST:
      /* 
	 While waiting for a reply,
	 we can either honor new requests from other connections immediately,
	 or just queue them. */
      if (queue_dialog_interruptions && [rmc connection] != self)
	{
	  /* Here we queue them */
	  [receivedRequestRmcQueueGate lock];
	  [receivedRequestRmcQueue enqueueObject:rmc];
	  [receivedRequestRmcQueueGate unlock];
	}
      else
	{
	  /* Here we honor them right away */
	  [self connectionPerformAndDismissCoder:rmc];
	}
      break;
    case CONNECTION_SHUTDOWN:
      {
	id c = [rmc connection];
	[c invalidate];
	if (c == self)
	  [self error:"connection waiting for reply was shut down"];
	[c dealloc];
	[rmc dismiss];
	break;
      }
    default:
      [self error:"unrecognized ConnectedCoder identifier"];
    }
  goto again;

  return rmc;
}

- newSendingRequestRmc
{
  id rmc;

  assert(in_port);
  rmc = [[self coderClass] newEncodingWithConnection:self
			sequenceNumber:[self _newMsgNumber]
			identifier:METHOD_REQUEST];
  return rmc;
}

- newSendingReplyRmcWithSequenceNumber: (int)n
{
  id rmc = [[self coderClass]
	       newEncodingWithConnection:self
	       sequenceNumber:n
	       identifier:METHOD_REPLY];
  return rmc;
}

- removeLocalObject: anObj
{
  unsigned target = PTR2LONG(anObj);
  [proxiesHashGate lock];
  if ([local_targets includesKey:target])
    {
      [local_targets removeElementAtKey:target];
      [anObj release];
    }
  [proxiesHashGate unlock];
  return self;
}

- removeProxy: (Proxy*)aProxy
{
  unsigned target = [aProxy targetForProxy];
  [proxiesHashGate lock];
  if ([remote_proxies includesKey:target])
    [remote_proxies removeElementAtKey:target];
  [proxiesHashGate unlock];
  return self;
}

- (id <Collecting>) localObjects
{
  id l = [Array alloc];

  [proxiesHashGate lock];
  [l initWithContentsOf:local_targets];
  [proxiesHashGate unlock];
  return l;
}

- (id <Collecting>) proxies
{
  id a = [[Array alloc] initWithCapacity:[remote_proxies count]];
  void doit (elt e)
    {
      [a appendElement:e];
    }

  [proxiesHashGate lock];
  [remote_proxies withElementsCall:doit];
  [proxiesHashGate unlock];
  return a;
}

- (Proxy*) proxyForTarget: (unsigned)target
{
  Proxy *p;
  [proxiesHashGate lock];
  if ([remote_proxies includesKey:target])
    p = [remote_proxies elementAtKey:target].id_u;
  else
    p = nil;
  [proxiesHashGate unlock];
  assert(!p || [p connectionForProxy] == self);
  return p;
}

- addProxy: (Proxy*) aProxy
{
  unsigned target = [aProxy targetForProxy];
  assert(aProxy->isa == [Proxy class]);
  assert([aProxy connectionForProxy] == self);
  [proxiesHashGate lock];
  if ([remote_proxies includesKey:target])
    [self error:"Trying to add the same proxy twice"];
  [remote_proxies putElement:aProxy atKey:target];
  [proxiesHashGate unlock];
  return self;
}

- (BOOL) includesProxyForTarget: (unsigned)target
{
  BOOL ret;
  [proxiesHashGate lock];
  ret = [remote_proxies includesKey:target];
  [proxiesHashGate unlock];
  return ret;
}

- (BOOL) includesLocalObject: anObj
{
  unsigned target = PTR2LONG(anObj);
  BOOL ret;
  [proxiesHashGate lock];
  ret = [local_targets includesKey:target];
  [proxiesHashGate unlock];
  return ret;
}

- addLocalObject: anObj
{
  unsigned target = PTR2LONG(anObj);
  [proxiesHashGate lock];
  if (![local_targets includesKey:target])
    {
      [anObj retain];
      [local_targets putElement:anObj atKey:target];
    }
  [proxiesHashGate unlock];
  return self;
}

/* Pass nil to remove any reference keyed by aPort. */
+ setRootObject: anObj forInPort: (Port*)aPort
{
  id oldRootObject = [self rootObjectForInPort:aPort];

  if (oldRootObject != anObj)
    {
      if (anObj)
	{
	  [anObj retain];
	  [rootObjectDictionaryGate lock];
	  [rootObjectDictionary putElement:anObj atKey:aPort];
	  [rootObjectDictionaryGate unlock];
	}
      else /* anObj == nil && oldRootObject != nil */
	{
	  [rootObjectDictionaryGate lock];
	  [rootObjectDictionary removeElementAtKey:aPort];
	  [rootObjectDictionaryGate unlock];
	}
      [oldRootObject release];
    }
  return self;
}  

+ rootObjectForInPort: (Port*)aPort
{
  id ro;
  [rootObjectDictionaryGate lock];
  ro = [rootObjectDictionary elementAtKey:aPort 
			     ifAbsentCall:exc_func_return_nil].id_u;
  [rootObjectDictionaryGate unlock];
  return ro;
}

- setRootObject: anObj
{
  [Connection setRootObject:anObj forInPort:in_port];
  return self;
}

- rootObject
{
  return [Connection rootObjectForInPort:in_port];
}

- (int) outTimeout
{
  return out_timeout;
}

- (int) inTimeout
{
  return in_timeout;
}

- setOutTimeout: (int)to
{
  out_timeout = to;
  return self;
}

- setInTimeout: (int)to
{
  in_timeout = to;
  return self;
}

- portClass
{
  return port_class;
}

- setPortClass: aPortClass
{
  port_class = aPortClass;
  return self;
}

- proxyClass
{
  /* we might replace this with a per-Connection proxy class. */
  return defaultProxyClass;
}

- coderClass
{
  /* we might replace this with a per-Connection proxy class. */
  return defaultCoderClass;
}

- (Port *) outPort
{
  return out_port;
}

- (Port *) inPort
{
  return in_port;
}

- delegate
{
  return delegate;
}

- setDelegate: anObj
{
  delegate = anObj;
  return self;
}

- _incomingConstPtrs
{
  return incoming_const_ptrs;
}

- _outgoingConstPtrs
{
  return outgoing_const_ptrs;
}

- senderIsInvalid: anObj
{
  if (anObj == in_port || anObj == out_port)
    [self invalidate];
  /* xxx What else? */
  return self;
}

/* xxx This needs locks */
- invalidate
{
  if (!isValid)
    return nil;
  /* xxx Note: this is causing us to send a shutdown message
     to the connection that shut *us* down.  Don't do that. 
     Well, perhaps it's a good idea just in case other side didn't really
     send us the shutdown; this way we let them know we're going away */
  [self _sendShutdown];
  [super invalidate];
  return self;
}

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self shouldNotImplement:_cmd];
}

+ newWithCoder: (Coder*)aDecoder;
{
  [self shouldNotImplement:_cmd];
  return self;
}


@end


#if 0 /* temporarily moved to Coder.m */

@implementation Object (ConnectionRequests)

/* By default, Object's encode themselves as proxies across Connection's */
- classForConnectedCoder:aRmc
{
  return [[aRmc connection] proxyClass];
}

/* But if any object overrides the above method to return [Object class]
   instead, the Object implementation of the coding method will actually
   encode the object itself, not a proxy */
+ (void) encodeObject: anObject withConnectedCoder: aRmc
{
  [anObject encodeWithCoder:aRmc];
}

@end

#endif /* 0 temporarily moved to Coder.m */
