/* Implementation of GNU Objective-C Proxy for remote object messaging
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

#include <stdlib.h>
#include <stdarg.h>
#include <objects/stdobjects.h>
#include <objects/Proxy.h>
#include <objects/Connection.h>
#include <objects/ConnectedCoder.h>
#include <objects/eltfuncs.h>
#include <objects/AutoreleasePool.h>
#include <assert.h>

static BOOL debugProxies = NO;

#if NeXT_runtime
static id tmp_kludge_protocol = nil;
#endif

@implementation Proxy

/* Required by NeXT runtime */
+ initialize
{
  return self;
}

#if NeXT_runtime
+ setProtocolForProxies: (Protocol*)p
{
  tmp_kludge_protocol = p;
  return self;
}
#endif

+ newForRemote: (unsigned)aTarget connection: (Connection*)c
{
  Proxy *newProxy;

  if ((newProxy = [c proxyForTarget:aTarget]))
    return newProxy;

  newProxy = class_create_instance([Proxy class]);
  newProxy->target = aTarget;
  newProxy->connection = c;
  newProxy->retain_count = 0;
#if NeXT_runtime
  newProxy->_method_types = coll_hash_new(32, 
					  elt_hash_void_ptr,
					  elt_compare_void_ptrs);
  newProxy->protocol = nil;
#endif

  if (debugProxies)
    printf("%s: proxy=0x%x name %u\n", 
	   sel_get_name(_cmd), (unsigned)newProxy, newProxy->target);

  [c addProxy:newProxy];
  return newProxy;
}

- notImplemented: (SEL)aSel
{
  [Object error:"Proxy notImplemented %s", sel_get_name(aSel)];
  return self;
}

- self
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

- invalidateProxy
{
  /* What should go here? */
  [connection removeProxy:self];
  return self;
}

- (BOOL) isProxy
{
  return YES;
}

- (void) encodeWithCoder: aRmc
{
  [[self classForConnectedCoder:aRmc] 
   encodeObject:self
   withConnectedCoder:aRmc];
}

- classForConnectedCoder: aRmc;
{
  return object_get_class(self);
}

static inline BOOL class_is_kind_of(Class self, Class aClassObject)
{
  Class class;

  for (class = self; class!=Nil; class = class_get_super_class(class))
    if (class==aClassObject)
      return YES;
  return NO;
}

+ (void) encodeObject: anObject withConnectedCoder: aRmc
{
  unsigned aTarget;
  BOOL willBeLocal;
  assert([aRmc connection]);
  if (class_is_kind_of(object_get_class(anObject), [Proxy class]))
    {
      /* anObject is a Proxy, or a Proxy subclass */
      aTarget = [anObject targetForProxy];
      if ([aRmc connection] == [anObject connectionForProxy])
	{
	  /* This proxy is local on the other side */
	  willBeLocal = YES;
	  [aRmc encodeObjectBycopy:nil
		withName:"Proxy is local on other side"];
	  [aRmc encodeValueOfType:@encode(unsigned)
		at:&aTarget 
		withName:"Object Proxy target"];
	  [aRmc encodeValueOfType:@encode(BOOL)
		at:&willBeLocal 
		withName:"Proxy willBeLocal"];
	}
      else
	{
	  /* This proxy will still be remote on the other side */
	  id op = [[anObject connectionForProxy] outPort];
	  willBeLocal = NO;
	  if (debugProxies)
	    fprintf(stderr, "Sending a triangle-connection proxy\n");
	  /* It's remote here, so we need to tell other side where to form
	     triangle connection to */
	  [aRmc encodeObjectBycopy:op
		withName:"Proxy outPort"];
	  [aRmc encodeValueOfType:@encode(unsigned)
		at:&aTarget 
		withName:"Object Proxy target"];
	  [aRmc encodeValueOfType:@encode(BOOL)
		at:&willBeLocal 
		withName:"Proxy willBeLocal"];
	}
    }
  else
    {
      /* anObject is a non-Proxy object, e.g. Object */
      aTarget = PTR2LONG(anObject);
      willBeLocal = NO;
      /* Let the connection know that we're going, this also retains anObj */
      [[aRmc connection] addLocalObject:anObject];
      /* if nil port, other connection will use ConnectedCoder remotePort */
      [aRmc encodeObjectBycopy:nil 
	    withName:"Proxy outPort == remotePort"];
      [aRmc encodeValueOfType:@encode(unsigned)
	    at:&aTarget 
	    withName:"Object Proxy target"];
      [aRmc encodeValueOfType:@encode(BOOL)
	    at:&willBeLocal 
	    withName:"Proxy willBeLocal"];
    }
}

+ newWithCoder: aRmc
{
  unsigned new_target;
  id newConnectionOutPort;
  id c;
  BOOL willBeLocal;

  if ([aRmc class] != [ConnectedCoder class])
    [self error:"Proxy objects only code with ConnectedCoder class"];
  assert([aRmc connection]);
  [aRmc decodeObjectAt:&newConnectionOutPort withName:NULL];
  [aRmc decodeValueOfType:@encode(unsigned) 
	at:&new_target 
	withName:NULL];
  [aRmc decodeValueOfType:@encode(BOOL) 
	at:&willBeLocal 
	withName:NULL];
  if (newConnectionOutPort)
    {
      c = [Connection newForInPort:[[aRmc connection] inPort]
                        outPort:newConnectionOutPort
			ancestorConnection:[aRmc connection]];
    }
  else
    {
      c = [aRmc connection];
    }

  if (!willBeLocal)
    {
      if (debugProxies)
	printf("returning remote Proxy, target=0x%x\n", new_target);
      return [self newForRemote:new_target connection:c];
    }
  else
    {
      assert(new_target);
      if (debugProxies)
	printf("returning local Object, target=0x%x\n", new_target);
      /* xxx I should add something that makes sure this number is a
	 valid object address... offer a little protection against bad
	 clients. */
      return (id)new_target;
    }
}

- (unsigned) targetForProxy
{
  return target;
}

- connectionForProxy
{
  return connection;
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
#else
  return sel_get_type(selector);
#endif
}

/* xxx Clean up all this junk below */

- (oneway void) release
{
  if (!retain_count--)
    {
      [self invalidateProxy];
      [self dealloc];
    }
}

- retain
{
  retain_count++;
  return self;
}

- (void) dealloc
{
#if NeXT_runtime
  coll_hash_delete(_method_types);
  object_dispose((Object*)self);
#else
  object_dispose(self);
#endif
}

- forward: (SEL)aSel :(arglist_t)frame
{
  if (debugProxies)
    printf("Proxy forwarding %s\n", sel_get_name(aSel));
  return [connection connectionForward:self :aSel :frame];
}

/* We need to make an effort to pass errors back from the server 
   to the client */

- (unsigned) retainCount
{
  return retain_count;
}

- autorelease
{
  /* xxx Problems here if the Connection goes away? */
  [autorelease_class autoreleaseObject:self];
  return self;
}

@end

@implementation Object (ForProxy)
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
  return sel_get_type(selector);
#endif
}
@end

#if 0 /* temporarily moved to Coder.m */
@implementation Object (IsProxy)
- (BOOL) isProxy
{
  return NO;
}
@end
#endif

@implementation Protocol (RemoteCoding)

/* Perhaps Protocol's should be sent bycopy? */

- classForConnectedCoder: aRmc;
{
  return [Proxy class];
}

@end
