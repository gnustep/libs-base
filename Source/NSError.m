/** Implementation for NSError for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: May 2004
   Additions:  Sheldon Gill <sheldon@westnet.net.au>
   Date: Oct 2006

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

#include    <Foundation/NSArray.h>
#include    <Foundation/NSDictionary.h>
#include    <Foundation/NSString.h>
#include    <Foundation/NSError.h>
#include    <Foundation/NSCoder.h>
#include    <GNUstepBase/GSFunctions.h>

#include    <GNUstepBase/Win32_Utilities.h>

/* ---- Error Keys ---- */
const NSString *NSLocalizedDescriptionKey = @"NSLocalizedDescriptionKey";
const NSString *NSUnderlyingErrorKey = @"NSUnderlyingErrorKey";

const NSString *NSFilePathErrorKey = @"NSFilePathErrorKey";
const NSString *NSStringEncodingErrorKey = @"NSStringEncodingErrorKey";

const NSString *NSLocalizedFailureReasonErrorKey = @"NSLocalizedFailureReasonErrorKey";
const NSString *NSLocalizedRecoverySuggestionErrorKey = @"NSLocalizedRecoverySuggestionErrorKey";
const NSString *NSLocalizedRecoveryOptionsErrorKey = @"NSLocalizedRecoveryOptionsErrorKey";
const NSString *NSRecoveryAttempterErrorKey = @"NSRecoveryAttempterErrorKey";

/* ---- Error Domains ---- */
const NSString *NSMACHErrorDomain = @"NSMACHErrorDomain";
const NSString *NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
const NSString *NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";

const NSString *GSMSWindowsErrorDomain = @"GSMSWindowsErrorDomain";


@implementation	NSError

+ (id) errorWithDomain: (NSString*)aDomain
		  code: (int)aCode
	      userInfo: (NSDictionary*)aDictionary
{
  NSError	*e = [self allocWithZone: NSDefaultMallocZone()];

  e = [e initWithDomain: aDomain code: aCode userInfo: aDictionary];
  return AUTORELEASE(e);
}

- (id) copyWithZone: (NSZone*)z
{
  NSError	*e = [[self class] allocWithZone: z];

  e = [e initWithDomain: _domain code: _code userInfo: _userInfo];
  return e;
}

- (void) dealloc
{
  DESTROY(_domain);
  DESTROY(_userInfo);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [aCoder encodeInt: _code forKey: @"NSCode"];
      [aCoder encodeObject: _domain forKey: @"NSDomain"];
      [aCoder encodeObject: _userInfo forKey: @"NSUserInfo"];
    }
  else
    {
      [aCoder encodeValueOfObjCType: @encode(int) at: &_code];
      [aCoder encodeValueOfObjCType: @encode(id) at: &_domain];
      [aCoder encodeValueOfObjCType: @encode(id) at: &_userInfo];
    }
}

- (id) init
{
  return [self initWithDomain: nil code: 0 userInfo: nil];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      int	c;
      id	d;
      id	u;

      c = [aCoder decodeIntForKey: @"NSCode"];
      d = [aCoder decodeObjectForKey: @"NSDomain"];
      u = [aCoder decodeObjectForKey: @"NSUserInfo"];
      self = [self initWithDomain: d code: c userInfo: u];
    }
  else
    {
      [aCoder decodeValueOfObjCType: @encode(int) at: &_code];
      [aCoder decodeValueOfObjCType: @encode(id) at: &_domain];
      [aCoder decodeValueOfObjCType: @encode(id) at: &_userInfo];
    }
  return self;
}

- (id) initWithDomain: (NSString*)aDomain
		 code: (int)aCode
	     userInfo: (NSDictionary*)aDictionary
{
  // FIXME: This should be NSParameterAssert(), so it throws -SG
  if (aDomain == nil)
    {
      NSLog(@"[%@-%@] with nil domain",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      DESTROY(self);
    }
  else if ((self = [super init]) != nil)
    {
      ASSIGN(_domain, aDomain);
      _code = aCode;
      ASSIGN(_userInfo, aDictionary);
    }
  return self;
}

- (int) code
{
  return _code;
}

- (NSString*) domain
{
  return _domain;
}

- (NSString *) localizedDescription
{
  NSString *desc = [_userInfo objectForKey: (NSString *)NSLocalizedDescriptionKey];

  /*
   * Autofill the description if it hasn't been specified
   */
  if (desc == nil)
    {
      if ([_domain isEqualToString: (NSString *)NSPOSIXErrorDomain])
        {
            /* It's the system/libc error code. */
            return [NSString stringWithCString: strerror(_code)
                                      encoding: [NSString defaultCStringEncoding]];
        }
#if defined(__MACOSX__)
      /* These only have meaning on MacOSX... */
      else if ([_domain isEqualToString: NSOSStatusErrorDomain])
        {
            /* This only has meaning on Carbon... */
            return [NSString stringWithFormat: @"%@",
                      GetMacOSStatusErrorString()];
        }
      else if ([_domain isEqualToString: NSMACHErrorDomain])
        {
            ; // FIXME: How do we get error strings from MACH? -SG
        }
#endif
#if defined(__MINGW32__)
      /* This only has meaning on MS-Windows... */
      else if ([_domain isEqualToString: (NSString *)GSMSWindowsErrorDomain])
        {
            return Win32ErrorString(_code);
        }
#endif
      else
        {
          desc = [NSString stringWithFormat: @"%@ Error#%d", _domain, _code];
        }
    }
  return desc;
}

- (NSString *) localizedFailureReason
{
  return [_userInfo objectForKey: (NSString *)NSLocalizedFailureReasonErrorKey];
}

- (NSArray *) localizedRecoveryOptions
{
  return [_userInfo objectForKey: (NSString *)NSLocalizedRecoveryOptionsErrorKey];
}

- (NSString *) localizedRecoverySuggestion
{
  return [_userInfo objectForKey: (NSString *)NSLocalizedRecoverySuggestionErrorKey];
}

- (id) recoveryAttempter
{
  return [_userInfo objectForKey: (NSString *)NSRecoveryAttempterErrorKey];
}

- (NSDictionary*) userInfo
{
  return _userInfo;
}
@end
