/* Implementation of GNU Objective-C Proxy for remote object messaging
   Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.
   
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

#include <stdlib.h>
#include <stdarg.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Proxy.h>
#include <gnustep/base/Connection.h>
#include <gnustep/base/Port.h>
#include <gnustep/base/TcpPort.h>
#include <gnustep/base/ConnectedCoder.h>
#include <Foundation/NSException.h>
#include <assert.h>

static int debug_proxy = 0;

#if NeXT_runtime
static id tmp_kludge_protocol = nil;
#endif

@implementation Proxy

/* Required by NeXT runtime */
+ (void) initialize
{
  return;
}

#if NeXT_runtime
+ setProtocolForProxies: (Protocol*)p
{
  tmp_kludge_protocol = p;
  return self;
}
#endif


/* This is the designated initializer. */

+ newForRemoteTarget: (unsigned)target connection: (Connection*)connection
{
  Proxy *new_proxy;

  assert ([connection isValid]);

  /* If there already is a proxy for this target/connection combination,
     don't create a new one, just return the old one. */
  if ((new_proxy = [connection proxyForTarget: target]))
    {
      return new_proxy;
    }

  /* There isn't one already created; make a new proxy object, 
     and set its ivars. */
  new_proxy = class_create_instance (self);
  new_proxy->_target = target;
  new_proxy->_connection = connection;
  new_proxy->_retain_count = 0;
#if NeXT_runtime
  new_proxy->_method_types = coll_hash_new(32, 
					  elt_hash_void_ptr,
					  elt_compare_void_ptrs);
  new_proxy->protocol = nil;
#endif

  if (debug_proxy)
    printf("Created new proxy=0x%x target 0x%x conn 0x%x\n", 
	   (unsigned)new_proxy,
	   (unsigned)new_proxy->_target,
	   (unsigned)connection);

  /* Register this proxy with the connection. */
  [connection addProxy: new_proxy];

  return new_proxy;
}

- notImplemented: (SEL)aSel
{
  [NSException raise: NSGenericException
	       format: @"Proxy notImplemented %s", sel_get_name(aSel)];
  return self;
}

- self
{
  return self;
}

- awakeAfterUsingCoder: aDecoder
{
  return self;
}

#if NeXT_runtime
+ class
{
  return self;
}
#else
+ (Class) class
{
  return (Class)self;
}
#endif

- (void) invalidateProxy
{
  /* xxx Who calls this? */
  /* xxx What should go here? */
  [_connection removeProxy: self];
}

- (BOOL) isProxy
{
  return YES;
}

- (void) encodeWithCoder: aRmc
{
  if (![_connection isValid])
    [NSException 
      raise: NSGenericException
      format: @"Trying to encode an invalid Proxy.\n"
      @"You should request ConnectionBecameInvalidNotification's and\n"
      @"remove all references to the Proxy's of invalid Connections."];
  [[self classForConnectedCoder: aRmc] 
   encodeObject: self withConnectedCoder: aRmc];
}

- classForConnectedCoder: aRmc;
{
  return object_get_class (self);
}

static inline BOOL class_is_kind_of (Class self, Class aClassObject)
{
  Class class;

  for (class = self; class!=Nil; class = class_get_super_class(class))
    if (class==aClassObject)
      return YES;
  return NO;
}


/* Encoding and Decoding Proxies on the wire. */

/* This is the proxy tag; it indicates where the local object is,
   and determines whether the reply port to the Connection-where-the-
   proxy-is-local needs to encoded/decoded or not. */
enum
{
  PROXY_LOCAL_FOR_RECEIVER = 0,
  PROXY_LOCAL_FOR_SENDER,
  PROXY_REMOTE_FOR_BOTH
};

+ (void) encodeObject: anObject withConnectedCoder: aRmc
{
  unsigned proxy_target;
  unsigned char proxy_tag;
  Connection *encoder_connection;

  encoder_connection = [aRmc connection];
  assert (encoder_connection);
  if (![encoder_connection isValid])
    [NSException 
      raise: NSGenericException
      format: @"Trying to encode to an invalid Connection.\n"
      @"You should request ConnectionBecameInvalidNotification's and\n"
      @"remove all references to the Proxy's of invalid Connections."];

  /* Find out if anObject is a proxy or not. */
  if (class_is_kind_of (object_get_class (anObject), self))
    {
      /* anObject is a Proxy, or a Proxy subclass */
      Connection *proxy_connection = [anObject connectionForProxy];
      proxy_target = [anObject targetForProxy];
      if (encoder_connection == proxy_connection)
	{
	  /* This proxy is a local object on the other side */
	  proxy_tag = PROXY_LOCAL_FOR_RECEIVER;
	  if (debug_proxy)
	    fprintf(stderr, "Sending a proxy, will be local 0x%x "
		    "connection 0x%x\n",
		    [anObject targetForProxy],
		    (unsigned)proxy_connection);
	  [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
		at: &proxy_tag
		withName: @"Proxy is local for receiver"];
	  [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
		at: &proxy_target 
		withName: @"Proxy target"];
	}
      else
	{
	  /* This proxy will still be remote on the other side */
	  OutPort *proxy_connection_out_port = [proxy_connection outPort];

	  assert (proxy_connection_out_port);
	  assert ([proxy_connection_out_port isValid]);
	  assert (proxy_connection_out_port != [encoder_connection outPort]);
	  /* xxx Remove this after debugging, because it won't be true
	     for connections across different hosts. */
	  assert ([(id)proxy_connection_out_port portNumber]
		  != [(id)[encoder_connection outPort] portNumber]);
	  assert ([proxy_connection inPort] == [encoder_connection inPort]);
	  proxy_tag = PROXY_REMOTE_FOR_BOTH;
	  if (debug_proxy)
	    fprintf(stderr, "Sending triangle-connection proxy 0x%x "
		    "proxy-conn 0x%x to-conn 0x%x\n",
		    [anObject targetForProxy],
		    (unsigned)proxy_connection, (unsigned)encoder_connection);
	  /* It's remote here, so we need to tell other side where to form
	     triangle connection to */
	  [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
		at: &proxy_tag
		withName: @"Proxy is remote for both sender and receiver"];
	  [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
		at: &proxy_target 
		withName: @"Proxy target"];
	  [aRmc encodeBycopyObject: proxy_connection_out_port
		withName: @"Proxy outPort"];
	}
    }
  else
    {
      /* anObject is a non-Proxy object, e.g. NSObject. */
      /* But now were sending this object across the wire in proxy form. */
      proxy_target = PTR2LONG(anObject);
      proxy_tag = PROXY_LOCAL_FOR_SENDER;
      if (debug_proxy)
	fprintf(stderr, "Sending a proxy for local 0x%x\n",
		(unsigned)anObject);
      /* Let the connection know that we're going;  this also retains anObj; 
	 it's OK to send -addLocalObject: more than once for the same
	 object, because it will only really get added and retained once. */
      [[aRmc connection] addLocalObject: anObject];

      [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
	    at: &proxy_tag
	    withName: @"Proxy is local for the sender"];
      [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
	    at: &proxy_target 
	    withName: @"Proxy target"];
    }
}

+ newWithCoder: aRmc
{
  unsigned char proxy_tag;
  unsigned target;
  id decoder_connection;

  if ([aRmc class] != [ConnectedDecoder class])
    [NSException 
      raise: NSGenericException
      format: @"Proxy objects only decode with ConnectedDecoder class"];

  decoder_connection = [aRmc connection];
  assert (decoder_connection);

  /* First get the tag, so we know what values need to be decoded. */
  [aRmc decodeValueOfCType: @encode(typeof(proxy_tag))
	at: &proxy_tag
	withName: NULL];

  switch (proxy_tag)
    {

    case PROXY_LOCAL_FOR_RECEIVER:
      /* This was a proxy on the other side of the connection, but
	 here it's local.  Just get the target address, make sure
	 that it is indeed the address of a local object that we
	 vended to the remote connection, then simply return the target
	 casted to (id). */
      [aRmc decodeValueOfCType: @encode(typeof(target))
	    at: &target 
	    withName: NULL];
      if (debug_proxy)
	fprintf(stderr, "Receiving a proxy for local object 0x%x "
		"connection 0x%x\n", target, (unsigned)decoder_connection);
      if (![[decoder_connection class] includesLocalObject: (id)target])
	[NSException raise: @"ProxyDecodedBadTarget"
		     format: @"No local object with given address"];
      return (id) target;

    case PROXY_LOCAL_FOR_SENDER:
      /* This was a local object on the other side of the connection,
	 but here it's a proxy object.  Get the target address, and
	 send [Proxy +newForRemoteTarget:connection:]; this will return 
	 the proxy object we already created for this target, or create
	 a new proxy object if necessary. */
      [aRmc decodeValueOfCType: @encode(typeof(target))
	    at: &target 
	    withName: NULL];
      if (debug_proxy)
	fprintf(stderr, "Receiving a proxy, was local 0x%x connection 0x%x\n",
		(unsigned)target, (unsigned)decoder_connection);
      return [self newForRemoteTarget: target 
		   connection: decoder_connection];

    case PROXY_REMOTE_FOR_BOTH:
      /* This was a proxy on the other side of the connection, and it
	 will be a proxy on this side too; that is, the local version
	 of this object is not on this host, not on the host the
	 ConnectedDecoder is connected to, but on a *third* host.
	 This is why I call this a "triangle connection".  In addition
	 to decoding the target, we decode the OutPort object that we
	 will use to talk directly to this third host.  We send
	 [Connection +newForInPort:outPort:ancestorConnection:]; this
	 will either return the connection already created for this
	 inPort/outPort pair, or create a new connection if necessary. */
      {
	Connection *proxy_connection;
	id proxy_connection_out_port = nil;

	[aRmc decodeValueOfCType: @encode(typeof(target))
	      at: &target 
	      withName: NULL];
	[aRmc decodeObjectAt: &proxy_connection_out_port
	      withName: NULL];
	assert (proxy_connection_out_port);
	proxy_connection = [[decoder_connection class]
			     newForInPort: [decoder_connection inPort]
			     outPort: proxy_connection_out_port
			     ancestorConnection: decoder_connection];
	if (debug_proxy)
	  fprintf(stderr, "Receiving a triangle-connection proxy 0x%x "
		  "connection 0x%x\n", target, (unsigned)proxy_connection);
	assert (proxy_connection != decoder_connection);
	assert ([proxy_connection isValid]);
	return [self newForRemoteTarget: target 
		     connection: proxy_connection];
      }
    default:
      /* xxx This should be something different than NSGenericException. */
      [NSException raise: NSGenericException
		   format: @"Bad proxy tag"];
    }
  /* Not reached. */
  return nil;
}

- (unsigned) targetForProxy
{
  return _target;
}

- connectionForProxy
{
  return _connection;
}

- (const char *) selectorTypeForProxy: (SEL)selector
{
#if NeXT_runtime
#if 0
  {
    /* This is bogosity.  You are required to include all methods sent
       by any proxies in the protocol you pass to
       +setProtocolForProxy: */
    struct objc_method_description *md;
    md = [tmp_kludge_protocol descriptionForInstanceMethod:selector];
    if (md)
      return md->types;
    else
      return NULL;
  }
#elif 0
  {
    /* This is disgusting bogosity.  This only works if some other
       class in the executable responds to this method. */
    /* xxx Look in the class hash table at all classes... */
  }
#else
  {
    elt e;
    const char *t;
    e = coll_hash_value_for_key(_method_types, selector);
    t = e.char_ptr_u;
    if (!t)
      {
	/* This isn't what we want, unless the remote machine has
	   the same architecture as us. */
	t = [connection _typeForSelector:selector remoteTarget:target];
	coll_hash_add(&_method_types, (void*)selector, t);
      }
    return t;
  }
#endif /* 1 */
#else /* NeXT_runtime */
  return sel_get_type (selector);
#endif
}

/* xxx Clean up all this junk below */

- (oneway void) release
{
  if (!_retain_count--)
    {
      [self invalidateProxy];
      [self dealloc];
    }
}

- retain
{
  _retain_count++;
  return self;
}

- (void) dealloc
{
#if NeXT_runtime
  coll_hash_delete (_method_types);
  object_dispose ((Object*)self);
#else
  NSDeallocateObject ((id)self);
#endif
}

- forward: (SEL)aSel :(arglist_t)frame
{
  if (debug_proxy)
    printf("Proxy forwarding %s\n", sel_get_name(aSel));
  if (![_connection isValid])
    [NSException 
      raise: NSGenericException
      format: @"Trying to send message to an invalid Proxy.\n"
      @"You should request ConnectionBecameInvalidNotification's and\n"
      @"remove all references to the Proxy's of invalid Connections."];
  return [_connection forwardForProxy: self
		      selector: aSel
		      argFrame: frame];
}

/* We need to make an effort to pass errors back from the server 
   to the client */

- (unsigned) retainCount
{
  return _retain_count;
}

- autorelease
{
  /* xxx Problems here if the Connection goes away? */
  [[NSObject autoreleaseClass] addObject: self];
  return self;
}

- (NSZone*) zone
{
  return NULL;			/* xxx Fix this. */
}

@end


@implementation Protocol (RemoteSelfCoding)

/* Perhaps Protocol's should be sent bycopy? */

- classForConnectedCoder: aRmc;
{
  return [Proxy class];
}

@end
