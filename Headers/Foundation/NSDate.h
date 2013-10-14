/* Interface for NSDate for GNUStep
   Copyright (C) 1994, 1996, 1999 Free Software Foundation, Inc.

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

#ifndef __NSDate_h_GNUSTEP_BASE_INCLUDE
#define __NSDate_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObjCRuntime.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/**
 * Time interval difference between two dates, in seconds.
 */
typedef double NSTimeInterval;

/**
 * Time interval between the unix standard reference date of 1 January 1970
 * and the OpenStep reference date of 1 January 2001<br />
 * This number comes from:<br />
 * (((31 years * 365 days) + 8 days for leap years) = total number of days<br />
 * 24 hours * 60 minutes * 60 seconds)<br />
 * This ignores leap-seconds.
 */
GS_EXPORT const NSTimeInterval NSTimeIntervalSince1970;

#import	<Foundation/NSObject.h>

@class NSArray;
@class NSCalendarDate;
@class NSData;
@class NSDictionary;
@class NSString;
@class NSTimeZone;
@class NSTimeZoneDetail;

@interface NSDate : NSObject <NSCoding,NSCopying>
{
}

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate;

// Allocation and initializing

+ (id) date;
+ (id) dateWithString: (NSString*)description;
+ (id) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds;
+ (id) dateWithTimeIntervalSince1970: (NSTimeInterval)seconds;
+ (id) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds;
+ (id) distantFuture;
+ (id) distantPast;

- (id) initWithString: (NSString*)description;
- (id) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		  sinceDate: (NSDate*)anotherDate;
- (id) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;

// Converting to NSCalendar

- (NSCalendarDate*) dateWithCalendarFormat: (NSString*)formatString
				  timeZone: (NSTimeZone*)timeZone;

// Representing dates

- (NSString*) description;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
				     locale: (NSDictionary*)l;
- (NSString*) descriptionWithLocale: (id)locale;

// Adding and getting intervals

- (id) addTimeInterval: (NSTimeInterval)seconds;
- (NSTimeInterval) timeIntervalSince1970;
- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate;
- (NSTimeInterval) timeIntervalSinceNow;
- (NSTimeInterval) timeIntervalSinceReferenceDate;

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate;
- (NSDate*) earlierDate: (NSDate*)otherDate;
- (BOOL) isEqualToDate: (NSDate*)other;
- (NSDate*) laterDate: (NSDate*)otherDate;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST)
/**
 * Returns an autoreleased NSDate instance whose value is offset from
 * that of the receiver by the specified interval.
 */
- (id) dateByAddingTimeInterval: (NSTimeInterval)ti;
+ (id) dateWithTimeInterval: (NSTimeInterval)seconds sinceDate: (NSDate*)date;
#endif

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
+ (id) dateWithNaturalLanguageString: (NSString*)string;
+ (id) dateWithNaturalLanguageString: (NSString*)string
                              locale: (NSDictionary*)locale;
- (id) initWithTimeIntervalSince1970: (NSTimeInterval)seconds;
#endif

@end

#if	defined(__cplusplus)
}
#endif

#endif  /* __NSDate_h_GNUSTEP_BASE_INCLUDE*/
