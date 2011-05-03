/* Implementation for NSURLConnection for GNUstep
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

@interface	GSURLConnection : NSObject <NSURLProtocolClient>
{
@public
  NSURLConnection		*_parent;	// Not retained
  NSURLRequest			*_request;
  NSURLProtocol			*_protocol;
  id				_delegate;
}
@end
 
typedef struct {
  @defs(NSURLConnection)
} priv;
#define	this	((GSURLConnection*)(((priv*)self)->_NSURLConnectionInternal))
#define	inst	((GSURLConnection*)(((priv*)o)->_NSURLConnectionInternal))

@implementation	NSURLConnection

+ (id) allocWithZone: (NSZone*)z
{
  NSURLConnection	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLConnectionInternal
        = NSAllocateObject([GSURLConnection class], 0, z);
      inst->_parent = o;
    }
  return o;
}

+ (BOOL) canHandleRequest: (NSURLRequest *)request
{
  // FIXME
  return NO;
}

+ (NSURLConnection *) connectionWithRequest: (NSURLRequest *)request
				   delegate: (id)delegate
{
  NSURLConnection	*o = [self alloc];

  o = [o initWithRequest: request delegate: delegate];
  return AUTORELEASE(o);
}

- (void) dealloc
{
  RELEASE(this);
  [super dealloc];
}

- (void) cancel
{
  [this->_protocol stopLoading];
  DESTROY(this->_protocol);
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
  if ((self = [super init]) != nil)
    {
      this->_request = [request copy];
      this->_delegate = [delegate retain];
      // FIXME ... start connection
    }
  return self;
}

@end



@implementation NSObject (NSURLConnectionDelegate)

- (void) connection: (NSURLConnection *)connection
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
}

- (void) connection: (NSURLConnection *)connection
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [[challenge sender]
    continueWithoutCredentialForAuthenticationChallenge: challenge];
}

- (void) connection: (NSURLConnection *)connection
     didReceiveData: (NSData *)data
{
}

- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse *)response
{
}

- (NSCachedURLResponse *) connection: (NSURLConnection *)connection
  willCacheResponse: (NSCachedURLResponse *)cachedResponse
{
  return cachedResponse;
}

- (NSURLRequest *) connection: (NSURLConnection *)connection
	      willSendRequest: (NSURLRequest *)request
	     redirectResponse: (NSURLResponse *)response
{
  return request;
}

@end



@implementation NSURLConnection (NSURLConnectionSynchronousLoading)

+ (NSData *) sendSynchronousRequest: (NSURLRequest *)request
		  returningResponse: (NSURLResponse **)response
			      error: (NSError **)error
{
  NSData	*data = nil;

  if ([self canHandleRequest: request] == YES)
    {
      NSURLConnection	*conn = [self alloc];

      conn = [conn initWithRequest: request delegate: nil];
      // FIXME ... handle load and get results;
      [conn release];
    }
  return data;
}

@end


@implementation	GSURLConnection

- (void) dealloc
{
  RELEASE(_protocol);
  RELEASE(_request);
  RELEASE(_delegate);
  [super dealloc];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{

}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
  [_delegate connection: _parent didFailWithError: error];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
	 didLoadData: (NSData *)data
{
  [_delegate connection: _parent didReceiveData: data];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [_delegate connection: _parent didReceiveAuthenticationChallenge: challenge];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
  [_delegate connection: _parent didReceiveResponse: response];
  if (policy == NSURLCacheStorageAllowed
    || policy == NSURLCacheStorageAllowedInMemoryOnly)
    {
      
      // FIXME ... cache response here
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  wasRedirectedToRequest: (NSURLRequest *)request
  redirectResponse: (NSURLResponse *)redirectResponse
{
  request = [_delegate connection: _parent
		  willSendRequest: request
	         redirectResponse: redirectResponse];
  // If we have been cancelled, our protocol will be nil
  if (_protocol != nil)
    {
      if (request == nil)
        {
	  [_delegate connectionDidFinishLoading: _parent];
	}
      else
        {
	  DESTROY(_protocol);
	  // FIXME start new request loading
	}
    }
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol
{
  [_delegate connectionDidFinishLoading: _parent];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [_delegate connection: _parent didCancelAuthenticationChallenge: challenge];
}

@end

