/* Implementation for NSDate for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Jeremy Bettis <jeremy@hksys.com>
   Date: March 1995

   This file is part of the GNU Objective C Class Library.

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
#include <sys/time.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

@interface NSConcreteDate : NSDate
{
@private
  NSTimeInterval timeSinceReference;
}
- (id) copyWithZone: (NSZone*)zone;
- (NSTimeInterval) timeIntervalSinceReferenceDate;
- (id) init;
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;
@end

// I hope 200,000 years is distant enough.

#define UNIX_OFFSET	-978307200.0
#define DISTANT_FUTURE	6307200000000.0
#define DISTANT_PAST	-DISTANT_FUTURE

@implementation NSConcreteDate

- (id) copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone]
	  initWithTimeIntervalSinceReferenceDate:timeSinceReference];
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return timeSinceReference;
}

- (id) init
{
  return [self initWithTimeIntervalSinceReferenceDate:
	  [[self class] timeIntervalSinceReferenceDate] ];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  self = [super init];
  timeSinceReference = secs;
  return self;
}

@end


@implementation NSDate

- (id) copyWithZone: (NSZone*)zone
{
  return [[[NSConcreteDate class] allocWithZone:zone]
	  initWithTimeIntervalSinceReferenceDate:timeSinceReference];
}

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
  NSTimeInterval	theTime = UNIX_OFFSET;
  struct timeval	tp;
  struct timezone	tzp;
	
  gettimeofday(&tp,&tzp);
  theTime += tp.tv_sec;
  theTime += (double)tp.tv_usec / 1000000.0;
	
  return theTime;
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
  return [[[self alloc] init] autorelease];
}

+ (NSDate*) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceNow:seconds]  
	  autorelease];
}

+ (NSDate*) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  return [[[self alloc] initWithTimeIntervalSinceReferenceDate:seconds]
	  autorelease];
}

+ (NSDate*) distantFuture
{
  return [self dateWithTimeIntervalSinceReferenceDate:DISTANT_FUTURE];
}

+ (NSDate*) distantPast
{
  return [self dateWithTimeIntervalSinceReferenceDate:DISTANT_PAST];
}

- (id) init
{
  // We have to do this, otherwise the subclasses cannot do [super init];
  return [super init];
}

- (id) initWithString: (NSString*)description
{
  NSTimeInterval	theTime;
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
  [self notImplemented:_cmd];
  return nil;
}

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone
{
  // Not done yet,  NSCalendarDate doesn't exist yet!
  [self notImplemented:_cmd];
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
  unix_secs = (time_t)secs - (time_t)UNIX_OFFSET;
  theTime = localtime(&unix_secs);
  strftime(buf, 64, "%Y-%m-%d %H:%M:%S", theTime);
  return [NSString stringWithCString: buf];
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
{
  // Not done yet, no NSCalendarDate or NSTimeZone...
  [self notImplemented:_cmd];
  return nil;
}


// Adding and getting intervals

- (NSDate*) addTimeInterval: (NSTimeInterval)seconds
{
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
  return [[self class] timeIntervalSinceReferenceDate] -
    [self timeIntervalSinceReferenceDate];
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  [self notImplemented:_cmd];
  abort();
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
