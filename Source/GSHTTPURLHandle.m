/** GSHTTPURLHandle.m - Class GSHTTPURLHandle
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written by: 		Mark Allison <mark@brainstorm.co.uk>
   Integrated by:	Richard Frith-Macdonald <rfm@gnu.org>
   Date:		November 2000 		
   
   This file is part of the GNUstep Library.
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include "config.h"
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSData.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/GSMime.h>
#include <string.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <sys/file.h>

#ifdef HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>		// For O_WRONLY, etc
#endif

static NSString	*httpVersion = @"1.1";

char emp[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z',
    '0','1','2','3','4','5','6','7','8','9','+','/'
};
 
@interface GSHTTPURLHandle : NSURLHandle
{
  BOOL			tunnel;
  BOOL			debug;
  NSFileHandle          *sock;
  NSURL                 *url;
  NSMutableData         *dat;
  GSMimeParser		*parser;
  GSMimeDocument	*document;
  NSMutableDictionary   *pageInfo;
  NSMutableDictionary   *wProperties;
  NSData		*wData;
  NSMutableDictionary   *request;
  unsigned int          bodyPos;
  enum {
    idle,
    connecting,
    writing,
    reading,
  } connectionState;
}
- (void) setDebug: (BOOL)flag;
@end

/**
 * <p>
 *   This is a <em>PRIVATE</em> subclass of NSURLHandle.
 *   It is documented here in order to give you information about the
 *   default behavior of an NSURLHandle created to deal with a URL
 *   that has either the <code>http</code> or <code>https</code> scheme.
 *   The name and/or other implementation details of this class
 *   may be changed at any time.
 * </p>
 * <p>
 *   A GSHTTPURLHandle instance is used to manage connections to
 *   <code>http</code> and <code>https</code> URLs.
 *    Secure connections are handled automatically
 *   (using openSSL) for URLs with the scheme <code>https</code>.
 *   Connection via proxy server is supported, as is proxy tunneling
 *   for secure connections.  Basic parsing of <code>http</code>
 *   headers is performed to extract <code>http</code> status
 *   information, cookies etc.  Cookies are
 *   retained and automatically sent during subsequent requests where
 *   the cookie is valid.
 * </p>
 * <p>
 *   Header information from the current page may be obtained using
 *   -propertyForKey and -propertyForKeyIfAvailable.  <code>HTTP</code>
 *   status information can be retrieved as by calling either of these 
 *   methods specifying one of the following keys:
 * </p>
 * <list>
 *   <item>
 *     NSHTTPPropertyStatusCodeKey - numeric status code
 *   </item>
 *   <item>
 *     NSHTTPPropertyStatusReasonKey - text describing status
 *   </item>
 *   <item>
 *     NSHTTPPropertyServerHTTPVersionKey - <code>http</code>
 *     version supported by remote server
 *   </item>
 * </list>
 * <p>
 *   According to MacOS-X headers, the following should also
 *   be supported, but currently are not:
 * </p>
 * <list>
 *   <item>NSHTTPPropertyRedirectionHeadersKey</item>
 *   <item>NSHTTPPropertyErrorPageDataKey</item>
 * </list>
 * <p>
 *   The omission of these headers is not viewed as important at
 *   present, since the MacOS-X public beta implementation doesn't
 *   work either.
 * </p>
 * <p>
 *   Other calls to -propertyForKey and -propertyForKeyIfAvailable may
 *   be made specifying a <code>http</code> header field name.
 *   For example specifying a key name of &quot;Content-Length&quot;
 *   would return the value of the &quot;Content-Length&quot; header
 *   field.
 * </p>
 * <p>
 *   [GSHTTPURLHandle-writeProperty:forKey:]
 *   can be used to specify the parameters
 *   for the <code>http</code> request.  The default request uses the
 *   &quot;GET&quot; method when fetching a page, and the
 *   &quot;POST&quot; method when using -writeData:.
 *   This can be over-ridden by calling -writeProperty:forKey: with
 *   the key name &quot;GSHTTPPropertyMethodKey&quot; and specifying an 
 *   alternative method (i.e &quot;PUT&quot;).
 * </p>
 * <p>
 *   A Proxy may be specified by calling -writeProperty:forKey:
 *   with the keys &quot;GSHTTPPropertyProxyHostKey&quot; and
 *   &quot;GSHTTPPropertyProxyPortKey&quot; to set the host and port
 *   of the proxy server respectively.  The GSHTTPPropertyProxyHostKey
 *   property can be set to either the IP address or the hostname of
 *   the proxy server.  If an attempt is made to load a page via a
 *   secure connection when a proxy is specified, GSHTTPURLHandle will
 *   attempt to open an SSL Tunnel through the proxy.
 * </p>
 */
@implementation GSHTTPURLHandle

static NSMutableDictionary	*urlCache = nil;
static NSLock			*urlLock = nil;

static Class			sslClass = 0;

static NSLock			*debugLock = nil;
static char			debugFile[128];

static void debugRead(NSData *data)
{
  NSString	*s;
  int		d;

  [debugLock lock];
  d = open(debugFile, O_WRONLY|O_CREAT|O_APPEND, 0644);
  if (d >= 0)
    {
      s = [NSString stringWithFormat: @"\nRead %@ %u bytes - '",
	[NSDate date], [data length]];
      write(d, [s cString], [s cStringLength]);
      write(d, [data bytes], [data length]);
      write(d, "'", 1);
      close(d);
    }
  [debugLock unlock];
}
static void debugWrite(NSData *data)
{
  NSString	*s;
  int		d;

  [debugLock lock];
  d = open(debugFile, O_WRONLY|O_CREAT|O_APPEND, 0644);
  if (d >= 0)
    {
      s = [NSString stringWithFormat: @"\nWrite %@ %u bytes - '",
	[NSDate date], [data length]];
      write(d, [s cString], [s cStringLength]);
      write(d, [data bytes], [data length]);
      write(d, "'", 1);
      close(d);
    }
  [debugLock unlock];
}

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)newUrl
{
  NSURLHandle	*obj = nil;

  if ([[newUrl scheme] caseInsensitiveCompare: @"http"] == NSOrderedSame
    || [[newUrl scheme] caseInsensitiveCompare: @"https"] == NSOrderedSame)
    {
      NSString	*page = [newUrl absoluteString];
      //NSLog(@"Lookup for handle for '%@'", page);
      [urlLock lock];
      obj = [urlCache objectForKey: page];
      AUTORELEASE(RETAIN(obj));
      [urlLock unlock];
      //NSLog(@"Found handle %@", obj);
    }
  return obj;
}

+ (void) initialize
{
  if (self == [GSHTTPURLHandle class])
    {
      urlCache = [NSMutableDictionary new];
      urlLock = [NSLock new];
      debugLock = [NSLock new];
      sprintf(debugFile, "/tmp/GSHTTP.%d",
	[[NSProcessInfo processInfo] processIdentifier]);
#ifndef __MINGW__
      sslClass = [NSFileHandle sslClass];
#endif
    }
}

- (void) dealloc
{
  RELEASE(sock);
  RELEASE(url);
  RELEASE(dat);
  RELEASE(parser);
  RELEASE(document);
  RELEASE(pageInfo);
  RELEASE(wData);
  RELEASE(wProperties);
  RELEASE(request);
  [super dealloc];
}

- (id) initWithURL: (NSURL*)newUrl
	    cached: (BOOL)cached
{
  if ((self = [super initWithURL: newUrl cached: cached]) != nil)
    {
      dat = [NSMutableData new];
      pageInfo = [NSMutableDictionary new];
      wProperties = [NSMutableDictionary new];
      request = [NSMutableDictionary new];

      ASSIGN(url, newUrl);
      connectionState = idle;
      if (cached == YES)
        {
	  NSString	*page = [newUrl absoluteString];

	  [urlLock lock];
	  [urlCache setObject: self forKey: page];
	  [urlLock unlock];
	  //NSLog(@"Cache handle %@ for '%@'", self, page);
	}
    }
  return self;
}

+ (BOOL) canInitWithURL: (NSURL*)newUrl
{
  if ([[newUrl scheme] isEqualToString: @"http"]
    || [[newUrl scheme] isEqualToString: @"https"])
    {
      return YES;
    }
  return NO;
}

- (void) bgdRead: (NSNotification*) not
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSDictionary		*dict = [not userInfo];
  NSData		*d;
  NSRange		r;

  d = [dict objectForKey: NSFileHandleNotificationDataItem];
  if (debug == YES) debugRead(d);

  if ([parser parse: d] == NO)
    {
      if ([parser isComplete] == YES)
	{
	  GSMimeHeader	*info;
	  NSString	*val;

	  connectionState = idle;
	  [nc removeObserver: self
			name: NSFileHandleReadCompletionNotification
		      object: sock];
	  [sock closeFile];
	  DESTROY(sock);

	  /*
	   * Retrieve essential keys from document
	   */
	  info = [document headerNamed: @"http"];
	  val = [info objectForKey: NSHTTPPropertyServerHTTPVersionKey];
	  if (val != nil)
	    {
	      [pageInfo setObject: val
			   forKey: NSHTTPPropertyServerHTTPVersionKey];
	    }
	  val = [info objectForKey: NSHTTPPropertyStatusCodeKey];
	  if (val != nil)
	    {
	      [pageInfo setObject: val forKey: NSHTTPPropertyStatusCodeKey];
	    }
	  val = [info objectForKey: NSHTTPPropertyStatusReasonKey];
	  if (val != nil)
	    {
	      [pageInfo setObject: val forKey: NSHTTPPropertyStatusReasonKey];
	    }
	  /*
	   * Tell superclass that we have successfully loaded the data.
	   */
	  d = [parser data];
	  r = NSMakeRange(bodyPos, [d length] - bodyPos);
	  bodyPos = 0;
	  [self didLoadBytes: [d subdataWithRange: r]
		loadComplete: YES];
	}
      else
	{
	  if (debug == YES)
	    {
	      NSLog(@"HTTP parse failure - %@", parser);
	    }
	  [self endLoadInBackground];
	  [self backgroundLoadDidFailWithReason: @"Response parse failed"];
	}
    }
  else
    {
      /*
       * Report partial data if possible.
       */
      if ([parser isInBody])
	{
	  d = [parser data];
	  r = NSMakeRange(bodyPos, [d length] - bodyPos);
	  bodyPos = [d length];
	  [self didLoadBytes: [d subdataWithRange: r]
		loadComplete: NO];
	}
      [sock readInBackgroundAndNotify];
    }
}

- (void) bgdTunnelRead: (NSNotification*) not
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSDictionary		*dict = [not userInfo];
  NSData		*d;
  GSMimeParser		*p = [GSMimeParser new];

  d = [dict objectForKey: NSFileHandleNotificationDataItem];
  if (debug == YES) debugRead(d);

  if ([d length] > 0)
    {
      [dat appendData: d];
    }
  [p parse: dat];
  if ([p isInBody] == YES || [d length] == 0)
    {
      GSMimeHeader	*info;
      NSString		*val;

      [p parse: nil];
      info = [[p mimeDocument] headerNamed: @"http"];
      val = [info objectForKey: NSHTTPPropertyServerHTTPVersionKey];
      if (val != nil)
	[pageInfo setObject: val forKey: NSHTTPPropertyServerHTTPVersionKey];
      val = [info objectForKey: NSHTTPPropertyStatusCodeKey];
      if (val != nil)
	[pageInfo setObject: val forKey: NSHTTPPropertyStatusCodeKey];
      val = [info objectForKey: NSHTTPPropertyStatusReasonKey];
      if (val != nil)
	[pageInfo setObject: val forKey: NSHTTPPropertyStatusReasonKey];
      [nc removeObserver: self
	            name: NSFileHandleReadCompletionNotification
                  object: sock];
      [dat setLength: 0];
      tunnel = NO;
    }
  else
    {
      [sock readInBackgroundAndNotify];
    }
  RELEASE(p);
}

- (void) loadInBackground
{
  NSNotificationCenter	*nc;
  NSString		*host = nil;
  NSString		*port = nil;

  /*
   * Don't start a load if one is in progress.
   */
  if (connectionState != idle)
    {
      NSLog(@"Attempt to load an http handle which is not idle ... ignored");
      return;
    }

  [dat setLength: 0];
  RELEASE(document);
  RELEASE(parser);
  parser = [GSMimeParser new];
  document = RETAIN([parser mimeDocument]);
  [self beginLoadInBackground];
  if (sock != nil)
    {
      [sock closeFile];
      DESTROY(sock);
    }
  if ([[request objectForKey: GSHTTPPropertyProxyHostKey] length] == 0)
    {
      NSNumber	*p;

      host = [url host];
      p = [url port];
      if (p != nil)
	{
	  port = [NSString stringWithFormat: @"%u", [p unsignedIntValue]];
	}
      else
	{
	  port = [url scheme];
	}
      if ([[url scheme] isEqualToString: @"https"])
	{
	  if (sslClass == 0)
	    {
	      [self backgroundLoadDidFailWithReason:
		@"https not supported ... needs SSL bundle"];
	      return;
	    }
	  sock = [sslClass
	    fileHandleAsClientInBackgroundAtAddress: host
					    service: port
					   protocol: @"tcp"];
	}
      else
	{
	  sock = [NSFileHandle 
	    fileHandleAsClientInBackgroundAtAddress: host
					    service: port
					   protocol: @"tcp"];
	}
    }
  else
    {
      if ([[request objectForKey: GSHTTPPropertyProxyPortKey] length] == 0)
	{
	  [request setObject: @"8080" forKey: GSHTTPPropertyProxyPortKey];
	}
      if ([[url scheme] isEqualToString: @"https"])
	{
	  if (sslClass == 0)
	    {
	      [self backgroundLoadDidFailWithReason:
		@"https not supported ... needs SSL bundle"];
	      return;
	    }
	  host = [request objectForKey: GSHTTPPropertyProxyHostKey];
	  port = [request objectForKey: GSHTTPPropertyProxyPortKey];
	  sock = [sslClass
	    fileHandleAsClientInBackgroundAtAddress: host 
					    service: port
					   protocol: @"tcp"];
	}
      else
	{
	  host = [request objectForKey: GSHTTPPropertyProxyHostKey];
	  port = [request objectForKey: GSHTTPPropertyProxyPortKey];
	  sock = [NSFileHandle 
	    fileHandleAsClientInBackgroundAtAddress: host 
					    service: port
					   protocol: @"tcp"];
	}
    }
  if (sock == nil)
    {
      /*
       * Tell superclass that the load failed - let it do housekeeping.
       */
      [self backgroundLoadDidFailWithReason: [NSString stringWithFormat:
	@"Unable to connect to %@:%@", host, port]];
      return;
    }
  RETAIN(sock);
  nc = [NSNotificationCenter defaultCenter];
  [nc addObserver: self
         selector: @selector(bgdConnect:)
             name: GSFileHandleConnectCompletionNotification
           object: sock];
  connectionState = connecting;
}

- (void) endLoadInBackground
{
  if (connectionState != idle)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSString			*name;

      if (connectionState == connecting)
	name = GSFileHandleConnectCompletionNotification;
      else if (connectionState == writing)
	name = GSFileHandleWriteCompletionNotification;
      else
	name = NSFileHandleReadCompletionNotification;

      [nc removeObserver: self name: name object: sock];
      [sock closeFile];
      DESTROY(sock);
      connectionState = idle;
    }
  [super endLoadInBackground];
}

- (void) bgdConnect: (NSNotification*)notification
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  
  NSDictionary          *userInfo = [notification userInfo];
  NSEnumerator          *wpEnumerator;
  NSMutableString	*s;
  NSString		*e;
  NSString              *key;
  NSMutableData		*buf;
  NSString		*method;

  /*
   * See if the connection attempt caused an error.
   */
  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      NSLog(@"Unable to connect to %@:%@ via socket",
	[sock socketAddress], [sock socketService]);
      /*
       * Tell superclass that the load failed - let it do housekeeping.
       */
      [self endLoadInBackground];
      [self backgroundLoadDidFailWithReason: e];
      return;
    }

  [nc removeObserver: self
                name: GSFileHandleConnectCompletionNotification
              object: sock];

  /*
   * Build HTTP request.
   */

  /* 
   * If SSL via proxy, set up tunnel first
   */
  if ([[url scheme] isEqualToString: @"https"]
    && [[request objectForKey: GSHTTPPropertyProxyHostKey] length] > 0)
    {
      NSRunLoop		*loop = [NSRunLoop currentRunLoop];
      NSString		*cmd;
      NSTimeInterval	last = 0.0;
      NSTimeInterval	limit = 0.01;
      NSData		*buf;
      NSDate		*when;
      NSString		*status;

      if ([url port] == nil)
	{
	  cmd = [NSString stringWithFormat: @"CONNECT %@:443 HTTP/%@\r\n\r\n",
	    [url host], httpVersion];
	}
      else
	{
	  cmd = [NSString stringWithFormat: @"CONNECT %@:%@ HTTP/%@\r\n\r\n",
	    [url host], [url port], httpVersion];
	}
      
      /*
       * Set up default status for if connection is lost.
       */
      [pageInfo setObject: @"1.0" forKey: NSHTTPPropertyServerHTTPVersionKey];
      [pageInfo setObject: @"503" forKey: NSHTTPPropertyStatusCodeKey];
      [pageInfo setObject: @"Connection dropped by proxy server"
		   forKey: NSHTTPPropertyStatusReasonKey];

      tunnel = YES;
      [nc addObserver: self
	     selector: @selector(bgdWrite:)
                 name: GSFileHandleWriteCompletionNotification
               object: sock];

      buf = [cmd dataUsingEncoding: NSASCIIStringEncoding];
      [sock writeInBackgroundAndNotify: buf]; 
      if (debug == YES) debugWrite(buf);

      when = [NSDate alloc];
      while (tunnel == YES)
	{
	  if (limit < 1.0)
	    {
	      NSTimeInterval	tmp = limit;

	      limit += last;
	      last = tmp;
	    }
          when = [when initWithTimeIntervalSinceNow: limit];
	  [loop runUntilDate: when];
	}
      RELEASE(when);

      status = [pageInfo objectForKey: NSHTTPPropertyStatusCodeKey];
      if ([status isEqual: @"200"] == NO)
	{
	  [self endLoadInBackground];
	  [self backgroundLoadDidFailWithReason: @"Failed proxy tunneling"];
	  return;
	}
    }
  if ([[url scheme] isEqualToString: @"https"])
    {
      /*
       * If we are an https connection, negotiate secure connection
       */
      if ([sock sslConnect] == NO)
	{
	  [self endLoadInBackground];
	  [self backgroundLoadDidFailWithReason: @"Failed to make ssl connect"];
	  return;
	}
    }

  /*
   * Set up request - differs for proxy version unless tunneling via ssl.
   */
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
  if ([[request objectForKey: GSHTTPPropertyProxyHostKey] length] > 0
    && [[url scheme] isEqualToString: @"https"] == NO)
    {
      if ([url port] == nil)
	{
	  s = [[NSMutableString alloc] initWithFormat: @"%@ http://%@%@", 
	    method, [url host], [url path]];
	}
      else
	{
	  s = [[NSMutableString alloc] initWithFormat: @"%@ http://%@:%@%@", 
	    method, [url host], [url port], [url path]];
	}
    }
  else    // no proxy
    {
      s = [[NSMutableString alloc] initWithFormat: @"%@ %@", 
	method, [url path]];
    }
  if ([[url query] length] > 0)
    {
      [s appendFormat: @"?%@", [url query]];
    }
  [s appendFormat: @" HTTP/%@\r\n", httpVersion];

  if ([wProperties objectForKey: @"host"] == nil)
    {
      [wProperties setObject: [url host] forKey: @"host"];
    }

  if ([wData length] > 0)
    {
      [wProperties setObject: [NSString stringWithFormat: @"%d", [wData length]]
		      forKey: @"content-length"];
      /*
       * Assume content type if not specified.
       */
      if ([wProperties objectForKey: @"content-type"] == nil)
	{
	  [wProperties setObject: @"application/x-www-form-urlencoded"
			  forKey: @"content-type"];
	}
    }
  if ([wProperties objectForKey: @"authorisation"] == nil)
    {
      if ([url user] != nil)
	{
	  NSString	*auth;

	  if ([[url password] length] > 0)
	    { 
	      auth = [NSString stringWithFormat: @"%@:%@", 
		[url user], [url password]];
	    }
	  else
	    {
	      auth = [NSString stringWithFormat: @"%@", [url user]];
	    }
	  auth = [NSString stringWithFormat: @"Basic %@",
	    [GSMimeDocument encodeBase64String: auth]];
	  [wProperties setObject: auth
			  forKey: @"authorization"];
	}
    }

  wpEnumerator = [wProperties keyEnumerator];
  while ((key = [wpEnumerator nextObject]))
    {
      [s appendFormat: @"%@: %@\r\n", key, [wProperties objectForKey: key]];
    }
  [wProperties removeAllObjects];
  [s appendString: @"\r\n"];
  buf = [[s dataUsingEncoding: NSASCIIStringEncoding] mutableCopy];

  /*
   * Append any data to be sent
   */
  if (wData != nil)
    {
      [buf appendData: wData];
      DESTROY(wData);
    }

  /*
   * Send request to server.
   */
  [sock writeInBackgroundAndNotify: buf];
  if (debug == YES) debugWrite(buf);
  RELEASE(buf);
  RELEASE(s);

  /*
   * Watch for write completion.
   */
  [nc addObserver: self
         selector: @selector(bgdWrite:)
             name: GSFileHandleWriteCompletionNotification
           object: sock];
  connectionState = writing;
}

- (void) bgdWrite: (NSNotification*)notification
{
  NSDictionary    	*userInfo = [notification userInfo];
  NSString        	*e;
 
  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      tunnel = NO;
      NSLog(@"Failed to write command to socket - %@", e);
      /*
       * Tell superclass that the load failed - let it do housekeeping.
       */
      [self endLoadInBackground];
      [self backgroundLoadDidFailWithReason: @"Failed to write request"];
      return;
    }
  else
    {
      NSNotificationCenter	*nc;

      /*
       * Don't watch for write completions any more.
       */
      nc = [NSNotificationCenter defaultCenter];
      [nc removeObserver: self
		    name: GSFileHandleWriteCompletionNotification
		  object: sock];

      /*
       * Ok - write completed, let's read the response.
       */
      if (tunnel == YES)
	{
	  [nc addObserver: self
	         selector: @selector(bgdTunnelRead:)
		     name: NSFileHandleReadCompletionNotification
	           object: sock];
	}
      else
	{
	  bodyPos = 0;
	  [nc addObserver: self
	         selector: @selector(bgdRead:)
		     name: NSFileHandleReadCompletionNotification
	           object: sock];
	}
      [sock readInBackgroundAndNotify];
      connectionState = reading;
    }
}

/**
 *  If necessary, this method calls -loadInForeground to send a
 *  request to the webserver, and get a page back.  It then returns
 *  the property for the specified key -
 * <list>
 *   <item>
 *     NSHTTPPropertyStatusCodeKey - numeric status code returned
 *     by the last request.
 *   </item>
 *   <item>
 *     NSHTTPPropertyStatusReasonKey - text describing status of
 *     the last request
 *   </item>
 *   <item>
 *     NSHTTPPropertyServerHTTPVersionKey - <code>http</code>
 *     version supported by remote server
 *   </item>
 *   <item>
 *     Other keys are taken to be the names of <code>http</code>
 *     headers and the corresponding header value (or nil if there
 *     is none) is returned.
 *   </item>
 * </list>
 */
- (id) propertyForKey: (NSString*) propertyKey
{
  if (document == nil)
    [self loadInForeground];
  return [self propertyForKeyIfAvailable: propertyKey];
}

- (id) propertyForKeyIfAvailable: (NSString*) propertyKey
{
  id	result = [pageInfo objectForKey: propertyKey];

  if (result == nil)
    {
      NSString	*key = [propertyKey lowercaseString];
      NSArray	*array = [document headersNamed: key];

      if ([array count] == 0)
	{
	  return nil;
	}
      else if ([array count] == 1)
	{
	  GSMimeHeader	*hdr = [array objectAtIndex: 0];

	  result = [hdr value];
	}
      else
	{
	  NSEnumerator	*enumerator = [array objectEnumerator];
	  GSMimeHeader	*val;

	  result = [NSMutableArray arrayWithCapacity: [array count]];
	  while ((val = [enumerator nextObject]) != nil)
	    {
	      [result addObject: [val value]];
	    }
	}
    }
  return result;
}

- (void) setDebug: (BOOL)flag
{
  debug = flag;
}

/**
 * Writes the specified data as the body of an <code>http</code>
 * or <code>https</code> request to the web server.
 * Returns YES on success,
 * NO on failure.  By default, this method performs a POST operation.
 * On completion, the resource data for this handle is set to the
 * page returned by the request.
 */
- (BOOL) writeData: (NSData*)d
{
  ASSIGN(wData, d);
  return YES;
}

/**
 * Sets a property to be used in the next request made by this handle.
 * The property is set as a header in the next request, unless it is
 * one of the following -
 * <list>
 *   <item>
 *     GSHTTPPropertyBodyKey - set an NSData item to be sent to
 *     the server as the body of the request.
 *   </item>
 *   <item>
 *     GSHTTPPropertyMethodKey - override the default method of
 *     the request (eg. &quot;PUT&quot;).
 *   </item>
 *   <item>
 *     GSHTTPPropertyProxyHostKey - specify the name or IP address
 *     of a host to proxy through.
 *   </item>
 *   <item>
 *     GSHTTPPropertyProxyPortKey - specify the port number to 
 *     connect to on the proxy host.  If not give, this defaults
 *     to 8080 for <code>http</code> and 4430 for <code>https</code>.
 *   </item>
 * </list>
 */
- (BOOL) writeProperty: (id) property forKey: (NSString*) propertyKey
{
  if (propertyKey == nil || [propertyKey isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"%@ with invalid key", NSStringFromSelector(_cmd)];
    }
  if ([propertyKey hasPrefix: @"GSHTTPProperty"])
    {
      if (property == nil)
	{
	  [request removeObjectForKey: propertyKey];
	}
      else
	{
	  [request setObject: property forKey: propertyKey];
	}
    }
  else
    {
      if (property == nil)
	{
	  [wProperties removeObjectForKey: [propertyKey lowercaseString]];
	}
      else
	{
	  [wProperties setObject: property
			  forKey: [propertyKey lowercaseString]];
	}
    }
  return YES;
}

@end

