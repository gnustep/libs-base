/* Implementation for GNU Objective-C version of NSDistantObject
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: August 1997

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

#include <Foundation/DistributedObjects.h>
#include <Foundation/NSException.h>

static int debug_proxy;

@implementation NSDistantObject

/* This is the proxy tag; it indicates where the local object is,
   and determines whether the reply port to the Connection-where-the-
   proxy-is-local needs to encoded/decoded or not. */
enum
{
  PROXY_LOCAL_FOR_RECEIVER = 0,
  PROXY_LOCAL_FOR_SENDER,
  PROXY_REMOTE_FOR_BOTH
};


+ (void) initialize
{
    return;
}

+ (NSDistantObject*) proxyWithLocal: anObject
			 connection: (NSConnection*)aConnection
{
    NSDistantObject	*new_proxy;

    assert ([aConnection isValid]);
    if ((new_proxy = [aConnection localForTarget: anObject])) {
        return new_proxy;
    }
    return [[[NSDistantObject alloc] initWithLocal: anObject
				connection: aConnection] autorelease];
}

+ (NSDistantObject*) proxyWithTarget: anObject
			  connection: (NSConnection*)aConnection
{
    NSDistantObject	*new_proxy;

    assert ([aConnection isValid]);
    if ((new_proxy = [aConnection proxyForTarget: anObject])) {
        return new_proxy;
    }
    return [[[NSDistantObject alloc] initWithTarget: anObject
					 connection: aConnection] autorelease];
}

- (NSConnection*) connectionForProxy
{
    return _connection;
}

- (void) dealloc
{
    if (_isLocal) {
	/*
	 *	A proxy for local object retains it's target so that it
	 *	will continue to exist as long as there is a remote
	 *	application using it - so we release the object here.
	 */
	[_object release];
    }
    else {
	/*
	 *	A proxy retains it's connection so that the connection will
	 *	continue to exist as long as there is a somethig to use it.
	 *	So we release our reference to the connection here.
	 */
	[_connection release];
    }
    [super dealloc];
}

- (void) encodeWithCoder: aRmc
{
    unsigned int	proxy_target;
    unsigned char	proxy_tag;
    NSConnection	*encoder_connection;

    if ([aRmc class] != [PortEncoder class])
	[NSException raise: NSGenericException
format: @"NSDistantObject objects only encode with PortEncoder class"];

    encoder_connection = [aRmc connection];
    assert (encoder_connection);
    if (![encoder_connection isValid])
	[NSException
	    raise: NSGenericException
	   format: @"Trying to encode to an invalid Connection.\n"
      @"You should request NSConnectionDidDieNotification's and\n"
      @"release all references to the proxy's of invalid Connections."];

    proxy_target = (unsigned int)_object;

    if (encoder_connection == _connection) {
	/*
	 *	This proxy is a local object on the other side.
	 */
	proxy_tag = PROXY_LOCAL_FOR_RECEIVER;

	if (debug_proxy)
	    fprintf(stderr, "Sending a proxy, will be local 0x%x "
		    "connection 0x%x\n",
		    (unsigned)_object,
		    (unsigned)_connection);

	[aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
			      at: &proxy_tag
			withName: @"Proxy is local for receiver"];

	[aRmc encodeValueOfCType: @encode(typeof(proxy_target))
			      at: &proxy_target
			withName: @"Proxy target"];
    }
    else {
	/*
	 *	This proxy will still be remote on the other side
	 */
	NSPort *proxy_connection_out_port = [_connection sendPort];

	assert (proxy_connection_out_port);
	assert ([proxy_connection_out_port isValid]);
	assert (proxy_connection_out_port != [encoder_connection sendPort]);

	proxy_tag = PROXY_REMOTE_FOR_BOTH;

	if (debug_proxy)
	    fprintf(stderr, "Sending triangle-connection proxy 0x%x "
		"proxy-conn 0x%x to-conn 0x%x\n",
		(unsigned)_object,
		(unsigned)_connection, (unsigned)encoder_connection);

	/*
	 *	It's remote here, so we need to tell other side where to form
	 *	triangle connection to
	 */
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

/*
 *	This method needs to be implemented to actually do anything.
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
    [NSException raise: NSInvalidArgumentException
		    format: @"Not yet implemented '%s'",
				sel_get_name(_cmd)];
}

- initWithCoder: coder
{
    [NSException raise: NSInvalidArgumentException
		    format: @"Not yet implemented '%s'",
				sel_get_name(_cmd)];
    return nil;
}

- initWithLocal:anObject connection: (NSConnection*)aConnection
{
    NSDistantObject	*new_proxy;

    assert ([aConnection isValid]);

    /*
     *	If there already is a local proxy for this target/connection
     *	combination, don't create a new one, just return the old one.
     */
    if ((new_proxy = [aConnection localForTarget: anObject])) {
	[self dealloc];
        return [new_proxy retain];
    }

    _isLocal = YES;
    _connection = aConnection;

    /*
     *	We retain our target object so it can't disappear while a remote
     *	application wants to use it.
     */
    _object = [anObject retain];

    /*
     *	We register this object with the connection using it.
     */
    [_connection addLocalObject: self];

    if (debug_proxy)
	printf("Created new local=0x%x object 0x%x connection 0x%x\n",
	   (unsigned)self, (unsigned)_object, (unsigned)_connection);

    return self;
}

- initWithTarget:anObject connection: (NSConnection*)aConnection
{
    NSDistantObject	*new_proxy;

    assert ([aConnection isValid]);

    /*
     *	If there already is a proxy for this target/connection combination,
     *	don't create a new one, just return the old one.
     */
    if ((new_proxy = [aConnection proxyForTarget: anObject])) {
	[self dealloc];
        return [new_proxy retain];
    }

    _isLocal = NO;
    _object = anObject;

    /*
     *	We retain our connection so it can't disappear while the app
     *	may want to use it.
     */
    _connection = [aConnection retain];

    /*
     *	We register this object with the connection using it.
     */
    [_connection addProxy: self];

    if (debug_proxy)
	printf("Created new proxy=0x%x object 0x%x connection 0x%x\n",
	   (unsigned)self, (unsigned)_object, (unsigned)_connection);

    return self;
}

- (void) setProtocolForProxy: (Protocol*)aProtocol
{
    _protocol = aProtocol;
}

- (void) release
{
    if ([self retainCount] == 2) {
	if (_isLocal == NO) {
	    /*
	     *	If the only thing retaining us after this release is our
	     *	connection we must be removed from the connection.
	     *	Bracket that removal with a retain and release to ensure
	     *	that we don't have problems when the connection releases us.
	     */
	    [super retain];
	    [_connection removeProxy:self];
	    [super release];
	}
    }
    [super release];
}

@end

@implementation NSDistantObject(GNUstepExtensions)

+ newForRemoteTarget: (unsigned)target connection: (NSConnection*)conn
{
    return [[NSDistantObject alloc] initWithTarget:(id)target connection:conn];
}

- awakeAfterUsingCoder: aDecoder
{
    return self;
}

static inline BOOL class_is_kind_of (Class self, Class aClassObject)
{
    Class class;

    for (class = self; class!=Nil; class = class_get_super_class(class))
	if (class==aClassObject)
	    return YES;
    return NO;
}



+ newWithCoder: aRmc
{
    unsigned char proxy_tag;
    unsigned target;
    id decoder_connection;

    if ([aRmc class] != [PortDecoder class])
	[NSException raise: NSGenericException
format: @"NSDistantObject objects only decode with PortDecoder class"];

    decoder_connection = [aRmc connection];
    assert (decoder_connection);

    /* First get the tag, so we know what values need to be decoded. */
    [aRmc decodeValueOfCType: @encode(typeof(proxy_tag))
			  at: &proxy_tag
		    withName: NULL];

    switch (proxy_tag) {

    case PROXY_LOCAL_FOR_RECEIVER:
	/*
	 *	This was a proxy on the other side of the connection, but
	 *	here it's local.
	 *	Lookup the target address to ensure that it exists here.
	 *	Send [NSDistantObject +proxyWithLocal:connection:]; this will
	 *	return the proxy object we already created for this target, or
	 *	create a new proxy object if necessary.
	 *	Return a retained copy of the local target object.
	 */
	[aRmc decodeValueOfCType: @encode(typeof(target))
			      at: &target
			withName: NULL];

        if (debug_proxy)
	    fprintf(stderr, "Receiving a proxy for local object 0x%x "
		"connection 0x%x\n", target, (unsigned)decoder_connection);

        if (![[decoder_connection class] includesLocalObject: (id)target])
	    [NSException raise: @"ProxyDecodedBadTarget"
			format: @"No local object with given address"];

	{
	    id	local = [NSDistantObject proxyWithLocal: (id)target
					     connection: decoder_connection];

	    return [[local targetForProxy] retain];
	}

    case PROXY_LOCAL_FOR_SENDER:
        /*
	 *	This was a local object on the other side of the connection,
	 *	but here it's a proxy object.  Get the target address, and
	 *	send [NSDistantObject +proxyWithTarget:connection:]; this will
	 *	return the proxy object we already created for this target, or
	 *	create a new proxy object if necessary.
	 */
      [aRmc decodeValueOfCType: @encode(typeof(target))
	    at: &target
	    withName: NULL];
      if (debug_proxy)
	fprintf(stderr, "Receiving a proxy, was local 0x%x connection 0x%x\n",
		(unsigned)target, (unsigned)decoder_connection);
      return [[NSDistantObject proxyWithTarget: (id)target
				    connection: decoder_connection] retain];

    case PROXY_REMOTE_FOR_BOTH:
        /*
	 *	This was a proxy on the other side of the connection, and it
	 *	will be a proxy on this side too; that is, the local version
	 *	of this object is not on this host, not on the host the
	 *	NSPortCoder is connected to, but on a *third* host.
	 *	This is why I call this a "triangle connection".  In addition
	 *	to decoding the target, we decode the OutPort object that we
	 *	will use to talk directly to this third host.  We send
	 *	[NSConnection +newForInPort:outPort:ancestorConnection:]; this
	 *	will either return the connection already created for this
	 *	inPort/outPort pair, or create a new connection if necessary.
	 */
	{
	    NSConnection *proxy_connection;
	    NSPort* proxy_connection_out_port = nil;

	    [aRmc decodeValueOfCType: @encode(typeof(target))
				  at: &target
			    withName: NULL];

	    [aRmc decodeObjectAt: &proxy_connection_out_port
		        withName: NULL];

	    assert (proxy_connection_out_port);
	    proxy_connection = [[decoder_connection class]
			     newForInPort: [decoder_connection receivePort]
				 outPort: proxy_connection_out_port
			     ancestorConnection: decoder_connection];

	    if (debug_proxy)
	        fprintf(stderr, "Receiving a triangle-connection proxy 0x%x "
		  "connection 0x%x\n", target, (unsigned)proxy_connection);

	    assert (proxy_connection != decoder_connection);
	    assert ([proxy_connection isValid]);

	    return [[NSDistantObject proxyWithTarget: (id)target
				          connection: proxy_connection] retain];
        }

    default:
        /* xxx This should be something different than NSGenericException. */
        [NSException raise: NSGenericException
		    format: @"Bad proxy tag"];
    }
    /* Not reached. */
    return nil;
}

- (void) encodeWithCoder: aRmc
{
    unsigned int	proxy_target;
    unsigned char	proxy_tag;
    NSConnection	*encoder_connection;

    if ([aRmc class] != [PortEncoder class])
	[NSException raise: NSGenericException
format: @"NSDistantObject objects only encode with PortEncoder class"];

    encoder_connection = [aRmc connection];
    assert (encoder_connection);
    if (![encoder_connection isValid])
	[NSException
	    raise: NSGenericException
	   format: @"Trying to encode to an invalid Connection.\n"
      @"You should request NSConnectionDidDieNotification's and\n"
      @"release all references to the proxy's of invalid Connections."];

    proxy_target = (unsigned int)_object;

    if (encoder_connection == _connection) {
	if (_isLocal) {
	    /*
	     *	This proxy is a local to us, remote to other side.
	     */
	    proxy_tag = PROXY_LOCAL_FOR_SENDER;

	    if (debug_proxy)
		fprintf(stderr, "Sending a proxy, will be remote 0x%x "
			"connection 0x%x\n",
			(unsigned)_object,
			(unsigned)_connection);

	    [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
				  at: &proxy_tag
			    withName: @"Proxy is local for sender"];

	    [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
				  at: &proxy_target
			    withName: @"Proxy target"];
	}
	else {
	    /*
	     *	This proxy is a local object on the other side.
	     */
	    proxy_tag = PROXY_LOCAL_FOR_RECEIVER;

	    if (debug_proxy)
		fprintf(stderr, "Sending a proxy, will be local 0x%x "
			"connection 0x%x\n",
			(unsigned)_object,
			(unsigned)_connection);

	    [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
				  at: &proxy_tag
			    withName: @"Proxy is local for receiver"];

	    [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
				  at: &proxy_target
			    withName: @"Proxy target"];
	}
    }
    else {
	/*
	 *	This proxy will still be remote on the other side
	 */
	NSPort *proxy_connection_out_port = [_connection sendPort];

	assert (proxy_connection_out_port);
	assert ([proxy_connection_out_port isValid]);
	assert (proxy_connection_out_port != [encoder_connection sendPort]);

	proxy_tag = PROXY_REMOTE_FOR_BOTH;

	if (debug_proxy)
	    fprintf(stderr, "Sending triangle-connection proxy 0x%x "
		"proxy-conn 0x%x to-conn 0x%x\n",
		(unsigned)_object,
		(unsigned)_connection, (unsigned)encoder_connection);

	/*
	 *	It's remote here, so we need to tell other side where to form
	 *	triangle connection to
	 */
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

- (const char *) selectorTypeForProxy: (SEL)selector
{
#if NeXT_runtime
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
#else /* NeXT_runtime */
  return sel_get_type (selector);
#endif
}

- targetForProxy
{
    return _object;
}

- forward: (SEL)aSel :(arglist_t)frame
{
    if (debug_proxy)
	printf("NSDistantObject forwarding %s\n", sel_get_name(aSel));

    if (![_connection isValid])
	[NSException
	   raise: NSGenericException
	  format: @"Trying to send message to an invalid Proxy.\n"
      @"You should request NSConnectionDidDieNotification's and\n"
      @"release all references to the proxy's of invalid Connections."];

    return [_connection forwardForProxy: self
			       selector: aSel
			       argFrame: frame];
}

- classForCoder: aRmc;
{
    return object_get_class (self);
}

- classForPortCoder: aRmc
{
    return object_get_class (self);
}

- replacementObjectForCoder:(NSPortCoder*)aCoder
{
    return self;
}

- replacementObjectForPortCoder:(NSPortCoder*)aCoder
{
  return self;
}
@end


@implementation NSObject (NSDistantObject)
- (const char *) selectorTypeForProxy: (SEL)selector
{
#if NeXT_runtime
  {
    Method m = class_get_instance_method(isa, selector);
    if (m)
      return m->method_types;
    else
      return NULL;
  }
#else
  return sel_get_type (selector);
#endif
}

@end

@implementation Protocol (DistributedObjectsCoding)

- (Class) classForPortCoder: (NSPortCoder*)aRmc;
{
    return [NSDistantObject class];
}

- replacementObjectForPortCoder: (NSPortCoder*)aRmc;
{
    return [NSDistantObject proxyWithLocal: self
			        connection: [aRmc connection]];
}

@end

