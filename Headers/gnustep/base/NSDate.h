/* Interface for NSDate for GNUStep
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#ifndef __NSDate_h_GNUSTEP_BASE_INCLUDE
#define __NSDate_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

/* Time interval difference between two dates, in seconds. */
typedef double NSTimeInterval;

@class NSArray;
@class NSCalendarDate;
@class NSDictionary;
@class NSString;
@class NSTimeZone;
@class NSTimeZoneDetail;

@interface NSDate : NSObject <NSCoding,NSCopying>

{
  NSTimeInterval seconds_since_ref;
}

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate;

// Allocation and initializing

+ (NSDate*) date;
+ (NSDate*) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds;
+ (NSDate*) dateWithTimeIntervalSince1970: (NSTimeInterval)seconds;
+ (NSDate*) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds;
+ (NSDate*) distantFuture;
+ (NSDate*) distantPast;

- (id) initWithString: (NSString*)description;
- (NSDate*) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		       sinceDate: (NSDate*)anotherDate;
- (NSDate*) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
- (NSDate*) initWithTimeIntervalSince1970: (NSTimeInterval)seconds;
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone;

// Representing dates

- (NSString*) description;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone;
- (NSString *) descriptionWithLocale: (NSDictionary *)locale;

// Adding and getting intervals

- (NSDate*) addTimeInterval: (NSTimeInterval)seconds;
- (NSTimeInterval) timeIntervalSince1970;
- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate;
- (NSTimeInterval) timeIntervalSinceNow;
- (NSTimeInterval) timeIntervalSinceReferenceDate;

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate;
- (NSDate*) earlierDate: (NSDate*)otherDate;
- (BOOL) isEqual: (id)other;
- (NSDate*) laterDate: (NSDate*)otherDate;

@end


@interface NSTimeZone : NSObject

//Creating and Initializing an NSTimeZone
+ (NSTimeZoneDetail *)defaultTimeZone;
+ (NSTimeZone *)localTimeZone;
+ (NSTimeZone *)timeZoneForSecondsFromGMT:(int)seconds;
+ (NSTimeZoneDetail *)timeZoneWithAbbreviation:(NSString *)abbreviation;  
+ (NSTimeZone *)timeZoneWithName:(NSString *)aTimeZoneName;
- (NSTimeZoneDetail *)timeZoneDetailForDate:(NSDate *)date;

//Managing Time Zones
+ (void)setDefaultTimeZone:(NSTimeZone *)aTimeZone;

// Getting Time Zone Information
+ (NSDictionary *)abbreviationDictionary;
- (NSString *)timeZoneName;

/* Returns an dictionary that maps abbreviations to the array
   containing all the time zone names that use the abbreviation.
   Not in OpenStep. */
+ (NSDictionary *)abbreviationMap;

//Getting Arrays of Time Zones
+ (NSArray *)timeZoneArray;
- (NSArray *)timeZoneDetailArray;

@end


@interface NSTimeZoneDetail : NSTimeZone

//Querying an NSTimeZoneDetail
- (BOOL)isDaylightSavingTimeZone;
- (NSString *)timeZoneAbbreviation;
- (int)timeZoneSecondsFromGMT;

@end


@interface NSCalendarDate : NSDate

{
  NSString *calendar_format;
  NSTimeZoneDetail *time_zone;
}

// Getting an NSCalendar Date
+ (NSCalendarDate *)calendarDate;
+ (NSCalendarDate *)dateWithString:(NSString *)description
		    calendarFormat:(NSString *)format;
+ (NSCalendarDate *)dateWithString:(NSString *)description
		    calendarFormat:(NSString *)format
			    locale:(NSDictionary *)dictionary;
+ (NSCalendarDate *)dateWithYear:(int)year
			   month:(unsigned int)month
			     day:(unsigned int)day
			    hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			timeZone:(NSTimeZone *)aTimeZone;

// Initializing an NSCalendar Date
- (id)initWithString:(NSString *)description;
- (id)initWithString:(NSString *)description
      calendarFormat:(NSString *)format;
- (id)initWithString:(NSString *)description
      calendarFormat:(NSString *)format
	      locale:(NSDictionary *)dictionary;
- (id)initWithYear:(int)year
	     month:(unsigned int)month
	       day:(unsigned int)day
	      hour:(unsigned int)hour
	    minute:(unsigned int)minute
	    second:(unsigned int)second
	  timeZone:(NSTimeZone *)aTimeZone;

// Retreiving Date Elements
- (int)dayOfCommonEra;
- (int)dayOfMonth;
- (int)dayOfWeek;
- (int)dayOfYear;
- (int)hourOfDay;
- (int)minuteOfHour;
- (int)monthOfYear;
- (int)secondOfMinute;
- (int)yearOfCommonEra;

// Providing Adjusted Dates
- (NSCalendarDate *)addYear:(int)year
		      month:(unsigned int)month
			day:(unsigned int)day
		       hour:(unsigned int)hour
		     minute:(unsigned int)minute
		     second:(unsigned int)second;

// Getting String Descriptions of Dates
- (NSString *)description;
- (NSString *)descriptionWithCalendarFormat:(NSString *)format;
- (NSString *)descriptionWithCalendarFormat:(NSString *)format
				     locale:(NSDictionary *)locale;
- (NSString *)descriptionWithLocale:(NSDictionary *)locale;

// Getting and Setting Calendar Formats
- (NSString *)calendarFormat;
- (void)setCalendarFormat:(NSString *)format;

// Getting and Setting Time Zones
- (void)setTimeZone:(NSTimeZone *)aTimeZone;
- (NSTimeZoneDetail *)timeZoneDetail;

@end


@interface NSCalendarDate (GregorianDate)

- (int)lastDayOfGregorianMonth:(int)month year:(int)year;
- (int)absoluteGregorianDay:(int)day month:(int)month year:(int)year;
- (void)gregorianDateFromAbsolute:(int)d
			      day:(int *)day
			    month:(int *)month
			     year:(int *)year;

@end

@interface NSCalendarDate (OPENSTEP)

- (NSCalendarDate *)dateByAddingYears:(int)years
			       months:(int)months
				 days:(int)days
			        hours:(int)hours
			      minutes:(int)minutes
			      seconds:(int)seconds;

- (void) years: (int*)years
	months: (int*)months
          days: (int*)days
         hours: (int*)hours
       minutes: (int*)minutes
       seconds: (int*)seconds
     sinceDate: (NSDate*)date;
@end

#endif  /* __NSDate_h_GNUSTEP_BASE_INCLUDE */
