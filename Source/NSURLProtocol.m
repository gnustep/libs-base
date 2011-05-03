/* Implementation for NSURLProtocol for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <frm@gnu.org>
   Date: 2006
   
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
   */ 

#include "GSURLPrivate.h"


// Internal data storage
typedef struct {
  NSInputStream			*input;
  NSOutputStream		*output;
  NSCachedURLResponse		*cachedResponse;
  id <NSURLProtocolClient>	client;
  NSURLRequest			*request;
} Internal;
 
typedef struct {
  @defs(NSURLProtocol)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSURLProtocolInternal))
#define	inst	((Internal*)(((priv*)o)->_NSURLProtocolInternal))

static NSMutableArray	*registered = nil;
static NSLock		*regLock = nil;

@implementation	NSURLProtocol

+ (id) allocWithZone: (NSZone*)z
{
  NSURLProtocol	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLProtocolInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

+ (void) initialize
{
  if (registered == nil)
    {
      registered = [NSMutableArray new];
      regLock = [NSLock new];
    }
}

+ (BOOL) registerClass: (Class)protocolClass
{
  if ([protocolClass isSubclassOfClass: [NSURLProtocol class]] == YES)
    {
      [regLock lock];
      [registered addObject: protocolClass];
      [regLock unlock];
      return YES;
    }
  return NO;
}

+ (id) propertyForKey: (NSString *)key inRequest: (NSURLRequest *)request
{
  return [request _propertyForKey: key];
}

+ (void) setProperty: (id)value
	      forKey: (NSString *)key
	   inRequest: (NSMutableURLRequest *)request
{
  [request _setProperty: value forKey: key];
}

+ (void) unregisterClass: (Class)protocolClass
{
  [regLock lock];
  [registered removeObjectIdenticalTo: protocolClass];
  [regLock unlock];
}

- (NSCachedURLResponse *) cachedResponse
{
  return this->cachedResponse;
}

- (id <NSURLProtocolClient>) client
{
  return this->client;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->input);
      RELEASE(this->output);
      RELEASE(this->cachedResponse);
      RELEASE(this->client);
      RELEASE(this->request);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (id) initWithRequest: (NSURLRequest *)request
	cachedResponse: (NSCachedURLResponse *)cachedResponse
		client: (id <NSURLProtocolClient>)client
{
  if ((self = [super init]) != nil)
    {
      this->request = [request copy];
      this->cachedResponse = RETAIN(cachedResponse);
      this->client = RETAIN(client);
    }
  return self;
}

- (NSURLRequest *) request
{
  return this->request;
}

@end


@implementation	NSURLProtocol (Subclassing)

+ (BOOL) canInitWithRequest: (NSURLRequest *)request
{
  [self subclassResponsibility: _cmd];
  return NO;
}

+ (NSURLRequest *) canonicalRequestForRequest: (NSURLRequest *)request
{
  return request;
}

+ (BOOL) requestIsCacheEquivalent: (NSURLRequest *)a
			toRequest: (NSURLRequest *)b
{
  return [a isEqual: b];
}

- (void) startLoading
{
  [self subclassResponsibility: _cmd];
}

- (void) stopLoading
{
  [self subclassResponsibility: _cmd];
}

@end

