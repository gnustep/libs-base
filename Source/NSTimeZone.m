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
   time and such for every entry in the dictionary.

   The local time zone can be specified with the user defaults
   database (when it's properly implemented, that is), the TZ
   environment variable, or the fallback local time zone, with the
   ones listed first having precedence.

   Any time zone must be a file name in ZONES_DIR.

   FIXME?: use leap seconds? */


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
#include <gnustep/base/config.h>

#define NOID
#include "tzfile.h"


/* Key for local time zone in user defaults. */
#define LOCALDBKEY "Local Time Zone"

/* Fallback local time zone. */
#ifndef LOCAL_TIME_ZONE
#define LOCAL_TIME_ZONE "Universal"
#endif

/* Directory that contains the time zone data. */
#define TIME_ZONE_DIR "NSTimeZones/"

/* Location of time zone abbreviation dictionary.  It is a text file
   with each line comprised of the abbreviation, a whitespace, and the
   name.  Neither the abbreviation nor the name can contain
   whitespace, and each line must not be longer than 80 characters. */
#define ABBREV_DICT TIME_ZONE_DIR "abbreviations"

/* File holding regions grouped by latitude.  It is a text file with
   each line comprised of the latitude region, whitespace, and the
   name.  Neither the abbreviation not the name can contain
   whitespace, and each line must not be longer than 80 characters. */
#define REGIONS_FILE TIME_ZONE_DIR "regions"

/* Directory that contains the actual time zones. */
#define ZONES_DIR TIME_ZONE_DIR "zones/"


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
  int offset; // Offset from UTC in seconds.
}

+ timeZoneWithOffset: (int)anOffset;

- initWithOffset: (int)anOffset withName: (NSString*)aName;
  @end
  

@interface NSConcreteTimeZoneDetail : NSTimeZoneDetail
{
  NSString *abbrev; // Abbreviation for time zone detail.
  int offset; // Offset from UTC in seconds.
  BOOL is_dst; // Is it daylight savings time?
}

- initWithAbbrev: (NSString*)anAbbrev withOffset: (int)anOffset
	 withDST: (BOOL)isDST;
  @end
  
  
@implementation NSInternalAbbrevDict
  
+ allocWithZone: (NSZone*)zone
{
  return NSAllocateObject(self, 0, zone);
  }
  
- init
  {
  return self;
  }
  
- (unsigned)count
  {
  return [[NSTimeZone abbreviationMap] count];
  }

- (NSEnumerator*)keyEnumerator
  {
  return [[NSTimeZone abbreviationMap] keyEnumerator];
  }
  
- (NSEnumerator*)objectEnumerator
  {
  /* FIXME: this is a memory hungry implementation */
  id e, name, a;

  a = [NSMutableArray array];
  e = [[NSTimeZone abbreviationMap] keyEnumerator];
  while ((name = [e nextObject]) != nil)
    [a addObject: [[[NSTimeZone abbreviationMap] objectForKey: name]
		    objectAtIndex: 0]];
  return [a objectEnumerator];
  }
  
- objectForKey: key
  {
  return [[[NSTimeZone abbreviationMap] objectForKey: key] objectAtIndex: 0];
  }
  
  @end
  

@implementation NSInternalTimeTransition

- (NSString*)description
  {
  return [NSString
	   stringWithFormat: @"(trans: %d, idx: %d)",
	   trans_time, (int)detail_index];
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
  
- initWithName: (NSString*)aName withTransitions: (NSArray*)trans
   withDetails: (NSArray*)zoneDetails
  {
  [super init];
  name = [aName retain];
  transitions = [trans retain];
  details = [zoneDetails retain];
  return self;
  }
  
- (void)dealloc
  {
  [name release];
  [transitions release];
  [details release];
  [super dealloc];
  }
  
- (void)encodeWithCoder: aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeObject: name];
}

- initWithDecoder: aDecoder
  {
  /* FIXME?: is this right? */
  self = [super initWithCoder: aDecoder];
  return (self = (id)[NSTimeZone timeZoneWithName: [aDecoder decodeObject]]);
  }
  
- (NSString*)description
  {
  return [NSString stringWithFormat: @"(trans: %@, details: %@)",
		   [transitions description], [details description]];
}
  
- (NSTimeZoneDetail*)timeZoneDetailForDate: (NSDate*)date
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
  
- (NSArray*)timeZoneDetailArray
{
  return details;
  }
  
- (NSString*)timeZoneName
  {
  return name;
  }
  
  @end
  
  
@implementation NSConcreteAbsoluteTimeZone
  
+ timeZoneWithOffset: (int)anOffset
  {
  id newName, zone;
  
  
  
  newName = [NSString stringWithFormat: @"%d", anOffset];
  zone = [zoneDictionary objectForKey: newName];
  if (zone == nil)
    {
      zone = [[self alloc] initWithOffset: anOffset withName: newName];
      [zoneDictionary setObject: zone forKey: newName];
    }
  return zone;
}
  
- initWithOffset: (int)anOffset withName: (NSString*)aName
{
  [super init];
  name = [aName retain];
  offset = anOffset;
  return self;
  }
  
- (void)dealloc
  {
  [name release];
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
  name = [aDecoder decodeObject];
  offset = [name intValue];
  return self;
}
  
- (NSString*)description
{
  return [NSString stringWithFormat: @"(offset: %d)", offset];
  }
  
- (NSTimeZoneDetail*)timeZoneDetailForDate: (NSDate*)date
  {
  return [[[NSConcreteTimeZoneDetail alloc]
	    initWithAbbrev: name withOffset: offset withDST: NO]
	   autorelease];
}
  
- (NSString*)timeZoneName
{
  return name;
  }
  
- (NSArray*)timeZoneDetailArray
  {
  return [NSArray arrayWithObject: [self timeZoneDetailForDate: nil]];
}
  
@end
  
  
@implementation NSConcreteTimeZoneDetail
  
- initWithAbbrev: (NSString*)anAbbrev withOffset: (int)anOffset
	 withDST: (BOOL)isDST
  {
  [super init];
  abbrev = [anAbbrev retain];
  offset = anOffset;
  is_dst = isDST;
  return self;
  }
  
- (void)dealloc
  {
  [abbrev release];
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
  abbrev = [aDecoder decodeObject];
  [aDecoder decodeValueOfObjCType: @encode(int) at: &offset];
  [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &is_dst];
  return self;
  }
  
- (NSString*)description
  {
  return [NSString stringWithFormat: @"(abbrev: %@, offset: %d, is_dst: %d)",
		   abbrev, offset, (int)is_dst];
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

      /* Don't use this for now. */
#if 0
      localZoneString = [[NSUserDefaults standardUserDefaults]
			  stringForKey: @LOCALDBKEY];
#endif
      if (localZoneString == nil)
	localZoneString = [[[NSProcessInfo processInfo]
			     environment] objectForKey: @"TZ"];
      if (localZoneString != nil)
	localTimeZone = [NSTimeZone timeZoneWithName: localZoneString];
      else
	localTimeZone = [NSTimeZone timeZoneWithName: @LOCAL_TIME_ZONE];

      /* If local time zone fails to allocate, then allocate something
         that is sure to succeed (unless we run out of memory, of
         course). */
      if (localTimeZone == nil)
	localTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];

      [localTimeZone retain];

      fake_abbrev_dict = [[NSInternalAbbrevDict alloc] init];
      zoneDictionary = [[NSMutableDictionary dictionary] retain];
      [zoneDictionary setObject: localTimeZone
		      forKey: [localTimeZone timeZoneName]];
    }
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
  return [NSConcreteAbsoluteTimeZone timeZoneWithOffset: seconds];
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
    format: @"Time zone abbreviation %@ inconsistent", abbreviation];
  return nil;
}

+ (NSTimeZone*)timeZoneWithName: (NSString*)aTimeZoneName
{
  static NSString *fileException = @"fileException";
  id zone, fileName, transArray, detailsArray;
  int i, n_trans, n_types, names_size;
  id *abbrevsArray;
  char *trans, *type_idxs, *zone_abbrevs;
  struct tzhead header;
  struct ttinfo *types; // Temporary array for details
  FILE *file;

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
      || ([aTimeZoneName cStringNoCopy])[0] == '/'
      || strchr([aTimeZoneName cStringNoCopy], '.') != NULL)
    {
      [zone_mutex unlock];
      return nil;
    }

  fileName = [NSString stringWithFormat: @"%s%@", ZONES_DIR, aTimeZoneName];
  file = fopen([fileName cStringNoCopy], "rb");
  if (file == NULL)
    {
      [zone_mutex unlock];
      return nil;
    }

  NS_DURING
    /* Read header. */
    if (fread(&header, sizeof(struct tzhead), 1, file) != 1)
      [NSException raise: fileException format: nil];

    n_trans = decode(header.tzh_timecnt);
    n_types = decode(header.tzh_typecnt);
    names_size = decode(header.tzh_charcnt);

    /* Read in transitions. */
    trans = NSZoneMalloc(NSDefaultMallocZone(), 4*n_trans);
    type_idxs = NSZoneMalloc(NSDefaultMallocZone(), n_trans);
    if (fread(trans, 4, n_trans, file) != n_trans
	|| fread(type_idxs, 1, n_trans, file) != n_trans)
      [NSException raise: fileException format: nil];
    transArray = [NSMutableArray array];
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
	  [NSException raise: fileException format: nil];
	types[i].offset = decode(x);
      }

    /* Read in time zone abbreviation strings. */
    zone_abbrevs = NSZoneMalloc(NSDefaultMallocZone(), names_size);
    if (fread(zone_abbrevs, 1, names_size, file) != names_size)
      [NSException raise: fileException format: nil];
    abbrevsArray = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*names_size);
    i = 0;
    while (i < names_size)
      {
	abbrevsArray[i] = [NSString stringWithCString: zone_abbrevs+i];
	i = (strchr(zone_abbrevs+i, '\0')-zone_abbrevs)+1;
      }
    NSZoneFree(NSDefaultMallocZone(), zone_abbrevs);

    /* Create time zone details. */
    detailsArray = [NSMutableArray array];
    for (i = 0; i < n_types; i++)
      [detailsArray
	addObject: [[NSConcreteTimeZoneDetail alloc]
		     initWithAbbrev: abbrevsArray[types[i].abbr_idx]
		     withOffset: types[i].offset
		     withDST: (types[i].isdst > 0)]];
    NSZoneFree(NSDefaultMallocZone(), abbrevsArray);
    NSZoneFree(NSDefaultMallocZone(), types);
    zone = [[NSConcreteTimeZone alloc]
	     initWithName: aTimeZoneName
	     withTransitions: transArray
	     withDetails: detailsArray];
    [zoneDictionary setObject: zone forKey: aTimeZoneName];
    fclose(file);
  NS_HANDLER
    if ([localException name] != fileException)
      [localException raise];
    fclose(file);
    zone = nil;
  NS_ENDHANDLER

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
		 format: @"Nil time zone specified"];
  [localTimeZone release];
  localTimeZone = [aTimeZone retain];
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

  if (abbreviationDictionary != nil)
    return abbreviationDictionary;

  /* Read dictionary from file. */
  abbreviationDictionary = [[NSMutableDictionary dictionary] retain];
  file = fopen(ABBREV_DICT, "r");
  if (file == NULL)
    [NSException raise: NSInternalInconsistencyException
		 format: @"Failed to open time zone abbreviation dictionary"];
  while (fscanf(file, "%s %s", abbrev, name) == 2)
    {
      id a, the_name, the_abbrev;

      the_name = [NSString stringWithCString: name];
      the_abbrev = [NSString stringWithCString: abbrev];
      a = [abbreviationDictionary objectForKey: the_abbrev];
      if (a == nil)
	{
	  a = [NSMutableArray array];
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

  if (regionsArray != nil)
    return regionsArray;

  for (i = 0; i < 24; i++)
    temp_array[i] = [NSMutableArray array];

  file = fopen(REGIONS_FILE, "r");
  if (file == NULL)
    [NSException raise: NSInternalInconsistencyException
		 format: @"Failed to open regions array file"];
  while (fscanf(file, "%d %s", &index, name) == 2)
    [temp_array[index] addObject: [NSString stringWithCString: name]];
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

- (NSString*)timeZoneName
{
  return [self shouldNotImplement: _cmd];
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
