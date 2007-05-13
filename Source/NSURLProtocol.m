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

#include <Foundation/NSError.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSRunLoop.h>

#include "GNUstepBase/GSMime.h"

#include "GSPrivate.h"
#include "GSURLPrivate.h"


@interface _NSAboutURLProtocol : NSURLProtocol
@end

@interface _NSFTPURLProtocol : NSURLProtocol
@end

@interface _NSFileURLProtocol : NSURLProtocol
@end

@interface _NSHTTPURLProtocol : NSURLProtocol
{
  GSMimeParser		*_parser;		// for parsing incoming data
  NSEnumerator		*_headerEnumerator;
  float			_version;
  NSInputStream		*_body;			// for sending the body
  unsigned char		*_receiveBuf;		// buffer while receiving header fragments
  unsigned int		_receiveBufLength;	// how much is really used in the current buffer
  unsigned int		_receiveBufCapacity;	// how much is allocated
  unsigned		_statusCode;
  unsigned		_bodyPos;
  BOOL			_debug;
  BOOL			_shouldClose;
}
@end

@interface _NSHTTPSURLProtocol : _NSHTTPURLProtocol
@end



// Internal data storage
typedef struct {
  NSInputStream			*input;
  NSOutputStream		*output;
  NSCachedURLResponse		*cachedResponse;
  id <NSURLProtocolClient>	client;		// Not retained
  NSURLRequest			*request;
} Internal;
 
typedef struct {
  @defs(NSURLProtocol)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSURLProtocolInternal))
#define	inst	((Internal*)(((priv*)o)->_NSURLProtocolInternal))

static NSMutableArray	*registered = nil;
static NSLock		*regLock = nil;
static Class		abstractClass = nil;
static NSURLProtocol	*placeholder = nil;

@implementation	NSURLProtocol

+ (id) allocWithZone: (NSZone*)z
{
  NSURLProtocol	*o;

  if ((self == abstractClass) && (z == 0 || z == NSDefaultMallocZone()))
    {
      /* Return a default placeholder instance to avoid the overhead of
       * creating and destroying instances of the abstract class.
       */
      o = placeholder;
    }
  else
    {
      /* Create and return an instance of the concrete subclass.
       */
      o = (NSURLProtocol*)NSAllocateObject(self, 0, z);
    }
  return o;
}

+ (void) initialize
{
  if (registered == nil)
    {
      abstractClass = [NSURLProtocol class];
      placeholder = (NSURLProtocol*)NSAllocateObject(abstractClass, 0,
	NSDefaultMallocZone());
      registered = [NSMutableArray new];
      regLock = [NSLock new];
      [self registerClass: [_NSHTTPURLProtocol class]];
      [self registerClass: [_NSHTTPSURLProtocol class]];
      [self registerClass: [_NSFTPURLProtocol class]];
      [self registerClass: [_NSFileURLProtocol class]];
      [self registerClass: [_NSAboutURLProtocol class]];
    }
}

+ (id) propertyForKey: (NSString *)key inRequest: (NSURLRequest *)request
{
  return [request _propertyForKey: key];
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
  if (self == placeholder)
    {
      [self retain];
      return;
    }
  if (this != 0)
    {
      [self stopLoading];
      RELEASE(this->input);
      RELEASE(this->output);
      RELEASE(this->cachedResponse);
      RELEASE(this->request);
      NSZoneFree([self zone], this);
      _NSURLProtocolInternal = 0;
    }
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"%@ %@",
    [super description], this ? (id)this->request : nil];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      if (isa != abstractClass)
	{
	  _NSURLProtocolInternal = NSZoneCalloc(GSObjCZone(self),
	    1, sizeof(Internal));
	}
    }
  return self;
}

- (id) initWithRequest: (NSURLRequest *)request
	cachedResponse: (NSCachedURLResponse *)cachedResponse
		client: (id <NSURLProtocolClient>)client
{
  if (isa == abstractClass)
    {
      unsigned	count;

      DESTROY(self);
      [regLock lock];
      count = [registered count];
      while (count-- > 0)
        {
	  Class	proto = [registered objectAtIndex: count];

	  if ([proto canInitWithRequest: request] == YES)
	    {
	      self = [proto alloc];
	      break;
	    }
	}
      [regLock unlock];
      return [self initWithRequest: request
		    cachedResponse: cachedResponse
			    client: client];
    }
  if ((self = [self init]) != nil)
    {
      this->request = [request copy];
      this->cachedResponse = RETAIN(cachedResponse);
      this->client = client;	// Not retained
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
  a = [self canonicalRequestForRequest: a];
  b = [self canonicalRequestForRequest: b];
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






@implementation _NSHTTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  return [[[request URL] scheme] isEqualToString: @"http"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
  return request;
}

- (void) _didInitializeOutputStream: (NSOutputStream*)stream
{
  return;
}

- (void) dealloc
{
  [_parser release];			// received headers
  [_body release];			// for sending the body
  [super dealloc];
}

- (void) _schedule
{
  [this->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
			 forMode: NSDefaultRunLoopMode];
  [this->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
			  forMode: NSDefaultRunLoopMode];
}

- (void) startLoading
{
  static NSDictionary *methods = nil;

  if (methods == nil)
    {
      methods = [[NSDictionary alloc] initWithObjectsAndKeys: 
	self, @"HEAD",
	self, @"GET",
	self, @"POST",
	self, @"PUT",
	self, @"DELETE",
	self, @"TRACE",
	self, @"OPTIONS",
	self, @"CONNECT",
	nil];
      }
  if ([methods objectForKey: [this->request HTTPMethod]] == nil)
    {
      NSLog(@"Invalid HTTP Method: %@", this->request);
      [this->client URLProtocol: self didFailWithError:
	[NSError errorWithDomain: @"Invalid HTTP Method"
			    code: 0
			userInfo: nil]];
      return;
    }

  if (0 && this->cachedResponse)
    {
    }
  else
    {
      NSURL	*url = [this->request URL];
      NSHost	*host = [NSHost hostWithName: [url host]];
      int	port = [[url port] intValue];

      _bodyPos = 0;
      DESTROY(_parser);
      _parser = [GSMimeParser new];

      if (host == nil)
        {
	  host = [NSHost hostWithAddress: [url host]];	// try dotted notation
	}
      if (host == nil)
        {
	  host = [NSHost hostWithAddress: @"127.0.0.1"];	// final default
	}
      if (port == 0)
        {
	  // default if not specified
	  port = [[url scheme] isEqualToString: @"https"] ? 433 : 80;
	}

      [NSStream getStreamsToHost: host
			    port: port
		     inputStream: &this->input
		    outputStream: &this->output];
      if (!this->input || !this->output)
	{
#if 0
	  NSLog(@"did not create streams for %@: %u", host, [[url port] intValue]);
#endif
	  [this->client URLProtocol: self didFailWithError:
	    [NSError errorWithDomain: @"can't connect" code: 0 userInfo: 
	      [NSDictionary dictionaryWithObjectsAndKeys: 
		url, @"NSErrorFailingURLKey",
		host, @"NSErrorFailingURLStringKey",
		@"can't find host", @"NSLocalizedDescription",
		nil]]];
	  return;
	}
      RETAIN(this->input);
      RETAIN(this->output);
      [self _didInitializeOutputStream: this->output];
      [this->input setDelegate: self];
      [this->output setDelegate: self];
      [self _schedule];
      [this->input open];
      [this->output open];
    }
}

- (void) _unschedule
{
  [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
			 forMode: NSDefaultRunLoopMode];
  [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
			  forMode: NSDefaultRunLoopMode];
}

- (void) stopLoading
{
#if 0
  NSLog(@"stopLoading: %@", self);
#endif
  if (this->input != nil)
    {
      [self _unschedule];
      [this->input close];
      [this->output close];
      DESTROY(this->input);
      DESTROY(this->output);
#if 0
      // CHECKME - or does this come if the other side rejects the request?
      [this->client URLProtocol: self didFailWithError: [NSError errorWithDomain: @"cancelled" code: 0 userInfo: 
	      [NSDictionary dictionaryWithObjectsAndKeys: 
		      url, @"NSErrorFailingURLKey",
		      host, @"NSErrorFailingURLStringKey",
		      @"cancelled", @"NSLocalizedDescription",
		      nil]]];
#endif
    }
}


/*
 FIXME: 
 because we receive from untrustworthy sources here, we must protect against malformed headers trying to create buffer overflows.
 This might also be some very lage constant for record length which wraps around the 32bit address limit (e.g. a negative record length).
 Ending up in infinite loops blocking the system.
 */

- (void) _got: (NSStream*)stream
{
  unsigned char	buffer[BUFSIZ*64];
  int 		readCount;
  NSError	*e;
  NSData	*d;
  BOOL		wasInHeaders = NO;
  BOOL		complete = NO;

  readCount = [(NSInputStream *)stream read: buffer
				  maxLength: sizeof(buffer)];
  if (readCount < 0)
    {
      if ([stream  streamStatus] == NSStreamStatusError)
        {
	  e = [stream streamError];
	  if (_debug)
	    {
	      NSLog(@"receive error %@", e);
	    }
	  [self _unschedule];
	  [this->client URLProtocol: self didFailWithError: e];
	}
      return;
    }

  wasInHeaders = [_parser isInHeaders];
  d = [NSData dataWithBytes: buffer length: readCount];
  if ([_parser parse: d] == NO && (complete = [_parser isComplete]) == NO)
    {
      if (_debug == YES)
	{
	  NSLog(@"HTTP parse failure - %@", _parser);
	}
      e = [NSError errorWithDomain: @"parse error"
			      code: 0
			  userInfo: nil];
      [self _unschedule];
      [this->client URLProtocol: self didFailWithError: e];
      return;
    }
  else
    {
      BOOL		isInHeaders = [_parser isInHeaders];
      GSMimeDocument	*document = [_parser mimeDocument];

      if (wasInHeaders == YES && isInHeaders == NO)
        {
	  NSHTTPURLResponse	*response;
	  GSMimeHeader		*info;
	  NSString		*enc;
	  int			len = -1;
	  NSString		*s;

	  info = [document headerNamed: @"http"];

	  _version = [[info value] floatValue];
	  if (_version < 1.1)
	    {
	      _shouldClose = YES;
	    }
	  else if ((s = [[document headerNamed: @"connection"] value]) != nil
	    && [s caseInsensitiveCompare: @"close"] == NSOrderedSame)
	    {
	      _shouldClose = YES;
	    }
	  else
	    {
	      _shouldClose = NO;	// Keep connection alive.
	    }

	  s = [info objectForKey: NSHTTPPropertyStatusCodeKey];
	  _statusCode = [s intValue];

	  s = [[document headerNamed: @"content-length"] value];
	  if ([s length] > 0)
	    {
	      len = [s intValue];
	    }

	  s = [info objectForKey: NSHTTPPropertyStatusReasonKey];
	  enc = [[document headerNamed: @"content-transfer-encoding"] value];
	  if (enc == nil)
	    {
	      enc = [[document headerNamed: @"transfer-encoding"] value];
	    }

	  response = [[NSHTTPURLResponse alloc] initWithURL: [this->request URL]
						   MIMEType: nil
				      expectedContentLength: len
					   textEncodingName: nil];
	  [response _setStatusCode: _statusCode text: s];
	  [document deleteHeaderNamed: @"http"];
	  [response _setHeaders: [document allHeaders]];

	  if (_statusCode == 204 || _statusCode == 304)
	    {
	      complete = YES;	// No body expected.
	    }
	  else if ([enc isEqualToString: @"chunked"] == YES)	
	    {
	      complete = NO;	// Read chunked body data
	    }
	  if (complete == NO && [d length] == 0)
	    {
	      complete = YES;	// Had EOF ... terminate
	    }

	  s = [[document headerNamed: @"location"] value];
	  if ([s length] > 0)
	    { // Location: entry exists
	      NSURLRequest	*request;
	      NSURL		*url;

	      url = [NSURL URLWithString: s];
	      request = [NSURLRequest requestWithURL: url];
	      if (request != nil)
	        {
		  NSError	*e;

		  e = [NSError errorWithDomain: @"Invalid redirect request"
					  code: 0
				      userInfo: nil];
		  [this->client URLProtocol: self
			   didFailWithError: e];
		}
	      else
	        {
		  [this->client URLProtocol: self
		     wasRedirectedToRequest: request
			   redirectResponse: response];
		}
	    }
	  else
	    {
	      NSURLCacheStoragePolicy policy;

	      /* Tell the client that we have a response and how
	       * it should be cached.
	       */
	      policy = [this->request cachePolicy];
	      if (policy == NSURLRequestUseProtocolCachePolicy)
		{
		  if ([self isKindOfClass: [_NSHTTPSURLProtocol class]] == YES)
		    {
		      /* For HTTPS we should not allow caching unless the
		       * request explicitly wants it.
		       */
		      policy = NSURLCacheStorageNotAllowed;
		    }
		  else
		    {
		      /* For HTTP we allow caching unless the request
		       * specifically denies it.
		       */
		      policy = NSURLCacheStorageAllowed;
		    }
		}
	      [this->client URLProtocol: self
		     didReceiveResponse: response
		     cacheStoragePolicy: policy];
	    }
	}

      if (complete == YES)
	{
	  [self _unschedule];
	  if (_shouldClose == YES)
	    {
	      [this->input close];
	      [this->output close];
	      DESTROY(this->input);
	      DESTROY(this->output);
	    }

#if 0
	  /*
	   * Retrieve essential keys from document
	   */
	  if (_statusCode == 401 && self->challenged < 2)
	    {
	      GSMimeHeader	*ah;

	      self->challenged++;	// Prevent repeated challenge/auth
	      if ((ah = [document headerNamed: @"WWW-Authenticate"]) != nil)
		{
		  NSURLProtectionSpace	*space;
		  NSString		*ac;
		  GSHTTPAuthentication	*authentication;
		  NSString		*method;
		  NSString		*auth;

		  ac = [ah value];
		  space = [GSHTTPAuthentication
		    protectionSpaceForAuthentication: ac requestURL: url];
		  if (space == nil)
		    {
		      authentication = nil;
		    }
		  else
		    {
		      NSURLCredential	*cred;

		      /*
		       * Create credential from user and password
		       * stored in the URL.
		       * Returns nil if we have no username or password.
		       */
		      cred = [[NSURLCredential alloc]
			initWithUser: [url user]
			password: [url password]
			persistence: NSURLCredentialPersistenceForSession];

		      if (cred == nil)
			{
			  authentication = nil;
			}
		      else
			{
			  /*
			   * Get the digest object and ask it for a header
			   * to use for authorisation.
			   * Returns nil if we have no credential.
			   */
			  authentication = [GSHTTPAuthentication
			    authenticationWithCredential: cred
			    inProtectionSpace: space];
			  RELEASE(cred);
			}
		    }

		  method = [request objectForKey: GSHTTPPropertyMethodKey];
		  if (method == nil)
		    {
		      if ([wData length] > 0)
			{
			  method = @"POST";
			}
		      else
			{
			  method = @"GET";
			}
		    }

		  auth = [authentication authorizationForAuthentication: ac
		    method: method
		    path: [url path]];
		  if (auth != nil)
		    {
		      [self writeProperty: auth forKey: @"Authorization"];
		      [self _tryLoadInBackground: u];
		      return;	// Retrying.
		    }
		}
	    }
#endif

	  /*
	   * Tell superclass that we have successfully loaded the data.
	   */
	  d = [_parser data];
	  if (_bodyPos > 0)
	    {
	      d = [d subdataWithRange: 
	        NSMakeRange(_bodyPos, [d length] - _bodyPos)];
	    }
	  _bodyPos = [d length];
	  [this->client URLProtocol: self didLoadData: d];

	  if (_statusCode >= 200 && _statusCode < 300)
	    {
	      [this->client URLProtocolDidFinishLoading: self];
	    }
	  else
	    {
	      [this->client URLProtocol: self
		       didFailWithError: [NSError errorWithDomain: @"receive error" code: 0 userInfo: nil]];

	    }
	}
      else
	{
	  /*
	   * Report partial data if possible.
	   */
	  if ([_parser isInBody])
	    {
	      d = [_parser data];
	      if (_bodyPos > 0)
	        {
		  d = [d subdataWithRange: 
		    NSMakeRange(_bodyPos, [d length] - _bodyPos)];
		}
	      _bodyPos = [d length];
	      [this->client URLProtocol: self didLoadData: d];
	    }
	}

      if (complete == NO && readCount == 0)
	{
	  /* The read failed ... dropped, but parsing is not complete.
	   * The request was sent, so we can't know whether it was
	   * lost in the network or the remote end received it and
	   * the response was lost.
	   */
	  if (_debug == YES)
	    {
	      NSLog(@"HTTP response not received - %@", _parser);
	    }
	  [this->client URLProtocol: self
		   didFailWithError: [NSError errorWithDomain: @"receive error" code: 0 userInfo: nil]];
	}
    }
}

- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event
{
#if 0
  NSLog(@"stream: %@ handleEvent: %x for: %@", stream, event, self);
#endif

  if (stream == this->input) 
    {
      switch(event)
	{
	  case NSStreamEventHasBytesAvailable: 
	  case NSStreamEventEndEncountered:
	    [self _got: stream];
	    return;

	  case NSStreamEventOpenCompleted: 
#if 0
	    NSLog(@"HTTP input stream opened");
#endif
	    return;

	  default: 
	    break;
	}
    }
  else if (stream == this->output)
    {
      unsigned char *msg;

  #if 0
      NSLog(@"An event occurred on the output stream.");
  #endif
      /* e.g.
      POST /wiki/Spezial: Search HTTP/1.1
      Host: de.wikipedia.org
      Content-Type: application/x-www-form-urlencoded
      Content-Length: 24
      
      search=Katzen&go=Artikel  <- body
      */

      switch(event)
	{
	  case NSStreamEventOpenCompleted: 
	    {
    #if 0
	      NSLog(@"HTTP output stream opened");
    #endif
	      msg = (unsigned char *)[[NSString stringWithFormat:
		@"%@ %@ HTTP/1.0\r\n",
		[this->request HTTPMethod],
		[[this->request URL] absoluteString]] UTF8String];
	      [(NSOutputStream *) stream write: msg
				     maxLength: strlen((char *) msg)];
    #if 0
	      NSLog(@"sent %s", msg);
    #endif
	      _headerEnumerator = [[[this->request allHTTPHeaderFields] keyEnumerator] retain];
	      return;
	    }
	  case NSStreamEventHasSpaceAvailable: 
	    {
	      // FIXME: should also send out relevant Cookies
	      if (_headerEnumerator)
		{ // send next header
		NSString *key;
		key = [_headerEnumerator nextObject];
		if (key)
		  {
    #if 0
		  NSLog(@"sending %@: %@", key, [this->request valueForHTTPHeaderField: key]);
    #endif
		  msg=(unsigned char *)[[NSString stringWithFormat: @"%@: %@\r\n", key, [this->request valueForHTTPHeaderField: key]] UTF8String];
		  }
		else
		  { // was last header entry
		  [_headerEnumerator release];
		  _headerEnumerator=nil;
		  msg=(unsigned char *) "\r\n";        // send empty line
		  _body=[[this->request HTTPBodyStream] retain];  // if present
		  if (!_body && [this->request HTTPBody])
		    _body=[[NSInputStream alloc] initWithData: [this->request HTTPBody]];  // prepare to send request body
		  [_body open];
		  }
		[(NSOutputStream *) stream write: msg maxLength: strlen((char *) msg)];  // NOTE: we might block here if header value is too long
    #if 0
		NSLog(@"sent %s", msg);
    #endif
		return;
		}
	      else if (_body)
		{ // send (next part of) body until done
		if ([_body hasBytesAvailable])
		  {
		  unsigned char buffer[512];
		  int len=[_body read: buffer maxLength: sizeof(buffer)];  // read next block from stream
		  if (len < 0)
		    {
    #if 0
		    NSLog(@"error reading from HTTPBody stream %@", [NSError _last]);
    #endif
		    [self _unschedule];
		    return;
		    }
		  [(NSOutputStream *) stream write: buffer maxLength: len];  // send
		  }
		else
		  { // done
    #if 0
		  NSLog(@"request sent");
    #endif
		  [self _unschedule];  // well, we should just unschedule the send stream
		  [_body close];
		  [_body release];
		  _body=nil;
		  }
		}
	      return;  // done
	    }
	  default: 
	    break;
	}
    }
  NSLog(@"An error %@ occurred on the event %08x of stream %@ of %@", [stream streamError], event, stream, self);
  [this->client URLProtocol: self didFailWithError: [stream streamError]];
}

@end

@implementation _NSHTTPSURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  return [[[request URL] scheme] isEqualToString: @"https"];
}

- (void) _didInitializeOutputStream: (NSOutputStream *) stream
{
  [stream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	       forKey: NSStreamSocketSecurityLevelKey];
}

@end

@implementation _NSFTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  return [[[request URL] scheme] isEqualToString: @"ftp"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
  return request;
}

- (void) startLoading
{
  if (this->cachedResponse)
    { // handle from cache
    }
  else
    {
      NSURL	*url = [this->request URL];
      NSHost	*host = [NSHost hostWithName: [url host]];

      if (host == nil)
        {
	  host = [NSHost hostWithAddress: [url host]];
	}
      [NSStream getStreamsToHost: host
			    port: [[url port] intValue]
		     inputStream: &this->input
		    outputStream: &this->output];
      if (this->input == nil || this->output == nil)
	{
	  [this->client URLProtocol: self didFailWithError:
	    [NSError errorWithDomain: @"can't connect" code: 0 userInfo: nil]];
	  return;
	}
      RETAIN(this->input);
      RETAIN(this->output);
      [this->input setDelegate: self];
      [this->output setDelegate: self];
      [this->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
			     forMode: NSDefaultRunLoopMode];
      [this->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
			      forMode: NSDefaultRunLoopMode];
      // set socket options for ftps requests
      [this->input open];
      [this->output open];
    }
}

- (void) stopLoading
{
  if (this->input)
    {
      [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
			     forMode: NSDefaultRunLoopMode];
      [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
			      forMode: NSDefaultRunLoopMode];
      [this->input close];
      [this->output close];
      DESTROY(this->input);
      DESTROY(this->output);
    }
}

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) event
{
  if (stream == this->input) 
    {
      switch(event)
	{
	  case NSStreamEventHasBytesAvailable: 
	    {
	    NSLog(@"FTP input stream has bytes available");
	    // implement FTP protocol
//			[this->client URLProtocol: self didLoadData: [NSData dataWithBytes: buffer length: len]];	// notify
	    return;
	    }
	  case NSStreamEventEndEncountered: 	// can this occur in parallel to NSStreamEventHasBytesAvailable???
		  NSLog(@"FTP input stream did end");
		  [this->client URLProtocolDidFinishLoading: self];
		  return;
	  case NSStreamEventOpenCompleted: 
		  // prepare to receive header
		  NSLog(@"FTP input stream opened");
		  return;
	  default: 
		  break;
	}
    }
  else if (stream == this->output)
    {
      NSLog(@"An event occurred on the output stream.");
  	// if successfully opened, send out FTP request header
    }
  NSLog(@"An error %@ occurred on the event %08x of stream %@ of %@",
    [stream streamError], event, stream, self);
  [this->client URLProtocol: self didFailWithError: [stream streamError]];
}

@end

@implementation _NSFileURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  return [[[request URL] scheme] isEqualToString: @"file"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
  return request;
}

- (void) startLoading
{
  // check for GET/PUT/DELETE etc so that we can also write to a file
  NSData	*data;
  NSURLResponse	*r;

  data = [NSData dataWithContentsOfFile: [[this->request URL] path]
  /* options: error: - don't use that because it is based on self */];
  if (data == nil)
    {
      [this->client URLProtocol: self didFailWithError:
	[NSError errorWithDomain: @"can't load file" code: 0 userInfo:
	  [NSDictionary dictionaryWithObjectsAndKeys: 
	    [this->request URL], @"URL",
	    [[this->request URL] path], @"path",
	    nil]]];
      return;
    }

  /* FIXME ... maybe should infer MIME type and encoding from extension or BOM
   */
  r = [[NSURLResponse alloc] initWithURL: [this->request URL]
				MIMEType: @"text/html"
		   expectedContentLength: [data length]
			textEncodingName: @"unknown"];	
  [this->client URLProtocol: self
    didReceiveResponse: r
    cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
  [this->client URLProtocol: self didLoadData: data];
  [this->client URLProtocolDidFinishLoading: self];
  RELEASE(r);
}

- (void) stopLoading
{
  return;
}

@end

@implementation _NSAboutURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  return [[[request URL] scheme] isEqualToString: @"about"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
  return request;
}

- (void) startLoading
{
  NSURLResponse	*r;
  NSData	*data = [NSData data];	// no data

  // we could pass different content depending on the [url path]
  r = [[NSURLResponse alloc] initWithURL: [this->request URL]
				MIMEType: @"text/html"
		   expectedContentLength: 0
			textEncodingName: @"utf-8"];	
  [this->client URLProtocol: self
    didReceiveResponse: r
    cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
  [this->client URLProtocol: self didLoadData: data];
  [this->client URLProtocolDidFinishLoading: self];
  RELEASE(r);
}

- (void) stopLoading
{
  return;
}

@end
