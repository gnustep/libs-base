/* Implementation for NSDate for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Jeremy Bettis <jeremy@hksys.com>
   Date: March 1995

   This file is part of the Gnustep Base Library.

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
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#ifndef WIN32
#include <sys/time.h>
#endif /* WIN32 */

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


/* Concrete implementation of NSDate. */

@interface NSConcreteDate : NSDate
{
  NSTimeInterval seconds_since_ref;
}
- (id) copyWithZone: (NSZone*)zone;
- (NSTimeInterval) timeIntervalSinceReferenceDate;
- (id) init;
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;
@end

@implementation NSConcreteDate

- (id) copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone: zone]
	  initWithTimeIntervalSinceReferenceDate: seconds_since_ref];
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return seconds_since_ref;
}

- (NSTimeInterval) timeIntervalSinceNow
{
  NSTimeInterval now = [[self class] timeIntervalSinceReferenceDate];
  return seconds_since_ref - now;
}

- (id) init
{
  return [self initWithTimeIntervalSinceReferenceDate:
		 [[self class] timeIntervalSinceReferenceDate]];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  self = [super init];
  seconds_since_ref = secs;
  return self;
}

@end


/* The abstract implementation of NSDate. */

@implementation NSDate

+ (void) initialize
{
  /* xxx Force NSConcreteDate to initialize itself.  There seems to be 
     a bug with __objc_word_forward and returning doubles? */
  if (self == [NSDate class])
    [NSConcreteDate instanceMethodForSelector: 
		      @selector(timeIntervalSinceReferenceDate)];
}

- (id) copyWithZone: (NSZone*)zone
{
  return [[NSConcreteDate class] copyWithZone:zone];
}

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
  volatile NSTimeInterval interval;
  struct timeval tp;
  struct timezone tzp;

  interval = UNIX_REFERENCE_INTERVAL;
  gettimeofday (&tp, &tzp);
  interval += tp.tv_sec;
  interval += (double)tp.tv_usec / 1000000.0;

  /* There seems to be a problem with bad double arithmetic... */
  assert (interval < 0);

  return interval;
}

// Allocation and initializing

+ (id) allocWithZone: (NSZone*)z
{
  if (self != [NSDate class])
    return [super allocWithZone:z];
  return [NSConcreteDate allocWithZone:z];
}

+ (NSDate*) date
{
  return [[[self alloc] init] 
	   autorelease];
}

+ (NSDate*) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceNow: seconds]  
	  autorelease];
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

- (id) init
{
  // We have to do this, otherwise the subclasses cannot do [super init];
  return [super init];
}

- (id) initWithString: (NSString*)description
{
  NSTimeInterval theTime = 0;
  /* From the doc:
     Returns an calendar date object with a date and time value  
     specified by the international string-representation format:  
     YYYY-MM-DD HH:MM:SS -HHMM, where -HHMM is a time zone offset in  
     hours and minutes from Greenwich Mean Time. (Adding the offset to  
     the specified time yields the equivalent GMT.) An example string  
     might be "1994-03-30 13:12:43 +0900". You must specify all fields of  
     the format, including the time-zone offset, which must have a plus-  
     or minus-sign prefix.
     */
  /* a miracle occurs  ****************************** */
  [self notImplemented:_cmd];
  return [self initWithTimeIntervalSinceReferenceDate: theTime];
}

- (NSDate*) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		       sinceDate: (NSDate*)anotherDate;
{
  return [self initWithTimeIntervalSinceReferenceDate:
	       [anotherDate timeIntervalSinceReferenceDate]];
}

- (NSDate*) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
{
  // Get the current time, add the secs and init thyself;
  return [self initWithTimeIntervalSinceReferenceDate:
	       [[self class] timeIntervalSinceReferenceDate] + secsToBeAdded];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone
{
  // Not done yet,  NSCalendarDate doesn't exist yet!
  [self notImplemented: _cmd];
  return nil;
}


// Representing dates

- (NSString*) description
{
  /* *********************** only works for >1970 dates */
  struct tm		*theTime;
  NSTimeInterval	secs;
  time_t			unix_secs;
  char			buf[64];
	
  secs = [self timeIntervalSinceReferenceDate];
  unix_secs = (time_t)secs - (time_t)UNIX_REFERENCE_INTERVAL;
  theTime = localtime(&unix_secs);
/* 
   Gregor Hoffleit <flight@mathi.uni-heidelberg.DE> reports problems
   with strftime on i386-next-nextstep3.
   Date: Fri, 12 Jan 96 16:00:42 +0100
   */
#ifdef NeXT
  sprintf(buf,"%4d-%02d-%02d %02d:%02d:%02d %c%02d%02d",
	  1900+theTime->tm_year, theTime->tm_mon+1, theTime->tm_mday,
	  theTime->tm_hour, theTime->tm_min, theTime->tm_sec,
	  (theTime->tm_gmtoff>0)?'+':'-', abs(theTime->tm_gmtoff)/3600,
	  (abs(theTime->tm_gmtoff)/60)%60);
#else
  strftime(buf, 64, "%Y-%m-%d %H:%M:%S", theTime);
#endif
  return [NSString stringWithCString: buf];
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
{
  // Not done yet, no NSCalendarDate or NSTimeZone...
  [self notImplemented: _cmd];
  return nil;
}


// Adding and getting intervals

- (NSDate*) addTimeInterval: (NSTimeInterval)seconds
{
  /* xxx We need to check for overflow? */
  return [[self class] dateWithTimeIntervalSinceReferenceDate:
		       [self timeIntervalSinceReferenceDate] + seconds];
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  return [self timeIntervalSinceReferenceDate] -
    [otherDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval) timeIntervalSinceNow
{
  NSTimeInterval now = [[self class] timeIntervalSinceReferenceDate];
  NSTimeInterval me = [self timeIntervalSinceReferenceDate];
  return me - now;
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  [self subclassResponsibility: _cmd];
  return 0.0;
}

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  if ([self timeIntervalSinceReferenceDate] >
      [otherDate timeIntervalSinceReferenceDate])
    return NSOrderedDescending;
		
  if ([self timeIntervalSinceReferenceDate] <
      [otherDate timeIntervalSinceReferenceDate])
    return NSOrderedAscending;
		
  return NSOrderedSame;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  if ([self timeIntervalSinceReferenceDate] >
      [otherDate timeIntervalSinceReferenceDate])
    return otherDate;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOf: [NSDate class]] 
      && 1.0 > ([self timeIntervalSinceReferenceDate] -
		[other timeIntervalSinceReferenceDate]))
    return YES;
  return NO;
}		

- (NSDate*) laterDate: (NSDate*)otherDate
{
  if ([self timeIntervalSinceReferenceDate] <
      [otherDate timeIntervalSinceReferenceDate])
    return otherDate;
  return self;
}

@end
