/* Implementation for NSCalendarDate for GNUstep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: October 1996

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

#include <gnustep/base/NSDate.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/NSException.h>

#ifndef __WIN32__
#include <time.h>
#endif /* !__WIN32__ */
#include <stdio.h>
#include <stdlib.h>
#ifndef __WIN32__
#include <sys/time.h>
#endif /* !__WIN32__ */

// Absolute Gregorian date for NSDate reference date Jan 01 2001
//
//  N = 1;                 // day of month
//  N = N + 0;             // days in prior months for year
//  N = N +                // days this year
//    + 365 * (year - 1)   // days in previous years ignoring leap days
//    + (year - 1)/4       // Julian leap days before this year...
//    - (year - 1)/100     // ...minus prior century years...
//    + (year - 1)/400     // ...plus prior years divisible by 400

#define GREGORIAN_REFERENCE 730486

//
// Short and long month names
// TODO: These should be localized for the language.
//
static id short_month[12] = {@"Jan",
			     @"Feb",
			     @"Mar",
			     @"Apr",
			     @"May",
			     @"Jun",
			     @"Jul",
			     @"Aug",
			     @"Sep",
			     @"Oct",
			     @"Nov",
			     @"Dec"};
static id long_month[12] = {@"January",
			    @"February",
			    @"March",
			    @"April",
			    @"May",
			    @"June",
			    @"July",
			    @"August",
			    @"September",
			    @"October",
			    @"November",
			    @"December"};

@implementation NSCalendarDate


//
// Getting an NSCalendar Date
//
+ (NSCalendarDate *)calendarDate
{
  return [[[self alloc] init] autorelease];
}

+ (NSCalendarDate *)dateWithString:(NSString *)description
		    calendarFormat:(NSString *)format
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithString: description
					      calendarFormat: format];
  return [d autorelease];
}

+ (NSCalendarDate *)dateWithString:(NSString *)description
		    calendarFormat:(NSString *)format
			    locale:(NSDictionary *)dictionary
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithString: description
					      calendarFormat: format
					      locale: dictionary];
  return [d autorelease];
}

+ (NSCalendarDate *)dateWithYear:(int)year
			   month:(unsigned int)month
			     day:(unsigned int)day
			    hour:(unsigned int)hour
			  minute:(unsigned int)minute
			  second:(unsigned int)second
			timeZone:(NSTimeZone *)aTimeZone
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithYear: year
					      month: month
					      day: day
					      hour: hour
					      minute: minute
					      second: second
					      timeZone: aTimeZone];
  return [d autorelease];
}

// Initializing an NSCalendar Date
- (id)initWithString:(NSString *)description
{
  // +++ What is the locale?
  return [self initWithString: description
	       calendarFormat: @"%Y-%m-%d %H:%M:%S %Z"
	       locale: nil];
}

- (id)initWithString:(NSString *)description
      calendarFormat:(NSString *)format
{
  // ++ What is the locale?
  return [self initWithString: description
	       calendarFormat: format
	       locale: nil];
}

//
// This function could possibly be written better
// but it works ok; currently ignores locale
// information and some specifiers.
//
- (id)initWithString:(NSString *)description
      calendarFormat:(NSString *)format
	      locale:(NSDictionary *)dictionary
{
  const char *d = [description cString];
  const char *f = [format cString];
  char *newf;
  int lf = strlen(f);
  BOOL mtag = NO, dtag = NO, ycent = NO;
  char ms[80] = "", ds[80] = "";
  int yd = 0, md = 0, dd = 0, hd = 0, mnd = 0, sd = 0;
  void *pntr[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int order;
  int yord = 0, mord = 0, dord = 0, hord = 0, mnord = 0, sord = 0;
  int i;

  // If either the string or format is nil then raise exception
  if (!description)
    [NSException raise: NSInvalidArgumentException
		 format: @"NSCalendar date description is nil"];
  if (!format)
    [NSException raise: NSInvalidArgumentException
		 format: @"NSCalendar date format is nil"];

  // The strftime specifiers
  // %a   abbreviated weekday name according to locale
  // %A   full weekday name according to locale
  // %b   abbreviated month name according to locale
  // %B   full month name according to locale
  // %d   day of month as decimal number
  // %H   hour as a decimal number using 24-hour clock
  // %I   hour as a decimal number using 12-hour clock
  // %j   day of year as a decimal number
  // %m   month as decimal number
  // %M   minute as decimal number
  // %p   'am' or 'pm'
  // %S   second as decimal number
  // %U   week of the current year as decimal number (Sunday first day)
  // %W   week of the current year as decimal number (Monday first day)
  // %w   day of the week as decimal number (Sunday = 0)
  // %y   year as a decimal number without century
  // %Y   year as a decimal number with century
  // %Z   time zone
  // %%   literal % character

  // Find the order of date elements
  // and translate format string into scanf ready string
  order = 1;
  newf = malloc(lf+1);
  for (i = 0;i < lf; ++i)
    {
      newf[i] = f[i];

      // Only care about a format specifier
      if (f[i] == '%')
	{
	  // check the character that comes after
	  switch (f[i+1])
	    {
	      // skip literal %
	    case '%':
	      ++i;
	      newf[i] = f[i];
	      break;

	      // is it the year
	    case 'Y':
	      ycent = YES;
	    case 'y':
	      yord = order;
	      ++order;
	      ++i;
	      newf[i] = 'd';
	      pntr[yord] = (void *)&yd;
	      break;

	      // is it the month
	    case 'b':
	    case 'B':
	      mtag = YES;    // Month is character string
	    case 'm':
	      mord = order;
	      ++order;
	      ++i;
	      if (mtag)
		{
		  newf[i] = 's';
		  pntr[mord] = (void *)ms;
		}
	      else
		{
		  newf[i] = 'd';
		  pntr[mord] = (void *)&md;
		}
	      break;

	      // is it the day
	    case 'a':
	    case 'A':
	      dtag = YES;   // Day is character string
	    case 'd':
	    case 'j':
	    case 'w':
	      dord = order;
	      ++order;
	      ++i;
	      if (dtag)
		{
		  newf[i] = 's';
		  pntr[dord] = (void *)ds;
		}
	      else
		{
		  newf[i] = 'd';
		  pntr[dord] = (void *)&dd;
		}
	      break;

	      // is it the hour
	    case 'H':
	    case 'I':
	      hord = order;
	      ++order;
	      ++i;
	      newf[i] = 'd';
	      pntr[hord] = (void *)&hd;
	      break;

	      // is it the minute
	    case 'M':
	      mnord = order;
	      ++order;
	      ++i;
	      newf[i] = 'd';
	      pntr[mnord] = (void *)&mnd;
	      break;

	      // is it the second
	    case 'S':
	      sord = order;
	      ++order;
	      ++i;
	      newf[i] = 'd';
	      pntr[sord] = (void *)&sd;
	      break;

	      // Anything else is an invalid format
	    default:
	      free(newf);
	      [NSException raise: NSInvalidArgumentException
			   format: @"Invalid NSCalendar date, specifier %c not recognized in format %s", f[i+1], f];
	    }
	}
    }
  newf[lf] = '\0';

  // Have sscanf parse and retrieve the values for us
  if (order != 1)
    sscanf(d, newf, pntr[1], pntr[2], pntr[3], pntr[4], pntr[5], pntr[6],
	   pntr[7], pntr[8], pntr[9]);
  else
    // nothing in the string?
    ;

  // Put century on year if need be
  // +++ How do we be year 2000 compliant?
  if (!ycent)
    yd += 1900;

  // Possibly convert month from string to decimal number
  // +++ how do we take locale into account?
  if (mtag)
    {
    }

  // Possibly convert day from string to decimal number
  // +++ how do we take locale into account?
  if (dtag)
    {
    }

  // +++ We need to take 'am' and 'pm' into account

  // +++ then there is the time zone

  free(newf);

  return [self initWithYear: yd month: md day: dd hour: hd
	       minute: mnd second: sd 
	       timeZone: [NSTimeZone localTimeZone]];
}

- (id)initWithYear:(int)year
	     month:(unsigned int)month
	       day:(unsigned int)day
	      hour:(unsigned int)hour
	    minute:(unsigned int)minute
	    second:(unsigned int)second
	  timeZone:(NSTimeZone *)aTimeZone
{
  int a;
  NSTimeInterval s;

  a = [self absoluteGregorianDay: day month: month year: year];

  a -= GREGORIAN_REFERENCE;
  s = (double)a * 86400;
  s += hour * 3600;
  s += minute * 60;
  s += second;

  // Assign time zone detail
  time_zone = [aTimeZone
		timeZoneDetailForDate:
		  [NSDate dateWithTimeIntervalSinceReferenceDate: s]];

  return [self initWithTimeIntervalSinceReferenceDate: s];
}

// Default initializer
- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{
  [super initWithTimeIntervalSinceReferenceDate: seconds];
  if (!calendar_format)
    calendar_format = @"%Y-%m-%d %H:%M:%S %Z";
  if (!time_zone)
    time_zone = [[NSTimeZone localTimeZone] timeZoneDetailForDate: self];
  return self;
}

// Retreiving Date Elements
- (void)getYear:(int *)year month:(int *)month day:(int *)day
	   hour:(int *)hour minute:(int *)minute second:(int *)second
{
  int h, m;
  double a, b, c, d = [self dayOfCommonEra];

  // Calculate year, month, and day
  [self gregorianDateFromAbsolute: d day: day month: month year: year];

  // Calculate hour, minute, and seconds
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]));
  b = a / 3600;
  *hour = (int)b;
  h = *hour;
  h = h * 3600;
  b = a - h;
  b = b / 60;
  *minute = (int)b;
  m = *minute;
  m = m * 60;
  c = a - h - m;
  *second = (int)c;
}

- (int)dayOfCommonEra
{
  double a;
  int r;

  // Get reference date in terms of days
  a = (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]) / 86400.0;
  // Offset by Gregorian reference
  a += GREGORIAN_REFERENCE;
  r = (int)a;

  return r;
}

- (int)dayOfMonth
{
  int m, d, y;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra] 
	day: &d month: &m year: &y];

  return d;
}

- (int)dayOfWeek
{
  return 0;
}

- (int)dayOfYear
{
  int m, d, y, days, i;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];
  days = d;
  for (i = m - 1;  i > 0; i--) // days in prior months this year
    days = days + [self lastDayOfGregorianMonth: i year: y];

  return days;
}

- (int)hourOfDay
{
  int h;
  double a, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]));
  a = a / 3600;
  h = (int)a;

  // There is a small chance of getting
  // it right at the stroke of midnight
  if (h == 24)
    h = 0;

  return h;
}

- (int)minuteOfHour
{
  int h, m;
  double a, b, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]));
  b = a / 3600;
  h = (int)b;
  h = h * 3600;
  b = a - h;
  b = b / 60;
  m = (int)b;

  return m;
}

- (int)monthOfYear
{
  int m, d, y;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];

  return m;
}

- (int)secondOfMinute
{
  int h, m, s;
  double a, b, c, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]));
  b = a / 3600;
  h = (int)b;
  h = h * 3600;
  b = a - h;
  b = b / 60;
  m = (int)b;
  m = m * 60;
  c = a - h - m;
  s = (int)c;

  return s;
}

- (int)yearOfCommonEra
{
  int m, d, y;
  int a;

  // Get reference date in terms of days
  a = (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]) / 86400;
  // Offset by Gregorian reference
  a += GREGORIAN_REFERENCE;
  [self gregorianDateFromAbsolute: a day: &d month: &m year: &y];

  return y;
}

// Providing Adjusted Dates
- (NSCalendarDate *)addYear:(int)year
		      month:(unsigned int)month
			day:(unsigned int)day
		       hour:(unsigned int)hour
		     minute:(unsigned int)minute
		     second:(unsigned int)second
{
  return self;
}

// Getting String Descriptions of Dates
- (NSString *)description
{
  return [self descriptionWithCalendarFormat: calendar_format
	       locale: nil];
}

- (NSString *)descriptionWithCalendarFormat:(NSString *)format
{
  return [self descriptionWithCalendarFormat: format
	       locale: nil];
}

#define UNIX_REFERENCE_INTERVAL -978307200.0
- (NSString *)descriptionWithCalendarFormat:(NSString *)format
				     locale:(NSDictionary *)locale
{
  char buf[1024];
  const char *f = [format cString];
  int lf = strlen(f);
  BOOL mtag = NO, dtag = NO, ycent = NO;
  BOOL mname = NO;
  int yd = 0, md = 0, dd = 0, hd = 0, mnd = 0, sd = 0;
  int nhd;
  int i, j, k;

  // If the format is nil then return an empty string
  if (!format)
    return @"";

  [self getYear: &yd month: &md day: &dd hour: &hd minute: &mnd second: &sd];
  nhd = hd;

  // The strftime specifiers
  // %a   abbreviated weekday name according to locale
  // %A   full weekday name according to locale
  // %b   abbreviated month name according to locale
  // %B   full month name according to locale
  // %d   day of month as decimal number
  // %H   hour as a decimal number using 24-hour clock
  // %I   hour as a decimal number using 12-hour clock
  // %j   day of year as a decimal number
  // %m   month as decimal number
  // %M   minute as decimal number
  // %p   'am' or 'pm'
  // %S   second as decimal number
  // %U   week of the current year as decimal number (Sunday first day)
  // %W   week of the current year as decimal number (Monday first day)
  // %w   day of the week as decimal number (Sunday = 0)
  // %y   year as a decimal number without century
  // %Y   year as a decimal number with century
  // %Z   time zone
  // %%   literal % character

  // Find the order of date elements
  // and translate format string into printf ready string
  j = 0;
  for (i = 0;i < lf; ++i)
    {
      // Only care about a format specifier
      if (f[i] == '%')
	{
	  // check the character that comes after
	  switch (f[i+1])
	    {
	      // literal %
	    case '%':
	      ++i;
	      buf[j] = f[i];
	      ++j;
	      break;

	      // is it the year
	    case 'Y':
	      ycent = YES;
	    case 'y':
	      ++i;
	      if (ycent)
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%04d", yd));
	      else
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", (yd - 1900)));
	      j += k;
	      break;

	      // is it the month
	    case 'b':
	      mname = YES;
	    case 'B':
	      mtag = YES;    // Month is character string
	    case 'm':
	      ++i;
	      if (mtag)
		{
		  // +++ Translate to locale character string
		  if (mname)
		    k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s", [short_month[md-1] cString]));
		  else
		    k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s", [long_month[md-1] cString]));
		}
	      else
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", md));
	      j += k;
	      break;

	      // is it the day
	    case 'a':
	    case 'A':
	      dtag = YES;   // Day is character string
	    case 'd':
	    case 'j':
	    case 'w':
	      ++i;
	      if (dtag)
		{
		  // +++ Translate to locale character string
		  /* Was: k = sprintf(&(buf[j]), ""); */
		  buf[j] = '\0';
		  k = 0;
		}
	      else
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", dd));
	      j += k;
	      break;

	      // is it the hour
	    case 'I':
	      nhd = hd % 12;  // 12 hour clock
	      if (hd == 12)
		nhd = 12;     // 12pm not 0pm
	    case 'H':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", nhd));
	      j += k;
	      break;

	      // is it the minute
	    case 'M':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", mnd));
	      j += k;
	      break;

	      // is it the second
	    case 'S':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", sd));
	      j += k;
	      break;

	      // Is it the am/pm indicator
	    case 'p':
	      ++i;
	      if (hd >= 12)
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "PM"));
	      else
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "AM"));
	      j += k;
	      break;

	      // is it the zone name
	    case 'Z':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s",
			  [[time_zone timeZoneAbbreviation] cStringNoCopy]));
	      j += k;
	      break;

	      // Anything else is unknown so just copy
	    default:
	      buf[j] = f[i];
	      ++i;
	      ++j;
	      buf[j] = f[i];
	      ++i;
	      ++j;
	      break;
	    }
	}
      else
	{
	  buf[j] = f[i];
	  ++j;
	}
    }
  buf[j] = '\0';

  return [NSString stringWithCString: buf];
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
  return [self descriptionWithCalendarFormat: calendar_format
	       locale: locale];
}

// Getting and Setting Calendar Formats
- (NSString *)calendarFormat
{
  return calendar_format;
}

- (void)setCalendarFormat:(NSString *)format
{
  calendar_format = format;
}

// Getting and Setting Time Zones
- (void)setTimeZone:(NSTimeZone *)aTimeZone
{
  time_zone = [aTimeZone timeZoneDetailForDate: self];
}

- (NSTimeZoneDetail *)timeZoneDetail
{
  return time_zone;
}

@end

//
// Routines for manipulating Gregorian dates
//
// The following code is based upon the source code in
// ``Calendrical Calculations'' by Nachum Dershowitz and Edward M. Reingold,
// Software---Practice & Experience, vol. 20, no. 9 (September, 1990),
// pp. 899--928.
//

@implementation NSCalendarDate (GregorianDate)

- (int)lastDayOfGregorianMonth:(int)month year:(int)year
{
  switch (month) {
  case 2:
    if ((((year % 4) == 0) && ((year % 100) != 0))
        || ((year % 400) == 0))
      return 29;
    else
      return 28;
  case 4:
  case 6:
  case 9:
  case 11: return 30;
  default: return 31;
  }
}

- (int)absoluteGregorianDay:(int)day month:(int)month year:(int)year
{
  int m, N;

  N = day;   // day of month
  for (m = month - 1;  m > 0; m--) // days in prior months this year
      N = N + [self lastDayOfGregorianMonth: m year: year];
  return 
    (N                    // days this year
     + 365 * (year - 1)   // days in previous years ignoring leap days
     + (year - 1)/4       // Julian leap days before this year...
     - (year - 1)/100     // ...minus prior century years...
     + (year - 1)/400);   // ...plus prior years divisible by 400
}

- (void)gregorianDateFromAbsolute:(int)d
			      day:(int *)day
			    month:(int *)month
			     year:(int *)year
{
  // Search forward year by year from approximate year
  *year = d/366;
  while (d >= [self absoluteGregorianDay: 1 month: 1 year: (*year)+1])
    (*year)++;
  // Search forward month by month from January
  (*month) = 1;
  while (d > [self absoluteGregorianDay: 
		   [self lastDayOfGregorianMonth: *month year: *year]
		   month: *month year: *year])
    (*month)++;
  *day = d - [self absoluteGregorianDay: 1 month: *month year: *year] + 1;
}

@end
