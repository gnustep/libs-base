/** Time zone management. -*- Mode: ObjC -*-
   Copyright (C) 1997-2002 Free Software Foundation, Inc.
  
   Written by: Yoo C. Chung <wacko@laplace.snu.ac.kr>
   Date: June 1997
  
   Rewritw large chunks by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: September 2002
  
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
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSTimeZone class reference</title>
   $Date$ $Revision$
 */
  
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
   database, the GNUSTEP_TZ environment variable, the file LOCAL_TIME_FILE,
   the TZ environment variable, or the fallback time zone (which is UTC),
   with the ones listed first having precedence.

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
#include <Foundation/NSData.h>
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
#include <Foundation/NSMapTable.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSTimeZone.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSDebug.h>
#include <GSConfig.h>

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


@class GSAbsTimeZone;
@class GSTimeZoneDetail;
@class GSAbsTimeZoneDetail;

@class	GSPlaceholderTimeZone;

/*
 * Information for abstract placeholder class.
 */
static GSPlaceholderTimeZone	*defaultPlaceholderTimeZone;
static NSMapTable		*placeholderMap;

/*
 * Temporary structure for holding time zone details.
 * This is the format in the data object.
 */
struct ttinfo
{
  char offset[4]; // Seconds east of UTC
  unsigned char isdst; // Daylight savings time?
  unsigned char abbr_idx; // Index into time zone abbreviations string
};

/*
 * And this is the structure used in the time zone instances.
 */
typedef struct {
  gss32		offset;
  BOOL		isdst;
  unsigned char	abbr_idx;
  char		pad[2];
  NSString	*abbreviation;
} TypeInfo;

@interface	GSTimeZone : NSTimeZone
{
@public
  NSString	*timeZoneName;
  NSData	*timeZoneData;
  unsigned int	n_trans;
  unsigned int	n_types;
  gss32		*trans;
  TypeInfo	*types;
  unsigned char	*idxs;
}
@end


static NSTimeZone	*defaultTimeZone = nil;
static NSTimeZone	*localTimeZone = nil;
static NSTimeZone	*systemTimeZone = nil;

/* Dictionary for time zones.  Each time zone must have a unique
   name. */
static NSMutableDictionary *zoneDictionary;

/* Fake one-to-one abbreviation to time zone name dictionary. */
static NSDictionary *fake_abbrev_dict;

/* Lock for creating time zones. */
static NSRecursiveLock *zone_mutex = nil;

static Class	NSTimeZoneClass;
static Class	GSPlaceholderTimeZoneClass;

/* Decode the four bytes at PTR as a signed integer in network byte order.
   Based on code included in the GNU C Library 2.0.3. */
static inline int
decode (const void *ptr)
{
#if defined(WORDS_BIGENDIAN) && SIZEOF_INT == 4
#if NEED_WORD_ALIGNMENT
  int value;
  memcpy(&value, ptr, sizeof(int));
  return value;
#else
  return *(const int *) ptr;
#endif
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

- (id) initWithDict: (NSDictionary*)aDict;
@end


/* Front end that actually uses [NSTimeZone abbrebiationMap]. */
@interface NSInternalAbbrevDict : NSDictionary
@end
  
  
@interface GSPlaceholderTimeZone : NSTimeZone
@end
  
@interface GSAbsTimeZone : NSTimeZone
{
@public
  NSString	*name;
  id		detail;
  int		offset; // Offset from UTC in seconds.
}

- (id) initWithOffset: (int)anOffset;
@end
  
@interface NSLocalTimeZone : NSTimeZone
@end

@interface GSTimeZoneDetail : NSTimeZoneDetail
{
  NSTimeZone	*timeZone; // Time zone which created this object.
  NSString	*abbrev; // Abbreviation for time zone detail.
  int		offset; // Offset from UTC in seconds.
  BOOL		is_dst; // Is it daylight savings time?
}

- (id) initWithTimeZone: (NSTimeZone*)aZone
	     withAbbrev: (NSString*)anAbbrev
	     withOffset: (int)anOffset
		withDST: (BOOL)isDST;
@end
  
@interface GSAbsTimeZoneDetail : NSTimeZoneDetail
{
  GSAbsTimeZone	*zone; // Time zone which created this object.
}

- (id) initWithTimeZone: (GSAbsTimeZone*)aZone;
@end
  
/* Private methods for obtaining resource file names. */
@interface NSTimeZone (Private)
+ (void) _becomeThreaded: (NSNotification*)notification;
+ (NSString*) getAbbreviationFile;
+ (NSString*) getRegionsFile;
+ (NSString*) getTimeZoneFile: (NSString*)name;
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

+ (id) allocWithZone: (NSZone*)zone
{
  return NSAllocateObject(self, 0, zone);
}

- (id) init
{
  return self;
}

- (unsigned) count
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


@implementation GSPlaceholderTimeZone

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised time zone");
  return self;		// placeholders never get released.
}

- (void) dealloc
{
  return;		// placeholders never get deallocated.
}

- (id) initWithName: (NSString*)name data: (NSData*)data
{
  NSTimeZone	*zone;
  unsigned	length = [name length];

  if (length == 0)
    {
      NSLog(@"Disallowed null time zone name");
      return nil;
    }
  if (length == 15 && [name isEqual: @"NSLocalTimeZone"])
    {
      zone = RETAIN(localTimeZone);
      DESTROY(self);
      return zone;
    }

  /*
   * Return a cached time zone if possible.
   * NB. if data of cached zone does not match new data ... don't use cache
   */
  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  zone = [zoneDictionary objectForKey: name];
  if (data != nil && [data isEqual: [zone data]] == NO)
    {
      zone = nil;
    }
  IF_NO_GC(RETAIN(zone));
  if (zone_mutex != nil)
    {
      [zone_mutex unlock];
    }

  if (zone == nil)
    {
      unichar	c;
      unsigned	i;

      if (length == 8 && [name hasPrefix: @"GMT"] == YES
	&& ((c = [name characterAtIndex: 3]) == '+' || c == '-'))
	{
	  c = [name characterAtIndex: 4];
	  if (c >= '0' && c <= '9')
	    {
	      i = c - '0';
	      c = [name characterAtIndex: 5];
	      if (c >= '0' && c <= '9')
		{
		  i = i * 10 + (c - '0');
		  c = [name characterAtIndex: 6];
		  if (c >= '0' && c <= '9')
		    {
		      i = i * 6 + (c - '0');
		      c = [name characterAtIndex: 7];
		      if (c >= '0' && c <= '9')
			{
			  i = i * 10 + (c - '0');
			  zone = [[GSAbsTimeZone alloc] initWithOffset: i*60];
			}
		    }
		}
	    }
	}

      if (zone == nil && length > 19
	&& [name hasPrefix: @"NSAbsoluteTimeZone:"] == YES)
	{
	  i = [[name substringFromIndex: 19] intValue];

	  zone = [[GSAbsTimeZone alloc] initWithOffset: i];
	}

      if (zone == nil)
	{
	  if (data == nil)
	    {
	      NSString		*fileName;
	      const char	*str = [name UTF8String];

	      /* Make sure that only time zone files are accessed.
		 FIXME: Make this more robust. */
	      if ((str)[0] == '/' || strchr(str, '.') != NULL)
		{
		  NSLog(@"Disallowed time zone name `%@'.", name);
		  return nil;
		}

	      fileName = [NSTimeZoneClass getTimeZoneFile: name];
	      if (fileName == nil)
		{
		  NSLog(@"Unknown time zone name `%@'.", name);
		  return nil;
		}
	      data = [NSData dataWithContentsOfFile: fileName];
	    }
	  zone = [[GSTimeZone alloc] initWithName: name data: data];
	}
    }
  RELEASE(self);
  return zone;
}

- (void) release
{
  return;		// placeholders never get released.
}

- (id) retain
{
  return self;		// placeholders never get retained.
}
@end



@implementation	NSLocalTimeZone
  
- (NSString*) abbreviation
{
  return [[NSTimeZoneClass defaultTimeZone] abbreviation];
}

- (NSString*) abbreviationForDate: (NSDate*)aDate
{
  return [[NSTimeZoneClass defaultTimeZone] abbreviationForDate: aDate];
}

- (id) autorelease
{
  return self;
}

- (NSData*) data
{
  return [[NSTimeZoneClass defaultTimeZone] data];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: @"NSLocalTimeZone"];
}

- (id) init
{
  return self;
}

- (BOOL) isDaylightSavingTime
{
  return [[NSTimeZoneClass defaultTimeZone] isDaylightSavingTime];
}

- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate
{
  return [[NSTimeZoneClass defaultTimeZone] isDaylightSavingTimeForDate: aDate];
}

- (NSString*) name
{
  return [[NSTimeZoneClass defaultTimeZone] name];
}

- (void) release
{
}

- (id) retain
{
  return self;
}

- (int) secondsFromGMT
{
  return [[NSTimeZoneClass defaultTimeZone] secondsFromGMT];
}

- (int) secondsFromGMTForDate: (NSDate*)aDate
{
  return [[NSTimeZoneClass defaultTimeZone] secondsFromGMTForDate: aDate];
}

- (NSArray*) timeZoneDetailArray
{
  return [[NSTimeZoneClass defaultTimeZone] timeZoneDetailArray];
}
  
- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return [[NSTimeZoneClass defaultTimeZone] timeZoneDetailForDate: date];
}

- (NSString*) timeZoneName
{
  return [[NSTimeZoneClass defaultTimeZone] timeZoneName];
}

@end
  
@implementation GSAbsTimeZone

static NSMapTable	*absolutes = 0;

+ (void) initialize
{
  if (self == [GSAbsTimeZone class])
    {
      absolutes = NSCreateMapTable(NSIntMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

- (NSString*) abbreviationForDate: (NSDate*)aDate
{
  return name;
}

- (void) dealloc
{
  if (zone_mutex != nil)
    [zone_mutex lock];
  NSMapRemove(absolutes, (void*)(gsaddr)offset);
  if (zone_mutex != nil)
    [zone_mutex unlock];
  RELEASE(name);
  RELEASE(detail);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: name];
}

- (id) initWithOffset: (int)anOffset
{
  GSAbsTimeZone	*z;
  int		extra;
  int		sign = anOffset >= 0 ? 1 : -1;

  /*
   * Round the offset to the nearest minute, (for MacOS-X compatibility)
   * and ensure it is no more than 18 hours.
   */
  anOffset *= sign;
  extra = anOffset % 60;
  if (extra < 30)
    {
      anOffset -= extra;
    }
  else
    {
      anOffset += 60 - extra;
    }
  if (anOffset > 64800)
    {
      RELEASE(self);
      return nil;
    }
  anOffset *= sign;

  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  z = (GSAbsTimeZone*)NSMapGet(absolutes, (void*)(gsaddr)anOffset);
  if (z != nil)
    {
      IF_NO_GC(RETAIN(z));
      RELEASE(self);
    }
  else
    {
      if (anOffset % 60 == 0)
	{
	  char	s = (anOffset >= 0) ? '+' : '-';
	  int	i = (anOffset >= 0) ? anOffset / 60 : -anOffset / 60;
	  int	h = i / 60;
	  int	m = i % 60;

	  name = [[NSString alloc] initWithFormat: @"GMT%c%02d%02d", s, h, m];
	}
      else
	{
	  /*
	   * Should never happen now we round to the minute
	   * for MacOS-X compatibnility.
	   */
	  name = [[NSString alloc] initWithFormat: @"NSAbsoluteTimeZone:%d",
	    anOffset];
	}
      detail = [[GSAbsTimeZoneDetail alloc] initWithTimeZone: self];
      offset = anOffset;
      z = self;
      NSMapInsert(absolutes, (void*)(gsaddr)anOffset, (void*)z);
      [zoneDictionary setObject: self forKey: (NSString*)name];
    }
  if (zone_mutex != nil)
    {
      [zone_mutex unlock];
    }
  return z;
}

- (BOOL) isDaylightSavingTimeZoneForDate: (NSDate*)aDate
{
  return NO;
}

- (NSString*) name
{
  return name;
}

- (int) secondsFromGMTForDate: (NSDate*)aDate
{
  return offset;
}

- (NSTimeZone*) timeZoneDetailTimeZone
{
  return [NSTimeZone arrayWithObject: detail];
}
  
- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return detail;
}
  
- (NSString*) timeZoneName
{
  return name;
}
@end
  
  
@implementation GSTimeZoneDetail
  
- (void) dealloc
{
  RELEASE(timeZone);
  [super dealloc];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  [aDecoder decodeValueOfObjCType: @encode(id) at: &abbrev];
  [aDecoder decodeValueOfObjCType: @encode(int) at: &offset];
  [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &is_dst];
  return self;
}

- (id) initWithTimeZone: (NSTimeZone*)aZone
	     withAbbrev: (NSString*)anAbbrev
	     withOffset: (int)anOffset
		withDST: (BOOL)isDST
{
  timeZone = RETAIN(aZone);
  abbrev = anAbbrev;		// NB. Depend on this being retained in aZone
  offset = anOffset;
  is_dst = isDST;
  return self;
}
  
- (BOOL) isDaylightSavingTimeZone
{
  return is_dst;
}
  
- (NSString*) name
{
  return [timeZone name];
}
 
- (NSString*) timeZoneAbbreviation
{
  return abbrev;
}
  
- (NSArray*) timeZoneDetailArray
{
  return [timeZone timeZoneDetailArray];
}

- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return [timeZone timeZoneDetailForDate: date];
}

- (int) timeZoneSecondsFromGMT
{
  return offset;
}

- (int) timeZoneSecondsFromGMTForDate: (NSDate*)aDate
{
  return offset;
}
  
@end



@implementation GSAbsTimeZoneDetail
  
- (NSString*) abbreviation
{
  return zone->name;
}

- (NSString*) abbreviationForDate: (NSDate*)aDate
{
  return zone->name;
}

- (void) dealloc
{
  RELEASE(zone);
  [super dealloc];
}

- (id) initWithTimeZone: (GSAbsTimeZone*)aZone
{
  zone = RETAIN(aZone);
  return self;
}
  
- (BOOL) isDaylightSavingTimeZone
{
  return NO;
}
  
- (BOOL) isDaylightSavingTimeZoneForDate: (NSDate*)aDate
{
  return NO;
}
  
- (NSString*) name
{
  return zone->name;
}
 
- (NSString*) timeZoneAbbreviation
{
  return zone->name;
}
  
- (NSArray*) timeZoneDetailArray
{
  return [zone timeZoneDetailArray];
}

- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return self;
}

- (int) timeZoneSecondsFromGMT
{
  return zone->offset;
}

- (int) timeZoneSecondsFromGMTForDate: (NSDate*)aDate
{
  return zone->offset;
}
  
@end



/**
 * <p>
 * If the GNUstep time zone datafiles become too out of date, one
 * can download an updated database from <uref
 * url="ftp://elsie.nci.nih.gov/pub/">ftp://elsie.nci.nih.gov/pub/</uref>
 * and compile it as specified in the README file in the
 * NSTimeZones directory.
 * </p>
 * <p>Time zone names in NSDates should be GMT, MET etc. not
 * Europe/Berlin, America/Washington etc.
 * </p>
 * <p>The problem with this is that various time zones may use the
 * same abbreviation (e.g. Australia/Brisbane and
 * America/New_York both use EST), and some time zones
 * may have different rules for daylight saving time even if the
 * abbreviation and offsets from UTC are the same.
 * </p>
 * <p>The problems with depending on the OS for providing time zone
 * info are that some methods for the NSTimeZone classes might be
 * difficult to implement, and also that time zone names may vary
 * wildly between OSes (this could be a big problem when
 * archiving is used between different systems).
 * </p>
 */
@implementation NSTimeZone

+ (NSDictionary*) abbreviationDictionary
{
  return fake_abbrev_dict;
}

+ (NSDictionary*) abbreviationMap
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

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSTimeZoneClass)
    {
      /*
       * We return a placeholder object that can
       * be converted to a real object when its initialisation method
       * is called.
       */
      if (z == NSDefaultMallocZone() || z == 0)
	{
	  /*
	   * As a special case, we can return a placeholder for a time zone
	   * in the default malloc zone extremely efficiently.
	   */
	  return defaultPlaceholderTimeZone;
	}
      else
	{
	  id	obj;

	  /*
	   * For anything other than the default zone, we need to
	   * locate the correct placeholder in the (lock protected)
	   * table of placeholders.
	   */
	  if (zone_mutex != nil)
	    {
	      [zone_mutex lock];
	    }
	  obj = (id)NSMapGet(placeholderMap, (void*)z);
	  if (obj == nil)
	    {
	      /*
	       * There is no placeholder object for this zone, so we
	       * create a new one and use that.
	       */
	      obj = (id)NSAllocateObject(GSPlaceholderTimeZoneClass, 0, z);
	      NSMapInsert(placeholderMap, (void*)z, (void*)obj);
	    }
	  if (zone_mutex != nil)
	    {
	      [zone_mutex unlock];
	    }
	  return obj;
	}
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

/**
 * Return the default time zone for this process.
 */
+ (NSTimeZone*) defaultTimeZone
{
  NSTimeZone	*zone;

  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  if (defaultTimeZone == nil)
    {
      zone = [self systemTimeZone];
    }
  else
    {
      if (zone_mutex != nil)
	{
	  zone = AUTORELEASE(RETAIN(defaultTimeZone));
	}
      else
	{
	  zone = defaultTimeZone;
	}
    }
  if (zone_mutex != nil)
    {
      [zone_mutex unlock];
    }
  return zone;
}

+ (void) initialize
{
  if (self == [NSTimeZone class])
    {
      NSTimeZoneClass = self;
      GSPlaceholderTimeZoneClass = [GSPlaceholderTimeZone class];
      zoneDictionary = [[NSMutableDictionary alloc] init];

      /*
       * Set up infrastructure for placeholder timezones.
       */
      defaultPlaceholderTimeZone = (GSPlaceholderTimeZone*)
	NSAllocateObject(GSPlaceholderTimeZoneClass, 0, NSDefaultMallocZone());
      placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);

      localTimeZone = [[NSLocalTimeZone alloc] init];

      fake_abbrev_dict = [[NSInternalAbbrevDict alloc] init];
      if ([NSThread isMultiThreaded])
	{
	  [self _becomeThreaded: nil];
	}
      else
	{
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	       selector: @selector(_becomeThreaded:)
		   name: NSWillBecomeMultiThreadedNotification
		 object: nil];
	}
    }
}

/**
 * Return a proxy to the default time zone for this process.
 */
+ (NSTimeZone*) localTimeZone
{
  return localTimeZone;
}

/**
 * Destroy the system time zone so that it will be recreated
 * next time it is used.
 */
+ (void) resetSystemTimeZone
{
  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  DESTROY(systemTimeZone);
  if (zone_mutex != nil)
    {
      [zone_mutex unlock];
    }
}

/**
 * Set the default time zone to be used for this process.
 */
+ (void) setDefaultTimeZone: (NSTimeZone*)aTimeZone
{
  if (aTimeZone != defaultTimeZone)
    {
      /*
       * We can't make the localTimeZone the default since that would
       * cause recursion ...
       */
      if (aTimeZone == localTimeZone)
	{
	  aTimeZone = [self systemTimeZone];
	}
      if (zone_mutex != nil)
	{
	  [zone_mutex lock];
	}
      ASSIGN(defaultTimeZone, aTimeZone);
      if (zone_mutex != nil)
	{
	  [zone_mutex unlock];
	}
    }
}

/**
 * Returns the current system time zone for the process.
 */
+ (NSTimeZone*) systemTimeZone
{
  NSTimeZone	*zone = nil;

  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  if (systemTimeZone == nil)
    {
      NSString	*localZoneString = nil;

      /*
       * setup default value in case something goes wrong.
       */
      systemTimeZone = RETAIN([NSTimeZoneClass timeZoneForSecondsFromGMT: 0]);

      localZoneString = [[NSUserDefaults standardUserDefaults]
	stringForKey: LOCALDBKEY];
      if (localZoneString == nil)
	{
	  /*
	   * Try to get timezone from GNUSTEP_TZ environment variable.
	   */
	  localZoneString = [[[NSProcessInfo processInfo]
	    environment] objectForKey: @"GNUSTEP_TZ"];
	}
      if (localZoneString == nil)
	{
	  /*
	   * Try to get timezone from LOCAL_TIME_FILE.
	   */
	  NSString	*f;

	  f = [NSBundle pathForGNUstepResource: LOCAL_TIME_FILE
					ofType: @""
				   inDirectory: TIME_ZONE_DIR];
	  if (f != nil)
	    {
	      localZoneString = [NSString stringWithContentsOfFile: f];
	      localZoneString = [localZoneString stringByTrimmingSpaces];
	    }
	}
      if (localZoneString == nil)
	{
	  /*
	   * Try to get timezone from standard unix environment variable.
	   */
	  localZoneString = [[[NSProcessInfo processInfo]
	    environment] objectForKey: @"TZ"];
	}
      if (localZoneString != nil)
	{
	  zone = [defaultPlaceholderTimeZone initWithName: localZoneString];
	}
      else
	{
	  NSLog(@"No local time zone specified.");
	}

      /*
       * If local time zone fails to allocate, then allocate something
       * that is sure to succeed (unless we run out of memory, of
       * course).
       */
      if (zone == nil)
        {
          NSLog(@"Using time zone with absolute offset 0.");
          zone = systemTimeZone;
        }
      ASSIGN(systemTimeZone, zone);
    }
  if (zone_mutex != nil)
    {
      zone = AUTORELEASE(RETAIN(systemTimeZone));
      [zone_mutex unlock];
    }
  else
    {
      zone = systemTimeZone;
    }
  return zone;
}

+ (NSArray*) timeZoneArray
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
    temp_array[i] = [NSMutableArray array];

  fileName = [NSTimeZoneClass getRegionsFile];
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
    [temp_array[index] addObject: [NSString stringWithCString: name]];
  fclose(file);
  regionsArray = [[NSArray alloc] initWithObjects: temp_array count: 24];
  return regionsArray;
}

/**
 * Return a timezone for the specified offset from GMT.<br />
 * The timezone returned does <em>not</em> use daylight savings time.
 * The actual timezone returned has an offset rounded to the nearest
 * minute.<br />
 * Time zones with an offset of more than +/- 18 hours  are disallowed,
 * and nil is returned.
 */
+ (NSTimeZone*) timeZoneForSecondsFromGMT: (int)seconds
{
  NSTimeZone	*zone;

  zone = [[GSAbsTimeZone alloc] initWithOffset: seconds];
  return AUTORELEASE(zone);
}

/**
 * Returns a timezone for the specified abbrevition,
 */
+ (NSTimeZone*) timeZoneWithAbbreviation: (NSString*)abbreviation
{
  NSTimeZone	*zone;

  zone = [self timeZoneWithName: [[self abbreviationDictionary]
				   objectForKey: abbreviation] data: nil];
  return zone;
}

/**
 * Returns a timezone for the specified name.
 */
+ (NSTimeZone*) timeZoneWithName: (NSString*)aTimeZoneName
{
  NSTimeZone	*zone;

  zone = [defaultPlaceholderTimeZone initWithName: aTimeZoneName data: nil];
  return AUTORELEASE(zone);
}

/**
 * Returns a timezone for the specified name, created from the supplied data.
 */
+ (NSTimeZone*) timeZoneWithName: (NSString*)name data: (NSData*)data
{
  NSTimeZone	*zone;

  zone = [defaultPlaceholderTimeZone initWithName: name data: nil];
  return AUTORELEASE(zone);
}

/**
 * Returns the abbreviation for this timezone now.
 * Invokes -abbreviationForDate:
 */
- (NSString*) abbreviation
{
  return [self abbreviationForDate: [NSDate date]];
}

/**
 * Returns the abbreviation for this timezone at aDate.  This may differ
 * depending on whether daylight savings time is in effect or not.
 */
- (NSString*) abbreviationForDate: (NSDate*)aDate
{
  NSTimeZoneDetail	*detail;
  NSString		*abbr;

  detail = [self timeZoneDetailForDate: aDate];
  abbr = [detail timeZoneAbbreviation];

  return abbr;
}

- (Class) classForCoder
{
  return NSTimeZoneClass;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

/**
 * Returns the data with which the receiver was initialised.
 */
- (NSData*) data
{
  return nil;
}

- (NSString*) description
{
  return [self name];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: [self name]];
}

- (id) init
{
  return [self initWithName: @"NSLocalTimeZone" data: nil];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  NSString	*name;

  name = [aDecoder decodeObject];
  self = [self initWithName: name data: nil];
  return self;
}

/**
 * Initialise a timezone with the supplied name.  May return a cached
 * timezone object rather than the newly created one.
 */
- (id) initWithName: (NSString*)name
{
  return [self initWithName: name data: nil];
}

/**
 * Initialises a time zone object using the supplied data object.<br />
 * This method is intended for internal use by the NSTimeZone
 * class cluster.
 * Don't use it ... use -initWithName: instead.
 */
- (id) initWithName: (NSString*)name data: (NSData*)data
{
  [self notImplemented: _cmd];
  return nil;
}

/**
 * Returns a boolean indicating whether daylight savings time is in
 * effect now.  Invokes -isDaylightSavingTimeForDate:
 */
- (BOOL) isDaylightSavingTime
{
  return [self isDaylightSavingTimeForDate: [NSDate date]];
}

/**
 * Returns a boolean indicating whether daylight savings time is in
 * effect for this time zone at aDate.
 */
- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate
{
  NSTimeZoneDetail	*detail;
  BOOL			isDST;

  detail = [self timeZoneDetailForDate: aDate];
  isDST = [detail isDaylightSavingTimeZone];

  return isDST;
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    return YES;
  if ([other isKindOfClass: NSTimeZoneClass] == NO)
    return NO;
  return [self isEqualToTimeZone: other];
}

- (BOOL) isEqualToTimeZone: (NSTimeZone*)aTimeZone
{
  if (aTimeZone == self)
    return YES;
  if ([[self name] isEqual: [aTimeZone name]] == NO)
    return NO;
  if (([self data] == nil && [aTimeZone data] == nil)
    || [[self name] isEqual: [aTimeZone name]] == YES)
    return YES;
  return NO;
}

- (NSString*) name
{
  return [self subclassResponsibility: _cmd];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    {
      return self;
    }
  return [super replacementObjectForPortCoder: aCoder];
}

/**
 * Returns the number of seconds by which the receiver differs
 * from Greenwich Mean Time at the current date and time.<br />
 * Invokes -secondsFromGMTForDate:
 */
- (int) secondsFromGMT
{
  return [self secondsFromGMTForDate: [NSDate date]];
}

/**
 * Returns the number of seconds by which the receiver differs
 * from Greenwich Mean Time at the date aDate.<br />
 * If the time zone uses dayl;ight savings time, the returned value
 * will vary at different times of year.
 */
- (int) secondsFromGMTForDate: (NSDate*)aDate
{
  NSTimeZoneDetail	*detail;
  int			offset;

  detail = [self timeZoneDetailForDate: aDate];
  offset = [detail timeZoneSecondsFromGMT];

  return offset;
}

- (NSArray*) timeZoneDetailArray
{
  return [self subclassResponsibility: _cmd];
}

- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return [self subclassResponsibility: _cmd];
}

- (NSString*) timeZoneName
{
  return [self name];
}

@end
  
/**
 * This class serves no useful purpose in GNUstep, and is provided
 * solely for backward compatibility with the OpenStep spec.  It is
 * missing entirely from MacOS-X.
 */
@implementation NSTimeZoneDetail

- (NSString*) description
{
  return [NSString stringWithFormat: @"%@(%@, %s%d)", [self name],
    [self timeZoneAbbreviation],
    ([self isDaylightSavingTimeZone]? "IS_DST, ": ""),
    [self timeZoneSecondsFromGMT]];
}

- (BOOL) isDaylightSavingTimeZone
{
  [self subclassResponsibility: _cmd];
  return NO;
}
  
- (NSString*) timeZoneAbbreviation
{
  return [self subclassResponsibility: _cmd];
}
  
- (int) timeZoneSecondsFromGMT
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end


@implementation NSTimeZone (Private)

/*
 *	When the system becomes multithreaded, we set a flag to say so
 */
+ (void) _becomeThreaded: (NSNotification*)notification
{
  if (zone_mutex == nil)
    {
      zone_mutex = [NSRecursiveLock new];
    }
  [[NSNotificationCenter defaultCenter]
    removeObserver: self
	      name: NSWillBecomeMultiThreadedNotification
	    object: nil];
}

+ (NSString*) getAbbreviationFile
{
  return [NSBundle pathForGNUstepResource: ABBREV_DICT
				   ofType: @""
			      inDirectory: TIME_ZONE_DIR];
}

+ (NSString*) getRegionsFile
{
  return [NSBundle pathForGNUstepResource: REGIONS_FILE
				   ofType: @""
			      inDirectory: TIME_ZONE_DIR];
}

+ (NSString*) getTimeZoneFile: (NSString *)name
{
  NSString	*dir;
  NSString	*path;

  dir = [NSString stringWithFormat: @"%@/%@", TIME_ZONE_DIR, ZONES_DIR];
  path = [NSBundle pathForGNUstepResource: name ofType: @"" inDirectory: dir];
  return path;
}

@end



@implementation	GSTimeZone

/**
 * Perform a binary search of a transitions table to locate the index
 * of the transition to use for a particular time interval since 1970.<br />
 * We locate the index of the highest transition before the date, or zero
 * if there is no transition before it.
 */
static TypeInfo*
chop(NSTimeInterval since, GSTimeZone *zone)
{
  gss32			when = (gss32)since;
  gss32			*trans = zone->trans;
  unsigned		hi = zone->n_trans;
  unsigned		lo = 0;
  int			i;

  if (hi == 0 || trans[0] > when)
    {
      unsigned	n_types = zone->n_types;

      /*
       * If the first transition is greater than our date,
       * we locate the first non-DST transition and use that offset,
       * or just use the first transition.
       */
      for (i = 0; i < n_types; i++)
	{
	  if (zone->types[i].isdst == 0)
	    {
	      return &zone->types[i];
	    }
	}
      return &zone->types[0];
    }
  else
    {
      for (i = hi/2; hi != lo; i = (hi + lo)/2)
	{
	  if (when < trans[i])
	    {
	      hi = i;
	    }
	  else if (when > trans[i])
	    {
	      lo = ++i;
	    }
	  else
	    {
	      break;
	    }
	}
      /*
       * If we went off the top of the table or the closest transition
       * was later than our date, we step back to find the last
       * transition before our date.
       */
      if (i == zone->n_trans || trans[i] > when)
	{
	  i--;
	}
      return &zone->types[zone->idxs[i]];
    }
}

static NSTimeZoneDetail*
newDetailInZoneForType(GSTimeZone *zone, TypeInfo *type)
{
  GSTimeZoneDetail	*detail;

  detail = [GSTimeZoneDetail alloc];
  detail = [detail initWithTimeZone: zone
			 withAbbrev: type->abbreviation
			 withOffset: type->offset
			    withDST: type->isdst];
  return detail;
}

- (NSString*) abbreviationForDate: (NSDate*)aDate
{
  TypeInfo	*type = chop([aDate timeIntervalSince1970], self);

  return type->abbreviation;
}

- (NSData*) data
{
  return timeZoneData;
}

- (void) dealloc
{
  RELEASE(timeZoneName);
  RELEASE(timeZoneData);
  if (types != 0)
    {
      unsigned	i;

      for (i = 0; i < n_types; i++)
	{
	  RELEASE(types[i].abbreviation);
	}
      NSZoneFree(NSDefaultMallocZone(), types);
    }
  [super dealloc];
}

- (id) initWithName: (NSString*)name data: (NSData*)data
{
  static NSString	*fileException = @"GSTimeZoneFileException";

  timeZoneName = [name copy];
  timeZoneData = [data copy];
  NS_DURING
    {
      const void	*bytes = [timeZoneData bytes];
      unsigned		length = [timeZoneData length];
      void		*buf;
      unsigned		pos = 0;
      unsigned		i, charcnt;
      unsigned char	*abbr;
      struct tzhead	*header;

      if (length < sizeof(struct tzhead))
	{
	  [NSException raise: fileException
		      format: @"File is too small"];
	}
      header = (struct tzhead *)(bytes + pos);
      pos += sizeof(struct tzhead);
      if (memcmp(header->tzh_magic, TZ_MAGIC, strlen(TZ_MAGIC)) != 0)
	{
	  [NSException raise: fileException
		      format: @"TZ_MAGIC is incorrect"];
	}
      n_trans = GSSwapBigI32ToHost(*(gss32*)header->tzh_timecnt);
      n_types = GSSwapBigI32ToHost(*(gss32*)header->tzh_typecnt);
      charcnt = GSSwapBigI32ToHost(*(gss32*)header->tzh_charcnt);

      i = pos;
      i += sizeof(gss32)*n_trans;
      if (i > length)
	{
	  [NSException raise: fileException
		      format: @"Transitions list is truncated"];
	}
      i += n_trans;
      if (i > length)
	{
	  [NSException raise: fileException
		      format: @"Transition indexes are truncated"];
	}
      i += sizeof(struct ttinfo)*n_types;
      if (i > length)
	{
	  [NSException raise: fileException
		      format: @"Types list is truncated"];
	}
      if (i + charcnt > length)
	{
	  [NSException raise: fileException
		      format: @"Abbreviations list is truncated"];
	}

      /*
       * Now calculate size we need to store the information
       * for efficient access ... not the same saze as the data
       * we received.
       */
      i = n_trans * (sizeof(gss32)+1) + n_types * sizeof(TypeInfo);
      buf = NSZoneMalloc(NSDefaultMallocZone(), i);
      types = (TypeInfo*)buf;
      buf += (n_types * sizeof(TypeInfo));
      trans = (gss32*)buf;
      buf += (n_trans * sizeof(gss32));
      idxs = (unsigned char*)buf;

      /* Read in transitions. */
      for (i = 0; i < n_trans; i++)
	{
	  trans[i] = GSSwapBigI32ToHost(*(gss32*)(bytes + pos));
	  pos += sizeof(gss32);
	}
      for (i = 0; i < n_trans; i++)
	{
	  idxs[i] = *(unsigned char*)(bytes + pos);
	  pos++;
	}
      for (i = 0; i < n_types; i++)
	{
	  struct ttinfo	*ptr = (struct ttinfo*)(bytes + pos);

	  types[i].isdst = (ptr->isdst != 0 ? YES : NO);
	  types[i].abbr_idx = ptr->abbr_idx;
	  types[i].offset = decode(ptr->offset);
	  pos += sizeof(struct ttinfo);
	}
      abbr = (char*)(bytes + pos);
      {
	id	abbrevs[charcnt];

	memset(abbrevs, '\0', sizeof(id)*charcnt);
	for (i = 0; i < n_types; i++)
	  {
	    int	loc = types[i].abbr_idx;

	    if (abbrevs[loc] == nil)
	      {
		abbrevs[loc] = [[NSString alloc] initWithCString: abbr + loc];
	      }
	    else
	      {
		RETAIN(abbrevs[loc]);
	      }
	    types[i].abbreviation = abbrevs[loc];
	  }
      }

      if (zone_mutex != nil)
	{
	  [zone_mutex lock];
	}
      [zoneDictionary setObject: self forKey: timeZoneName];
      if (zone_mutex != nil)
	{
	  [zone_mutex unlock];
	}
    }
  NS_HANDLER
    {
      DESTROY(self);
      NSLog(@"Unable to obtain time zone `%@'... %@", name, localException);
      if ([localException name] != fileException)
	{
	  [localException raise];
	}
    }
  NS_ENDHANDLER
  return self;
}

- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate
{
  TypeInfo	*type = chop([aDate timeIntervalSince1970], self);

  return type->isdst;
}

- (NSString*) name
{
  return timeZoneName;
}

- (int) secondsFromGMTForDate: (NSDate*)aDate
{
  TypeInfo	*type = chop([aDate timeIntervalSince1970], self);

  return type->offset;
}

- (NSArray*) timeZoneDetailArray
{
  NSTimeZoneDetail	*details[n_types];
  unsigned		i;
  NSArray		*array;

  for (i = 0; i < n_types; i++)
    {
      details[i] = newDetailInZoneForType(self, &types[i]);
    }
  array = [NSArray arrayWithObjects: details count: n_types];
  for (i = 0; i < n_types; i++)
    {
      RELEASE(details[i]);
    }
  return array;
}

- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)aDate
{
  TypeInfo		*type;
  NSTimeZoneDetail	*detail;

  type = chop([aDate timeIntervalSince1970], self);
  detail = newDetailInZoneForType(self, type);
  return AUTORELEASE(detail);
}

- (NSString*) timeZoneName
{
  return timeZoneName;
}

@end

