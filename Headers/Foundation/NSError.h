/** Interface for NSError for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: May 2004
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   AutogsdocSource: NSError.m
   */ 

#ifndef __NSError_h_GNUSTEP_BASE_INCLUDE
#define __NSError_h_GNUSTEP_BASE_INCLUDE

#ifndef	STRICT_OPENSTEP

#include <Foundation/NSObject.h>

@class NSDictionary, NSString;

/**
 * Key for user info dictionary component which describes the error in
 * a human readable format.
 */
GS_EXPORT NSString* const NSLocalizedDescriptionKey;

/**
 * Where one error has caused another, the underlying error can be stored
 * in the user info dictionary uisng this key.
 */
GS_EXPORT NSString* const NSUnderlyingErrorKey;

/**
 * Domain for system errors (on MACH).
 */
GS_EXPORT NSString* const NSMACHErrorDomain;
/**
 * Domain for system errors.
 */
GS_EXPORT NSString* const NSOSStatusErrorDomain;
/**
 * Domain for system and system library errors.
 */
GS_EXPORT NSString* const NSPOSIXErrorDomain;

/**
 * Error information class
 */
@interface NSError : NSObject <NSCopying, NSCoding>
{
@private
  int		_code;
  NSString	*_domain;
  NSDictionary	*_userInfo;
}

/**
 * Creates and returns an autoreleased NSError instance by calling
 * -initWithDomain:code:userInfo:
 */
+ (id) errorWithDomain: (NSString*)aDomain
		  code: (int)aCode
	      userInfo: (NSDictionary*)aDictionary;

/**
 * Return the error code ... which is not globally unique, just unique for
 * a particular domain.
 */
- (int) code;

/**
 * Return the domain for this instance.
 */
- (NSString*) domain;

/** <init />
 * Initialises the receiver using the supplied domain, code, and info.<br />
 * The domain musat be non-nil.
 */
- (id) initWithDomain: (NSString*)aDomain
		 code: (int)aCode
	     userInfo: (NSDictionary*)aDictionary;

/** <override-subclass />
 * Return a human readable description for the error.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it generates a generic one from domain
 * and code.
 */
- (NSString *)localizedDescription;

/**
 * Return the user info for this instance (or nil if none is set)<br />
 * The NSLocalizedDescriptionKey should locate a human readable description
 * in the dictionary.<br /> 
 * The NSUnderlyingErrorKey key should locate an NSError instance if an
 * error is available describing any underlying problem.<br />
 */
- (NSDictionary*) userInfo;
@end

#endif	/* STRICT_OPENSTEP */
#endif	/* __NSError_h_GNUSTEP_BASE_INCLUDE*/
