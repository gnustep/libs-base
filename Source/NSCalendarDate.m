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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <math.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSTimeZone.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <base/behavior.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "GSUserDefaults.h"

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

static inline int
lastDayOfGregorianMonth(int month, int year)
{
  switch (month)
    {
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

static inline int
absoluteGregorianDay(int day, int month, int year)
{
  int m, N;

  N = day;   // day of month
  for (m = month - 1;  m > 0; m--) // days in prior months this year
    N = N + lastDayOfGregorianMonth(m, year);
  return
    (N                    // days this year
     + 365 * (year - 1)   // days in previous years ignoring leap days
     + (year - 1)/4       // Julian leap days before this year...
     - (year - 1)/100     // ...minus prior century years...
     + (year - 1)/400);   // ...plus prior years divisible by 400
}

/*
 * External - so NSDate can use it.
 */
NSTimeInterval
GSTime(int day, int month, int year, int h, int m, int s, int mil)
{
  NSTimeInterval	a;

  a = (NSTimeInterval)absoluteGregorianDay(day, month, year);

  // Calculate date as GMT
  a -= GREGORIAN_REFERENCE;
  a = (NSTimeInterval)a * 86400;
  a += h * 3600;
  a += m * 60;
  a += s;
  a += mil/1000.0;
  return a;
}

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
+ (id) calendarDate
{
  id	d = [[self alloc] init];

  return AUTORELEASE(d);
}

+ (id) dateWithString: (NSString *)description
       calendarFormat: (NSString *)format
{
  NSCalendarDate *d = [[self alloc] initWithString: description
				    calendarFormat: format];
  return AUTORELEASE(d);
}

+ (id) dateWithString: (NSString *)description
       calendarFormat: (NSString *)format
	       locale: (NSDictionary *)dictionary
{
  NSCalendarDate *d = [[self alloc] initWithString: description
				    calendarFormat: format
				    locale: dictionary];
  return AUTORELEASE(d);
}

+ (id) dateWithYear: (int)year
	      month: (unsigned int)month
	        day: (unsigned int)day
	       hour: (unsigned int)hour
	     minute: (unsigned int)minute
	     second: (unsigned int)second
	   timeZone: (NSTimeZone *)aTimeZone
{
  NSCalendarDate *d = [[self alloc] initWithYear: year
				    month: month
				    day: day
				    hour: hour
				    minute: minute
				    second: second
				    timeZone: aTimeZone];
  return AUTORELEASE(d);
}

- (id) addTimeInterval: (NSTimeInterval)seconds
{
  id newObj = [[self class] dateWithTimeIntervalSinceReferenceDate:
     [self timeIntervalSinceReferenceDate] + seconds];
	
  [newObj setTimeZone: [self timeZoneDetail]];

  return newObj;
}

- (Class) classForCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aRmc
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  [coder encodeValueOfObjCType: @encode(NSTimeInterval)
			    at: &_seconds_since_ref];
  [coder encodeObject: _calendar_format];
  [coder encodeObject: _time_zone];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(NSTimeInterval)
			    at: &_seconds_since_ref];
  [coder decodeValueOfObjCType: @encode(id) at: &_calendar_format];
  [coder decodeValueOfObjCType: @encode(id) at: &_time_zone];
  return self;
}

- (void) dealloc
{
  RELEASE(_calendar_format);
  RELEASE(_time_zone);
  [super dealloc];
}

/*
 * Initializing an NSCalendar Date
 */
- (id) initWithString: (NSString *)description
{
  // +++ What is the locale?
  return [self initWithString: description
	       calendarFormat: @"%Y-%m-%d %H:%M:%S %z"
		       locale: nil];
}

- (id) initWithString: (NSString *)description
       calendarFormat: (NSString *)format
{
  // ++ What is the locale?
  return [self initWithString: description
	       calendarFormat: format
		       locale: nil];
}

/*
 * read up to the specified number of characters, terminating at a non-digit
 * except for leading whitespace characters.
 */
static inline int getDigits(const char *from, char *to, int limit)
{
  int	i = 0;
  int	j = 0;
  BOOL	foundDigit = NO;

  while (i < limit)
    {
      if (isdigit(from[i]))
	{
	  to[j++] = from[i];
	  foundDigit = YES;
	}
      else if (isspace(from[i]))
	{
	  if (foundDigit == YES)
	    {
	      break;
	    }
	}
      else
	{
	  break;
	}
      i++;
    }
  to[j] = '\0';
  return i;
}

#define	hadY	1
#define	hadM	2
#define	hadD	4
#define	hadh	8
#define	hadm	16
#define	hads	32
#define	hadw	64

- (id) initWithString: (NSString *)description 
       calendarFormat: (NSString *)fmt
               locale: (NSDictionary *)locale
{
  // If description does not match this format exactly, this method returns nil 
  if ([description length] == 0)
    {
      // Autorelease self because it isn't done by the calling function
      // [[NSCalendarDate alloc] initWithString:calendarFormat:locale:];
      AUTORELEASE(self);
      return nil;
    }
  else
    {
      int		year = 0, month = 1, day = 1;
      int		hour = 0, min = 0, sec = 0;
      NSTimeZone	*tz = [NSTimeZone localTimeZone];
      BOOL		ampm = NO;
      BOOL		twelveHrClock = NO; 
      int		julianWeeks = -1, weekStartsMonday = 0, dayOfWeek = -1;
      const char	*source = [description cString];
      unsigned		sourceLen = strlen(source);
      unichar		*format;
      unsigned		formatLen;
      unsigned		formatIdx = 0;
      unsigned		sourceIdx = 0;
      char		tmpStr[20];
      int		tmpIdx;
      unsigned		had = 0;
      int		pos;
      BOOL		hadPercent = NO;
      NSString		*dForm;
      NSString		*tForm;
      NSString		*TForm;
      NSMutableData	*fd;
      BOOL		changedFormat = NO;
      
      if (locale == nil)
	{
	  locale = GSUserDefaultsDictionaryRepresentation();
	}
      if (fmt == nil)
	{
	  fmt = [locale objectForKey: NSTimeDateFormatString];
	  if (fmt == nil)
	    fmt = @"";
	}

      TForm = [locale objectForKey: NSTimeDateFormatString];
      if (TForm == nil)
	TForm = @"%X %x";
      dForm = [locale objectForKey: NSShortDateFormatString];
      if (dForm == nil)
	dForm = @"%y-%m-%d";
      tForm = [locale objectForKey: NSTimeFormatString];
      if (tForm == nil)
	tForm = @"%H-%M-%S";

      /*
       * Get format into a buffer, leaving room for expansion in case it has
       * escapes that need to be converted.
       */
      formatLen = [fmt length];
      fd = [[NSMutableData alloc]
	initWithLength: (formatLen + 32) * sizeof(unichar)];
      format = (unichar*)[fd mutableBytes];
      [fmt getCharacters: format];

      /*
       * Expand any sequences to their basic components.
       */
      for (pos = 0; pos < formatLen; pos++)
	{
	  unichar	c = format[pos];

	  if (c == '%')
	    {
	      if (hadPercent == YES)
		{
		  hadPercent = NO;
		}
	      else
		{
		  hadPercent = YES;
		}
	    }
	  else
	    {
	      if (hadPercent == YES)
		{
		  NSString	*sub = nil;

		  if (c == 'c')
		    {
		      sub = TForm;
		    }
		  else if (c == 'R')
		    {
		      sub = @"%H:%M";
		    }
		  else if (c == 'r')
		    {
		      sub = @"%I:%M:%S %p";
		    }
		  else if (c == 'X')
		    {
		      sub = tForm;
		    }
		  else if (c == 'x')
		    {
		      sub = dForm;
		    }

		  if (sub != nil)
		    {
		      unsigned	sLen = [sub length];
		      unsigned	i;

		      if (sLen > 2)
			{
			  [fd setLength:
			    (formatLen + sLen - 2) * sizeof(unichar)];
			  format = (unichar*)[fd mutableBytes];
			  for (i = formatLen-1; i > pos; i--)
			    {
			      format[i+sLen-2] = format[i];
			    }
			}
		      else
			{
			  for (i = pos+1; i < formatLen; i++)
			    {
			      format[i+sLen-2] = format[i];
			    }
			  [fd setLength:
			    (formatLen + sLen - 2) * sizeof(unichar)];
			  format = (unichar*)[fd mutableBytes];
			}
		      [sub getCharacters: &format[pos-1]];
		      formatLen += sLen - 2;
		      changedFormat = YES;
		      pos -= 2;	// Re-parse the newly substituted data.
		    }
		}
	      hadPercent = NO;
	    }
	}

      /*
       * Set up calendar format.
       */
      if (changedFormat == YES)
	{
	  fmt = [NSString stringWithCharacters: format length: formatLen];
	}
      ASSIGN(_calendar_format, fmt);

      //
      // WARNING:
      //   %F, does NOT work.
      //    and the underlying call has granularity to the second.
      //   -Most locale stuff is dubious at best.
      //   -Long day and month names depend on a non-alpha character after the
      //    last digit to work.
      //
      // The strftime specifiers as used by OpenStep + %U.
      //
      // %%   literal % character
      // %a   abbreviated weekday name according to locale
      // %A   full weekday name according to locale
      // %b   abbreviated month name according to locale
      // %B   full month name according to locale
      // %c   same as '%X %x'
      // %d   day of month as decimal number
      // %e   same as %d without leading zero (you get a leading space instead)
      // %F   milliseconds as a decimal number
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
      // %x   date with date representation for locale
      // %X   time with time representation for locale
      // %y   year as a decimal number without century 
      // %Y   year as a decimal number with century
      // %z   time zone offset in hours and minutes from GMT (HHMM)
      // %Z   time zone abbreviation

      while (formatIdx < formatLen)
	{
	  if (format[formatIdx] != '%')
	    {
	      // If it's not a format specifier, ignore it.
	      if (isspace(format[formatIdx]))
		{
		  // Skip any amount of white space.
		  while (source[sourceIdx] != 0 && isspace(source[sourceIdx]))
		    {
		      sourceIdx++;
		    }
		}
	      else
		{
		  if (sourceIdx < sourceLen)
		    {
		      if (source[sourceIdx] != format[formatIdx])
			{
			  NSLog(@"Expected literal '%c' but got '%c'",
			    format[formatIdx], source[sourceIdx]);
			}
		      sourceIdx++;
		    }
		}
	    }
	  else
	    {
	      // Skip '%'
	      formatIdx++;

	      switch (format[formatIdx])
		{
		  case '%':
		    // skip literal %
		    if (sourceIdx < sourceLen)
		      {
			if (source[sourceIdx] != '%')
			  {
			    NSLog(@"Expected literal '%' but got '%c'",
			      source[sourceIdx]);
			  }
			sourceIdx++;
		      }
		    break;

		  case 'a':
		    // Are Short names three chars in all locales?????
		    tmpStr[0] = toupper(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[1] = tolower(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[2] = tolower(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[3] = '\0';
		    {
		      NSString	*currDay;
		      NSArray	*dayNames;

		      currDay = [NSString stringWithCString: tmpStr];
		      dayNames = [locale objectForKey: NSShortWeekDayNameArray];
		      for (tmpIdx = 0; tmpIdx < 7; tmpIdx++)
			{
			  if ([[dayNames objectAtIndex: tmpIdx] isEqual:
			    currDay] == YES)
			    {
			      break;
			    }
			}
		      dayOfWeek = tmpIdx; 
		      had |= hadw;
		    }
		    break;

		  case 'A':
		    for (tmpIdx = sourceIdx; tmpIdx < sourceLen; tmpIdx++)
		      {
			if (isalpha(source[tmpIdx]))
			  {
			    tmpStr[tmpIdx - sourceIdx] = source[tmpIdx];
			  }
			else
			  {
			    break;
			  }
		      }
		    tmpStr[tmpIdx - sourceIdx] = '\0';
		    sourceIdx += tmpIdx - sourceIdx;
		    {
		      NSString	*currDay;
		      NSArray	*dayNames;

		      currDay = [NSString stringWithCString: tmpStr];
		      dayNames = [locale objectForKey: NSWeekDayNameArray];
		      for (tmpIdx = 0; tmpIdx < 7; tmpIdx++)
			{
			  if ([[dayNames objectAtIndex: tmpIdx] isEqual:
			    currDay] == YES)
			    {
			      break;
			    }
			}
		      dayOfWeek = tmpIdx;
		      had |= hadw;
		    }
		    break;

		  case 'b':
		    // Are Short names three chars in all locales?????
		    tmpStr[0] = toupper(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[1] = tolower(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[2] = tolower(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[3] = '\0';
		    {
		      NSString	*currMonth;
		      NSArray	*monthNames;

		      currMonth = [NSString stringWithCString: tmpStr];
		      monthNames = [locale objectForKey: NSShortMonthNameArray];

		      for (tmpIdx = 0; tmpIdx < 12; tmpIdx++)
			{
			  if ([[monthNames objectAtIndex: tmpIdx]
				    isEqual: currMonth] == YES)
			    {
			      break;
			    }
			}
		      month = tmpIdx+1;
		      had |= hadM;
		    }
		    break;

		  case 'B':
		    for (tmpIdx = sourceIdx; tmpIdx < sourceLen; tmpIdx++)
		      {
			if (isalpha(source[tmpIdx]))
			  {
			    tmpStr[tmpIdx - sourceIdx] = source[tmpIdx];
			  }
			else
			  {
			    break;
			  }
		      }
		    tmpStr[tmpIdx - sourceIdx] = '\0';
		    sourceIdx += tmpIdx - sourceIdx;
		    {
		      NSString	*currMonth;
		      NSArray	*monthNames;

		      currMonth = [NSString stringWithCString: tmpStr];
		      monthNames = [locale objectForKey: NSMonthNameArray];

		      for (tmpIdx = 0; tmpIdx < 12; tmpIdx++)
			{
			  if ([[monthNames objectAtIndex: tmpIdx]
				    isEqual: currMonth] == YES)
			    {
			      break;
			    }
			}
		      month = tmpIdx+1;
		      had |= hadM;
		    }
		    break;

		  case 'd': // fall through
		  case 'e':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    day = atoi(tmpStr);
		    had |= hadD;
		    break;

		  case 'F':
		    NSLog(@"%F format ignored when creating date");
		    break;

		  case 'I': // fall through
		    twelveHrClock = YES;
		  case 'H':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    hour = atoi(tmpStr);
		    had |= hadh;
		    break;

		  case 'j':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 3);
		    day = atoi(tmpStr);
		    had |= hadD;
		    break;

		  case 'm':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    month = atoi(tmpStr);
		    had |= hadM;
		    break;

		  case 'M':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    min = atoi(tmpStr);
		    had |= hadm;
		    break;

		  case 'p':
		    // Questionable assumption that all am/pm indicators are 2
		    // characters and in upper case....
		    tmpStr[0] = toupper(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[1] = toupper(source[sourceIdx]);
		    if (sourceIdx < sourceLen)
		      sourceIdx++;
		    tmpStr[2] = '\0';
		    {
		      NSString	*currAMPM;
		      NSArray	*amPMNames;

		      currAMPM = [NSString stringWithCString: tmpStr];
		      amPMNames = [locale objectForKey: NSAMPMDesignation];

		      /*
		       * The time addition is handled below because this
		       * indicator only modifies the time on a 12hour clock.
		       */
		      if ([[amPMNames objectAtIndex: 1] isEqual:
			currAMPM] == YES)
			{
			  ampm = YES;
			}
		    }
		    break;

		  case 'S':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    sec = atoi(tmpStr);
		    had |= hads;
		    break;

		  case 'w':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 1);
		    dayOfWeek = atoi(tmpStr);
		    had |= hadw;
		    break;

		  case 'W': // Fall through
		    weekStartsMonday = 1;
		  case 'U':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 1);
		    julianWeeks = atoi(tmpStr);
		    break;

		    //	case 'x':
		    //	break;

		    //	case 'X':
		    //	break;

		  case 'y':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 2);
		    year = atoi(tmpStr);
		    if (year >= 70)
		      {
			year += 1900;
		      }
		    else
		      {
			year += 2000;
		      }
		    had |= hadY;
		    break;

		  case 'Y':
		    sourceIdx += getDigits(&source[sourceIdx], tmpStr, 4);
		    year = atoi(tmpStr);
		    had |= hadY;
		    break;

		  case 'z':
		    {
		      int	sign = 1;
		      int	zone;

		      if (source[sourceIdx] == '+')
			{
			  sourceIdx++;
			}
		      else if (source[sourceIdx] == '-')
			{
			  sign = -1;
			  sourceIdx++;
			}
		      sourceIdx += getDigits(&source[sourceIdx], tmpStr, 4);
		      zone = atoi(tmpStr) * sign;

		      if ((tz = [NSTimeZone timeZoneForSecondsFromGMT: 
			(zone / 100 * 60 + (zone % 100)) * 60]) == nil)
			{
			  tz = [NSTimeZone localTimeZone];
			}
		    }
		    break;

		  case 'Z':
		    for (tmpIdx = sourceIdx; tmpIdx < sourceLen; tmpIdx++)
		      {
			if (isalpha(source[tmpIdx]) || source[tmpIdx] == '-'
			  || source[tmpIdx] == '+')
			  {
			    tmpStr[tmpIdx - sourceIdx] = source[tmpIdx];
			  }
			else
			  {
			    break;
			  }
		      }
		    tmpStr[tmpIdx - sourceIdx] = '\0';
		    sourceIdx += tmpIdx - sourceIdx;
		    {
		      NSString	*z = [NSString stringWithCString: tmpStr];

		      tz = [NSTimeZone timeZoneWithName: z];
		      if (tz == nil)
			{
			  tz = [NSTimeZone timeZoneWithAbbreviation: z];
			}
		      if (tz == nil)
			{
			  tz = [NSTimeZone localTimeZone];
			}
		    }
		    break;

		  default:
		    [NSException raise: NSInvalidArgumentException
				format: @"Invalid NSCalendar date, "
			@"specifier %c not recognized in format %@",
			format[formatIdx], fmt];
		}
	    } 
	  formatIdx++;
	}
      RELEASE(fd);

      if (tz == nil)
	{
	  tz = [NSTimeZone localTimeZone];
	}

      if (twelveHrClock == YES)
	{
	  if (ampm == YES && hour != 12)
	    {
	      hour += 12;
	    }
	}

      if (julianWeeks != -1)
	{
	  NSTimeZone		*gmtZone;
	  NSCalendarDate	*d;
	  int			currDay;

	  gmtZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];

	  if ((had & (hadY|hadw)) != (hadY|hadw))
	    {
	      NSCalendarDate	*now = [NSCalendarDate  date];

	      [now setTimeZone: gmtZone];
	      if ((had | hadY) == 0)
		{
		  year = [now yearOfCommonEra];
		  had |= hadY;
		}
	      if ((had | hadw) == 0)
		{
		  dayOfWeek = [now dayOfWeek];
		  had |= hadw;
		}
	    }

	  d  = [NSCalendarDate dateWithYear: year
				      month: 1
					day: 1
				       hour: 0
				     minute: 0
				     second: 0
				   timeZone: gmtZone];
	  currDay = [d dayOfWeek];

	  /*
	   * The julian weeks are either sunday relative or monday relative
	   * but all of the day of week specifiers are sunday relative.
	   * This means that if no day of week specifier was used the week
	   * starts on monday.
	   */
	  if (dayOfWeek == -1)
	    {
	      if (weekStartsMonday)
		{
		  dayOfWeek = 1;
		}
	      else
		{
		  dayOfWeek = 0;
		}
	    }
	  day = dayOfWeek + (julianWeeks * 7 - (currDay - 1));
	  had |= hadD;
	}

      /*
       * Use current date/time information for anything missing.
       */
      if ((had & (hadY|hadM|hadD|hadh|hadm|hads))
	!= (hadY|hadM|hadD|hadh|hadm|hads))
	{
	  NSCalendarDate	*now = [NSCalendarDate  date];
	  int			Y, M, D, h, m, s;

	  [now setTimeZone: tz];
	  [now getYear: &Y month: &M day: &D hour: &h minute: &m second: &s];
	  if ((had & hadY) == 0)
	    year = Y;
	  if ((had & hadM) == 0)
	    month = M;
	  if ((had & hadD) == 0)
	    day = D;
	  if ((had & hadh) == 0)
	    hour = h;
	  if ((had & hadm) == 0)
	    min = m;
	  if ((had & hads) == 0)
	    sec = s;
	}

      return [self initWithYear: year
			  month: month
			    day: day
			   hour: hour
			 minute: min
			 second: sec
		       timeZone: tz];
    }
}


- (id) initWithYear: (int)year
	      month: (unsigned int)month
	        day: (unsigned int)day
	       hour: (unsigned int)hour
	     minute: (unsigned int)minute
	     second: (unsigned int)second
	   timeZone: (NSTimeZone *)aTimeZone
{
  int			c;
  NSDate		*d;
  NSTimeInterval	s;
  NSTimeInterval	oldOffset;

  // Calculate date as GMT
  s = GSTime(day, month, year, hour, minute, second, 0);

  // Assign time zone detail
  if (aTimeZone == nil)
    {
      _time_zone = RETAIN([NSTimeZone localTimeZone]);
    }
  else
    {
      _time_zone = RETAIN(aTimeZone);
    }
  d = [NSDate dateWithTimeIntervalSinceReferenceDate: s];

  // Adjust date so it is correct for time zone.
  oldOffset = [_time_zone secondsFromGMTForDate: d];
  s -= oldOffset;
  self = [self initWithTimeIntervalSinceReferenceDate: s];

  /* Now permit up to five cycles of adjustment to allow for daylight savings.
     NB. this depends on it being OK to call the
      [-initWithTimeIntervalSinceReferenceDate: ] method repeatedly! */

  for (c = 0; c < 5 && self != nil; c++)
    {
      int	y, m, d, h, mm, ss;
      NSTimeInterval	newOffset;

      [self getYear: &y month: &m day: &d hour: &h minute: &mm second: &ss];
      if (y==year && m==month && d==day && h==hour && mm==minute && ss==second)
	return self;

      /* Has the time-zone offset changed?  If so - adjust time for it,
	 other wise -  try to adjust to the correct time. */
      newOffset = [_time_zone secondsFromGMTForDate: self];
      if (newOffset != oldOffset)
	{
	  s += newOffset - oldOffset;
	  oldOffset = newOffset;
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
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  _seconds_since_ref = seconds;
  if (_calendar_format == nil)
    _calendar_format = @"%Y-%m-%d %H:%M:%S %z";
  if (_time_zone == nil)
    _time_zone = RETAIN([NSTimeZone localTimeZone]);
  return self;
}

// Retreiving Date Elements
- (void) getYear: (int *)year
	   month: (int *)month
	     day: (int *)day
	    hour: (int *)hour
	  minute: (int *)minute
	  second: (int *)second
{
  int h, m;
  double a, b, c, d = [self dayOfCommonEra];

  // Calculate year, month, and day
  [self gregorianDateFromAbsolute: d day: day month: month year: year];

  // Calculate hour, minute, and seconds
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (_seconds_since_ref+[_time_zone secondsFromGMTForDate: self]));
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

- (int) dayOfCommonEra
{
  double a;
  int r;

  // Get reference date in terms of days
  a = (_seconds_since_ref+[_time_zone secondsFromGMTForDate: self]) / 86400.0;
  // Offset by Gregorian reference
  a += GREGORIAN_REFERENCE;
  r = (int)a;

  return r;
}

- (int) dayOfMonth
{
  int m, d, y;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];

  return d;
}

- (int) dayOfWeek
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

- (int) dayOfYear
{
  int m, d, y, days, i;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];
  days = d;
  for (i = m - 1;  i > 0; i--) // days in prior months this year
    days = days + lastDayOfGregorianMonth(i, y);

  return days;
}

- (int) hourOfDay
{
  int h;
  double a, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (_seconds_since_ref+[_time_zone secondsFromGMTForDate: self]));
  a = a / 3600;
  h = (int)a;

  // There is a small chance of getting
  // it right at the stroke of midnight
  if (h == 24)
    h = 0;

  return h;
}

- (int) minuteOfHour
{
  int h, m;
  double a, b, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (_seconds_since_ref+[_time_zone secondsFromGMTForDate: self]));
  b = a / 3600;
  h = (int)b;
  h = h * 3600;
  b = a - h;
  b = b / 60;
  m = (int)b;

  return m;
}

- (int) monthOfYear
{
  int m, d, y;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];

  return m;
}

- (int) secondOfMinute
{
  int h, m, s;
  double a, b, c, d = [self dayOfCommonEra];
  d -= GREGORIAN_REFERENCE;
  d *= 86400;
  a = abs(d - (_seconds_since_ref+[_time_zone secondsFromGMTForDate: self]));
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

- (int) yearOfCommonEra
{
  int m, d, y;

  [self gregorianDateFromAbsolute: [self dayOfCommonEra]
	day: &d month: &m year: &y];

  return y;
}

// Providing Adjusted Dates
- (NSCalendarDate*) addYear: (int)year
		      month: (int)month
			day: (int)day
		       hour: (int)hour
		     minute: (int)minute
		     second: (int)second
{
  return [self dateByAddingYears: year
		          months: month
			    days: day
			   hours: hour
		         minutes: minute
		         seconds: second];
}

// Getting String Descriptions of Dates
- (NSString*) description
{
  return [self descriptionWithCalendarFormat: _calendar_format locale: nil];
}

- (NSString*) descriptionWithCalendarFormat: (NSString *)format
{
  return [self descriptionWithCalendarFormat: format locale: nil];
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
    locale = GSUserDefaultsDictionaryRepresentation();
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
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%02d", yd % 100));
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
	      s -= (_seconds_since_ref
		+ [_time_zone secondsFromGMTForDate: self]);
	      s = fabs(s);
	      s -= floor(s);
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%03d", (int)(s*1000)));
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
		      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%01d", dow));
		  }
		else
		  k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%01d", dow));
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
		  {
		    if ([a count] > 1)
		      ampm = [a objectAtIndex: 1];
		    else
		      ampm = @"pm";
		  }
		else
		  {
		    if ([a count] > 0)
		      ampm = [a objectAtIndex: 0];
		    else
		      ampm = @"am";
		  }
		k = VSPRINTF_LENGTH(sprintf(&(buf[j]), [ampm cString]));
		j += k;
	      }
	      break;

	      // is it the zone name
	    case 'Z':
	      ++i;
	      k = VSPRINTF_LENGTH(sprintf(&(buf[j]), "%s",
			  [[_time_zone abbreviationForDate: self] cString]));
	      j += k;
	      break;

	    case 'z':
	      ++i;
	      z = [_time_zone secondsFromGMTForDate: self];
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
	  newDate->_calendar_format = [_calendar_format copyWithZone: zone];
	  newDate->_time_zone = RETAIN(_time_zone);
	}
    }
  return newDate;
}

- (NSString*) descriptionWithLocale: (NSDictionary *)locale
{
  return [self descriptionWithCalendarFormat: _calendar_format locale: locale];
}

// Getting and Setting Calendar Formats
- (NSString*) calendarFormat
{
  return _calendar_format;
}

- (void) setCalendarFormat: (NSString *)format
{
  RELEASE(_calendar_format);
  _calendar_format = [format copyWithZone: [self zone]];
}

// Getting and Setting Time Zones
- (void) setTimeZone: (NSTimeZone *)aTimeZone
{
  ASSIGN(_time_zone, aTimeZone);
}

- (NSTimeZone*) timeZone
{
  return _time_zone;
}

- (NSTimeZoneDetail*) timeZoneDetail
{
  NSTimeZoneDetail	*detail = [_time_zone timeZoneDetailForDate: self];
  return detail;
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

- (int) lastDayOfGregorianMonth: (int)month year: (int)year
{
  return lastDayOfGregorianMonth(month, year);
}

- (int) absoluteGregorianDay: (int)day month: (int)month year: (int)year
{
  return absoluteGregorianDay(day, month, year);
}

- (void) gregorianDateFromAbsolute: (int)d
			       day: (int *)day
			     month: (int *)month
			      year: (int *)year
{
  // Search forward year by year from approximate year
  *year = d/366;
  while (d >= absoluteGregorianDay(1, 1, (*year)+1))
    (*year)++;
  // Search forward month by month from January
  (*month) = 1;
  while (d > absoluteGregorianDay(lastDayOfGregorianMonth(*month, *year),
    *month, *year))
    (*month)++;
  *day = d - absoluteGregorianDay(1, *month, *year) + 1;
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
			     timeZone: [self timeZoneDetail]];
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
          extra += lastDayOfGregorianMonth(tmpmonth, tmpyear);
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
