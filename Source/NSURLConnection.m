/* Implementation for NSURLConnection for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#define	EXPOSE_NSURLConnection_IVARS	1
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSDebug.h"
#import "GSURLPrivate.h"

@interface _NSURLConnectionDataCollector : NSObject <NSURLProtocolClient>
{
  NSURLConnection	*_connection;	// Not retained
  NSMutableData		*_data;
  NSError		**_error;
  NSURLResponse		**_response;
  BOOL			_done;
}

- (id) initWithResponsePointer: (NSURLResponse **)response
	       andErrorPointer: (NSError **)error;
- (NSData*) _data;
- (BOOL) _done;
- (void) _setConnection: (NSURLConnection *)c;

@end

@implementation _NSURLConnectionDataCollector

- (id) initWithResponsePointer: (NSURLResponse **)response
	       andErrorPointer: (NSError **)error
{
  if ((self = [super init]) != nil)
    {
      _response = response;
      _error = error;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_data);
  [super dealloc];
}

- (BOOL) _done
{
  return _done;
}

- (NSData*) _data
{
  return _data;
}

- (void) _setConnection: (NSURLConnection*)c
{
  _connection = c;
}

// notification handler

- (void) URLProtocol: (NSURLProtocol*)proto
cachedResponseIsValid: (NSCachedURLResponse*)resp
{
  return;
}

- (void) URLProtocol: (NSURLProtocol*)proto
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  return;
}

- (void) URLProtocol: (NSURLProtocol*)proto
didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  return;
}

- (void) URLProtocol: (NSURLProtocol*)proto
wasRedirectedToRequest: (NSURLRequest*)request
redirectResponse: (NSURLResponse*)redirectResponse
{
  return;
}

- (void) URLProtocol: (NSURLProtocol*)proto
    didFailWithError: (NSError*)error
{
  *_error = error;
  _done = YES;
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
  *_error = error;
  _done = YES;
}

- (void) URLProtocol: (NSURLProtocol*)proto
  didReceiveResponse: (NSURLResponse*)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
  *_response = response;
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol*)proto
{
  _done = YES;
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
  _done = YES;
}


- (void) URLProtocol: (NSURLProtocol*)proto
	 didLoadData: (NSData*)data
{
  if (_data == nil)
    {
      _data = [data mutableCopy];
    }
  else
    {
      [_data appendData: data];
    }
}

- (void) connection: (NSURLConnection *)connection
     didReceiveData: (NSData *)data
{
  if (_data == nil)
    {
      _data = [data mutableCopy];
    }
  else
    {
      [_data appendData: data];
    }
}

@end


typedef struct
{
  NSURLRequest			*_request;
  NSURLProtocol			*_protocol;
  id				_delegate;	// Not retained
  BOOL				_debug;
} Internal;
 
#define	this	((Internal*)(self->_NSURLConnectionInternal))
#define	inst	((Internal*)(o->_NSURLConnectionInternal))

@implementation	NSURLConnection

+ (id) allocWithZone: (NSZone*)z
{
  NSURLConnection	*o = [super allocWithZone: z];

  if (o != nil)
    {
#if	GS_WITH_GC
      o->_NSURLConnectionInternal
	= NSAllocateCollectable(sizeof(Internal), NSScannedOption);
#else
      o->_NSURLConnectionInternal = NSZoneCalloc(GSObjCZone(self),
	1, sizeof(Internal));
#endif
    }
  return o;
}

+ (BOOL) canHandleRequest: (NSURLRequest *)request
{
  return ([NSURLProtocol _classToHandleRequest: request] != nil);
}

+ (NSURLConnection *) connectionWithRequest: (NSURLRequest *)request
				   delegate: (id)delegate
{
  NSURLConnection	*o = [self alloc];

  o = [o initWithRequest: request delegate: delegate];
  return AUTORELEASE(o);
}

- (void) cancel
{
  [this->_protocol stopLoading];
  DESTROY(this->_protocol);
}

- (void) dealloc
{
  if (this != 0)
    {
      [self cancel];
      RELEASE(this->_request);
      NSZoneFree([self zone], this);
      _NSURLConnectionInternal = 0;
    }
  [super dealloc];
}

- (void) finalize
{
  if (this != 0)
    {
      [self cancel];
    }
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
  if ((self = [super init]) != nil)
    {
      this->_request = [request copy];
      this->_delegate = delegate;
      this->_protocol = [[NSURLProtocol alloc]
	initWithRequest: this->_request
	cachedResponse: nil
	client: (id<NSURLProtocolClient>)self];
      [this->_protocol startLoading];
      this->_debug = GSDebugSet(@"NSURLConnection");
    }
  return self;
}

@end



@implementation NSObject (NSURLConnectionDelegate)

- (void) connection: (NSURLConnection *)connection
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  return;
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
  return;
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
  return;
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
  return;
}

- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse *)response
{
  return;
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
      _NSURLConnectionDataCollector	*collector;
      NSURLConnection			*conn;
      NSRunLoop				*loop;

      collector = [_NSURLConnectionDataCollector alloc];
      collector = [collector initWithResponsePointer: response
				     andErrorPointer: error];
      conn = [self alloc];
      conn = [conn initWithRequest: request delegate: AUTORELEASE(collector)];
      [collector _setConnection: conn];
      loop = [NSRunLoop currentRunLoop];
      while ([collector _done] == NO)
        {
	  NSDate	*limit;

	  limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 1.0];
	  [loop runMode: NSDefaultRunLoopMode beforeDate: limit];
	  RELEASE(limit);
	}
      data = RETAIN([collector _data]);
    }
  return AUTORELEASE(data);
}

@end


@implementation	NSURLConnection (URLProtocolClient)

- (void) URLProtocol: (NSURLProtocol *)protocol
  cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{

}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
  [this->_delegate connection: self didFailWithError: error];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
	 didLoadData: (NSData *)data
{
  [this->_delegate connection: self didReceiveData: data];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [this->_delegate connection: self
  didReceiveAuthenticationChallenge: challenge];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
  [this->_delegate connection: self didReceiveResponse: response];
  if (policy == NSURLCacheStorageAllowed
    || policy == NSURLCacheStorageAllowedInMemoryOnly)
    {
      // FIXME ... cache response here?
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  wasRedirectedToRequest: (NSURLRequest *)request
  redirectResponse: (NSURLResponse *)redirectResponse
{
  if (this->_debug)
    {
      NSLog(@"%@ tell delegate %@ about redirect to %@ as a result of %@",
        self, this->_delegate, request, redirectResponse);
    }
  request = [this->_delegate connection: self
			willSendRequest: request
		       redirectResponse: redirectResponse];
  if (this->_protocol == nil)
    {
      if (this->_debug)
	{
          NSLog(@"%@ delegate cancelled request", self);
	}
      /* Our protocol is nil, so we have been cancelled by the delegate.
       */
      return;
    }
  if (request != nil)
    {
      if (this->_debug)
	{
          NSLog(@"%@ delegate allowed redirect to %@", self, request);
	}
      /* Follow the redirect ... stop the old load and start a new one.
       */
      [this->_protocol stopLoading];
      DESTROY(this->_protocol);
      ASSIGNCOPY(this->_request, request);
      this->_protocol = [[NSURLProtocol alloc]
	initWithRequest: this->_request
	cachedResponse: nil
	client: (id<NSURLProtocolClient>)self];
      [this->_protocol startLoading];
    }
  else if (this->_debug)
    {
      NSLog(@"%@ delegate cancelled redirect", self);
    }
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol
{
  [this->_delegate connectionDidFinishLoading: self];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [this->_delegate connection: self
  didCancelAuthenticationChallenge: challenge];
}

@end

