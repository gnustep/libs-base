/* Interface for NSCalendarDate for GNUStep
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

#ifndef __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE
#define __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSDate.h>

@class	NSTimeZone;
@class	NSTimeZoneDetail;

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
       calendarFormat: (NSString*)fmt
	       locale: (NSDictionary*)locale;
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

#ifndef	NO_GNUSTEP
void
GSBreakTime(NSTimeInterval when, int *year, int *month, int *day, int *hour,
  int *minute, int *second, int *mil);
NSTimeInterval
GSTime(int day, int month, int year, int hour, int minute, int second, int mil);
#endif

#endif  /* __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE*/
