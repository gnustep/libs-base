/* Implementation for NSDate for GNUStep
   Copyright (C) 1995, 1996, 1997, 1998 Free Software Foundation, Inc.

   Written by:  Jeremy Bettis <jeremy@hksys.com>
   Rewritten by:  Scott Christley <scottc@net-community.com>
   Date: March 1995
   Modifications by: Richard Frith-Macdonald <richard@brainstorm.co.uk>

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
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSScanner.h>
#include <base/preface.h>
#include <base/behavior.h>
#include <base/fast.x>
#if HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

/* The number of seconds between 1/1/2001 and 1/1/1970 = -978307200. */
/* This number comes from:
-(((31 years * 365 days) + 8 days for leap years) =total number of days
  * 24 hours
  * 60 minutes
  * 60 seconds)
  This ignores leap-seconds. */
#define UNIX_REFERENCE_INTERVAL -978307200.0

/* I hope 100,000 years is distant enough. */
#define DISTANT_YEARS 100000.0
#define DISTANT_FUTURE	(DISTANT_YEARS * 365.0 * 24 * 60 * 60)
#define DISTANT_PAST	(-DISTANT_FUTURE)



static BOOL	debug = NO;
static Class	abstractClass = nil;
static Class	concreteClass = nil;
static Class	calendarClass = nil;

@interface	GSDateSingle : NSGDate
@end

@interface	GSDatePast : GSDateSingle
@end

@interface	GSDateFuture : GSDateSingle
@end

static NSDate	*_distantPast = nil;
static NSDate	*_distantFuture = nil;


static NSString*
findInArray(NSArray *array, unsigned pos, NSString *str)
{
  unsigned	index;
  unsigned	limit = [array count];

  for (index = pos; index < limit; index++)
    {
      NSString	*item;

      item = [array objectAtIndex: index];
      if ([str caseInsensitiveCompare: item] == NSOrderedSame)
	return item;
    }
  return nil;
}

static inline NSTimeInterval
otherTime(NSDate* other)
{
  Class	c = fastClass(other);

  if (c == concreteClass || c == calendarClass)
    return ((NSGDate*)other)->_seconds_since_ref;
  else
    return [other timeIntervalSinceReferenceDate];
}

NSTimeInterval
GSTimeNow()
{
#if !defined(__MINGW__)
  volatile NSTimeInterval interval;
  struct timeval tp;

  interval = UNIX_REFERENCE_INTERVAL;
  gettimeofday (&tp, NULL);
  interval += tp.tv_sec;
  interval += (double)tp.tv_usec / 1000000.0;
  return interval;
#else
  SYSTEMTIME sys_time;
  NSTimeInterval t;
#if 0
  NSCalendarDate *d;

  // Get the system time
  GetLocalTime(&sys_time);

  // Use an NSCalendar object to make it easier
  d = [NSCalendarDate alloc];
  [d initWithYear: sys_time.wYear
     month: sys_time.wMonth
     day: sys_time.wDay
     hour: sys_time.wHour
     minute: sys_time.wMinute
     second: sys_time.wSecond
     timeZone: [NSTimeZone localTimeZone]];
  t = otherTime(d);
  RELEASE(d);
#else
  /*
   * Get current GMT time, convert to NSTimeInterval since reference date,
   */
  GetSystemTime(&sys_time);
  t = GSTime(sys_time.eDay, sys_time.wMonth, sys_time.wYear,
    sys_time.wHour, sys_time.wMinute, sys_time.wSecond); 
#endif
  return t + sys_time.wMilliseconds / 1000.0;
#endif /* __MINGW__ */
}

/* The implementation of NSDate. */

@implementation NSDate

+ (void) initialize
{
  if (self == [NSDate class])
    {
      [self setVersion: 1];
      abstractClass = self;
      concreteClass = [NSGDate class];
      calendarClass = [NSCalendarDate class];
    }
}

+ (id) alloc
{
  if (self == abstractClass)
    return NSAllocateObject(concreteClass, 0, NSDefaultMallocZone());
  else
    return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    return NSAllocateObject(concreteClass, 0, z);
  else
    return NSAllocateObject(self, 0, z);
}

+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return GSTimeNow();
}

// Allocation and initializing

+ (id) date
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
	initWithTimeIntervalSinceReferenceDate: GSTimeNow()]);
}

+ (id) dateWithNaturalLanguageString: (NSString*)string
{
  return [self dateWithNaturalLanguageString: string
				      locale: nil];
}

+ (id) dateWithNaturalLanguageString: (NSString*)string
                              locale: (NSDictionary*)locale
{
  NSCharacterSet	*ws;
  NSCharacterSet	*digits;
  NSScanner		*scanner;
  NSString		*tmp;
  NSString		*dto;
  NSArray		*ymw;
  NSMutableArray	*words;
  unsigned		index;
  unsigned		length;
  NSCalendarDate	*theDate;
  BOOL			hadHour = NO;
  BOOL			hadMinute = NO;
  BOOL			hadSecond = NO;
  BOOL			hadDay = NO;
  BOOL			hadMonth = NO;
  BOOL			hadYear = NO;
  BOOL			hadWeekDay = NO;
  int			weekDay = 0;
  int			dayOfWeek = 0;
  int			modMonth = 0;
  int			modYear = 0;
  int			modDay = 0;
  int			D, M, Y;
  int			h = 12;
  int			m = 0;
  int			s = 0;
  unsigned		dtoIndex;

  if (locale == nil)
    locale = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];

  ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  digits = [NSCharacterSet decimalDigitCharacterSet];
  scanner = [NSScanner scannerWithString: string];
  words = [NSMutableArray arrayWithCapacity: 10];

  theDate = (NSCalendarDate*)[calendarClass date];
  Y = [theDate yearOfCommonEra];
  M = [theDate monthOfYear];
  D = [theDate dayOfMonth];
  dayOfWeek = [theDate dayOfWeek];

  [scanner scanCharactersFromSet: ws intoString: 0];
  while ([scanner scanUpToCharactersFromSet: ws intoString: &tmp] == YES)
    {
      [words addObject: tmp];
      [scanner scanCharactersFromSet: ws intoString: 0];
    }

  /*
   *	Scan the array for day specifications and remove them.
   */
  if (hadDay == NO)
    {
      NSString	*tdd = [locale objectForKey: NSThisDayDesignations];
      NSString	*ndd = [locale objectForKey: NSNextDayDesignations];
      NSString	*pdd = [locale objectForKey: NSPriorDayDesignations];
      NSString	*nndd = [locale objectForKey: NSNextNextDayDesignations];

      for (index = 0; hadDay == NO && index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  if ([tmp caseInsensitiveCompare: tdd] == NSOrderedSame)
	    {
	      hadDay = YES;
	    }
	  else if ([tmp caseInsensitiveCompare: ndd] == NSOrderedSame)
	    {
	      modDay++;
	      hadDay = YES;
	    }
	  else if ([tmp caseInsensitiveCompare: nndd] == NSOrderedSame)
	    {
	      modDay += 2;
	      hadDay = YES;
	    }
	  else if ([tmp caseInsensitiveCompare: pdd] == NSOrderedSame)
	    {
	      modDay--;
	      hadDay = YES;
	    }
	  if (hadDay)
	    {
	      hadMonth = YES;
	      hadYear = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for month specifications and remove them.
   */
  if (hadMonth == NO)
    {
      NSArray	*lm = [locale objectForKey: NSMonthNameArray];
      NSArray	*sm = [locale objectForKey: NSShortMonthNameArray];

      for (index = 0; hadMonth == NO && index < [words count]; index++)
	{
	  NSString	*mname;

	  tmp = [words objectAtIndex: index];

	  if ((mname = findInArray(lm, 0, tmp)) != nil)
	    {
	      modMonth += M - [lm indexOfObjectIdenticalTo: mname] - 1;
	      hadMonth = YES;
	    }
	  else if ((mname = findInArray(sm, 0, tmp)) != nil)
	    {
	      modMonth += M - [sm indexOfObjectIdenticalTo: mname] - 1;
	      hadMonth = YES;
	    }

	  if (mname != nil)
	    {
	      hadMonth = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for weekday specifications and remove them.
   */
  if (hadWeekDay == NO)
    {
      NSArray	*lw = [locale objectForKey: NSWeekDayNameArray];
      NSArray	*sw = [locale objectForKey: NSShortWeekDayNameArray];

      for (index = 0; hadWeekDay == NO && index < [words count]; index++)
	{
	  NSString	*dname;

	  tmp = [words objectAtIndex: index];

	  if ((dname = findInArray(lw, 0, tmp)) != nil)
	    {
	      weekDay = [lw indexOfObjectIdenticalTo: dname];
	    }
	  else if ((dname = findInArray(sw, 0, tmp)) != nil)
	    {
	      weekDay = [sw indexOfObjectIdenticalTo: dname];
	    }

	  if (dname != nil)
	    {
	      hadWeekDay = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for year month week modifiers and remove them.
   *	Going by the documentation, these modifiers adjust the date by
   *	plus or minus a week, month, or year.
   */
  ymw = [locale objectForKey: NSYearMonthWeekDesignations];
  if (ymw != nil && [ymw count] > 0)
    {
      unsigned	c = [ymw count];
      NSString	*yname = [ymw objectAtIndex: 0];
      NSString	*mname = c > 1 ? [ymw objectAtIndex: 1] : nil;
      NSArray	*early = [locale objectForKey: NSEarlierTimeDesignations];
      NSArray	*later = [locale objectForKey: NSLaterTimeDesignations];

      for (index = 0; index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  /*
           *	See if the current word is a year, month, or week.
	   */
	  if (findInArray(ymw, 0, tmp))
	    {
	      BOOL	hadAdjective = NO;
	      int	adjective = 0;
	      NSString	*adj = nil;

	      /*
	       *	See if there is a prefix adjective
	       */
	      if (index > 0)
		{
		  adj = [words objectAtIndex: index - 1];

		  if (findInArray(early, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = -1;
		    }
		  else if (findInArray(later, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = 1;
		    }
		  if (hadAdjective)
		    {
		      [words removeObjectAtIndex: --index];
		    }
		}
	      /*
	       *	See if there is a prefix adjective
	       */
	      if (hadAdjective == NO && index < [words count] - 1)
		{
		  NSString	*adj = [words objectAtIndex: index + 1];

		  if (findInArray(early, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = -1;
		    }
		  else if (findInArray(later, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = 1;
		    }
		  if (hadAdjective)
		    {
		      [words removeObjectAtIndex: index];
		    }
		}
	      /*
	       *	Record the adjective information.
	       */
	      if (hadAdjective)
		{
		  if ([tmp caseInsensitiveCompare: yname] == NSOrderedSame)
		    {
		      modYear += adjective;
		      hadYear = YES;
		    }
		  else if ([tmp caseInsensitiveCompare: mname] == NSOrderedSame)
		    {
		      modMonth += adjective;
		      hadMonth = YES;
		    }
		  else
		    {
		      if (hadWeekDay)
			{
			  modDay += weekDay - dayOfWeek;
			}
		      modDay += 7*adjective;
		      hadDay = YES;
		      hadMonth = YES;
		      hadYear = YES;
		    }
		}
	      /*
	       *	Remove from list of words.
	       */
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /* Scan for hour of the day */
  if (hadHour == NO)
    {
      NSArray	*hours = [locale objectForKey: NSHourNameDesignations];
      unsigned	hLimit = [hours count];
      unsigned	hIndex;

      for (index = 0; hadHour == NO && index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  for (hIndex = 0; hadHour == NO && hIndex < hLimit; hIndex++)
	    {
	      NSArray	*names;

	      names = [hours objectAtIndex: hIndex];
	      if (findInArray(names, 1, tmp) != nil)
		{
		  h = [[names objectAtIndex: 0] intValue];
		  hadHour = YES;
		  hadMinute = YES;
		  hadSecond = YES;
		}
	    }
	}
    }

  /*
   *	Now re-scan the string for numeric information.
   */

  dto = [locale objectForKey: NSDateTimeOrdering];
  if (dto == nil)
    {
      if (debug)
	NSLog(@"no NSDateTimeOrdering - default to DMYH.\n");
      dto = @"DMYH";
    }
  length = [dto length];
  if (length > 4)
    {
      if (debug)
	NSLog(@"too many characters in NSDateTimeOrdering - truncating.\n");
      length = 4;
    }

  dtoIndex = 0;
  scanner = [NSScanner scannerWithString: string];
  [scanner scanUpToCharactersFromSet: digits intoString: 0];
  while ([scanner scanCharactersFromSet: digits intoString: &tmp] == YES)
    {
      int	num = [tmp intValue];

      if ([scanner scanUpToCharactersFromSet: digits intoString: &tmp] == NO)
	{
	  tmp = nil;
	}
      /*
       *	Numbers separated by colons are a time specification.
       */
      if (tmp && ([tmp characterAtIndex: 0] == (unichar)':'))
	{
	  BOOL	done = NO;

	  do
	    {
	      if (hadHour == NO)
		{
		  if (num > 23)
		    {
		      if (debug)
			NSLog(@"hour (%d) too large - ignored.\n", num);
		      else
			return nil;
		    }
		  else
		    {
		      h = num;
		      m = 0;
		      s = 0;
		      hadHour = YES;
		    }
		}
	      else if (hadMinute == NO)
		{
		  if (num > 59)
		    {
		      if (debug)
			NSLog(@"minute (%d) too large - ignored.\n", num);
		      else
			return nil;
		    }
		  else
		    {
		      m = num;
		      s = 0;
		      hadMinute = YES;
		    }
		}
	      else if (hadSecond == NO)
		{
		  if (num > 59)
		    {
		      if (debug)
			NSLog(@"second (%d) too large - ignored.\n", num);
		      else
			return nil;
		    }
		  else
		    {
		      s = num;
		      hadSecond = YES;
		    }
		}
	      else
		{
		  if (debug)
		    NSLog(@"odd time spec - excess numbers ignored.\n");
		}

	      done = YES;
	      if (tmp && ([tmp characterAtIndex: 0] == (unichar)':'))
		{
		  if ([scanner scanCharactersFromSet: digits intoString: &tmp])
		    {
		      num = [tmp intValue];
		      done = NO;
		      if ([scanner scanUpToCharactersFromSet: digits
						  intoString: &tmp] == NO)
			{
			  tmp = nil;
			}
		    }
		}
	    }
	  while (done == NO);
	}
      else
	{
	  BOOL	mustSkip = YES;

	  while ((dtoIndex < [dto length]) && (mustSkip == YES))
	    {
	      switch ([dto characterAtIndex: dtoIndex])
		{
		  case 'D':
		    if (hadDay)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'M':
		    if (hadMonth)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'Y':
		    if (hadYear)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'H':
		    if (hadHour)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  default:
		    if (debug)
		      NSLog(@"odd char (unicode %d) in NSDateTimeOrdering.\n",
			    [dto characterAtIndex: dtoIndex]);
		    dtoIndex++;
		    break;
		}
	    }
	  if (dtoIndex >= [dto length])
	    {
	      if (debug)
		NSLog(@"odd date specification - excess numbers ignored.\n");
	      break;
	    }
	  switch ([dto characterAtIndex: dtoIndex])
	    {
	      case 'D':
		if (num < 1)
		  {
		    if (debug)
		      NSLog(@"day (0) too small - ignored.\n");
		    else
		      return nil;
		  }
		else if (num > 31)
		  {
		    if (debug)
		      NSLog(@"day (%d) too large - ignored.\n", num);
		    else
		      return nil;
		  }
		else
		  {
		    D = num;
		    hadDay = YES;
		  }
		break;
	      case 'M':
		if (num < 1)
		  {
		    if (debug)
		      NSLog(@"month (0) too small - ignored.\n");
		    else
		      return nil;
		  }
		else if (num > 12)
		  {
		    if (debug)
		      NSLog(@"month (%d) too large - ignored.\n", num);
		    else
		      return nil;
		  }
		else
		  {
		    M = num;
		    hadMonth = YES;
		  }
		break;
	      case 'Y':
		if (num < 100)
		  {
		    if (num < 70)
		      {
			Y = num + 2000;
		      }
		    else
		      {
			Y = num + 1900;
		      }
		    if (debug)
		      NSLog(@"year (%d) adjusted to %d.\n", num, Y);
		  }
		else
		  {
		    Y = num;
		  }
		hadYear = YES;
		break;
	      case 'H':
		{
		  BOOL	shouldIgnore = NO;

		  /*
		   *	Check the next text to see if it is an am/pm
		   *	designation.
		   */
		  if (tmp)
		    {
		      NSArray	*ampm;
		      NSString	*mod;

		      ampm = [locale objectForKey: NSAMPMDesignation];
		      mod = findInArray(ampm, 0, tmp);
		      if (mod)
			{
			  if (num > 11)
			    {
			      if (debug)
				NSLog(@"hour (%d) too large - ignored.\n",
				      num);
			      else
				return nil;
			      shouldIgnore = YES;
			    }
			  else if (mod == [ampm objectAtIndex: 1])
			    {
			      num += 12;
			    }
			}
		    }
		  if (shouldIgnore == NO)
		    {
		      if (num > 23)
			{
			  if (debug)
			    NSLog(@"hour (%d) too large - ignored.\n", num);
			  else
			    return nil;
			}
		      else
			{
			  hadHour = YES;
			  h = num;
			}
		    }
		  break;
		}
	      default:
		if (debug)
		  NSLog(@"unexpected char (unicode%d) in NSDateTimeOrdering.\n",
		    [dto characterAtIndex: dtoIndex]);
		break;
	    }
	}
    }

  /*
   *	If we had no date or time information - we give up, otherwise
   *	we can use reasonable defaults for any missing info.
   *	Missing date => today
   *	Missing time => 12: 00
   *	If we had a week/month/year modifier without a day, we assume today.
   *	If we had a day name without any more day detail - adjust to that
   *	day this week.
   */
  if (hadDay == NO && hadWeekDay == YES)
    {
      modDay += weekDay - dayOfWeek;
      hadDay = YES;
    }
  if (hadDay == NO && hadHour == NO)
    {
      if (modDay == NO && modMonth == NO && modYear == NO)
	{
	  return nil;
	}
    }

  /*
   *	Build a calendar date we can adjust easily.
   */
  theDate = [calendarClass dateWithYear: Y
				   month: M
				     day: D
				    hour: h
				  minute: m
				  second: s
				timeZone: [NSTimeZone defaultTimeZone]];

  /*
   *	Adjust the date by year month or days if necessary.
   */
  if (modYear || modMonth || modDay)
    {
      theDate = [theDate dateByAddingYears: modYear
				    months: modMonth
				      days: modDay
				     hours: 0
				   minutes: 0
				   seconds: 0];
    }
  if (hadWeekDay && [theDate dayOfWeek] != weekDay)
    {
      if (debug)
	NSLog(@"Date resulted in wrong day of week.\n");
      return nil;
    }
  return [self dateWithTimeIntervalSinceReferenceDate:
		otherTime(theDate)];
}

+ (id) dateWithString: (NSString*)description
{
  return AUTORELEASE([[self alloc] initWithString: description]);
}

+ (id) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceNow: seconds]);
}

+ (id)dateWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate:
		       UNIX_REFERENCE_INTERVAL + seconds]);
}

+ (id) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate: seconds]);
}

+ (id) distantFuture
{
  if (_distantFuture == nil)
    return [GSDateFuture allocWithZone: 0];
  return _distantFuture;
}

+ (id) distantPast
{
  if (_distantPast == nil)
    return [GSDatePast allocWithZone: 0];
  return _distantPast;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject(self, 0, zone);
}

- (Class) classForPortCoder
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return abstractClass;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aRmc
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  NSTimeInterval	interval = [self timeIntervalSinceReferenceDate];

  [coder encodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
}

- (id) initWithCoder: (NSCoder*)coder
{
  NSTimeInterval	interval;
  id			o;

  [coder decodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
  o = [[concreteClass alloc] initWithTimeIntervalSinceReferenceDate: interval];
  [self release];
  return o;
}

- (id) init
{
  return [self initWithTimeIntervalSinceReferenceDate: GSTimeNow()];
}

- (id) initWithString: (NSString*)description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSCalendarDate	*d = [calendarClass alloc];

  d = [d initWithString: description];
  self = [self initWithTimeIntervalSinceReferenceDate: otherTime(d)];
  RELEASE(d);
  return self;
}

- (id) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		  sinceDate: (NSDate*)anotherDate;
{
  // Get the other date's time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate:
	       otherTime(anotherDate) + secsToBeAdded];
}

- (id) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
{
  // Get the current time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate:
    GSTimeNow() + secsToBeAdded];
}

- (id)initWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
  return [self initWithTimeIntervalSinceReferenceDate:
    UNIX_REFERENCE_INTERVAL + seconds];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  [self subclassResponsibility: _cmd];
  return self;
}

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone
{
  NSCalendarDate *d = [calendarClass alloc];
  [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  [d setCalendarFormat: formatString];
  [d setTimeZone: timeZone];
  return AUTORELEASE(d);
}

// Representing dates

- (NSString*) description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];
  [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  s = [d description];
  RELEASE(d);
  return s;
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
				     locale: (NSDictionary*)l
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];
  id f;

  [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  if (!format)
    f = [d calendarFormat];
  else
    f = format;
  if (aTimeZone)
    [d setTimeZone: aTimeZone];

  s = [d descriptionWithCalendarFormat: f locale: l];
  RELEASE(d);
  return s;
}

- (NSString *) descriptionWithLocale: (NSDictionary *)locale
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];
  [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  s = [d descriptionWithLocale: locale];
  RELEASE(d);
  return s;
}

// Adding and getting intervals

- (id) addTimeInterval: (NSTimeInterval)seconds
{
  /* xxx We need to check for overflow? */
  return [[self class] dateWithTimeIntervalSinceReferenceDate:
		       otherTime(self) + seconds];
}

- (NSTimeInterval) timeIntervalSince1970
{
  return otherTime(self) - UNIX_REFERENCE_INTERVAL;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for timeIntervalSinceDate:"];
    }
  return otherTime(self) - otherTime(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
  return otherTime(self) - GSTimeNow();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  if (otherDate == self)
    {
      return NSOrderedSame;
    }
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  if (otherTime(self) > otherTime(otherDate))
    {
      return NSOrderedDescending;
    }
  if (otherTime(self) < otherTime(otherDate))
    {
      return NSOrderedAscending;
    }
  return NSOrderedSame;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for earlierDate:"];
    }
  if (otherTime(self) > otherTime(otherDate))
    return otherDate;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == nil)
    return NO;
  if ([other isKindOf: abstractClass]
      && 1.0 > ABS(otherTime(self) - otherTime(other)))
    return YES;
  return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
  if (other == nil)
    return NO;
  if (1.0 > ABS(otherTime(self) - otherTime(other)))
    return YES;
  return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for laterDate:"];
    }
  if (otherTime(self)
    < otherTime(otherDate))
    return otherDate;
  return self;
}

@end

@implementation NSGDate

+ (void) initialize
{
  if (self == [NSDate class])
    {
      [self setVersion: 1];
    }
}

- (Class) classForPortCoder
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
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(NSTimeInterval)
			    at: &_seconds_since_ref];
  return self;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  _seconds_since_ref = secs;
  return self;
}


// Adding and getting intervals

- (NSTimeInterval) timeIntervalSince1970
{
  return _seconds_since_ref - UNIX_REFERENCE_INTERVAL;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for timeIntervalSinceDate:"];
    }
  return _seconds_since_ref - otherTime(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
  return _seconds_since_ref - GSTimeNow();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return _seconds_since_ref;
}

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  if (otherDate == self)
    {
      return NSOrderedSame;
    }
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  if (_seconds_since_ref > otherTime(otherDate))
    {
      return NSOrderedDescending;
    }
  if (_seconds_since_ref < otherTime(otherDate))
    {
      return NSOrderedAscending;
    }
  return NSOrderedSame;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for earlierDate:"];
    }
  if (_seconds_since_ref > otherTime(otherDate))
    return otherDate;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == nil)
    return NO;
  if ([other isKindOfClass: abstractClass]
      && 1.0 > ABS(_seconds_since_ref - otherTime(other)))
    return YES;
  return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
  if (other == nil)
    return NO;
  if (1.0 > ABS(_seconds_since_ref - otherTime(other)))
    return YES;
  return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
  if (otherDate == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for laterDate:"];
    }
  if (_seconds_since_ref < otherTime(otherDate))
    return otherDate;
  return self;
}

@end



/*
 *	This abstract class represents a date of which there can be only
 *	one instance.
 */
@implementation GSDateSingle

+ (void) initialize
{
  if (self == [GSDateSingle class])
    {
      [self setVersion: 1];
      behavior_class_add_class(self, [NSGDate class]);
    }
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aRmc
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
}

- (id) initWithCoder: (NSCoder*)coder
{
  return self;
}

- (id) autorelease
{
  return self;
}

- (void) release
{
}

- (id) retain
{
  return self;
}

+ (id) allocWithZone: (NSZone*)z
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to allocate fixed date"];
  return nil;
}

- (id) copyWithZone: (NSZone*)z
{
  return self;
}

- (void) dealloc
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to deallocate fixed date"];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  return self;
}

@end



@implementation GSDatePast

+ (id) allocWithZone: (NSZone*)z
{
  if (_distantPast == nil)
    {
      id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());

      _distantPast = [obj init];
    }
  return _distantPast;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  _seconds_since_ref = DISTANT_PAST;
  return self;
}

@end


@implementation GSDateFuture

+ (id) allocWithZone: (NSZone*)z
{
  if (_distantFuture == nil)
    {
      id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());

      _distantFuture = [obj init];
    }
  return _distantFuture;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  _seconds_since_ref = DISTANT_FUTURE;
  return self;
}

@end


