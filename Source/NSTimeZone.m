/* Implementation for NSTimeZone for GNUStep

   Written by:  Peter Burka <pburka@upei.ca>
   Date: July 1995

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
  This is about complete, but mostly untested.  Many of the methods
  rely on NSDictionary and NSUserDefaults, neither of which are
  complete yet.  I am testing and fixing as the supporting classes
  materialize.

  Note: in this implementation, all objects returned are always
   instances of NSTimeZoneDetail.
*/

#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
//#include <Foundation/NSUserDefaults.h>
@class NSUserDefaults;

#define MINUTES 60
#define HOURS (60 * MINUTES)

@interface NSConcreteTimeZoneDetail: NSTimeZoneDetail
{
@private
	BOOL dst;  	// true if Daylight Savings Time is in effect in this zone
	NSString* abbreviation; 		// the abbreviation
	NSString* name;				// the name
	int deltaGMT;				// difference (in seconds) from Greenwich
}

// initializing
- initWithName:(NSString*)aName
	abbreviation:(NSString*)anAbbreviation
	secondsFromGMT:(int)aDifference
	isDaylightSaving:(BOOL)aDst;

// querying
- (BOOL)isDaylightSavingTimeZone;
- (NSString *)timeZoneAbbreviation;
- (int)timeZoneSecondsFromGMT;
- (NSString*)timeZoneName;

// archiving
- (NSString*)description;

@end

@interface NSConcreteTimeZoneDetail (NSCopying)
- (id)copyWithZone:(NSZone *)zone;
@end

@interface NSConcreteTimeZoneDetail (Archiving)
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;
@end

@implementation NSConcreteTimeZoneDetail

- initWithName:(NSString*)aName
	abbreviation:(NSString*)anAbbreviation
	secondsFromGMT:(int)aDifference
	isDaylightSaving:(BOOL)aDst
{
	[super init];

	//xxx initWithString is not yet available
	//name = [[NSString alloc] initWithString:aName];
	//abbreviation = [[NSString alloc] initWithString:anAbbreviation];
	name = [NSString stringWithCString: [aName cString]];
	abbreviation = [NSString stringWithCString: [anAbbreviation cString]];
	deltaGMT = aDifference;
	dst = aDst;

	return self;
}

- (NSString*)timeZoneName
{
	return name;
}

- (BOOL)isDaylightSavingTimeZone
{
	return dst;
}
	
- (NSString *)timeZoneAbbreviation
{
	return abbreviation;
}

- (int)timeZoneSecondsFromGMT
{
	return deltaGMT;
}

- (NSString*)description
{
	char astr[1024]; // xxx ugly! But it'll do until NSString is done
	BOOL hasAbbreviation = [[self timeZoneAbbreviation] length] > 0;
	sprintf (astr,"%s %s%s%s %+is %s",
		[[self timeZoneName] cString],
		(hasAbbreviation ? "(" : ""),
		[[self timeZoneAbbreviation] cString],
		(hasAbbreviation ? ")" : ""),
		[self timeZoneSecondsFromGMT],
		([self isDaylightSavingTimeZone] ? "(DST)" : ""));
	return [NSString  stringWithCString:astr];
}

@end

@implementation NSConcreteTimeZoneDetail (NSCopying)
- (id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone]
		initWithName:name
		abbreviation:abbreviation
		secondsFromGMT:deltaGMT
		isDaylightSaving:dst];
}
@end

@implementation NSConcreteTimeZoneDetail (NSCoding)
- (void)encodeWithCoder:(NSCoder *)aCoder 
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"i@@i", &dst, &abbreviation, &name, &deltaGMT];
}

- (id)initWithCoder:(NSCoder *)aDecoder 
{
	self = [super initWithCoder:aDecoder];
	[aDecoder decodeValuesOfObjCTypes:"i@@i", &dst, &abbreviation, &name, &deltaGMT];
	return self;
}
@end


@implementation NSTimeZoneDetail

- (BOOL)isDaylightSavingTimeZone
{
	[self notImplemented:_cmd];
	return NO;
}

- (NSString *)timeZoneAbbreviation
{
	[self notImplemented:_cmd];
	return nil;
}

- (int)timeZoneSecondsFromGMT
{
	[self notImplemented:_cmd];
	return 0;
}

- (BOOL)isEqual:anObject
{
	if (anObject == self) return YES;

	if ([super isEqual:anObject]) // this checks to ensure that they're the same class, no?
		if ([[self timeZoneName] isEqual: [anObject timeZoneName]])
		if ([[self timeZoneAbbreviation] isEqual: [anObject timeZoneAbbreviation]])
		if ([self isDaylightSavingTimeZone] == [anObject isDaylightSavingTimeZone])
		if ([self timeZoneSecondsFromGMT] == [anObject timeZoneSecondsFromGMT])
			return YES;

	return NO;
}

- (unsigned int)hash
{
	// This should be sufficient for hashing
	return ([[self timeZoneName] hash] + 1) *
				([self timeZoneSecondsFromGMT] / MINUTES);
}

@end

@implementation NSTimeZone

#define DEFAULTDBKEY "Time Zone"
#define LOCALDBKEY "Local Time Zone"
#define TIMEZONEFILE "NSTimeZones"

NSDictionary* abbreviationDictionary;

+ (void)initialize
{
	// initialize super
	[super initialize];

#if 0
	if ((abbreviationDictionary =
			// [NSDictionary dictionaryWithContentsOfFile:@TIMEZONEFILE] //NIY
			[[NSDictionary dictionary] initWithContentsOfFile:@TIMEZONEFILE])
		== nil)
#else
	if (1)
#endif
	{
		NSConcreteTimeZoneDetail *tzones[] = {
			[[NSConcreteTimeZoneDetail alloc]
										initWithName: @"Greenwich Mean Time"
									  	abbreviation: @"GMT"
										secondsFromGMT: 0 * HOURS
										isDaylightSaving: NO],
			[[NSConcreteTimeZoneDetail alloc]
									 	initWithName: @"Atlantic STandard Time"
									  	abbreviation: @"AST"
										secondsFromGMT: -4 * HOURS
										isDaylightSaving: NO],
			[[NSConcreteTimeZoneDetail alloc]
									 	initWithName: @"Atlantic Daylight Time"
									  	abbreviation: @"ADT"
										secondsFromGMT: -3 * HOURS
										isDaylightSaving: YES],
			[[NSConcreteTimeZoneDetail alloc]
									 	initWithName: @"Eastern Standard Time"
									  	abbreviation: @"EST"
										secondsFromGMT: -5 * HOURS
										isDaylightSaving: NO],
			[[NSConcreteTimeZoneDetail alloc]
									 	initWithName: @"Eastern Daylight Time"
									  	abbreviation: @"EDT"
										secondsFromGMT: -4 * HOURS
										isDaylightSaving: YES]
		};
		NSString* abbrevs[] = {@"GMT", @"AST", @"ADT", @"EST", @"EDT"};

		fprintf (stderr, "Unable to load TimeZones from data file: '%s'\n",
			TIMEZONEFILE);
		abbreviationDictionary = [NSDictionary dictionaryWithObjects:tzones
									forKeys: abbrevs count:5];
	}

	return;
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self != [NSTimeZone class])
    return [super allocWithZone:z];
  return [NSConcreteTimeZoneDetail allocWithZone:z];
}


//Creating and Initializing an NSTimeZone
+ (NSTimeZoneDetail *)defaultTimeZone 
{
/*	NSUserDefaults *db = [NSUserDefaults standardUserDefaults];

	return [self timeZoneWithName: [db stringForKey: @DEFAULTDBKEY]];
*/
return nil;
}

+ (NSTimeZone *)localTimeZone 
{
/*	NSUserDefaults *db = [NSUserDefaults standardUserDefaults];

	return [self timeZoneWithName: [db stringForKey: @LOCALDBKEY]];
*/
return nil;
}

+ (NSTimeZone *)timeZoneForSecondsFromGMT:(int)seconds
{
	id step = [abbreviationDictionary objectEnumerator];
	NSConcreteTimeZoneDetail* zone;

	while ((zone = [step nextObject]) != nil)
		if (seconds == [zone timeZoneSecondsFromGMT]) break;
	[step autorelease];

	if (zone == nil)
		zone = [[NSConcreteTimeZoneDetail alloc]
					initWithName:
						[[NSString stringWithFormat:@"%+i", seconds] autorelease]
					abbreviation: @""
					secondsFromGMT: seconds
					isDaylightSaving: NO];

	return zone;
}

+ (NSTimeZoneDetail *)timeZoneWithAbbreviation:(NSString *)abbreviation 
{
	return [abbreviationDictionary objectForKey:abbreviation];
}

+ (NSTimeZone *)timeZoneWithName:(NSString *)aTimeZoneName
{
	NSEnumerator* step = [abbreviationDictionary objectEnumerator];
	NSConcreteTimeZoneDetail* zone;

	while ((zone = [step nextObject]) != nil)
		if ([aTimeZoneName isEqual:[zone timeZoneName]]) break;
	[step release];

	return zone;
}

- (NSTimeZoneDetail *)timeZoneDetailForDate:(NSDate *)date
// XXX not implemented yet!
{
	return nil;
}

//Managing Time Zones
+ (void)setDefaultTimeZone:(NSTimeZone *)aTimeZone
{
/*	NSUserDefaults *db = [NSUserDefaults standardUserDefaults];

	if (aTimeZone != nil)
		[db setObject:[aTimeZone name] forKey: @DEFAULTDBKEY];
	else
		[db removeObjectForKey: @DEFAULTDBKEY];

	return;
*/
return;
}

// Getting Time Zone Information
+ (NSDictionary *)abbreviationDictionary
{
	return abbreviationDictionary;
}

- (NSString *)timeZoneName
/* this is really the subclass's responsibility */
{
	return @"";
}

//Getting Arrays of Time Zones
+ (NSArray *)timeZoneArray
/* this should return a NSArray of NSTimeZones.
    Instead, it returns a NSArray of NSTimeZoneDetail:NSTimeZone.
    This shouldn't cause problems, as far as I can tell.
*/
{
	return [abbreviationDictionary allValues];
}

- (NSArray *)timeZoneDetailArray
{
	return [abbreviationDictionary allValues];
}

@end

@implementation NSTimeZone (NSCopying)
- (id)copyWithZone:(NSZone *)zone
{
	return [super copyWithZone:zone];
}
@end

@implementation NSTimeZone (Archiving)
- (void)encodeWithCoder: aCoder
{
	return [super encodeWithCoder:aCoder];
}

- (id)initWithCoder: aDecoder
{
	return [super initWithCoder:aDecoder];
}
@end

