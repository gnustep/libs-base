/* Interface for NSDate for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.

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

#ifndef __NSDate_h_OBJECTS_INCLUDE
#define __NSDate_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>

typedef double	NSTimeInterval;

@class NSCalendarDate;
@class NSString;
@class NSTimeZone;

@interface NSDate : NSObject <NSCopying>

// Getting current time

+ (NSTimeInterval) timeIntervalSinceReferenceDate;

// Allocation and initializing

+ (id) allocWithZone: (NSZone*)z;
+ (NSDate*) date;
+ (NSDate*) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds;
+ (NSDate*) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds;
+ (NSDate*) distantFuture;
+ (NSDate*) distantPast;
- (id) init;
- (id) initWithString: (NSString*)description;
- (NSDate*) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
		       sinceDate: (NSDate*)anotherDate;
- (NSDate*) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded;
- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs;

// Converting to NSCalendar

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone;

// Representing dates

- (NSString*) description;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone;

// Adding and getting intervals

- (NSDate*) addTimeInterval: (NSTimeInterval)seconds;
- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate;
- (NSTimeInterval) timeIntervalSinceNow;
- (NSTimeInterval) timeIntervalSinceReferenceDate;

// Comparing dates

- (NSComparisonResult) compare: (NSDate*)otherDate;
- (NSDate*) earlierDate: (NSDate*)otherDate;
- (BOOL) isEqual: (id)other;
- (NSDate*) laterDate: (NSDate*)otherDate;

@end

#endif  /* __NSDate_h_OBJECTS_INCLUDE */
