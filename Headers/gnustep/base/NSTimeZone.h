/* Interface for NSTimeZone for GNUStep
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

#ifndef __NSTimeZone_h_GNUSTEP_BASE_INCLUDE
#define __NSTimeZone_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class	NSArray;
@class	NSDate;
@class	NSDictionary;
@class	NSString;

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
- (NSString*) abbreviationForDate: (NSDate*)when;
- (id) initWithName: (NSString*)name;
- (id) initWithName: (NSString*)name data: (NSData*)data;
- (BOOL) isDaylightSavingTime;
- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate;
- (BOOL) isEqualToTimeZone: (NSTimeZone*)aTimeZone;
- (NSString*) name;
- (int) secondsFromGMT;
- (int) secondsFromGMTForDate: (NSDate*)when;
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

#endif  /* __NSTimeZone_h_GNUSTEP_BASE_INCLUDE*/

