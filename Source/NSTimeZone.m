/* Time zone management. -*- Mode: ObjC -*-
   Copyright (C) 1997 Free Software Foundation, Inc.
  
   Written by: Yoo C. Chung <wacko@laplace.snu.ac.kr>
   Date: June 1997
  
     This file is part of the GNUstep Base Library.
  
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License
   as published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.
  
   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
  
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */
  
/* We use a implementation independent of the system, since POSIX
   functions for time zones are woefully inadequate for implementing
   NSTimeZone, and time zone names can be different from system to
   system.

   We do not use a dictionary for storing time zones, since such a
   dictionary would be VERY large (~500K).  And we would have to use a
   complicated object determining whether we're using daylight savings
   time and such for every entry in the dictionary.  (Though we will
   eventually have to change the implementation to prevent the year
   2038 problem.)

   The local time zone can be specified with the user defaults
   database, the TZ environment variable, the file LOCAL_TIME_FILE, or
   the fallback time zone (which is UTC), with the ones listed first
   having precedence.

   Any time zone must be a file name in ZONES_DIR.

   FIXME?: use leap seconds? */

#include <config.h>
#include <base/preface.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSBundle.h>

#define NOID
#include "tzfile.h"


/* Key for local time zone in user defaults. */
#define LOCALDBKEY @"Local Time Zone"

/* Directory that contains the time zone data. */
#define TIME_ZONE_DIR @"NSTimeZones"

/* Location of time zone abbreviation dictionary.  It is a text file
   with each line comprised of the abbreviation, a whitespace, and the
   name.  Neither the abbreviation nor the name can contain
   whitespace, and each line must not be longer than 80 characters. */
#define ABBREV_DICT @"abbreviations"

/* File holding regions grouped by latitude.  It is a text file with
   each line comprised of the latitude region, whitespace, and the
   name.  Neither the abbreviation nor the name can contain
   whitespace, and each line must not be longer than 80 characters. */
#define REGIONS_FILE @"regions"

/* Name of the file that contains the name of the local time zone. */
#define LOCAL_TIME_FILE @"localtime"

/* Directory that contains the actual time zones. */
#define ZONES_DIR @"zones/"


@class NSInternalTimeTransition;
@class NSConcreteTimeZone;
@class NSConcreteAbsoluteTimeZone;
@class NSConcreteTimeZoneDetail;


/* Temporary structure for holding time zone details. */
struct ttinfo
{
  int offset; // Seconds east of UTC
  BOOL isdst; // Daylight savings time?
  char abbr_idx; // Index into time zone abbreviations string
};


/* The local time zone. */
static id localTimeZone;

/* Dictionary for time zones.  Each time zone must have a unique
   name. */
static NSMutableDictionary *zoneDictionary;

/* Fake one-to-one abbreviation to time zone name dictionary. */
static NSDictionary *fake_abbrev_dict;

/* Lock for creating time zones. */
static NSLock *zone_mutex;


/* Decode the four bytes at PTR as a signed integer in network byte order.
   Based on code included in the GNU C Library 2.0.3. */
static inline int
decode (const void *ptr)
{
#if defined(WORDS_BIGENDIAN) && SIZEOF_INT == 4
  return *(const int *) ptr;
#else /* defined(WORDS_BIGENDIAN) && SIZEOF_INT == 4 */
  const unsigned char *p = ptr;
  int result = *p & (1 << (CHAR_BIT - 1)) ? ~0 : 0;

  result = (result << 8) | *p++;
  result = (result << 8) | *p++;
  result = (result << 8) | *p++;
  result = (result << 8) | *p++;
  return result;
#endif /* defined(WORDS_BIGENDIAN) && SIZEOF_INT == 4 */
}


/* Object enumerator for NSInternalAbbrevDict. */
@interface NSInternalAbbrevDictObjectEnumerator : NSEnumerator
{
  NSEnumerator *dict_enum;
}

- initWithDict: (NSDictionary*)aDict;
@end


/* Front end that actually uses [NSTimeZone abbrebiationMap]. */
@interface NSInternalAbbrevDict : NSDictionary
@end
  
  
@interface NSInternalTimeTransition : NSObject
{
  int trans_time; // When the transition occurs
  char detail_index; // Index of time zone detail
}
  
- initWithTime: (int)aTime withIndex: (char)anIndex;
- (int)transTime;
- (char)detailIndex;
@end
  
  
@interface NSConcreteTimeZone : NSTimeZone
{
  NSString *name;
  NSArray *transitions; // Transition times and rules
  NSArray *details; // Time zone details
}
  
- initWithName: (NSString*)aName withTransitions: (NSArray*)trans
   withDetails: (NSArray*)zoneDetails;
@end
  

@interface NSConcreteAbsoluteTimeZone : NSTimeZone
{
  NSString *name;
  id detail;
  int offset; // Offset from UTC in seconds.
}

- initWithOffset: (int)anOffset;
@end
  

@interface NSConcreteTimeZoneDetail : NSTimeZoneDetail
{
  NSTimeZone *timeZone; // Time zone which created this object.
  NSString *abbrev; // Abbreviation for time zone detail.
  int offset; // Offset from UTC in seconds.
  BOOL is_dst; // Is it daylight savings time?
}

- initWithTimeZone: (NSTimeZone*)aZone withAbbrev: (NSString*)anAbbrev
       withOffset: (int)anOffset withDST: (BOOL)isDST;
@end
  
/* Private methods for obtaining resource file names. */
@interface NSTimeZone (Private)
+ (NSString*)getAbbreviationFile;
+ (NSString*)getRegionsFile;
+ (NSString*)getLocalTimeFile;
+ (NSString*)getTimeZoneFile: (NSString*)name;
@end


@implementation NSInternalAbbrevDictObjectEnumerator

- (void) dealloc
{
  RELEASE(dict_enum);
}

- (id) initWithDict: (NSDictionary*)aDict
{
  dict_enum = RETAIN([aDict objectEnumerator]);
  return self;
}

- (id) nextObject
{
  id object;

  object = [dict_enum nextObject];
  if (object != nil)
    return [object objectAtIndex: 0];
  else
    return nil;
}

@end


@implementation NSInternalAbbrevDict

+ allocWithZone: (NSZone*)zone
{
  return NSAllocateObject(self, 0, zone);
}

- (id) init
{
  return self;
}

- (unsigned)count
{
  return [[NSTimeZone abbreviationMap] count];
}

- (NSEnumerator*) keyEnumerator
{
  return [[NSTimeZone abbreviationMap] keyEnumerator];
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[NSInternalAbbrevDictObjectEnumerator alloc]
	    initWithDict: [NSTimeZone abbreviationMap]]);
}
  
- (id) objectForKey: (NSString*)key
{
  return [[[NSTimeZone abbreviationMap] objectForKey: key] objectAtIndex: 0];
}
  
@end


@implementation NSInternalTimeTransition

- (NSString*) description
{
  return [NSString
          stringWithFormat: @"%@(%d, %d)",
          [self class], trans_time, (int)detail_index];
}

- initWithTime: (int)aTime withIndex: (char)anIndex
{
  [super init];
  trans_time = aTime;
  detail_index = anIndex;
  return self;
}

- (int)transTime
{
  return trans_time;
}

- (char)detailIndex
{
  return detail_index;
}

@end
  
  
@implementation NSConcreteTimeZone
  
- (id) initWithName: (NSString*)aName
    withTransitions: (NSArray*)trans
	withDetails: (NSArray*)zoneDetails
{
  [super init];
  name = RETAIN(aName);
  transitions = RETAIN(trans);
  details = RETAIN(zoneDetails);
  return self;
}

- (void)dealloc
{
  RELEASE(name);
  RELEASE(transitions);
  RELEASE(details);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
  if (self == localTimeZone)
    [aCoder encodeObject: @"NSLocalTimeZone"];
  else
    [aCoder encodeObject: name];
}

- (id) awakeAfterUsingCoder: (NSCoder*)aCoder
{
  if ([name isEqual: @"NSLocalTimeZone"])
    {
      return localTimeZone;
    }
  return [NSTimeZone timeZoneWithName: name];
}

- (id) initWithDecoder: (NSCoder*)aDecoder
{
  self = [super initWithCoder: aDecoder];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &name];
  return self;
}

- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  unsigned index;
  int the_time;
  unsigned count;

  the_time = (int)[date timeIntervalSince1970];
  count = [transitions count];
  if (count == 0
      || the_time < [[transitions objectAtIndex: 0] transTime])
    /* Either DATE is before any transitions or there is no transition.
       Return the first non-DST type, or the first one if they are all DST. */
    {
      unsigned detail_count;

      detail_count = [details count];
      index = 0;
      while (index < detail_count
        && [[details objectAtIndex: index] isDaylightSavingTimeZone])
	index++;
      if (index == detail_count)
	index = 0;
    }
  else
    /* Find the first transition after DATE, and then pick the type of
       the transition before it. */
    {
      for (index = 1; index < count; index++)
	if (the_time < [[transitions objectAtIndex: index] transTime])
	  break;
      index = [[transitions objectAtIndex: index-1] detailIndex];
    }
  return [details objectAtIndex: index];
}
  
- (NSArray*) timeZoneDetailArray
{
  return details;
}
  
- (NSString*)timeZoneName
{
  return name;
}
  
@end
  
  
@implementation NSConcreteAbsoluteTimeZone

- initWithOffset: (int)anOffset
{
  [super init];
  name = [NSString stringWithFormat: @"%d", anOffset];
  detail = [[NSConcreteTimeZoneDetail alloc]
	     initWithTimeZone: self withAbbrev: name
	     withOffset: offset withDST: NO];
  offset = anOffset;
  return self;
}

- (void)dealloc
{
  RELEASE(name);
  RELEASE(detail);
  [super dealloc];
}

- (void)encodeWithCoder: aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeObject: name];
}

- initWithCoder: aDecoder
{
  self = [super initWithCoder: aDecoder];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &name];
  offset = [name intValue];
  return self;
}

- (NSTimeZoneDetail*)timeZoneDetailForDate: (NSDate*)date
{
  return detail;
}
  
- (NSString*)timeZoneName
{
  return name;
}
  
- (NSArray*)timeZoneDetailArray
{
  return [NSArray arrayWithObject: detail];
}
  
@end
  
  
@implementation NSConcreteTimeZoneDetail
  
- initWithTimeZone: (NSTimeZone*)aZone withAbbrev: (NSString*)anAbbrev
       withOffset: (int)anOffset withDST: (BOOL)isDST
{
  [super init];
  timeZone = RETAIN(aZone);
  abbrev = RETAIN(anAbbrev);
  offset = anOffset;
  is_dst = isDST;
  return self;
}
  
- (void)dealloc
{
  RELEASE(timeZone);
  RELEASE(abbrev);
  [super dealloc];
}

- (void)encodeWithCoder: aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeObject: abbrev];
  [aCoder encodeValueOfObjCType: @encode(int) at: &offset];
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &is_dst];
}

- initWithCoder: aDecoder
{
  self = [super initWithCoder: aDecoder];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &abbrev];
  [aDecoder decodeValueOfObjCType: @encode(int) at: &offset];
  [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &is_dst];
  return self;
}
  
- (NSTimeZoneDetail*)timeZoneDetailForDate: (NSDate*)date
{
  return [timeZone timeZoneDetailForDate: date];
}

- (NSString*)timeZoneName
{
  return [timeZone timeZoneName];
}
 
- (NSArray*)timeZoneDetailArray
{
  return [timeZone timeZoneDetailArray];
}

- (BOOL)isDaylightSavingTimeZone
{
  return is_dst;
}
  
- (NSString*)timeZoneAbbreviation
{
  return abbrev;
}
  
- (int)timeZoneSecondsFromGMT
{
  return offset;
}
  
@end


@implementation NSTimeZone

+ (void)initialize
{
  if (self == [NSTimeZone class])
    {
      id localZoneString = nil;

      zone_mutex = [NSLock new];
      zoneDictionary = [[NSMutableDictionary alloc] init];

      localZoneString = [[NSUserDefaults standardUserDefaults]
			  stringForKey: LOCALDBKEY];
      if (localZoneString == nil)
        /* Try to get timezone from environment. */
	localZoneString = [[[NSProcessInfo processInfo]
			     environment] objectForKey: @"TZ"];
      if (localZoneString == nil)
       /* Try to get timezone from LOCAL_TIME_FILE. */
       {
	 NSString *f = [NSTimeZone getLocalTimeFile];
         char zone_name[80];
         FILE *fp;

	 if (f)
	   {
#if	defined(__WIN32__)
	     fp = fopen([f fileSystemRepresentation], "rb");
#else
	     fp = fopen([f fileSystemRepresentation], "r");
#endif
	     if (fp != NULL)
	       {
                 if (fscanf(fp, "%79s", zone_name) == 1)
                  localZoneString = [NSString stringWithCString: zone_name];
		 fclose(fp);
	       }
	   }
       }
      if (localZoneString != nil)
	localTimeZone = [NSTimeZone timeZoneWithName: localZoneString];
      else
        NSLog(@"No local time zone specified.");

      /* If local time zone fails to allocate, then allocate something
         that is sure to succeed (unless we run out of memory, of
         course). */
      if (localTimeZone == nil)
        {
          NSLog(@"Using time zone with absolute offset 0.");
          localTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
        }

      fake_abbrev_dict = [[NSInternalAbbrevDict alloc] init];
    }
}

- (NSString*)description
{
  return [self timeZoneName];
}

+ (NSTimeZoneDetail*)defaultTimeZone
{
  return [localTimeZone timeZoneDetailForDate: [NSDate date]];
}

+ (NSTimeZone*)localTimeZone
{
  return localTimeZone;
}

+ (NSTimeZone*)timeZoneForSecondsFromGMT: (int)seconds
{
  /* We simply return the following because an existing time zone with
     the given offset might not always have the same offset (daylight
     savings time, change in standard time, etc.). */
  return [[NSConcreteAbsoluteTimeZone alloc] initWithOffset: seconds];
}

+ (NSTimeZoneDetail*)timeZoneWithAbbreviation: (NSString*)abbreviation
{
  /* We obtain a time zone from the abbreviation dictionary, get the
     time zone detail array, and then obtain the time zone detail we
     want from that array.  This convulated and twisted method is used
     because there is no way to directly obtain the time zone
     detail. */
  id zone, detailArray, e, object;

  zone = [self timeZoneWithName: [[self abbreviationDictionary]
				   objectForKey: abbreviation]];
  if (zone == nil)
    return nil;
  detailArray = [zone timeZoneDetailArray];
  e = [detailArray objectEnumerator];
  while ((object = [e nextObject]) != nil)
    if ([[object timeZoneAbbreviation] isEqualToString: abbreviation])
      return object;

  /* If we reach here, we've got an inconsistency in our time zone
     database. */
  [NSException
    raise: NSInternalInconsistencyException
    format: @"Time zone abbreviation `%@' inconsistent.", abbreviation];
  return nil;
}

+ (NSTimeZone*)timeZoneWithName: (NSString*)aTimeZoneName
{
  static NSString *fileException = @"fileException";
  static NSString *errMess = @"File read error in NSTimeZone.";
  id zone, transArray, detailsArray;
  int i, n_trans, n_types, names_size;
  id *abbrevsArray;
  char *trans, *type_idxs, *zone_abbrevs;
  struct tzhead header;
  struct ttinfo *types; // Temporary array for details
  FILE *file = NULL;
  NSString *fileName;

  [zone_mutex lock];
  zone = [zoneDictionary objectForKey: aTimeZoneName];
  if (zone != nil)
    {
      [zone_mutex unlock];
      return zone;
    }

  /* Make sure that only time zone files are accessed.
     FIXME: Make this more robust. */
  if ([aTimeZoneName length] == 0
      || ([aTimeZoneName cString])[0] == '/'
      || strchr([aTimeZoneName cString], '.') != NULL)
    {
      NSLog(@"Disallowed time zone name `%@'.", aTimeZoneName);
      [zone_mutex unlock];
      return nil;
    }

  NS_DURING
    zone = [NSConcreteTimeZone alloc];

    /* Open file. */
    fileName = [NSTimeZone getTimeZoneFile: aTimeZoneName];
#if	defined(__WIN32__)
    file = fopen([fileName fileSystemRepresentation], "rb");
#else
    file = fopen([fileName fileSystemRepresentation], "r");
#endif
    if (file == NULL)
      [NSException raise: fileException format: errMess];

    /* Read header. */
    if (fread(&header, sizeof(struct tzhead), 1, file) != 1)
      [NSException raise: fileException format: errMess];

    n_trans = decode(header.tzh_timecnt);
    n_types = decode(header.tzh_typecnt);
    names_size = decode(header.tzh_charcnt);

    /* Read in transitions. */
    trans = NSZoneMalloc(NSDefaultMallocZone(), 4*n_trans);
    type_idxs = NSZoneMalloc(NSDefaultMallocZone(), n_trans);
    if (fread(trans, 4, n_trans, file) != n_trans
	|| fread(type_idxs, 1, n_trans, file) != n_trans)
      [NSException raise: fileException format: errMess];
    transArray = [[NSMutableArray alloc] initWithCapacity: n_trans];
    for (i = 0; i < n_trans; i++)
      [transArray
	addObject: [[NSInternalTimeTransition alloc]
		     initWithTime: decode(trans+(i*4))
		     withIndex: type_idxs[i]]];
    NSZoneFree(NSDefaultMallocZone(), trans);
    NSZoneFree(NSDefaultMallocZone(), type_idxs);

    /* Read in time zone details. */
    types =
      NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct ttinfo)*n_types);
    for (i = 0; i < n_types; i++)
      {
	unsigned char x[4];

	if (fread(x, 1, 4, file) != 4
	    || fread(&types[i].isdst, 1, 1, file) != 1
	    || fread(&types[i].abbr_idx, 1, 1, file) != 1)
	  [NSException raise: fileException format: errMess];
	types[i].offset = decode(x);
      }

    /* Read in time zone abbreviation strings. */
    zone_abbrevs = NSZoneMalloc(NSDefaultMallocZone(), names_size);
    if (fread(zone_abbrevs, 1, names_size, file) != names_size)
      [NSException raise: fileException format: errMess];
    abbrevsArray = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*names_size);
    i = 0;
    while (i < names_size)
      {
	abbrevsArray[i] = [NSString stringWithCString: zone_abbrevs+i];
	i = (strchr(zone_abbrevs+i, '\0')-zone_abbrevs)+1;
      }
    NSZoneFree(NSDefaultMallocZone(), zone_abbrevs);

    /* Create time zone details. */
    detailsArray = [[NSMutableArray alloc] initWithCapacity: n_types];
    for (i = 0; i < n_types; i++)
      {
        NSConcreteTimeZoneDetail	*detail;

	detail = [[NSConcreteTimeZoneDetail alloc]
			initWithTimeZone: zone
			      withAbbrev: abbrevsArray[types[i].abbr_idx]
			      withOffset: types[i].offset
				 withDST: (types[i].isdst > 0)];
	[detailsArray addObject: detail];
	RELEASE(detail);
      }
    NSZoneFree(NSDefaultMallocZone(), abbrevsArray);
    NSZoneFree(NSDefaultMallocZone(), types);

    [zone initWithName: [aTimeZoneName copy] withTransitions: transArray
	  withDetails: detailsArray];
    [zoneDictionary setObject: zone forKey: aTimeZoneName];
  NS_HANDLER
    if (zone != nil)
      RELEASE(zone);
    if ([localException name] != fileException)
      [localException raise];
    zone = nil;
    NSLog(@"Unable to obtain time zone `%@'.", aTimeZoneName);
  NS_ENDHANDLER

  if (file != NULL)
    fclose(file);
  [zone_mutex unlock];
  return zone;
}

- (NSTimeZoneDetail*)timeZoneDetailForDate: (NSDate*)date
{
  return [self subclassResponsibility: _cmd];
}

+ (void)setDefaultTimeZone: (NSTimeZone*)aTimeZone
{
  if (aTimeZone == nil)
    [NSException raise: NSInvalidArgumentException
		 format: @"Nil time zone specified."];
  ASSIGN(aTimeZone, localTimeZone);
}

+ (NSDictionary*)abbreviationDictionary
{
  return fake_abbrev_dict;
}

+ (NSDictionary*)abbreviationMap
{
  /* Instead of creating the abbreviation dictionary when the class is
     initialized, we create it when we first need it, since the
     dictionary can be potentially very large, considering that it's
     almost never used. */

  static NSMutableDictionary *abbreviationDictionary = nil;
  FILE *file; // For the file containing the abbreviation dictionary
  char abbrev[80], name[80];
  NSString *fileName;

  if (abbreviationDictionary != nil)
    return abbreviationDictionary;

  /* Read dictionary from file. */
  abbreviationDictionary = [[NSMutableDictionary alloc] init];
  fileName = [NSTimeZone getAbbreviationFile];
#if	defined(__WIN32__)
  file = fopen([fileName fileSystemRepresentation], "rb");
#else
  file = fopen([fileName fileSystemRepresentation], "r");
#endif
  if (file == NULL)
    [NSException
      raise: NSInternalInconsistencyException
      format: @"Failed to open time zone abbreviation dictionary."];
  while (fscanf(file, "%79s %79s", abbrev, name) == 2)
    {
      id a, the_name, the_abbrev;

      the_name = [NSString stringWithCString: name];
      the_abbrev = [NSString stringWithCString: abbrev];
      a = [abbreviationDictionary objectForKey: the_abbrev];
      if (a == nil)
	{
	  a = [[NSMutableArray alloc] init];
	  [abbreviationDictionary setObject: a forKey: the_abbrev];
	}
      [a addObject: the_name];
    }
  fclose(file);

  return abbreviationDictionary;
}

- (NSString*)timeZoneName
{
  return [self subclassResponsibility: _cmd];
}

+ (NSArray*)timeZoneArray
{
  /* We create the array only when we need it to reduce overhead. */

  static NSArray *regionsArray = nil;
  int index, i;
  char name[80];
  FILE *file;
  id temp_array[24];
  NSString *fileName;

  if (regionsArray != nil)
    return regionsArray;

  for (i = 0; i < 24; i++)
    temp_array[i] = [[NSMutableArray alloc] init];

  fileName = [NSTimeZone getRegionsFile];
#if	defined(__WIN32__)
  file = fopen([fileName fileSystemRepresentation], "rb");
#else
  file = fopen([fileName fileSystemRepresentation], "r");
#endif
  if (file == NULL)
    [NSException
      raise: NSInternalInconsistencyException
      format: @"Failed to open time zone regions array file."];
  while (fscanf(file, "%d %s", &index, name) == 2)
    [temp_array[index] addObject: [[NSString alloc] initWithCString: name]];
  fclose(file);
  regionsArray = [[NSArray alloc] initWithObjects: temp_array count: 24];
  return regionsArray;
}

- (NSArray*)timeZoneDetailArray
{
  return [self subclassResponsibility: _cmd];
}

@end
  

@implementation NSTimeZoneDetail

- (NSString*)description
{
  return [NSString
	   stringWithFormat: @"%@(%@, %s%d)",
	   [self timeZoneName],
	   [self timeZoneAbbreviation],
	   ([self isDaylightSavingTimeZone]? "IS_DST, ": ""),
	   [self timeZoneSecondsFromGMT]];
}

- (BOOL)isDaylightSavingTimeZone
{
  [self subclassResponsibility: _cmd];
  return NO;
}
  
- (NSString*)timeZoneAbbreviation
{
  return [self subclassResponsibility: _cmd];
}
  
- (int)timeZoneSecondsFromGMT
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end


@implementation NSTimeZone (Private)

+ (NSString*)getAbbreviationFile
{
  return [NSBundle pathForGNUstepResource: ABBREV_DICT
		   ofType: @""
		   inDirectory: TIME_ZONE_DIR];
}

+ (NSString*)getRegionsFile
{
  return [NSBundle pathForGNUstepResource: REGIONS_FILE
		   ofType: @""
		   inDirectory: TIME_ZONE_DIR];
}

+ (NSString*)getLocalTimeFile
{
  return [NSBundle pathForGNUstepResource: LOCAL_TIME_FILE
		   ofType: @""
		   inDirectory: TIME_ZONE_DIR];
}

+ (NSString*)getTimeZoneFile: (NSString *)name
{
  NSString *fileName = [NSString stringWithFormat: @"%@%@",
				 ZONES_DIR, name];

  return [NSBundle pathForGNUstepResource: fileName
		   ofType: @""
		   inDirectory: TIME_ZONE_DIR];
}

@end
