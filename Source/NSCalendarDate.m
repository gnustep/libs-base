/* Implementation for NSCalendarDate for GNUstep
   Copyright (C) 1996, 1998 Free Software Foundation, Inc.

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

#include <config.h>
#include <math.h>
#include <objc/objc-api.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUserDefaults.h>
#include <base/behavior.h>

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

@interface NSCalendarDate (Private)

- (void)getYear: (int *)year month: (int *)month day: (int *)day
	   hour: (int *)hour minute: (int *)minute second: (int *)second;

@end

@implementation NSCalendarDate

+ (void) initialize
{
  if (self == [NSCalendarDate class])
    {
      [self setVersion: 1];
      behavior_class_add_class(self, [NSGDate class]);
    }
}

//
// Getting an NSCalendar Date
//
+ (id)calendarDate
{
  id	d = [[self alloc] init];

  return AUTORELEASE(d);
}

+ (id)dateWithString: (NSString *)description
      calendarFormat: (NSString *)format
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithString: description
					      calendarFormat: format];
  return AUTORELEASE(d);
}

+ (id)dateWithString: (NSString *)description
      calendarFormat: (NSString *)format
	      locale: (NSDictionary *)dictionary
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithString: description
					      calendarFormat: format
					      locale: dictionary];
  return AUTORELEASE(d);
}

+ (id)dateWithYear: (int)year
	     month: (unsigned int)month
	       day: (unsigned int)day
	      hour: (unsigned int)hour
	    minute: (unsigned int)minute
	    second: (unsigned int)second
	  timeZone: (NSTimeZone *)aTimeZone
{
  NSCalendarDate *d = [[NSCalendarDate alloc] initWithYear: year
					      month: month
					      day: day
					      hour: hour
					      minute: minute
					      second: second
					      timeZone: aTimeZone];
  return AUTORELEASE(d);
}

- (Class) classForPortCoder
{
  return [self class];
}

- replacementObjectForPortCoder: aRmc
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  [coder encodeValueOfObjCType: @encode(NSTimeInterval) at: &seconds_since_ref];
  [coder encodeObject: calendar_format];
  [coder encodeObject: time_zone];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(NSTimeInterval) at: &seconds_since_ref];
  [coder decodeValueOfObjCType: @encode(id) at: &calendar_format];
  [coder decodeValueOfObjCType: @encode(id) at: &time_zone];
  return self;
}

- (void) dealloc
{
  RELEASE(calendar_format);
  [super dealloc];
}

// Initializing an NSCalendar Date
- (id)initWithString: (NSString *)description
{
  // +++ What is the locale?
  return [self initWithString: description
	       calendarFormat: @"%Y-%m-%d %H:%M:%S %z"
	       locale: nil];
}

- (id)initWithString: (NSString *)description
      calendarFormat: (NSString *)format
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
- (id)initWithString: (NSString *)description
      calendarFormat: (NSString *)format
	      locale: (NSDictionary *)locale
{
  const char *d = [description cString];
  const char *f = [format cString];
  char *newf;
  int lf = strlen(f);
  BOOL mtag = NO, dtag = NO, ycent = NO;
  BOOL fullm = NO;
  char ms[80] = "", ds[80] = "", timez[80] = "", ampm[80] = "";
  int tznum = 0;
  int yd = 0, md = 0, dd = 0, hd = 0, mnd = 0, sd = 0;
  void *pntr[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int order;
  int yord = 0, mord = 0, dord = 0, hord = 0, mnord = 0, sord = 0, tzord = 0;
  int ampmord = 0;
  int i;
  NSTimeZone *tz;
  BOOL zoneByAbbreviation = YES;

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
  newf = objc_malloc(lf+1);
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
	    case 'B':
	      fullm = YES;   // Full month name
	    case 'b':
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

	      // the time zone abbreviation
	    case 'Z':
	      tzord = order;
	      ++order;
	      ++i;
	      newf[i] = 's';
	      pntr[tzord] = (void *)timez;
	      break;

	      // the time zone in numeric format
	    case 'z':
	      tzord = order;
	      ++order;
	      ++i;
	      newf[i] = 'd';
	      pntr[tzord] = (void *)&tznum;
	      zoneByAbbreviation = NO;
	      break;

	      // AM PM indicator
	    case 'p':
	      ampmord = order;
	      ++order;
	      ++i;
	      newf[i] = 's';
	      pntr[ampmord] = (void *)ampm;
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
  if (mtag)
    {
      int i;
      NSString *m = [NSString stringWithCString: ms];

      if (fullm)
	{
	  NSArray	*names = [locale objectForKey: NSMonthNameArray];

	  for (i = 0;i < 12; ++i)
	    if ([[names objectAtIndex: i] isEqual: m] == YES)
	      break;
	}
      else
	{
	  NSArray	*names = [locale objectForKey: NSShortMonthNameArray];

	  for (i = 0;i < 12; ++i)
	    if ([[names objectAtIndex: i] isEqual: m] == YES)
	      break;
	}
      md = i + 1;
    }

  // Possibly convert day from string to decimal number
  // +++ how do we take locale into account?
  if (dtag)
    {
    }

  // +++ We need to take 'am' and 'pm' into account
  if (ampmord)
    {
      // If its PM then we shift
      if ((ampm[0] == 'p') || (ampm[0] == 'P'))
	{
	  // 12pm is 12pm not 24pm
	  if (hd != 12)
	    hd += 12;
	}
    }

  // +++ then there is the time zone
  if (tzord)
    if (zoneByAbbreviation)
    {
      tz = [NSTimeZone timeZoneWithAbbreviation:
			 [NSString stringWithCString: timez]];
      if (!tz)
	tz = [NSTimeZone localTimeZone];
    }
    else
    {
      int tzm, tzh, sign;

      if (tznum < 0)
      {
	sign = -1;
	tznum = -tznum;
      }
      else
	sign = 1;
      tzm = tznum % 100;
      tzh = tznum / 100;
      tz = [NSTimeZone timeZoneForSecondsFromGMT: (tzh * 60 + tzm) * 60 * sign];
      if (!tz)
        tz = [NSTimeZone localTimeZone];
    }
  else
    tz = [NSTimeZone localTimeZone];

  free(newf);

  return [self initWithYear: yd month: md day: dd hour: hd
	       minute: mnd second: sd
	       timeZone: tz];
}

- (id)initWithYear: (int)year
	     month: (unsigned int)month
	       day: (unsigned int)day
	      hour: (unsigned int)hour
	    minute: (unsigned int)minute
	    second: (unsigned int)second
	  timeZone: (NSTimeZone *)aTimeZone
{
  int	a;
  int	c;
  NSTimeInterval s;

  a = [self absoluteGregorianDay: day month: month year: year];

  // Calculate date as GMT
  a -= GREGORIAN_REFERENCE;
  s = (double)a * 86400;
  s += hour * 3600;
  s += minute * 60;
  s += second;

  // Assign time zone detail
  time_zone = [aTimeZone
		timeZoneDetailForDate:
		  [NSDate dateWithTimeIntervalSinceReferenceDate: s]];

  // Adjust date so it is correct for time zone.
  s -= [time_zone timeZoneSecondsFromGMT];
  self = [self initWithTimeIntervalSinceReferenceDate: s];

  /* Now permit up to five cycles of adjustment to allow for daylight savings.
     NB. this depends on it being OK to call the
      [-initWithTimeIntervalSinceReferenceDate: ] method repeatedly! */

  for (c = 0; c < 5 && self != nil; c++)
    {
      int	y, m, d, h, mm, ss;
      NSTimeZoneDetail	*z;

      [self getYear: &y month: &m day: &d hour: &h minute: &mm second: &ss];
      if (y==year && m==month && d==day && h==hour && mm==minute && ss==second)
	return self;

      /* Has the time-zone detail changed?  If so - adjust time for it,
	 other wise -  try to adjust to the correct time. */
      z = [aTimeZone
		timeZoneDetailForDate:
		  [NSDate dateWithTimeIntervalSinceReferenceDate: s]];
      if (z != time_zone)
	{
	  NSTimeInterval	oldOffset;
	  NSTimeInterval	newOffset;

	  oldOffset = [time_zone timeZoneSecondsFromGMT];
	  time_zone = z;
	  newOffset = [time_zone timeZoneSecondsFromGMT];
	  s += newOffset - oldOffset;
	}
      else
	{
	  NSTimeInterval	move;

	  /* Do we need to go back or forwards in time?
	     Shift at most two hours - we know of no daylight savings time
	     which is an offset of more than two hourts */
	  if (y > year)
	    move = -7200.0;
	  else if (y < year)
	    move = +7200.0;
	  else if (m > month)
	    move = -7200.0;
	  else if (m < month)
	    move = +7200.0;
	  else if (d > day)
	    move = -7200.0;
	  else if (d < day)
	    move = +7200.0;
	  else if (h > hour || h < hour)
	    move = (hour - h)*3600.0;
	  else if (mm > minute || mm < minute)
	    move = (minute - mm)*60.0;
	  else
	    move = (second - ss);

	  s += move;
	}
      self = [self initWithTimeIntervalSinceReferenceDate: s];
    }
  return self;
}

// Default initializer
- (id)initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  seconds_since_ref = seconds;
  if (!calendar_format)
    calendar_format = @"%Y-%m-%d %H:%M:%S %z";
  if (!time_zone)
    time_zone = [[NSTimeZone localTimeZone] timeZoneDetailForDate: self];
  return self;
}

// Retreiving Date Elements
- (void)getYear: (int *)year month: (int *)month day: (int *)day
	   hour: (int *)hour minute: (int *)minute second: (int *)second
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
  int	d = [self dayOfCommonEra];

  /* The era started on a sunday.
     Did we always have a seven day week?
     Did we lose week days changing from Julian to Gregorian?
     AFAIK seven days a week is ok for all reasonable dates.  */
  d = d % 7;
  if (d < 0)
    d += 7;
  return d;
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
- (NSCalendarDate *)addYear: (int)year
		      month: (unsigned int)month
			day: (unsigned int)day
		       hour: (unsigned int)hour
		     minute: (unsigned int)minute
		     second: (unsigned int)second
{
  return [self dateByAddingYears: year
		          months: month
			    days: day
			   hours: hour
		         minutes: minute
		         seconds: second];
}

// Getting String Descriptions of Dates
- (NSString *)description
{
  return [self descriptionWithCalendarFormat: calendar_format
	       locale: nil];
}

- (NSString *)descriptionWithCalendarFormat: (NSString *)format
{
  return [self descriptionWithCalendarFormat: format
	       locale: nil];
}

#define UNIX_REFERENCE_INTERVAL -978307200.0
- (NSString *)descriptionWithCalendarFormat: (NSString *)format
				     locale: (NSDictionary *)locale
{
  char buf[1024];
  const char *f;
  int lf;
  BOOL mtag = NO, dtag = NO, ycent = NO;
  BOOL mname = NO, dname = NO;
  double s;
  int yd = 0, md = 0, mnd = 0, sd = 0, dom = -1, dow = -1, doy = -1;
  int hd = 0, nhd;
  int i, j, k, z;

  if (locale == nil)
    locale = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  if (format == nil)
    format = [locale objectForKey: NSTimeDateFormatString];

  // If the format is nil then return an empty string
  if (!format)
    return @"";

  f = [format cString];
  lf = strlen(f);

  [self getYear: &yd month: &md day: &dom hour: &hd minute: &mnd second: &sd];
  nhd = hd;

  // The strftime specifiers
  // %a   abbreviated weekday name according to locale
  // %A   full weekday name according to locale
  // %b   abbreviated month name according to locale
  // %B   full month name according to locale
  // %d   day of month as decimal number (leading zero)
  // %e   day of month as decimal number (leading space)
  // %F   milliseconds (000 to 999)
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
  // %z   time zone offset (HHMM)
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
		  NSArray	*months;
		  NSString	*name;

		  if (mname)
		    months = [locale objectForKey: NSShortMonthNameArray];
		  else
		    months = [locale objectForKey: NSMonthNameArray];
		  name = [months objectAtIndex: md-1];
		  if (name)
		    k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s",
		      [name cString]));
		  else
		    k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", md));
		}
	      else
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", md));
	      j += k;
	      break;

	    case 'd': 	// day of month
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", dom));
	      j += k;
	      break;

	    case 'e': 	// day of month
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%2d", dom));
	      j += k;
	      break;

	    case 'F': 	// milliseconds
	      s = ([self dayOfCommonEra] - GREGORIAN_REFERENCE) * 86400.0;
	      s -= (seconds_since_ref+[time_zone timeZoneSecondsFromGMT]);
	      s = abs(s);
	      s -= floor(s);
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%03d", (int)s*1000));
	      j += k;
	      break;

	    case 'j': 	// day of year
	      if (doy < 0) doy = [self dayOfYear];
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", doy));
	      j += k;
	      break;

	      // is it the week-day
	    case 'a':
	      dname = YES;
	    case 'A':
	      dtag = YES;   // Day is character string
	    case 'w':
	      {
		++i;
		if (dow < 0) dow = [self dayOfWeek];
		if (dtag)
		  {
		    NSArray	*days;
		    NSString	*name;

		    if (dname)
		      days = [locale objectForKey: NSShortWeekDayNameArray];
		    else
		      days = [locale objectForKey: NSWeekDayNameArray];
		    name = [days objectAtIndex: dow];
		    if (name)
		      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s",
			[name cString]));
		    else
		      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", dow));
		  }
		else
		  k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", dow));
		j += k;
	      }
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
	      {
		NSArray		*a = [locale objectForKey: NSAMPMDesignation];
		NSString	*ampm;

		++i;
		if (hd >= 12)
		  if ([a count] > 1)
		    ampm = [a objectAtIndex: 1];
		  else
		    ampm = @"pm";
		else
		  if ([a count] > 0)
		    ampm = [a objectAtIndex: 0];
		  else
		    ampm = @"am";
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), [ampm cString]));
		j += k;
	      }
	      break;

	      // is it the zone name
	    case 'Z':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s",
			  [[time_zone timeZoneAbbreviation] cString]));
	      j += k;
	      break;

	    case 'z':
	      ++i;
	      z = [time_zone timeZoneSecondsFromGMT];
	      if (z < 0) {
		z = -z;
		z /= 60;
	        k = VSPRINTF_LENGTH(sprintf(&(buf[j]),"-%02d%02d",z/60,z%60));
	      }
	      else {
		z /= 60;
	        k = VSPRINTF_LENGTH(sprintf(&(buf[j]),"+%02d%02d",z/60,z%60));
              }
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

- (id) copyWithZone: (NSZone*)zone
{
  NSCalendarDate	*newDate;

  if (NSShouldRetainWithZone(self, zone))
    {
      newDate = RETAIN(self);
    }
  else
    {
      newDate = (NSCalendarDate*)NSCopyObject(self, 0, zone);

      if (newDate)
	{
	  newDate->calendar_format = [calendar_format copyWithZone: zone];
	}
    }
  return newDate;
}

- (NSString *)descriptionWithLocale: (NSDictionary *)locale
{
  return [self descriptionWithCalendarFormat: calendar_format
	       locale: locale];
}

// Getting and Setting Calendar Formats
- (NSString *)calendarFormat
{
  return calendar_format;
}

- (void)setCalendarFormat: (NSString *)format
{
  RELEASE(calendar_format);
  calendar_format = [format copyWithZone: [self zone]];
}

// Getting and Setting Time Zones
- (void)setTimeZone: (NSTimeZone *)aTimeZone
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

- (int)lastDayOfGregorianMonth: (int)month year: (int)year
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

- (int)absoluteGregorianDay: (int)day month: (int)month year: (int)year
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

- (void)gregorianDateFromAbsolute: (int)d
			      day: (int *)day
			    month: (int *)month
			     year: (int *)year
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


@implementation NSCalendarDate (OPENSTEP)

- (NSCalendarDate *)dateByAddingYears: (int)years
			       months: (int)months
				 days: (int)days
			        hours: (int)hours
			      minutes: (int)minutes
			      seconds: (int)seconds
{
  int		i, year, month, day, hour, minute, second;

  [self getYear: &year
	  month: &month
	    day: &day
	   hour: &hour
	 minute: &minute
	 second: &second];

  second += seconds;
  minute += second/60;
  second %= 60;
  if (second < 0)
    {
      minute--;
      second += 60;
    }

  minute += minutes;
  hour += minute/60;
  minute %= 60;
  if (minute < 0)
    {
      hour--;
      minute += 60;
    }

  hour += hours;
  day += hour/24;
  hour %= 24;
  if (hour < 0)
    {
      day--;
      hour += 24;
    }

  day += days;
  if (day > 28)
    {
      i = [self lastDayOfGregorianMonth: month year: year];
      while (day > i)
	{
	  day -= i;
	  if (month < 12)
	    month++;
	  else
	    {
	      month = 1;
	      year++;
	    }
	  i = [self lastDayOfGregorianMonth: month year: year];
	}
    }
  else
    while (day < 1)
      {
        if (month == 1)
	  {
	    year--;
	    month = 12;
	  }
	else
          month--;
        day += [self lastDayOfGregorianMonth: month year: year];
      }

  month += months;
  while (month > 12)
    {
      year++;
      month -= 12;
    }
  while (month < 1)
    {
      year--;
      month += 12;
    }

  year += years;

  /*
   * Special case - we adjusted to the correct day for the month in the
   * starting date - but our month and year adjustment may have made that
   * invalid for the final month and year - in which case we may have to
   * advance to the next month.
   */
  if (day > 28 && day > [self lastDayOfGregorianMonth: month year: year])
    {
      day -= [self lastDayOfGregorianMonth: month year: year];
      month++;
      if (month > 12)
	year++;
    }

  return [NSCalendarDate dateWithYear: year
			        month: month
			          day: day
			         hour: hour
			       minute: minute
			       second: second
			     timeZone: nil];
}

- (void) years: (int*)years
	months: (int*)months
          days: (int*)days
         hours: (int*)hours
       minutes: (int*)minutes
       seconds: (int*)seconds
     sinceDate: (NSDate*)date
{
  NSCalendarDate	*start;
  NSCalendarDate	*end;
  NSCalendarDate	*tmp;
  int			diff;
  int			extra;
  int			sign;
  int			syear, smonth, sday, shour, sminute, ssecond;
  int			eyear, emonth, eday, ehour, eminute, esecond;

  /* FIXME What if the two dates are in different time zones?
    How about daylight savings time?
   */
  if ([date isKindOfClass: [NSCalendarDate class]])
    tmp = (NSCalendarDate*)RETAIN(date);
  else
    tmp = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:
		[date timeIntervalSinceReferenceDate]];

  end = (NSCalendarDate*)[self laterDate: tmp];
  if (end == self)
    {
      start = tmp;
      sign = 1;
    }
  else
    {
      start = self;
      sign = -1;
    }

  [start getYear: &syear
	   month: &smonth
	     day: &sday
	    hour: &shour
	  minute: &sminute
	  second: &ssecond];
  [end getYear: &eyear
	 month: &emonth
	   day: &eday
	  hour: &ehour
	minute: &eminute
	second: &esecond];

  /* Calculate year difference and leave any remaining months in 'extra' */
  diff = eyear - syear;
  extra = 0;
  if (emonth < smonth)
    {
      diff--;
      extra += 12;
    }
  if (years)
    *years = sign*diff;
  else
    extra += diff*12;

  /* Calculate month difference and leave any remaining days in 'extra' */
  diff = emonth - smonth + extra;
  extra = 0;
  if (eday < sday)
    {
      diff--;
      extra = [end lastDayOfGregorianMonth: smonth year: syear];
    }
  if (months)
    *months = sign*diff;
  else
    {
      while (diff--)
	{
	  int tmpmonth = emonth - diff - 1;
	  int tmpyear = eyear;

          while (tmpmonth < 1)
	    {
	      tmpmonth += 12;
	      tmpyear--;
	    }
          extra += [end lastDayOfGregorianMonth: tmpmonth year: tmpyear];
        }
    }

  /* Calculate day difference and leave any remaining hours in 'extra' */
  diff = eday - sday + extra;
  extra = 0;
  if (ehour < shour)
    {
      diff--;
      extra = 24;
    }
  if (days)
    *days = sign*diff;
  else
    extra += diff*24;

  /* Calculate hour difference and leave any remaining minutes in 'extra' */
  diff = ehour - shour + extra;
  extra = 0;
  if (eminute < sminute)
    {
      diff--;
      extra = 60;
    }
  if (hours)
    *hours = sign*diff;
  else
    extra += diff*60;

  /* Calculate minute difference and leave any remaining seconds in 'extra' */
  diff = eminute - sminute + extra;
  extra = 0;
  if (esecond < ssecond)
    {
      diff--;
      extra = 60;
    }
  if (minutes)
    *minutes = sign*diff;
  else
    extra += diff*60;

  diff = esecond - ssecond + extra;
  if (seconds)
    *seconds = sign*diff;

  RELEASE(tmp);
}

@end
