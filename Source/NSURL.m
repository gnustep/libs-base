/* NSUrl.m - Class NSURL
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 		Jan 1999
   
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

/*
Note from Manuel Guesdon: 
* I've made some test to compare apple NSURL results 
and GNUstep NSURL results but as there this class is not very documented, some
function may be incorrect
* I've put 2 functions to make tests. You can add your own tests
* Some functions are not implemented
*/
#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSRunLoop.h>

NSString	*NSURLFileScheme = @"file";

NSString	*NSURLPartKey_host = @"host";
NSString	*NSURLPartKey_port = @"port";
NSString	*NSURLPartKey_user = @"user";
NSString	*NSURLPartKey_password = @"password";
NSString	*NSURLPartKey_path = @"path";
NSString	*NSURLPartKey_fragment = @"fragment";
NSString	*NSURLPartKey_parameterString = @"parameterString";
NSString	*NSURLPartKey_query = @"query";

//=============================================================================
@implementation NSURL

//-----------------------------------------------------------------------------
+ (id) fileURLWithPath: (NSString*)aPath
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath]);
}

//-----------------------------------------------------------------------------
+ (id) URLWithString: (NSString*)aUrlString
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString]);
}

//-----------------------------------------------------------------------------
+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString
				     relativeToURL: aBaseUrl]);
}

//-----------------------------------------------------------------------------
- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 path: (NSString*)aPath
{
  NSString	*aUrlString = nil;

  if (aHost != nil)
    aUrlString = [NSString stringWithFormat: @"%@://%@", aScheme, aHost];
  else
    aUrlString = [NSString stringWithFormat: @"%@:", aScheme];

  if (aPath != nil)
    aUrlString = [aUrlString stringByAppendingString: aPath];

  self = [self initWithString: aUrlString];
  return self;
}

//-----------------------------------------------------------------------------
//Non Standard Function
- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 port: (NSNumber*)aPort
		 path: (NSString*)aPath
{
  NSString	*tmpHost = nil;

  if (aPort != nil)
    tmpHost = [NSString stringWithFormat: @"%@:%@", aHost, aPort];
  else
    tmpHost = aHost;

  self = [self initWithScheme: aScheme
			 host: tmpHost
			 path: aPath];
  return self;
}

//-----------------------------------------------------------------------------
//Do a initWithScheme: NSFileScheme host: nil path: aPath
- (id) initFileURLWithPath: (NSString*)aPath
{
  self = [self initWithScheme: NSURLFileScheme
			 host: nil
			 path: aPath];
  return self;
}

//-----------------------------------------------------------------------------
// _urlString is escaped
- (id) initWithString: (NSString*)aUrlString
{
  self = [self init];
  ASSIGNCOPY(_urlString, aUrlString);
  return self;
}

//-----------------------------------------------------------------------------
//_urlString!= nil 
// _urlString is escaped
- (id) initWithString: (NSString*)aUrlString
	relativeToURL: (NSURL*)aBaseUrl
{
  self = [self init];
  ASSIGNCOPY(_urlString, aUrlString);
  ASSIGNCOPY(_baseURL, aBaseUrl);
  return self;
}

//-----------------------------------------------------------------------------
- (void) dealloc
{
  DESTROY(_urlString);
  DESTROY(_baseURL);
  [super dealloc];
}

//-----------------------------------------------------------------------------
- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone) == NO)
    return [[isa allocWithZone: zone] initWithString: _urlString
				       relativeToURL: _baseURL];
  else
    return RETAIN(self);
}

//-----------------------------------------------------------------------------
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: _urlString];
  [aCoder encodeObject: _baseURL];
}

//-----------------------------------------------------------------------------
- (id) initWithCoder: (NSCoder*)aCoder
{
  [aCoder decodeValueOfObjCType: @encode(id) at: &_urlString];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_baseURL];
  return self;
}


//-----------------------------------------------------------------------------
- (NSString*) description
{
  NSString	*dscr = _urlString;

  if (_baseURL != nil)
    dscr = [dscr stringByAppendingFormat: @" -- %@", _baseURL];
  return dscr;
}

//-----------------------------------------------------------------------------
// Non Standard Function
- (NSString*) baseURLAbsolutePart
{
  if (_baseURL != nil)
    {
      NSString	*suffix = [_baseURL path];
      NSString	*query = [_baseURL query];
      NSString	*tmp = nil;

      if (query != nil)
	suffix = [suffix stringByAppendingFormat: @"?%@", query];
      // /test?aa = bb&cc=dd -- http: //user: passwd@www.gnustep.org: 80/apache
      //    ==> http: //user: passwd@www.gnustep.org: 80/
      tmp = [[_baseURL absoluteString] stringWithoutSuffix: suffix];

      //    ==> http: //user: passwd@www.gnustep.org: 80
      if ([tmp hasSuffix: @"/"])
	tmp = [tmp stringWithoutSuffix: @"/"];
      return tmp;
    }
  else
    return @"";
}


//-----------------------------------------------------------------------------
- (NSString*) absoluteString
{
  NSString *absString = nil;

  if (_baseURL != nil)
    {
      // /test?aa = bb&cc=dd -- http: //user: passwd@www.gnustep.org: 80/apache
      //    ==> http: //user: passwd@www.gnustep.org: 80
      absString = [self baseURLAbsolutePart];

      if ([_urlString hasPrefix: @"/"])
	absString = [absString stringByAppendingString: _urlString];
      else
	absString = [absString stringByAppendingFormat: @"/%@", _urlString];
    }
  else
    absString = _urlString;
  return absString;
}

//-----------------------------------------------------------------------------
- (NSString*) relativeString
{
  return _urlString;
}

//-----------------------------------------------------------------------------
- (NSURL*) baseURL
{
  return _baseURL;
}

//-----------------------------------------------------------------------------
- (NSURL*) absoluteURL
{
  if (_baseURL != nil)
    return self;
  else
    return [NSURL URLWithString: [self absoluteString]];
}

//-----------------------------------------------------------------------------
- (NSString*) scheme
{
  NSString	*scheme = nil;
  NSString	*absoluteString = [self absoluteString];
  NSRange	range = [absoluteString rangeOfString: @"://"];

  if (range.length > 0)
    {
      scheme = [absoluteString substringToIndex: range.location];
    }
  else
    {
      /*
       * Cope with URLs missing net_path info -  <scheme>:/<path>...
       */
      range = [absoluteString rangeOfString: @":"];
      if (range.length > 0)
	{
	  scheme = [absoluteString substringToIndex: range.location];
	}
    }
  return scheme;
}

//-----------------------------------------------------------------------------
- (NSString*) resourceSpecifier
{
  NSString	*absoluteString = [self absoluteString];
  NSRange	range = [absoluteString rangeOfString: @"://"];

  if (range.length > 0)
    {
      return [absoluteString substringFromIndex: range.location + 1];
    }
  else
    {
      /*
       * Cope with URLs missing net_path info -  <scheme>:/<path>...
       */
      range = [absoluteString rangeOfString: @":"];
      if (range.length > 0)
	{
	  return [absoluteString substringFromIndex: range.location + 1];
	}
      else
	{
	  return absoluteString;
	}
    }
}

//-----------------------------------------------------------------------------
//Non Standard Function
- (NSDictionary*) explode
{
  NSMutableDictionary	*elements = nil;
  NSString		*resourceSpecifier = [self resourceSpecifier];
  int			index = 0;
  NSRange		range;

  if ([resourceSpecifier hasPrefix: @"//"])
    {
      index = 2;
    }
  else if ([resourceSpecifier hasPrefix: @"/"])
    {
      index = 0;
    }
  else
    {
      [NSException raise: NSGenericException
		  format: @"'%@' is a bad URL", self];
    }

  elements = [NSMutableDictionary dictionaryWithCapacity: 0];
  range = [resourceSpecifier rangeOfString: @"/" options: 0
    range: NSMakeRange(index, [resourceSpecifier length] - index)];
  if (range.length > 0)
    {
      NSString	*userPasswordHostPort;
      NSString	*userPassword = nil;
      NSString	*hostPort = nil;

      userPasswordHostPort = [resourceSpecifier substringWithRange:
	NSMakeRange(index, range.location - index)];
      index = range.location;
      range = [userPasswordHostPort rangeOfString: @"@"];
      if (range.length > 0)
	{
	  if (range.location > 0)
	    {
	      userPassword = [userPasswordHostPort substringToIndex:
		range.location];
	    }
	  if (range.location + 1 < [userPasswordHostPort length])
	    {
	      hostPort = [userPasswordHostPort substringFromIndex:
		range.location + 1];
	    }
	}
      else
	hostPort = userPasswordHostPort;
      if (userPassword != nil)
	{
	  range = [userPassword rangeOfString: @": "];
	  if (range.length > 0)
	    {
	      if (range.location > 0)
		{
		  NSString	*sub;

		  sub = [userPassword substringToIndex: range.location];
		  [elements setObject: sub
			forKey: NSURLPartKey_user];
		}
	      if (range.location + 1 < [userPassword length])
		{
		  NSString	*sub;

		  sub = [userPassword substringToIndex:
		    range.location + 1];
		  [elements setObject: sub
			       forKey: NSURLPartKey_password];
		}
	    }
	  else
	    {
	      [elements setObject: userPassword
			   forKey: NSURLPartKey_user];
	    }
	}

      if (hostPort != nil)
	{
	  range = [hostPort rangeOfString: @": "];
	  if (range.length > 0)
	    {
	      if (range.location > 0)
		{
		  NSString	*sub;

		  sub = [hostPort substringToIndex: range.location];
		  [elements setObject: sub
			       forKey: NSURLPartKey_host];
		}
	      if (range.location + 1 < [hostPort length])
		{
		  NSString	*sub;

												  sub = [hostPort substringFromIndex:
		    range.location + 1];
		  [elements setObject: [NSNumber valueFromString: sub]
			       forKey: NSURLPartKey_port];
		}
	    }
	  else
	    {
	      [elements setObject: hostPort
			   forKey: NSURLPartKey_host];
	    }
	}
    }

  range = NSMakeRange(index, [resourceSpecifier length] - index);
  range = [resourceSpecifier rangeOfString: @"?"
				   options: 0
				     range: range];
  if (range.length > 0)
    {
      if (range.location > 0)
	{
	  NSString	*sub;

	  sub = [resourceSpecifier substringWithRange:
	    NSMakeRange(index, range.location - index)];
	  [elements setObject: sub
		       forKey: NSURLPartKey_path];
	}
      if (range.location + 1 < [resourceSpecifier length])
	{
	  NSString	*sub;

	  sub = [resourceSpecifier substringFromIndex: range.location + 1];
	  [elements setObject: sub
		       forKey: NSURLPartKey_query];
	}
    }
  else
    {
      [elements setObject: [resourceSpecifier substringFromIndex: index]
		   forKey: NSURLPartKey_path];
    }

  return elements;
}

//-----------------------------------------------------------------------------
- (NSString*) host
{
  return [[self explode] objectForKey: NSURLPartKey_host];
}

//-----------------------------------------------------------------------------
- (NSNumber*) port;
{
  return [[self explode] objectForKey: NSURLPartKey_port];
}

//-----------------------------------------------------------------------------
- (NSString*) user;
{
  return [[self explode] objectForKey: NSURLPartKey_user];
}

//-----------------------------------------------------------------------------
- (NSString*) password;
{
  return [[self explode] objectForKey: NSURLPartKey_password];
}

//-----------------------------------------------------------------------------
- (NSString*) path;
{
  return [[self explode] objectForKey: NSURLPartKey_path];
}

//-----------------------------------------------------------------------------
- (NSString*) fragment;
{
  return [[self explode] objectForKey: NSURLPartKey_fragment];
}

//-----------------------------------------------------------------------------
- (NSString*) parameterString;
{
  return [[self explode] objectForKey: NSURLPartKey_parameterString];
}

//-----------------------------------------------------------------------------
- (NSString*) query;
{
  return [[self explode] objectForKey: NSURLPartKey_query];
}

//-----------------------------------------------------------------------------
- (NSString*) relativePath
{
  //FIXME?
  return [self path];
}

//-----------------------------------------------------------------------------
- (BOOL) isFileURL
{
  return [[self scheme] isEqualToString: NSURLFileScheme];
}

//-----------------------------------------------------------------------------
- (NSURL*) standardizedURL
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData
{
}

//-----------------------------------------------------------------------------
- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender
{
}

//-----------------------------------------------------------------------------
- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender
{
}

//-----------------------------------------------------------------------------
- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender
{
}

//-----------------------------------------------------------------------------
- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
}

//-----------------------------------------------------------------------------
//FIXME: delete these fn when NSURL will be validated
+ (void) test
{
  NSURL* url2;
  NSURL* url3;
  NSURL* url = [NSURL URLWithString: @"http: //user: passwd@www.gnustep.org: 80/apache"];
  url2= [NSURL URLWithString: @"/test?aa = bb&cc=dd" relativeToURL: url];
  url3= [NSURL URLWithString: @"test?aa = bb&cc=dd" relativeToURL: url];
  NSLog(@"=== url ===");
  [NSURL testPrint: url];
  NSLog(@"=== url2===");
  [NSURL testPrint: url2];
  NSLog(@"=== url3===");
  [NSURL testPrint: url3];
}

+ (void) testPrint: (NSURL*)url
{
  id aBaseUrl = nil;
  id aUrlString = nil;
  GSGetInstanceVariable(url, @"_baseURL", &aBaseUrl);
  GSGetInstanceVariable(url, @"_urlString", &aUrlString);
  NSLog(@"*BaseURL: %ld", (long)aBaseUrl);
  NSLog(@"*BaseURL: %@", [aBaseUrl description]);
  NSLog(@"*_urlString: %@", aUrlString);
  NSLog(@"*host: %@", [url host]);
  NSLog(@"*port: %@", [url port]);
  NSLog(@"*user: %@", [url user]);
  NSLog(@"*password: %@", [url password]);
  NSLog(@"*path: %@", [url path]);
  NSLog(@"*fragment: %@", [url fragment]);
  NSLog(@"*parameterString: %@", [url parameterString]);
  NSLog(@"*query: %@", [url query]);
  NSLog(@"*relativePath: %@", [url relativePath]);
  NSLog(@"*absoluteString: %@", [url absoluteString]);
  NSLog(@"*relativeString: %@", [url relativeString]);
  NSLog(@"*_baseURL: %@", [[url baseURL] description]);
}

//-----------------------------------------------------------------------------
- (void) loadResourceDataNotifyingClient: (id)client
			      usingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: shouldUseCache];
  NSRunLoop	*loop;
  NSDate	*future;
  
  if (client != nil)
    [handle addClient: client];

  /*
   * Kick off the load process.
   */
  [handle loadInBackground];

  /*
   * Keep the runloop going until the load has completed (or failed).
   */
  loop = [NSRunLoop currentRunLoop];
  future = [NSDate distantFuture];
  while ([handle status] == NSURLHandleLoadInProgress)
    {
      [loop runMode: NSDefaultRunLoopMode beforeDate: future];
    }

  if (client != nil)
    [handle removeClient: client];
}

- (NSData*) resourceDataUsingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: shouldUseCache];
  NSData	*data;

  if (shouldUseCache == NO || [handle status] != NSURLHandleLoadSucceeded)
    {
      [self loadResourceDataNotifyingClient: self
				 usingCache: shouldUseCache];
    }
  data = [handle resourceData];
  return data;
}

//-----------------------------------------------------------------------------
- (NSURLHandle*) URLHandleUsingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = nil;

  if (shouldUseCache)
    {
      handle = [NSURLHandle cachedHandleForURL: self];
    }
  if (handle == nil)
    {
      Class	c = [NSURLHandle URLHandleClassForURL: self];

      if (c != 0)
	{
	  handle = [[c alloc] initWithURL: self cached: shouldUseCache];
	  AUTORELEASE(handle);
	}
    }
  return handle;
}

//-----------------------------------------------------------------------------
- (BOOL) setResourceData: (NSData*)data
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle writeData: data];
}

//-----------------------------------------------------------------------------
- (id) propertyForKey: (NSString*)propertyKey
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle propertyForKey: propertyKey];
}

//-----------------------------------------------------------------------------
- (BOOL) setProperty: (id)property
	      forKey: (NSString*)propertyKey;
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle writeProperty: property forKey: propertyKey];
}

@end

//=============================================================================
@implementation NSObject (NSURLClient)

- (void) URL: (NSURL*)sender
  resourceDataDidBecomeAvailable: (NSData*)newBytes
{
  [self notImplemented: _cmd];
}

- (void) URLResourceDidFinishLoading: (NSURL*)sender
{
  [self notImplemented: _cmd];
}

- (void) URLResourceDidCancelLoading: (NSURL*)sender
{
  [self notImplemented: _cmd];
}

- (void) URL: (NSURL*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
  [self notImplemented: _cmd];
}

@end
