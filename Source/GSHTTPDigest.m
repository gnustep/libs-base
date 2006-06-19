/* Implementation for GSHTTPDigest for GNUstep
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
#include "Foundation/NSDictionary.h"
#include "Foundation/NSScanner.h"
#include "Foundation/NSDebug.h"
#include "GNUstepBase/GSLock.h"
#include "GNUstepBase/GSMime.h"


static NSMutableDictionary	*store = nil;
static GSLazyLock		*storeLock = nil;
static GSMimeParser		*mimeParser = nil;

@interface NSData(GSHTTPDigest)
- (NSString*) digestHex;
@end
@implementation NSData(GSHTTPDigest)
- (NSString*) digestHex
{
  static const char	*hexChars = "0123456789abcdef";
  unsigned		slen = [self length];
  unsigned		dlen = slen * 2;
  const unsigned char	*src = (const unsigned char *)[self bytes];
  char			*dst = (char*)NSZoneMalloc(NSDefaultMallocZone(), dlen);
  unsigned		spos = 0;
  unsigned		dpos = 0;
  NSData		*data;
  NSString		*string;

  while (spos < slen)
    {
      unsigned char	c = src[spos++];

      dst[dpos++] = hexChars[(c >> 4) & 0x0f];
      dst[dpos++] = hexChars[c & 0x0f];
    }
  data = [NSData allocWithZone: NSDefaultMallocZone()];
  data = [data initWithBytesNoCopy: dst length: dlen];
  string = [[NSString alloc] initWithData: data
				 encoding: NSASCIIStringEncoding];
  RELEASE(data);
  return AUTORELEASE(string);
}
@end



@implementation GSHTTPDigest

+ (void) initialize
{
  if (store == nil)
    {
      mimeParser = [GSMimeParser new];
      store = [NSMutableDictionary new];
      storeLock = [GSLazyLock new];
    }
}

+ (GSHTTPDigest *) digestWithCredential: (NSURLCredential*)credential
		      inProtectionSpace: (NSURLProtectionSpace*)space
{
  NSMutableDictionary	*cDict;
  GSHTTPDigest		*digest = nil;

  [storeLock lock];
  cDict = [store objectForKey: space];
  if (cDict == nil)
    {
      cDict = [NSMutableDictionary new];
      [store setObject: cDict forKey: space];
      RELEASE(cDict);
    }
  digest = [cDict objectForKey: credential];
  if (digest == nil)
    {
      digest = [[GSHTTPDigest alloc] initWithCredential: credential
				      inProtectionSpace: space];
      [cDict setObject: digest forKey: [digest credential]];
    }
  else
    {
      RETAIN(digest);
    }
  [storeLock unlock];
  return AUTORELEASE(digest);
}

+ (NSString*) digestRealmForAuthentication: (NSString*)authentication
{
  if (authentication != nil)
    {
      NSScanner		*sc;
      NSString		*key;
      NSString		*val;

      sc = [NSScanner scannerWithString: authentication];
      if ([sc scanString: @"Digest" intoString: 0] == NO)
	{
	  return nil;	// Not a digest authentication
	}
      while ((key = [mimeParser scanName: sc]) != nil)
	{
	  if ([sc scanString: @"=" intoString: 0] == NO)
	    {
	      return nil;	// Bad name=value specification
	    }
	  if ((val = [mimeParser scanToken: sc]) == nil)
	    {
	      return nil;	// Bad name=value specification
	    }
	  if ([key caseInsensitiveCompare: @"realm"] == NSOrderedSame)
	    {
	      return val;
	    }
	}
    }
  return nil;
}

- (NSString*) authorizationForAuthentication: (NSString*)authentication
				      method: (NSString*)method
					path: (NSString*)path
{
  NSString		*realm = nil;
  NSString		*qop = nil;
  NSString		*nonce = nil;
  NSString		*opaque = nil;
  NSString		*stale = @"FALSE";
  NSString		*algorithm = @"MD5";
  NSString		*cnonce;
  NSString		*HA1;
  NSString		*HA2;
  NSString		*response;
  NSMutableString	*authorisation;
  int			nc;

  if (authentication != nil)
    {
      NSScanner		*sc;
      NSString		*key;
      NSString		*val;

      sc = [NSScanner scannerWithString: authentication];
      if ([sc scanString: @"Digest" intoString: 0] == NO)
	{
	  NSDebugMLog(@"Bad format HTTP digest in '%@'", authentication);
	  return nil;	// Not a digest authentication
	}
      while ((key = [mimeParser scanName: sc]) != nil)
	{
	  if ([sc scanString: @"=" intoString: 0] == NO)
	    {
	      NSDebugMLog(@"Missing '=' in HTTP digest '%@'", authentication);
	      return nil;	// Bad name=value specification
	    }
	  if ((val = [mimeParser scanToken: sc]) == nil)
	    {
	      NSDebugMLog(@"Missing value in HTTP digest '%@'", authentication);
	      return nil;	// Bad name=value specification
	    }
	  if ([key caseInsensitiveCompare: @"realm"] == NSOrderedSame)
	    {
	      realm = val;
	    }
	  if ([key caseInsensitiveCompare: @"qop"] == NSOrderedSame)
	    {
	      qop = val;
	    }
	  if ([key caseInsensitiveCompare: @"nonce"] == NSOrderedSame)
	    {
	      nonce = val;
	    }
	  if ([key caseInsensitiveCompare: @"opaque"] == NSOrderedSame)
	    {
	      opaque = val;
	    }
	  if ([key caseInsensitiveCompare: @"stale"] == NSOrderedSame)
	    {
	      stale = val;
	    }
	  if ([key caseInsensitiveCompare: @"algorithm"] == NSOrderedSame)
	    {
	      algorithm = val;
	    }
	  if ([sc scanString: @"," intoString: 0] == NO)
	    {
	      break;	// No more in list.
	    }
	}

      if (realm == nil)
	{
	  NSDebugMLog(@"Missing HTTP digest realm in '%@'", authentication);
	  return nil;
	}
      if ([realm isEqual: [self->_space realm]] == NO)
        {
	  NSDebugMLog(@"Bad HTTP digest realm in '%@'", authentication);
	  return nil;
	}
      if (nonce == nil)
	{
	  NSDebugMLog(@"Missing HTTP digest nonce in '%@'", authentication);
	  return nil;
	}

      if ([algorithm isEqual: @"MD5"] == NO)
        {
	  NSDebugMLog(@"Unsupported HTTP digest algorithm in '%@'",
	    authentication);
	  return nil;
	}
      if (![[qop componentsSeparatedByString: @","] containsObject: @"auth"])
        {
	  NSDebugMLog(@"Unsupported/missing HTTP digest qop in '%@'",
	    authentication);
	  return nil;
	}

      [self->_lock lock];
      if ([stale boolValue] == YES || [nonce isEqual: _nonce] == NO)
	{
	  _nc = 1;
	}
      ASSIGN(_nonce, nonce);
      ASSIGN(_qop, qop);
      ASSIGN(_opaque, opaque);
    }
  else
    {
      [self->_lock lock];
      nonce = _nonce;
      opaque = _opaque;
      qop = _qop;
      realm = [self->_space realm];
    }

  nc = _nc++;

  qop = @"auth";

  cnonce = [[[[[NSProcessInfo processInfo] globallyUniqueString]
    dataUsingEncoding: NSUTF8StringEncoding] md5Digest] digestHex];

  HA1 = [[[[NSString stringWithFormat: @"%@:%@:%@",
    [self->_credential user], realm, [self->_credential password]]
    dataUsingEncoding: NSUTF8StringEncoding] md5Digest] digestHex];

  HA2 = [[[[NSString stringWithFormat: @"%@:%@", method, path]
    dataUsingEncoding: NSUTF8StringEncoding] md5Digest] digestHex];

  response = [[[[NSString stringWithFormat: @"%@:%@:%08x:%@:%@:%@",
    HA1, nonce, nc, cnonce, qop, HA2]
    dataUsingEncoding: NSUTF8StringEncoding] md5Digest] digestHex];

  authorisation = [NSMutableString stringWithCapacity: 512];
  [authorisation appendFormat:  @"Digest realm=\"%@\"", realm];
  [authorisation appendFormat:  @",username=\"%@\"", [self->_credential user]];
  [authorisation appendFormat:  @",nonce=\"%@\"", nonce];
  [authorisation appendFormat:  @",uri=\"%@\"", path];
  [authorisation appendFormat:  @",response=\"%@\"", response];
  [authorisation appendFormat:  @",qop=\"%@\"", qop];
  [authorisation appendFormat:  @",nc=%08x", nc];
  [authorisation appendFormat:  @",cnonce=\"%@\"", cnonce];
  if (opaque != nil)
    {
      [authorisation appendFormat:  @",opaque=\"%@\"", opaque];
    }

  [self->_lock unlock];
 
  return authorisation;
}

- (NSURLCredential *) credential
{
  return self->_credential;
}

- (void) dealloc
{
  RELEASE(_credential);
  RELEASE(_space);
  RELEASE(_nonce);
  RELEASE(_opaque);
  RELEASE(_qop);
  RELEASE(_lock);
  [super dealloc];
}

- (id) initWithCredential: (NSURLCredential*)credential
	inProtectionSpace: (NSURLProtectionSpace*)space
{
  if ((self = [super init]) != nil)
    {
      self->_lock = [GSLazyLock new];
      ASSIGNCOPY(self->_space, space);
      ASSIGNCOPY(self->_credential, credential);
    }
  return self;
}

- (NSURLProtectionSpace *) space
{
  return self->_space;
}
@end

