/* Implementation of Objective-C method-name-compatible NXConnection
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   This file is part of the GNU Objective C Class Library.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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

#include <remote/NXConnection.h>
#include <remote/NXProxy.h>
#include <objects/ConnectedCoder.h>
#include <assert.h>

static Class* NXConnectionProxyClass;

/* Just to make -encodeRemotelyFor:... work */
@interface NXConnectedCoder : ConnectedCoder
- (void) _doEncodeObject: anObj;
@end

@implementation NXConnection

+ initialize
{
  if ([self class] == [NXConnection class])
    NXConnectionProxyClass = [NXProxy class];
  return self;
}

+ connections: aList
{
  id cs = [Connection allConnections];
  void add_to_aList(id c)
    {
      [aList addObject:c];
    }
  [cs withObjectsCall:add_to_aList];
  [cs free];
  return self;
}

+ setDefaultProxyClass: (Class*)aClass
{
  NXConnectionProxyClass = aClass;
  return self;
}

+ (Class*) defaultProxyClass
{
  return NXConnectionProxyClass;
}

+ (NXZone*) defaultZone
{
  return NX_NOZONE;
}

+ setDefaultZone: (NXZone *)z
{
  return self;
}

+ (int) defaultTimeout
{
  /* not correct, but it will do for now. */
  return [self defaultInTimeout];
}

+ setDefaultTimeout: (int)to
{
  /* not correct, but it will do for now. */
  return [self setDefaultInTimeout:to];
}

+ registerRoot: anObj fromZone: (NXZone*)z
{
  return [Connection newWithRootObject:anObj];
}

+ registerRoot: anObj
{
  return [self registerRoot:anObj fromZone:NX_NOZONE];
}

+ registerRoot: anObj withName: (char*)n fromZone: (NXZone*)z
{
  return [Connection newRegisteringAtName:n withRootObject:anObj];
}

+ registerRoot: anObj withName: (char*)n
{
  return [self registerRoot:anObj withName:n fromZone:NX_NOZONE];
}

+ connectToPort: aPort fromZone: (NXZone*)z
{
  return [Connection rootProxyAtPort:aPort];
}

+ connectToPort: aPort
{
  return [self connectToPort:aPort fromZone:NX_NOZONE];
}

+ connectToPort: aPort withInPort: anInPort fromZone: (NXZone*)z
{
  return [Connection rootProxyAtPort:aPort withInPort:anInPort];
}

+ connectToPort: aPort withInPort: anInPort
{
  return [self connectToPort:aPort withInPort:anInPort fromZone:NX_NOZONE];
}

+ connectToName: (char*)n onHost: (char*)h fromZone: (NXZone*)z
{
  return [Connection rootProxyAtName:n onHost:h];
}

+ connectToName: (char*)n fromZone: (NXZone*)z
{
  return [Connection rootProxyAtName:n];
}

+ connectToName: (char*)n onHost: (char*)h
{
  return [self connectToName:n onHost:h fromZone:NX_NOZONE];
}

+ connectToName: (char*)n
{
  return [self connectToName:n fromZone:NX_NOZONE];
}

+ (unsigned) count
{
  return [Connection connectionsCount];
}

- runInNewThread
{
  return [self notImplemented:_cmd];
}

- removeLocal: anObj
{
  return [self removeLocalObject:anObj];
}

- removeRemote: anObj
{
  return [self removeProxy:anObj];
}

- (List*) localObjects
{
  id aList = [[List alloc] init];
  id cs = [self localObjects];
  void add_to_aList(id c)
    {
      [aList addObject:c];
    }
  [cs withObjectsCall:add_to_aList];
  [cs free];
  return aList;
}

- (List*) remoteObjects
{
  id aList = [[List alloc] init];
  id cs = [self proxies];
  void add_to_aList(id c)
    {
      [aList addObject:c];
    }
  [cs withObjectsCall:add_to_aList];
  [cs free];
  return aList;
}

- getLocal: anObj
{
  return [self notImplemented:_cmd];
}

- getRemote: (unsigned)aName
{
  return [self proxyForTarget:aName];
}

- newLocal: anObj
{
  return [self notImplemented:_cmd];
}

- newRemote: (unsigned)r withProtocol: aProtocol
{
  return [[self proxyClass] newForRemote:r connection:self];
}

- insertProxy: anObj
{
  return [self addProxy:anObj];
}

- setRoot: anObj
{
  return [self setRootObject:anObj];
}

- (Class*) proxyClass
{
  /* we might replace this with a per-Connection proxy class. */
  return NXConnectionProxyClass;
}

- (Class*) coderClass
{
  return [NXConnectedCoder class];
}

@end


@implementation Object (NXConnectionCompatibility)

- encodeRemotelyFor: (NXConnection*)conn 
   freeAfterEncoding: (BOOL*)fp
   isBycopy: (BOOL)f;
{
  if (f)
    return self;
  return [[conn proxyClass] newBogusLocal:self];
}

@end


@implementation NXConnectedCoder

- encodeData:(void *)data ofType:(const char *)type
{
  [self encodeValueOfType:type at:data withName:NULL];
  return self;
}

- encodeBytes:(const void *)bytes count:(int)count
{
  char types[16];
  sprintf(types, "[%dc]", count);
  [self encodeValueOfType:types at:bytes withName:NULL];
  return self;
}

- encodeVM:(const void *)bytes count:(int)count
{
  [self notImplemented:_cmd];
  return self;
}

- encodeMachPort:(port_t)port
{
  [self notImplemented:_cmd];
  return self;
}

- encodeObject:anObject
{
  [self encodeObject:anObject withName:NULL];
  return self;
}

- encodeObjectBycopy:anObject
{
  [self encodeObjectBycopy:anObject withName:NULL];
  return self;
}

- decodeData:(void *)d ofType:(const char *)t
{
  [self decodeValueOfType:t at:d withName:NULL];
  return self;
}

- decodeBytes:(void *)bytes count:(int)count
{
  char types[16];
  sprintf(types, "[%dc]", count);
  [self decodeValueOfType:types at:bytes withName:NULL];
  return self;
}

- decodeVM:(void **)bytes count:(int *)count
{
  [self notImplemented:_cmd];
  return self;
}

- decodeMachPort:(port_t *)pp
{
  [self notImplemented:_cmd];
  return self;
}

/* WARNING: This won't work if the object is a GNU forward object reference */
- (id) decodeObject
{
  id o;
  [self decodeObjectAt:&o withName:NULL];
  return o;
}

- (void) _doEncodeObject: anObj
{
  BOOL f = NO;
  Class *c;
  id o;

  assert([[self connection] class] == [NXConnection class]);
  /* xxx We have yet to set isBycopy correctly */
  o = [anObj encodeRemotelyFor:(NXConnection*)[self connection]
	     freeAfterEncoding:&f
	     isBycopy:NO];
  c = [o classForConnectedCoder:self];
  [self encodeClass:c];
  [c encodeObject:o withConnectedCoder:self];
  if (f)
    [anObj free];
  [o free];
}

@end
