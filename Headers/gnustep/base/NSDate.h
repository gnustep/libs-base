/* Interface for NSDate for GNUStep
   Copyright (C) 1994, 1996, 1999 Free Software Foundation, Inc.

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
  */

#ifndef __NSDate_h_GNUSTEP_BASE_INCLUDE
#define __NSDate_h_GNUSTEP_BASE_INCLUDE

/* Time interval difference between two dates, in seconds.*/
typedef double NSTimeInterval;

#include <Foundation/NSObject.h>

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
				     locale: (NSDictionary*)localeDictionary;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;

// Adding and getting intervals

- (id) addTimeInterval: (NSTimeInterval)seconds;
- (NSTimeInterval) timeIntervalSince1970;
- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate;
- (NSTimeInterval) timeIntervalSinceNow;
- (NSTimeInterval) timeIntervalSinceReferenceDate;
- (NSTimeInterval) timeIntervalSinceReferenceDate;

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate;
- (NSDate*) earlierDate: (NSDate*)otherDate;
- (BOOL) isEqualToDate: (NSDate*)otherDate;
- (NSDate*) laterDate: (NSDate*)otherDate;

#ifndef	STRICT_OPENSTEP
+ (id) dateWithNaturalLanguageString: (NSString*)string;
+ (id) dateWithNaturalLanguageString: (NSString*)string
                              locale: (NSDictionary*)localeDictionary;
- (id) initWithTimeIntervalSince1970: (NSTimeInterval)seconds;
#endif

@end

#ifndef	NO_GNUSTEP
/*
*	Our concrete base class - NSCalendar date must share the ivar layout.
*/
@interface NSGDate : NSDate
{
@public
  NSTimeInterval _seconds_since_ref;
}
@end

NSTimeInterval GSTimeNow();	/* Get time since reference date*/
NSTimeInterval GSTime(int d, int m, int y, int hh, int mm, int ss, int mil);
#endif



@interface NSTimeZone : NSObject

//Creating and Initializing an NSTimeZone
+ (NSTimeZone*) localTimeZone;
+ (NSTimeZone*) timeZoneForSecondsFromGMT: (int)seconds;
+ (NSTimeZone*) timeZoneWithName: (NSString*)aTimeZoneName;

//Managing Time Zones
+ (void) setDefaultTimeZone: (NSTimeZone*)aTimeZone;

// Getting Time Zone Information
+ (NSDictionary*) abbreviationDictionary;

//Getting Arrays of Time Zones
+ (NSArray*) timeZoneArray;
- (NSArray*) timeZoneDetailArray;

#ifndef	NO_GNUSTEP
/* Returns an dictionary that maps abbreviations to the array
   containing all the time zone names that use the abbreviation. */
+ (NSDictionary*) abbreviationMap;
#endif

#ifndef	STRICT_OPENSTEP
+ (void) resetSystemTimeZone;
+ (NSTimeZone*) systemTimeZone;
+ (NSTimeZone*) timeZoneWithName: (NSString*)name data: (NSData*)data;
- (NSString*) abbreviation;
- (NSString*) abbreviationForDate: (NSDate*)aDate;
- (id) initWithName: (NSString*)name;
- (id) initWithName: (NSString*)name data: (NSData*)data;
- (BOOL) isDaylightSavingTime;
- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate;
- (BOOL) isEqualToTimeZone: (NSTimeZone*)aTimeZone;
- (NSString*) name;
- (int) secondsFromGMT;
- (int) secondsFromGMTForDate: (NSDate*)aDate;
#endif

#ifndef	STRICT_MACOS_X
- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date;
- (NSString*) timeZoneName;
#endif

/*
 * The next two methods are a problem ... they are present in both
 * OpenStep and MacOS-X, but return different types!
 * We resort to the MaxOS-X version.
 */
+ (NSTimeZone*) defaultTimeZone;
+ (NSTimeZone*) timeZoneWithAbbreviation: (NSString*)abbreviation;  
@end

#ifndef	STRICT_MACOS_X
@interface NSTimeZoneDetail : NSTimeZone
- (BOOL) isDaylightSavingTimeZone;
- (NSString*) timeZoneAbbreviation;
- (int) timeZoneSecondsFromGMT;
@end
#endif


@interface NSCalendarDate : NSDate
{
  NSTimeInterval	_seconds_since_ref;
  NSString		*_calendar_format;
  NSTimeZone		*_time_zone;
}

// Getting an NSCalendar Date
+ (id) calendarDate;
+ (id) dateWithString: (NSString*)description
       calendarFormat: (NSString*)format;
+ (id) dateWithString: (NSString*)description
       calendarFormat: (NSString*)format
	       locale: (NSDictionary*)dictionary;
+ (id) dateWithYear: (int)year
	      month: (unsigned int)month
	        day: (unsigned int)day
	       hour: (unsigned int)hour
	     minute: (unsigned int)minute
	     second: (unsigned int)second
	   timeZone: (NSTimeZone*)aTimeZone;

// Initializing an NSCalendar Date
- (id) initWithString: (NSString*)description;
- (id) initWithString: (NSString*)description
       calendarFormat: (NSString*)format;
- (id) initWithString: (NSString*)description
       calendarFormat: (NSString*)format
	       locale: (NSDictionary*)dictionary;
- (id) initWithYear: (int)year
	      month: (unsigned int)month
	        day: (unsigned int)day
	       hour: (unsigned int)hour
	     minute: (unsigned int)minute
	     second: (unsigned int)second
	   timeZone: (NSTimeZone*)aTimeZone;

// Retreiving Date Elements
- (int) dayOfCommonEra;
- (int) dayOfMonth;
- (int) dayOfWeek;
- (int) dayOfYear;
- (int) hourOfDay;
- (int) minuteOfHour;
- (int) monthOfYear;
- (int) secondOfMinute;
- (int) yearOfCommonEra;

// Providing Adjusted Dates
- (NSCalendarDate*) addYear: (int)year
		      month: (int)month
			day: (int)day
		       hour: (int)hour
		     minute: (int)minute
		     second: (int)second;

// Getting String Descriptions of Dates
- (NSString*) description;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				     locale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;

// Getting and Setting Calendar Formats
- (NSString*) calendarFormat;
- (void) setCalendarFormat: (NSString*)format;

// Getting and Setting Time Zones
- (void) setTimeZone: (NSTimeZone*)aTimeZone;
#ifndef	STRICT_OPENSTEP
- (NSTimeZone*) timeZone;
#endif
#ifndef	STRICT_MACOS_X
- (NSTimeZoneDetail*) timeZoneDetail;
#endif

@end


@interface NSCalendarDate (GregorianDate)

- (int) lastDayOfGregorianMonth: (int)month year: (int)year;
- (int) absoluteGregorianDay: (int)day month: (int)month year: (int)year;
- (void) gregorianDateFromAbsolute: (int)d
			       day: (int*)day
			     month: (int*)month
			      year: (int*)year;

@end

@interface NSCalendarDate (OPENSTEP)

- (NSCalendarDate*) dateByAddingYears: (int)years
			       months: (int)months
				 days: (int)days
				hours: (int)hours
			      minutes: (int)minutes
			      seconds: (int)seconds;

- (void) years: (int*)years
	months: (int*)months
          days: (int*)days
         hours: (int*)hours
       minutes: (int*)minutes
       seconds: (int*)seconds
     sinceDate: (NSDate*)date;
@end

#endif  /* __NSDate_h_GNUSTEP_BASE_INCLUDE*/
