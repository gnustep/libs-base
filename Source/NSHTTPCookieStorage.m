/* Implementation for NSHTTPCookieStorage for GNUstep
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
#include "Foundation/NSSet.h"

NSString * const NSHTTPCookieManagerAcceptPolicyChangedNotification
  = @"NSHTTPCookieManagerAcceptPolicyChangedNotification";

NSString * const NSHTTPCookieManagerCookiesChangedNotification
  = @"NSHTTPCookieManagerCookiesChangedNotification";

// Internal data storage
typedef struct {
  NSHTTPCookieAcceptPolicy	_policy;
  NSMutableSet			*_cookies;
} Internal;
 
typedef struct {
  @defs(NSHTTPCookieStorage)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSHTTPCookieStorageInternal))
#define	inst	((Internal*)(((priv*)o)->_NSHTTPCookieStorageInternal))


/* FIXME
 * handle persistent storage and use policies.
 */
@implementation NSHTTPCookieStorage

static NSHTTPCookieStorage   *storage = nil;

+ (id) allocWithZone: (NSZone*)z
{
  return RETAIN([self sharedHTTPCookieStorage]);
}

+ (NSHTTPCookieStorage *) sharedHTTPCookieStorage
{
  if (storage == nil)
    {
      [gnustep_global_lock lock];
      if (storage == nil)
        {
	  NSHTTPCookieStorage	*o;

	  o = (NSHTTPCookieStorage*)
	    NSAllocateObject(self, 0, NSDefaultMallocZone());
	  o->_NSHTTPCookieStorageInternal = (Internal*)
	    NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(Internal));
	  inst->_policy = NSHTTPCookieAcceptPolicyAlways;
	  inst->_cookies = [NSMutableSet new];
	  storage = o;
	}
      [gnustep_global_lock unlock];
    }
  return storage;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->_cookies);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSHTTPCookieAcceptPolicy) cookieAcceptPolicy
{
  return this->_policy;
}

- (NSArray *) cookies
{
  return [this->_cookies allObjects];
}

- (NSArray *) cookiesForURL: (NSURL *)URL
{
  [self notImplemented: _cmd];	// FIXME
  return nil;
}

- (void) deleteCookie: (NSHTTPCookie *)cookie
{
  [this->_cookies removeObject: cookie];
}

- (void) setCookie: (NSHTTPCookie *)cookie
{
  NSAssert([cookie isKindOfClass: [NSHTTPCookie class]] == YES,
    NSInvalidArgumentException);
  [this->_cookies addObject: cookie];
}

- (void) setCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{
  this->_policy = cookieAcceptPolicy;
}

- (void) setCookies: (NSArray *)cookies
	     forURL: (NSURL *)URL
    mainDocumentURL: (NSURL *)mainDocumentURL
{
  unsigned	count = [cookies count];

  while (count-- > 0)
    {
      NSHTTPCookie	*c = [cookies objectAtIndex: count];

      // FIXME check domain matches 
      [this->_cookies addObject: c];
    }
}

@end

