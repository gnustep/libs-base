/** Implementation for NSURLResponse for GNUstep
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
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
   */ 

#import "common.h"

#define	EXPOSE_NSURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSBundle.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSScanner.h"
#import "NSCallBacks.h"
#import "GNUstepBase/GSMime.h"


// Internal data storage
typedef struct {
  long long		expectedContentLength;
  NSURL			*URL;
  NSString		*MIMEType;
  NSString		*textEncodingName;
  NSString		*statusText;
  NSMutableDictionary	*headers; /* _GSMutableInsensitiveDictionary */
  int			statusCode;
} Internal;
 
#define	this	((Internal*)(self->_NSURLResponseInternal))
#define	inst	((Internal*)(o->_NSURLResponseInternal))


@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLResponse (Private)

- (void) _checkHeaders
{
  if (NSURLResponseUnknownLength == this->expectedContentLength)
    {
      NSString	*s= [self _valueForHTTPHeaderField: @"content-length"];

      if ([s length] > 0)
	{
	  this->expectedContentLength = [s intValue];
	}
    }

  if (nil == this->MIMEType)
    {
      GSMimeHeader	*c;
      GSMimeParser	*p;
      NSScanner		*s;
      NSString		*v;

      v = [self _valueForHTTPHeaderField: @"content-type"];
      if (v == nil)
        {
	  v = @"text/plain";	// No content type given.
	}
      s = [NSScanner scannerWithString: v];
      p = [GSMimeParser new];
      c = AUTORELEASE([[GSMimeHeader alloc] initWithName: @"content-type"
                                                   value: nil]);
      /* We just set the header body, so we know it will scan and don't need
       * to check the retrurn type.
       */
      (void)[p scanHeaderBody: s into: c];
      RELEASE(p);
      ASSIGNCOPY(this->MIMEType, [c value]);
      v = [c parameterForKey: @"charset"];
      ASSIGNCOPY(this->textEncodingName, v);
    }
}

- (void) _setHeaders: (id)headers
{
  NSEnumerator	*e;
  NSString	*v;

  if ([headers isKindOfClass: [NSDictionary class]] == YES)
    {
      NSString		*k;

      e = [(NSDictionary*)headers keyEnumerator];
      while ((k = [e nextObject]) != nil)
	{
	  v = [(NSDictionary*)headers objectForKey: k];
	  [self _setValue: v forHTTPHeaderField: k];
	}
    }
  else if ([headers isKindOfClass: [NSArray class]] == YES)
    {
      GSMimeHeader	*h;

      /* Remove existing headers matching the ones we are setting.
       */
      e = [(NSArray*)headers objectEnumerator];
      while ((h = [e nextObject]) != nil)
	{
	  NSString	*n = [h namePreservingCase: YES];

	  [this->headers removeObjectForKey: n];
	}
      /* Set new headers, joining values where we have multiple headers
       * with the same name.
       */
      e = [(NSArray*)headers objectEnumerator];
      while ((h = [e nextObject]) != nil)
        {
	  NSString	*n = [h namePreservingCase: YES];
	  NSString	*v = [h fullValue];
	  NSString	*o = [this->headers objectForKey: n];

	  if ([v isKindOfClass: [NSString class]] && [v length] > 0)
	    {
	      if ([o length] > 0)
		{
		  v = [NSString stringWithFormat: @"%@, %@", o, v];
		}
	      [self _setValue: v forHTTPHeaderField: n];
	    }
	  else if (nil == o)
	    {
	      [self _setValue: @"" forHTTPHeaderField: n];
	    }
	}
    }
  [self _checkHeaders];
}
- (void) _setStatusCode: (NSInteger)code text: (NSString*)text
{
  this->statusCode = code;
  ASSIGNCOPY(this->statusText, text);
}
- (void) _setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
  if (this->headers == 0)
    {
      this->headers = [_GSMutableInsensitiveDictionary new];
    }
  [this->headers setObject: value forKey: field];
}
- (NSString *) _valueForHTTPHeaderField: (NSString *)field
{
  return [this->headers objectForKey: field];
}
@end


@implementation	NSURLResponse

+ (id) allocWithZone: (NSZone*)z
{
  NSURLResponse	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLResponseInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

- (id) copyWithZone: (NSZone*)z
{
  NSURLResponse	*o;

  if (NSShouldRetainWithZone(self, z) == YES)
    {
      o = RETAIN(self);
    }
  else
    {
      o = [[self class] allocWithZone: z];
      o = [o initWithURL: [self URL]
	MIMEType: [self MIMEType]
	expectedContentLength: [self expectedContentLength]
	textEncodingName: [self textEncodingName]];
      if (o != nil)
	{
	  ASSIGN(inst->statusText, this->statusText);
	  inst->statusCode = this->statusCode;
	  if (this->headers == 0)
	    {
	      inst->headers = 0;
	    }
	  else
	    {
	      inst->headers = [this->headers mutableCopy];
	    }
	}
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->URL);
      RELEASE(this->MIMEType);
      RELEASE(this->textEncodingName);
      RELEASE(this->statusText);
      RELEASE(this->headers);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"%@ { URL: %@ } { Status Code: %d, Headers %@ }", [super description], this->URL, this->statusCode, this->headers];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
// FIXME
  if ([aCoder allowsKeyedCoding])
    {
    }
  else
    {
    }
}

- (long long) expectedContentLength
{
  return this->expectedContentLength;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
// FIXME
  if ([aCoder allowsKeyedCoding])
    {
    }
  else
    {
    }
  return self;
}

/**
 * Initialises the receiver with the URL, MIMEType, expected length and
 * text encoding name provided.
 */
- (id) initWithURL: (NSURL *)URL
  MIMEType: (NSString *)MIMEType
  expectedContentLength: (NSInteger)length
  textEncodingName: (NSString *)name
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(this->URL, URL);
      ASSIGNCOPY(this->MIMEType, MIMEType);
      ASSIGNCOPY(this->textEncodingName, name);
      this->expectedContentLength = length;
    }
  return self;
}

- (id) initWithURL: (NSURL*)URL
	statusCode: (NSInteger)statusCode
       HTTPVersion: (NSString*)HTTPVersion
      headerFields: (NSDictionary*)headerFields
{
  self = [self initWithURL: URL
		  MIMEType: nil
     expectedContentLength: NSURLResponseUnknownLength
	  textEncodingName: nil];
  if (nil != self)
    {
      NSString *k;
      NSEnumerator *e = [headerFields keyEnumerator];
      while (nil != (k = [e nextObject]))
        {
          NSString *v = [headerFields objectForKey: k];
          [self _setValue: v forHTTPHeaderField: k];
        }

      this->statusCode = statusCode;
      [self _checkHeaders];
    }
  return self;
}

- (NSString *) MIMEType
{
  return this->MIMEType;
}

/**
 * Returns a suggested file name for storing the response data, with
 * suggested names being found in the following order:<br />
 * <list>
 *   <item>content-disposition header</item>
 *   <item>last path component of URL</item>
 *   <item>host name from URL</item>
 *   <item>'unknown'</item>
 * </list>
 * If possible, an extension based on the MIME type of the response
 * is also appended.<br />
 * The result should always be a valid file name.
 */
- (NSString *) suggestedFilename
{
  NSString	*disp = [self _valueForHTTPHeaderField: @"content-disposition"];
  NSString	*name = nil;

  if (disp != nil)
    {
      GSMimeParser	*p;
      GSMimeHeader	*h;
      NSScanner		*sc;

      // Try to get name from content disposition header.
      p = AUTORELEASE([GSMimeParser new]);
      h = [[GSMimeHeader alloc] initWithName: @"content-displosition"
				       value: disp];
      IF_NO_ARC([h autorelease];)
      sc = [NSScanner scannerWithString: [h value]];
      if ([p scanHeaderBody: sc into: h] == YES)
        {
	  name = [h parameterForKey: @"filename"];
	  name = [name stringByDeletingPathExtension];
	}
    }

  if ([name length] == 0)
    {
      name = [[[self URL] absoluteString] lastPathComponent];
      name = [name stringByDeletingPathExtension];
    }
  if ([name length] == 0)
    {
      name = [[self URL] host];
    }
  if ([name length] == 0)
    {
      name = @"unknown";
    }
// FIXME ... add type specific extension
  return name;
}

- (NSString *) textEncodingName
{
  return this->textEncodingName;
}

- (NSURL *) URL
{
  return this->URL;
}

@end


@implementation NSHTTPURLResponse

+ (NSString *) localizedStringForStatusCode: (NSInteger)statusCode
{
  /* Mappings from codes to text taken from
   * https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
   */
  switch (statusCode)
    {
      case 100:
	return NSLocalizedString(@"Continue", @"HTTP Status");
      case 101:
	return NSLocalizedString(@"Switching Protocols", @"HTTP Status");
      case 102:
	return NSLocalizedString(@"Processing", @"HTTP Status");
      case 103:
	return NSLocalizedString(@"Early Hints", @"HTTP Status");
      case 200:
	return NSLocalizedString(@"OK", @"HTTP Status");
      case 201:
	return NSLocalizedString(@"Created", @"HTTP Status");
      case 202:
	return NSLocalizedString(@"Accepted", @"HTTP Status");
      case 203:
	return NSLocalizedString(@"Non-Authoritative Information",
	  @"HTTP Status");
      case 204:
	return NSLocalizedString(@"No Content", @"HTTP Status");
      case 205:
	return NSLocalizedString(@"Reset Content", @"HTTP Status");
      case 206:
	return NSLocalizedString(@"Partial Content", @"HTTP Status");
      case 207:
	return NSLocalizedString(@"Multi-Status", @"HTTP Status");
      case 208:
	return NSLocalizedString(@"Already Reported", @"HTTP Status");
      case 226:
	return NSLocalizedString(@"IM Used", @"HTTP Status");
      case 300:
	return NSLocalizedString(@"Multiple Choices", @"HTTP Status");
      case 301:
	return NSLocalizedString(@"Moved Permanently", @"HTTP Status");
      case 302:
	return NSLocalizedString(@"Found", @"HTTP Status");
      case 303:
	return NSLocalizedString(@"See Other", @"HTTP Status");
      case 304:
	return NSLocalizedString(@"Not Modified", @"HTTP Status");
      case 305:
	return NSLocalizedString(@"Use Proxy", @"HTTP Status");
      case 307:
	return NSLocalizedString(@"Temporary Redirect", @"HTTP Status");
      case 308:
	return NSLocalizedString(@"Permanent Redirect", @"HTTP Status");
      case 400:
	return NSLocalizedString(@"Bad Request", @"HTTP Status");
      case 401:
	return NSLocalizedString(@"Unauthorized", @"HTTP Status");
      case 402:
	return NSLocalizedString(@"Payment Required", @"HTTP Status");
      case 403:
	return NSLocalizedString(@"Forbidden", @"HTTP Status");
      case 404:
	return NSLocalizedString(@"Not Found", @"HTTP Status");
      case 405:
	return NSLocalizedString(@"Method Not Allowed", @"HTTP Status");
      case 406:
	return NSLocalizedString(@"Not Acceptable", @"HTTP Status");
      case 407:
	return NSLocalizedString(@"Proxy Authentication Required",
	  @"HTTP Status");
      case 408:
	return NSLocalizedString(@"Request Timeout", @"HTTP Status");
      case 409:
	return NSLocalizedString(@"Conflict", @"HTTP Status");
      case 410:
	return NSLocalizedString(@"Gone", @"HTTP Status");
      case 411:
	return NSLocalizedString(@"Length Required", @"HTTP Status");
      case 412:
	return NSLocalizedString(@"Precondition Failed", @"HTTP Status");
      case 413:
	return NSLocalizedString(@"Content Too Large", @"HTTP Status");
      case 414:
	return NSLocalizedString(@"URI Too Long", @"HTTP Status");
      case 415:
	return NSLocalizedString(@"Unsupported Media Type", @"HTTP Status");
      case 416:
	return NSLocalizedString(@"Range Not Satisfiable", @"HTTP Status");
      case 417:
	return NSLocalizedString(@"Expectation Failed", @"HTTP Status");
      case 421:
	return NSLocalizedString(@"Misdirected Request", @"HTTP Status");
      case 422:
	return NSLocalizedString(@"Unprocessable Content", @"HTTP Status");
      case 423:
	return NSLocalizedString(@"Locked", @"HTTP Status");
      case 424:
	return NSLocalizedString(@"Failed Dependency", @"HTTP Status");
      case 425:
	return NSLocalizedString(@"Too Early", @"HTTP Status");
      case 426:
	return NSLocalizedString(@"Upgrade Required", @"HTTP Status");
      case 428:
	return NSLocalizedString(@"Precondition Required", @"HTTP Status");
      case 429:
	return NSLocalizedString(@"Too Many Requests", @"HTTP Status");
      case 431:
	return NSLocalizedString(@"Request Header Fields Too Large",
	  @"HTTP Status");
      case 451:
	return NSLocalizedString(@"Unavailable For Legal Reasons",
	  @"HTTP Status");
      case 500:
	return NSLocalizedString(@"Internal Server Error", @"HTTP Status");
      case 501:
	return NSLocalizedString(@"Not Implemented", @"HTTP Status");
      case 502:
	return NSLocalizedString(@"Bad Gateway", @"HTTP Status");
      case 503:
	return NSLocalizedString(@"Service Unavailable", @"HTTP Status");
      case 504:
	return NSLocalizedString(@"Gateway Timeout", @"HTTP Status");
      case 505:
	return NSLocalizedString(@"HTTP Version Not Supported", @"HTTP Status");
      case 506:
	return NSLocalizedString(@"Variant Also Negotiates", @"HTTP Status");
      case 507:
	return NSLocalizedString(@"Insufficient Storage", @"HTTP Status");
      case 508:
	return NSLocalizedString(@"Loop Detected", @"HTTP Status");
      case 510:
	return NSLocalizedString(@"Not Extended (OBSOLETED)", @"HTTP Status");
      case 511:
	return NSLocalizedString(@"Network Authentication Required",
	  @"HTTP Status");
      default:
        return [NSString stringWithFormat: @"%"PRIdPTR, statusCode];
    }
}

- (NSDictionary *) allHeaderFields
{
  return AUTORELEASE([this->headers copy]);
}

- (NSInteger) statusCode
{
  return this->statusCode;
}
@end

