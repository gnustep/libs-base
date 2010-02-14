/* Implementation for NSHTTPCookie for GNUstep
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

#define	EXPOSE_NSHTTPCookie_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSSet.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

NSString * const NSHTTPCookieComment = @"NSHTTPCookieComment";
NSString * const NSHTTPCookieCommentURL = @"NSHTTPCookieCommentURL";
NSString * const NSHTTPCookieDiscard = @"NSHTTPCookieDiscard";
NSString * const NSHTTPCookieDomain = @"NSHTTPCookieDomain";
NSString * const NSHTTPCookieExpires = @"NSHTTPCookieExpires";
NSString * const NSHTTPCookieMaximumAge = @"NSHTTPCookieMaximumAge";
NSString * const NSHTTPCookieName = @"NSHTTPCookieName";
NSString * const NSHTTPCookieOriginURL = @"NSHTTPCookieOriginURL";
NSString * const NSHTTPCookiePath = @"NSHTTPCookiePath";
NSString * const NSHTTPCookiePort = @"NSHTTPCookiePort";
NSString * const NSHTTPCookieSecure = @"NSHTTPCookieSecure";
NSString * const NSHTTPCookieValue = @"NSHTTPCookieValue";
NSString * const NSHTTPCookieVersion = @"NSHTTPCookieVersion";

// Internal data storage
typedef struct {
  NSDictionary	*_properties;
} Internal;
 
#define	this	((Internal*)(self->_NSHTTPCookieInternal))
#define	inst	((Internal*)(o->_NSHTTPCookieInternal))

@implementation NSHTTPCookie

+ (id) allocWithZone: (NSZone*)z
{
  NSHTTPCookie	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSHTTPCookieInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

+ (id) cookieWithProperties: (NSDictionary *)properties
{
  NSHTTPCookie	*o;

  o = [[self alloc] initWithProperties: properties];
  return AUTORELEASE(o);
}

+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *)headerFields
				       forURL: (NSURL *)URL
{
  NSMutableArray	*a = nil;

  [self notImplemented: _cmd];	// FIXME
  return a;
}

+ (NSDictionary *) requestHeaderFieldsWithCookies: (NSArray *)cookies
{
  NSMutableDictionary	*d = nil;

  [self notImplemented: _cmd];	// FIXME
  return d;
}

- (NSString *) comment
{
  return [this->_properties objectForKey: NSHTTPCookieComment];
}

- (NSURL *) commentURL
{
  return [this->_properties objectForKey: NSHTTPCookieCommentURL];
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->_properties);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSString *) domain
{
  return [this->_properties objectForKey: NSHTTPCookieDomain];
}

- (NSDate *) expiresDate
{
  return [this->_properties objectForKey: NSHTTPCookieExpires];
}

- (id) initWithProperties: (NSDictionary *)properties
{
  if ((self = [super init]) != nil)
    {
      this->_properties = [properties copy];
      // FIXME ... parse and validate
    }
  return self;
}

- (BOOL) isSecure
{
  return [[this->_properties objectForKey: NSHTTPCookieSecure] boolValue];
}

- (BOOL) isSessionOnly
{
  return [[this->_properties objectForKey: NSHTTPCookieDiscard] boolValue];
}

- (NSString *) name
{
  return [this->_properties objectForKey: NSHTTPCookieName];
}

- (NSString *) path
{
  return [this->_properties objectForKey: NSHTTPCookiePath];
}

- (NSArray *) portList
{
  return [[this->_properties objectForKey: NSHTTPCookiePort]
    componentsSeparatedByString: @","];
}

- (NSDictionary *) properties
{
  return this->_properties;
}

- (NSString *) value
{
  return [this->_properties objectForKey: NSHTTPCookieValue];
}

- (NSUInteger) version
{
  return [[this->_properties objectForKey: NSHTTPCookieVersion] integerValue];
}

@end

