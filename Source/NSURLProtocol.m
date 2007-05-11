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
  NSMutableDictionary	*_headers;		// received headers
  NSEnumerator		*_headerEnumerator;	// enumerates headers while sending
  NSInputStream		*_body;			// for sending the body
  unsigned char		*_receiveBuf;		// buffer while receiving header fragments
  unsigned int		_receiveBufLength;	// how much is really used in the current buffer
  unsigned int		_receiveBufCapacity;	// how much is allocated
  unsigned		_statusCode;
  BOOL			_readingBody;
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
  if (this != 0)
    {
      [self stopLoading];
      RELEASE(this->input);
      RELEASE(this->output);
      RELEASE(this->cachedResponse);
      RELEASE(this->request);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"%@ %@",
    [super description], this->request];
}

- (id) initWithRequest: (NSURLRequest *)request
	cachedResponse: (NSCachedURLResponse *)cachedResponse
		client: (id <NSURLProtocolClient>)client
{
  if (isa == [NSURLProtocol class])
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
  if ((self = [super init]) != nil)
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
  [_headers release];			// received headers
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
#if 1
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
#if 1
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

- (BOOL) _processHeaderLine: (unsigned char *) buffer length: (int) len
{ // process header line
  unsigned char *c, *end;
  NSString *key, *val;
#if 0
  NSLog(@"process header line len=%d", len);
#endif
  // if it begins with ' ' or '\t' it is a continuation line to the previous header field
  if (!_headers)
  	{ // should be/must be the header line
  	unsigned major, minor;
  	if (sscanf((char *) buffer, "HTTP/%u.%u %u", &major, &minor, &_statusCode) == 3)
  		{ // response header line
  		if (major != 1 || minor > 1)
  			[this->client URLProtocol: self didFailWithError: [NSError errorWithDomain: @"Bad HTTP version" code: 0 userInfo: nil]];
  		// must be first - but must also be present and valid before we go to receive the body!
  		_headers=[NSMutableDictionary dictionaryWithCapacity: 10];	// start collecting headers
  //		if (_statusCode >= 400 && _statusCode <= 499)
  			NSLog(@"Client header: %.*s", len, buffer);
  		return NO;	// process next line
  		}
  	else
  		; // invalid header
  	return NO;	// process next line
  	}
  if (len == 0)
  	{ // empty line, i.e. end of header
  	NSString *loc;
  	NSHTTPURLResponse *response;

  	response = [[NSHTTPURLResponse alloc] initWithURL: [this->request URL]
	  MIMEType: nil
	  expectedContentLength: -1
	  textEncodingName: nil];
	[response _setHeaders: _headers];
	DESTROY(_headers);
	[response _setStatusCode: _statusCode text: @""];
  	loc = [response _valueForHTTPHeaderField: @"location"];
  	if ([loc length])
  		{ // Location: entry exists
  		NSURLRequest *request=[NSURLRequest requestWithURL: [NSURL URLWithString: loc]];
  		if (!request)
  			[this->client URLProtocol: self didFailWithError: [NSError errorWithDomain: @"Invalid redirect request" code: 0 userInfo: nil]]; // error
  		[this->client URLProtocol: self wasRedirectedToRequest: request redirectResponse: response];
  		}
  	else
  		{
  		NSURLCacheStoragePolicy policy=NSURLCacheStorageAllowed;	// default
  		// read from [this->request cachePolicy];
  		/*
  		 NSURLCacheStorageAllowed,
  		 NSURLCacheStorageAllowedInMemoryOnly
  		 NSURLCacheStorageNotAllowed
  		 */			 
  		if ([self isKindOfClass: [_NSHTTPSURLProtocol class]])
  			policy=NSURLCacheStorageNotAllowed;	// never
  		[this->client URLProtocol: self didReceiveResponse: response cacheStoragePolicy: policy];
  		}
  	return YES;
  	}
  for (c=buffer, end=c+len; *c != ':'; c++)
  	{
  	if (c == end)
  		{ // no colon found!
  		// raise bad header error or simply ignore?
  		return NO;	// keep processing header lines
  		}
  	}
  key=[[NSString stringWithCString: (char *) buffer length: c-buffer] capitalizedString];
  while(++c < end && (*c == ' ' || *c == '\t'))
  	;	// skip spaces
  val=[NSString stringWithCString: (char *) c length: end-c];
  [_headers setObject: val forKey: [key lowercaseString]];
  return NO;	// not yet done
}

- (void) _processHeader: (unsigned char *) buffer length: (int) len
{ // next header fragment received
  unsigned char *ptr, *end;
#if 0
  NSLog(@"received %d bytes", len);
#endif
  if (len <= 0)
  	return;	// ignore
  if (_receiveBufLength + len > _receiveBufCapacity)
  	{ // needs to increase capacity
  	_receiveBuf=objc_realloc(_receiveBuf, _receiveBufCapacity=_receiveBufLength+len+1);	// creates new one if NULL
  	if (!_receiveBuf)
  		; // FIXME allocation did fail: stop reception
  	}
  memcpy(_receiveBuf+_receiveBufLength, buffer, len);		// append to last partial block
  _receiveBufLength+=len;
#if 0
  NSLog(@"len=%u capacity=%u buf=%.*s", _receiveBufLength, _receiveBufCapacity, _receiveBufLength, _receiveBuf);
#endif
  ptr=_receiveBuf;	// start of current line
  end=_receiveBuf+_receiveBufLength;
  while(YES)
  	{ // look for complete lines
  	unsigned char *eol=ptr;
  	while(!(eol[0] == '\r' && eol[1] == '\n'))
  		{ // search next line end
  		eol++;
  		if (eol == end)
  			{ // no more lines found
#if 0
  			NSLog(@"no CRLF");
#endif
  			if (ptr != _receiveBuf)
  				{ // remove already processed lines from buffer
  				memmove(_receiveBuf, ptr, end-ptr);
  				_receiveBufLength-=(end-ptr);
  				}
  			return;
  			}
  		}
  	if ([self _processHeaderLine: ptr length: eol-ptr])
  		{ // done
  		if (this->input)
  			{ // is still open, i.e. hasn't been stopped in a client callback
  			if (eol+2 != end)
  				{ // we have already received the first fragment of the body
  				[this->client URLProtocol: self didLoadData: [NSData dataWithBytes: eol+2 length: (end-eol)-2]];	// notify
  				}
  			}
  		objc_free(_receiveBuf);
  		_receiveBuf=NULL;
  		_receiveBufLength=0;
  		_receiveBufCapacity=0;
  		_readingBody=YES;
  		return;
  		}				
  	ptr=eol+2;	// go to start of next line
  	}
}

/*
 FIXME: 
 because we receive from untrustworthy sources here, we must protect against malformed headers trying to create buffer overflows.
 This might also be some very lage constant for record length which wraps around the 32bit address limit (e.g. a negative record length).
 Ending up in infinite loops blocking the system.
 */

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) event
{
#if 0
  NSLog(@"stream: %@ handleEvent: %x for: %@", stream, event, self);
#endif
    if (stream == this->input) 
  	{
  	switch(event)
  		{
  		case NSStreamEventHasBytesAvailable: 
  			{
  				unsigned char buffer[512];
  				int len=[(NSInputStream *) stream read: buffer maxLength: sizeof(buffer)];
  				if (len < 0)
  					{
#if 1
  					NSLog(@"receive error %@", [NSError _last]);
#endif
  					[this->client URLProtocol: self didFailWithError: [NSError errorWithDomain: @"receive error" code: 0 userInfo: nil]];
  					[self _unschedule];
  					return;
  					}
  				if (_readingBody)
  					[this->client URLProtocol: self didLoadData: [NSData dataWithBytes: buffer length: len]];	// notify
  				else
  					[self _processHeader: buffer length: len];
  				return;
  			}
  		case NSStreamEventEndEncountered: 	// can this occur in parallel to NSStreamEventHasBytesAvailable???
  			{
#if 0
  				NSLog(@"end of response");
#endif
  				if (!_readingBody)
  					[this->client URLProtocol: self didFailWithError: [NSError errorWithDomain: @"incomplete header" code: 0 userInfo: nil]];
  				[this->client URLProtocolDidFinishLoading: self];
  				_readingBody=NO;
  				[self _unschedule];
  				return;
  			}
  		case NSStreamEventOpenCompleted: 
  			{ // prepare to receive header
#if 0
  				NSLog(@"HTTP input stream opened");
#endif
  				return;
  			}
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
  				msg=(unsigned char *) [[NSString stringWithFormat: @"%@ %@ HTTP/1.1\r\n",
  					[this->request HTTPMethod],
  					[[this->request URL] absoluteString]
  										] cString];	// FIXME: UTF8???
  				[(NSOutputStream *) stream write: msg maxLength: strlen((char *) msg)];
#if 1
  				NSLog(@"sent %s", msg);
#endif
  				_headerEnumerator=[[[this->request allHTTPHeaderFields] objectEnumerator] retain];
  				return;
  			}
  		case NSStreamEventHasSpaceAvailable: 
  			{
  				// FIXME: should also send out relevant Cookies
  				if (_headerEnumerator)
  					{ // send next header
  					NSString *key;
  					key=[_headerEnumerator nextObject];
  					if (key)
  						{
#if 1
  						NSLog(@"sending %@: %@", key, [this->request valueForHTTPHeaderField: key]);
#endif
  						msg=(unsigned char *)[[NSString stringWithFormat: @"%@: %@\r\n", key, [this->request valueForHTTPHeaderField: key]] UTF8String];
  						}
  					else
  						{ // was last header entry
  						[_headerEnumerator release];
  						_headerEnumerator=nil;
  						msg=(unsigned char *) "\r\n";				// send empty line
  						_body=[[this->request HTTPBodyStream] retain];	// if present
  						if (!_body && [this->request HTTPBody])
  							_body=[[NSInputStream alloc] initWithData: [this->request HTTPBody]];	// prepare to send request body
  						[_body open];
  						}
  					[(NSOutputStream *) stream write: msg maxLength: strlen((char *) msg)];	// NOTE: we might block here if header value is too long
#if 1
  					NSLog(@"sent %s", msg);
#endif
  					return;
  					}
  				else if (_body)
  					{ // send (next part of) body until done
  					if ([_body hasBytesAvailable])
  						{
  						unsigned char buffer[512];
  						int len=[_body read: buffer maxLength: sizeof(buffer)];	// read next block from stream
  						if (len < 0)
  							{
#if 1
  							NSLog(@"error reading from HTTPBody stream %@", [NSError _last]);
#endif
  							[self _unschedule];
  							return;
  							}
  						[(NSOutputStream *) stream write: buffer maxLength: len];	// send
  						}
  					else
  						{ // done
#if 0
  						NSLog(@"request sent");
#endif
  						[self _unschedule];	// well, we should just unschedule the send stream
  						[_body close];
  						[_body release];
  						_body=nil;
  						}
  					}
  				return;	// done
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
