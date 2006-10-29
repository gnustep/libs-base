/** Interface for NSError for GNUStep
   Copyright (C) 2004-2006 Free Software Foundation, Inc.

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

   AutogsdocSource: NSError.m
   */

#ifndef __NSError_h_GNUSTEP_BASE_INCLUDE
#define __NSError_h_GNUSTEP_BASE_INCLUDE

#if	OS_API_VERSION(100207,GS_API_LATEST)

#include <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray, NSDictionary, NSString;

/**
 * Key for user info dictionary component which describes the error in
 * a human readable format.
 */
GS_EXPORT const NSString *NSLocalizedDescriptionKey;

/**
 * Where one error has caused another, the underlying error can be stored
 * in the user info dictionary using this key.
 */
GS_EXPORT const NSString *NSUnderlyingErrorKey;

/**
 * Where the error relates to a particular file or directory, this
 * key stores the particular path in question.
 */
GS_EXPORT const NSString *NSFilePathErrorKey;

GS_EXPORT const NSString *NSStringEncodingErrorKey;

#if OS_API_VERSION(100400,GS_API_LATEST) && GS_API_VERSION(011400,GS_API_LATEST)
GS_EXPORT const NSString *NSLocalizedFailureReasonErrorKey;
GS_EXPORT const NSString *NSLocalizedRecoverySuggestionErrorKey;
GS_EXPORT const NSString *NSLocalizedRecoveryOptionsErrorKey;
GS_EXPORT const NSString *NSRecoveryAttempterErrorKey;

/**
 * Domain for errors generated in MS-Windows libraries.
 */
GS_EXPORT const NSString *GSMSWindowsErrorDomain;
#endif

/**
 * Domain for kernel errors (on MACH).
 */
GS_EXPORT const NSString *NSMACHErrorDomain;
/**
 * Domain for Carbon errors.
 */
GS_EXPORT const NSString *NSOSStatusErrorDomain;
/**
 * Domain for errors from libc and such.
 */
GS_EXPORT const NSString *NSPOSIXErrorDomain;

/**
 * <p>
 * NSError objects encapsulate information about an error. This includes the
 * domain where the error was generated, an integer error code for the
 * specific error and a dictionary containing application defined information
 * </p>
 * <p>
 * GNUstep provides localized descriptive strings for the NSPOSIXErrorDomain
 * & GSMSWindowsErrorDomain.
 * </p>
 */
@interface NSError : NSObject <NSCopying, NSCoding>
{
@private
  int          _code;
  NSString     *_domain;
  NSDictionary *_userInfo;
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
 * The domain must be non-nil.
 */
- (id) initWithDomain: (NSString*)aDomain
		 code: (int)aCode
	     userInfo: (NSDictionary*)aDictionary;

/**
 * Return a human readable description for the error.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it generates one from domain and code.
 */
- (NSString *)localizedDescription;


#if OS_API_VERSION(100400,GS_API_LATEST) && GS_API_VERSION(011400,GS_API_LATEST)
/**
 * Returns a localised string explaining the reason why the error was
 * generated and should be more descriptive and helpful than given by
 * localizedDescription. If no localised failure reasons are available
 * this will return nil;
 */
- (NSString *)localizedFailureReason;

/**
 * Returns an array containing the localized titles of buttons appropriate for displaying in an alert panel.
 */
- (NSArray *)localizedRecoveryOptions;

- (NSString *)localizedRecoverySuggestion;

- (id)recoveryAttempter;
#endif

/**
 * Return the user info for this instance (or nil if none is set)<br />
 * The <code>NSLocalizedDescriptionKey</code> should locate a human readable
 * description in the dictionary.<br />
 * The <code>NSUnderlyingErrorKey</code> key should locate an
 * <code>NSError</code> instance if an error is available describing any
 * underlying problem.<br />
 */
- (NSDictionary*) userInfo;
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* STRICT_OPENSTEP */
#endif	/* __NSError_h_GNUSTEP_BASE_INCLUDE*/
