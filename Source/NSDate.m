/* Implementation for NSDate for GNUStep
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.

   Written by:  Jeremy Bettis <jeremy@hksys.com>
   Rewritten by:  Scott Christley <scottc@net-community.com>
   Date: March 1995

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

/*
  1995-03-31 02:41:00 -0600	Jeremy Bettis <jeremy@hksys.com>
  Release the first draft of NSDate.
  Three methods not implemented, and NSCalendarDate/NSTimeZone don't exist.
*/

#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#ifndef __WIN32__
#include <time.h>
#endif /* !__WIN32__ */
#include <stdio.h>
#include <stdlib.h>
#ifndef __WIN32__
#include <sys/time.h>
#endif /* !__WIN32__ */

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


/* The implementation of NSDate. */

@implementation NSDate

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
#if !defined(__WIN32__) && !defined(_WIN32)
  volatile NSTimeInterval interval;
  struct timeval tp;

  interval = UNIX_REFERENCE_INTERVAL;
  gettimeofday (&tp, NULL);
  interval += tp.tv_sec;
  interval += (double)tp.tv_usec / 1000000.0;

  /* There seems to be a problem with bad double arithmetic... */
  assert (interval < 0);

  return interval;
#else
  TIME_ZONE_INFORMATION sys_time_zone;
  SYSTEMTIME sys_time;
  NSCalendarDate *d;
  NSTimeInterval t;

  // Get the time zone information
  GetTimeZoneInformation(&sys_time_zone);

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
     timeZone: [NSTimeZone defaultTimeZone]];
  t = [d timeIntervalSinceReferenceDate];
  [d release];
  return t;
#endif /* __WIN32__ */
}

// Allocation and initializing

+ (NSDate*) date
{
  return [[[self alloc] init] autorelease];
}

+ (NSDate*) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceNow: seconds]  
	  autorelease];
}

+ (NSDate *)dateWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceReferenceDate: 
		       UNIX_REFERENCE_INTERVAL + seconds] autorelease];
}

+ (NSDate*) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceReferenceDate: seconds]
	   autorelease];
}

+ (NSDate*) distantFuture
{
  static id df = nil;
  if (!df)
    df = [[self alloc] initWithTimeIntervalSinceReferenceDate: DISTANT_FUTURE];
  return df;
}

+ (NSDate*) distantPast
{
  static id dp = nil;
  if (!dp)
    dp = [[self alloc] initWithTimeIntervalSinceReferenceDate: DISTANT_PAST];
  return dp;
}

- (id) copyWithZone:(NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return [self retain];
  else
    return [super copyWithZone: zone];
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (Class) classForPortCoder: aRmc
{
  return [self class];
}
- replacementObjectForPortCoder: aRmc
{
  return self;
}

- (void) encodeWithCoder:(NSCoder*)coder
{
  [super encodeWithCoder:coder];
  [coder encodeValueOfObjCType:"d" at:&seconds_since_ref];
}

- (id) initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  [coder decodeValueOfObjCType:"d" at:&seconds_since_ref];
  return self;
}

- (id) init
{
  return [self initWithTimeIntervalSinceReferenceDate:
		 [[self class] timeIntervalSinceReferenceDate]];
}

- (id) initWithString: (NSString*)description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSCalendarDate *d = [NSCalendarDate alloc];
  [d initWithString: description];
  [self initWithTimeIntervalSinceReferenceDate:
	[d timeIntervalSinceReferenceDate]];
  [d release];
  return self;
}

- (NSDate*) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		       sinceDate: (NSDate*)anotherDate;
{
  // Get the other date's time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate:
	       [anotherDate timeIntervalSinceReferenceDate] + secsToBeAdded];
}

- (NSDate*) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
{
  // Get the current time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate:
	       [[self class] timeIntervalSinceReferenceDate] + secsToBeAdded];
}

- (NSDate *)initWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
  return [self initWithTimeIntervalSinceReferenceDate: 
		       UNIX_REFERENCE_INTERVAL + seconds];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  [super init];
  seconds_since_ref = secs;
  return self;
}

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone
{
  NSCalendarDate *d = [NSCalendarDate alloc];
  [d initWithTimeIntervalSinceReferenceDate: seconds_since_ref];
  [d setCalendarFormat: formatString];
  [d setTimeZone: timeZone];
  return [d autorelease];
}

// Representing dates

- (NSString*) description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [NSCalendarDate alloc];
  [d initWithTimeIntervalSinceReferenceDate: seconds_since_ref];
  s = [d description];
  [d release];
  return s;
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [NSCalendarDate alloc];
  id f, t;

  [d initWithTimeIntervalSinceReferenceDate: seconds_since_ref];
  if (!format)
    f = [d calendarFormat];
  else
    f = format;
  if (!aTimeZone)
    t = [d timeZoneDetail];
  else
    t = aTimeZone;

  s = [d descriptionWithCalendarFormat: f timeZone: t];
  [d release];
  return s;
}

- (NSString *) descriptionWithLocale: (NSDictionary *)locale
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [NSCalendarDate alloc];
  [d initWithTimeIntervalSinceReferenceDate: seconds_since_ref];
  s = [d descriptionWithLocale: locale];
  [d release];
  return s;
}

// Adding and getting intervals

- (NSDate*) addTimeInterval: (NSTimeInterval)seconds
{
  /* xxx We need to check for overflow? */
  return [[self class] dateWithTimeIntervalSinceReferenceDate:
		       seconds_since_ref + seconds];
}

- (NSTimeInterval) timeIntervalSince1970
{
  return seconds_since_ref - UNIX_REFERENCE_INTERVAL;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  return seconds_since_ref - [otherDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval) timeIntervalSinceNow
{
  NSTimeInterval now = [[self class] timeIntervalSinceReferenceDate];
  return seconds_since_ref - now;
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return seconds_since_ref;
}

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  if (seconds_since_ref > [otherDate timeIntervalSinceReferenceDate])
    return NSOrderedDescending;
		
  if (seconds_since_ref < [otherDate timeIntervalSinceReferenceDate])
    return NSOrderedAscending;
		
  return NSOrderedSame;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  if (seconds_since_ref > [otherDate timeIntervalSinceReferenceDate])
    return otherDate;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOf: [NSDate class]] 
      && 1.0 > ABS(seconds_since_ref - [other timeIntervalSinceReferenceDate]))
    return YES;
  return NO;
}		

- (NSDate*) laterDate: (NSDate*)otherDate
{
  if (seconds_since_ref < [otherDate timeIntervalSinceReferenceDate])
    return otherDate;
  return self;
}

@end
