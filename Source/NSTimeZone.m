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
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */
  
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
#include <Foundation/NSDebug.h>

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

@class	GSPlaceholderTimeZone;

/*
 * Information for abstract placeholder class.
 */
static GSPlaceholderTimeZone	*defaultPlaceholderTimeZone;
static NSMapTable		*placeholderMap;

/* Temporary structure for holding time zone details. */
struct ttinfo
{
  char offset[4]; // Seconds east of UTC
  BOOL isdst; // Daylight savings time?
  char abbr_idx; // Index into time zone abbreviations string
};


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
  
  
@interface NSInternalTimeTransition : NSObject
{
  int trans_time; // When the transition occurs
  char detail_index; // Index of time zone detail
}
  
- (id) initWithTime: (int)aTime withIndex: (char)anIndex;
- (int) transTime;
- (char) detailIndex;
@end
  
@interface GSPlaceholderTimeZone : NSTimeZone
@end
  
@interface NSConcreteTimeZone : NSTimeZone
{
  NSString	*name;
  NSArray	*transitions; // Transition times and rules
  NSArray	*details; // Time zone details
}

- (id) initWithName: (NSString*)aName
    withTransitions: (NSArray*)trans
        withDetails: (NSArray*)zoneDetails;
@end
  

@interface NSConcreteAbsoluteTimeZone : NSTimeZone
{
  NSString *name;
  id detail;
  int offset; // Offset from UTC in seconds.
}

- (id) initWithOffset: (int)anOffset;
@end
  
@interface NSLocalTimeZone : NSTimeZone
@end


@interface NSConcreteTimeZoneDetail : NSTimeZoneDetail
{
  NSTimeZone *timeZone; // Time zone which created this object.
  NSString *abbrev; // Abbreviation for time zone detail.
  int offset; // Offset from UTC in seconds.
  BOOL is_dst; // Is it daylight savings time?
}

- (id) initWithTimeZone: (NSTimeZone*)aZone
	     withAbbrev: (NSString*)anAbbrev
	     withOffset: (int)anOffset
		withDST: (BOOL)isDST;
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


@implementation NSInternalTimeTransition

- (NSString*) description
{
  return [NSString stringWithFormat: @"%@(%d, %d)",
    [self class], trans_time, (int)detail_index];
}

- (id) initWithTime: (int)aTime withIndex: (char)anIndex
{
  [super init];
  trans_time = aTime;
  detail_index = anIndex;
  return self;
}

- (int) transTime
{
  return trans_time;
}

- (char) detailIndex
{
  return detail_index;
}

@end
  

@implementation GSPlaceholderTimeZone

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised time zone");
  return self;		// placeholders never get released.
}

- (id) objectAtIndex: (unsigned)index
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised time zone"];
  return 0;
}

- (void) dealloc
{
  return;		// placeholders never get deallocated.
}

- (id) initWithName: (NSString*)name
{
  NSTimeZone	*zone;

  /*
   * Quick return if it's the local timezone.
   */
  if ([name isEqual: @"NSLocalTimeZone"])
    {
      return [self initWithName: name data: nil];
    }

  /*
   * Return a chached time zone if possible.
   */
  if (zone_mutex != nil)
    {
      [zone_mutex lock];
    }
  zone = [zoneDictionary objectForKey: name];
  if (zone != nil)
    {
      IF_NO_GC(RETAIN(zone));
      if (zone_mutex != nil)
	{
	  [zone_mutex unlock];
	}
      return zone;
    }

  /*
   * Now return an absolute time zone or load one from file.
   */
  if ([name hasPrefix: @"NSAbsoluteTimeZone:"] == YES)
    {
      int	i = [[name substringFromIndex: 19] intValue];

      zone = [[NSConcreteAbsoluteTimeZone alloc] initWithOffset: i];
    }
  else
    {
      NSString	*fileName;
      NSData	*data;
      unsigned	length;

      length = [name length];
      if (length == 0)
	{
	  NSLog(@"Disallowed null time zone name");
	  return nil;
	}
      else
	{
	  const char	*str = [name lossyCString];

	  /* Make sure that only time zone files are accessed.
	     FIXME: Make this more robust. */
	  if ((str)[0] == '/' || strchr(str, '.') != NULL)
	    {
	      NSLog(@"Disallowed time zone name `%@'.", name);
	      return nil;
	    }
	}

      fileName = [NSTimeZoneClass getTimeZoneFile: name];
      if (fileName == nil)
	{
	  NSLog(@"Unknown time zone name `%@'.", name);
	  return nil;
	}
      data = [NSData dataWithContentsOfFile: fileName];
      zone = [self initWithName: name data: data];
    }
  return zone;
}

- (id) initWithName: (NSString*)name data: (NSData*)data
{
  NSTimeZone	*zone;

  if ([name isEqual: @"NSLocalTimeZone"])
    {
      zone = RETAIN(localTimeZone);
    }
  else if ([name hasPrefix: @"NSAbsoluteTimeZone:"] == YES)
    {
      int	i = [[name substringFromIndex: 19] intValue];

      zone = [[NSConcreteAbsoluteTimeZone alloc] initWithOffset: i];
    }
  else
    {
      static NSString	*fileException = @"fileException";
      static NSString	*errMess = @"File read error in NSTimeZone.";

      zone = nil;
      NS_DURING
	{
	  const void	*bytes = [data bytes];
	  unsigned	length = [data length];
	  unsigned	pos = 0;
	  id		transArray;
	  id		detailsArray;
	  int		i, n_trans, n_types, names_size;
	  id		*abbrevsArray;
	  char		*trans;
	  char		*type_idxs;
	  char		*zone_abbrevs;
	  struct tzhead	*header;
	  struct ttinfo	*types; // Temporary array for details

	  if (length < sizeof(struct tzhead))
	    {
	      [NSException raise: fileException format: errMess];
	    }
	  header = (struct tzhead *)(bytes + pos);
	  pos += sizeof(struct tzhead);

	  n_trans = decode(header->tzh_timecnt);
	  n_types = decode(header->tzh_typecnt);
	  names_size = decode(header->tzh_charcnt);

	  /* Read in transitions. */
	  trans = (char*)(bytes + pos);
	  pos += 4*n_trans;
	  type_idxs = (char*)(bytes + pos);
	  pos += n_trans;
	  if (pos > length)
	    {
	      [NSException raise: fileException format: errMess];
	    }
	  transArray = [NSMutableArray arrayWithCapacity: n_trans];
	  for (i = 0; i < n_trans; i++)
	    {
	      [transArray
		addObject: [[NSInternalTimeTransition alloc]
			   initWithTime: decode(trans+(i*4))
			   withIndex: type_idxs[i]]];
	    }

	  /* Read in time zone details. */
	  types = (struct ttinfo*)(bytes + pos);
	  pos += n_types*sizeof(struct ttinfo);
	  if (pos > length)
	    {
	      [NSException raise: fileException format: errMess];
	    }

	  /* Read in time zone abbreviation strings. */
	  zone_abbrevs = (char*)(bytes + pos);
	  pos += names_size;
	  if (pos > length)
	    {
	      [NSException raise: fileException format: errMess];
	    }
	  abbrevsArray = NSZoneMalloc(NSDefaultMallocZone(),
	    sizeof(id)*names_size);
	  memset(abbrevsArray, '\0', sizeof(id)*names_size);
	  for (i = 0; i < n_types; i++)
	    {
	      struct ttinfo	*inf = types + i;
	      int		loc = inf->abbr_idx;

	      if (abbrevsArray[loc] == nil)
		{
		  abbrevsArray[loc]
		    = [NSString stringWithCString: zone_abbrevs+loc];
		}
	    }

	  zone = [NSConcreteTimeZone alloc];

	  /* Create time zone details. */
	  detailsArray = [NSMutableArray arrayWithCapacity: n_types];
	  for (i = 0; i < n_types; i++)
	    {
	      NSConcreteTimeZoneDetail	*detail;
	      struct ttinfo		*inf = types + i;
	      int			off = decode(inf->offset);
	      BOOL			dst = (inf->isdst > 0) ? YES : NO;
	      int			idx = inf->abbr_idx;
	      id			abr = abbrevsArray[idx];

	      detail = [[NSConcreteTimeZoneDetail alloc]
			      initWithTimeZone: zone
				    withAbbrev: abr
				    withOffset: off
				       withDST: dst];
	      [detailsArray addObject: detail];
	      RELEASE(detail);
	    }
	  NSZoneFree(NSDefaultMallocZone(), abbrevsArray);

	  zone = [(id)zone initWithName: name
			withTransitions: transArray
			    withDetails: detailsArray];
	  if (zone_mutex != nil)
	    {
	      [zone_mutex lock];
	    }
	  [zoneDictionary setObject: zone forKey: (NSString*)[zone name]];
	  if (zone_mutex != nil)
	    {
	      [zone_mutex unlock];
	    }
	}
      NS_HANDLER
	{
	  DESTROY(zone);
	  if ([localException name] != fileException)
	    [localException raise];
	  NSLog(@"Unable to obtain time zone `%@'.", name);
	}
      NS_ENDHANDLER

    }
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


  
@implementation NSConcreteTimeZone
  
- (void) dealloc
{
  RELEASE(name);
  RELEASE(transitions);
  RELEASE(details);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: name];
}

- (id) initWithName: (NSString*)aName
    withTransitions: (NSArray*)trans
	withDetails: (NSArray*)zoneDetails
{
  self = [super init];
  if (self != nil)
    {
      name = [aName copyWithZone: [self zone]];
      transitions = RETAIN(trans);
      details = RETAIN(zoneDetails);
    }
  return self;
}

- (NSString*) name
{
  return name;
}

- (NSArray*) timeZoneDetailArray
{
  return details;
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
  
@end

@implementation	NSLocalTimeZone
  
- (id) autorelease
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: @"NSLocalTimeZone"];
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

- (NSArray*) timeZoneDetailArray
{
  return [[NSTimeZoneClass defaultTimeZone] timeZoneDetailArray];
}
  
- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return [[NSTimeZoneClass defaultTimeZone] timeZoneDetailForDate: date];
}

@end
  
@implementation NSConcreteAbsoluteTimeZone

static NSMapTable	*absolutes = 0;

+ (void) initialize
{
  if (self == [NSConcreteAbsoluteTimeZone class])
    {
      absolutes = NSCreateMapTable(NSIntMapKeyCallBacks,
                NSNonOwnedPointerMapValueCallBacks, 0);
    }
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
  NSConcreteAbsoluteTimeZone	*z;

  if (zone_mutex != nil)
    [zone_mutex lock];
  z = (NSConcreteAbsoluteTimeZone*)NSMapGet(absolutes, (void*)(gsaddr)anOffset);
  if (z)
    {
      IF_NO_GC(RETAIN(z));
      RELEASE(self);
    }
  else
    {
      self = [super init];
      if (self != nil)
	{
	  name = [[NSString alloc] initWithFormat: @"NSAbsoluteTimeZone:%d",
	    anOffset];
	  detail = [[NSConcreteTimeZoneDetail alloc]
	    initWithTimeZone: self withAbbrev: name
	      withOffset: anOffset withDST: NO];
	  offset = anOffset;
	  z = self;
	  NSMapInsert(absolutes, (void*)(gsaddr)anOffset, (void*)z);
	  [zoneDictionary setObject: self forKey: (NSString*)name];
	}
    }
  if (zone_mutex != nil)
    [zone_mutex unlock];
  return z;
}

- (NSString*) name
{
  return name;
}

- (NSTimeZone*) timeZoneDetailTimeZone
{
  return [NSTimeZone arrayWithObject: detail];
}
  
- (NSTimeZoneDetail*) timeZoneDetailForDate: (NSDate*)date
{
  return detail;
}
  
@end
  
  
@implementation NSConcreteTimeZoneDetail
  
- (void) dealloc
{
  RELEASE(timeZone);
  RELEASE(abbrev);
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
  [super init];
  timeZone = RETAIN(aZone);
  abbrev = RETAIN(anAbbrev);
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

+ (NSTimeZone*) defaultTimeZone
{
  NSTimeZone	*zone;

  if (zone_mutex != nil)
    [zone_mutex lock];
  if (defaultTimeZone == nil)
    {
      zone = [self systemTimeZone];
    }
  else
    {
      if (zone_mutex != nil)
	zone = AUTORELEASE(RETAIN(defaultTimeZone));
      else
	zone = defaultTimeZone;
    }
  if (zone_mutex != nil)
    [zone_mutex unlock];
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
      [self setDefaultTimeZone: [self systemTimeZone]];

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

+ (NSTimeZone*) localTimeZone
{
  return localTimeZone;
}

+ (void) resetSystemTimeZone
{
  if (zone_mutex != nil)
    [zone_mutex lock];
  DESTROY(systemTimeZone);
  if (zone_mutex != nil)
    [zone_mutex unlock];
}

+ (void) setDefaultTimeZone: (NSTimeZone*)aTimeZone
{
  if (zone_mutex != nil)
    [zone_mutex lock];
  ASSIGN(defaultTimeZone, aTimeZone);
  if (zone_mutex != nil)
    [zone_mutex unlock];
}

+ (NSTimeZone*) systemTimeZone
{
  NSTimeZone	*zone = nil;

  if (zone_mutex != nil)
    [zone_mutex lock];
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

+ (NSTimeZone*) timeZoneForSecondsFromGMT: (int)seconds
{
  /* We simply return the following because an existing time zone with
     the given offset might not always have the same offset (daylight
     savings time, change in standard time, etc.). */
  return AUTORELEASE([[NSConcreteAbsoluteTimeZone alloc] initWithOffset: seconds]);
}

+ (NSTimeZone*) timeZoneWithAbbreviation: (NSString*)abbreviation
{
  NSTimeZone	*zone;

  zone = [self timeZoneWithName: [[self abbreviationDictionary]
				   objectForKey: abbreviation]];
  return zone;
}

+ (NSTimeZone*) timeZoneWithName: (NSString*)aTimeZoneName
{
  NSTimeZone	*zone;

  zone = [defaultPlaceholderTimeZone initWithName: aTimeZoneName];
  return AUTORELEASE(zone);
}

+ (NSTimeZone*) timeZoneWithName: (NSString*)name data: (NSData*)data

{
  [self notImplemented: _cmd];
  return nil;
}

- (NSString*) abbreviation
{
  return [self abbreviationForDate: [NSDate date]];
}

- (NSString*) abbreviationForDate: (NSDate*)when
{
  NSTimeZoneDetail	*detail;

  detail = [self timeZoneDetailForDate: when];
  return [detail timeZoneAbbreviation];
}

- (Class) classForCoder
{
  return NSTimeZoneClass;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (NSString*) description
{
  return [self name];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: [self name]];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  NSString	*name;

  name = [aDecoder decodeObject];
  self = [self initWithName: name];
  return self;
}

- (id) initWithName: (NSString*)name
{
  [self notImplemented: _cmd];
  return nil;
}

- (id) initWithName: (NSString*)name data: (NSData*)data
{
  [self notImplemented: _cmd];
  return nil;
}

- (BOOL) isDaylightSavingTime
{
  return [self isDaylightSavingTimeForDate: [NSDate date]];
}

- (BOOL) isDaylightSavingTimeForDate: (NSDate*)aDate
{
  NSTimeZoneDetail	*detail;

  detail = [self timeZoneDetailForDate: aDate];
  return [detail isDaylightSavingTimeZone];
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
  if ([[self name] isEqual: [aTimeZone name]] == YES)
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
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

- (int) secondsFromGMT
{
  return [self secondsFromGMTForDate: [NSDate date]];
}

- (int) secondsFromGMTForDate: (NSDate*)when
{
  NSTimeZoneDetail	*detail;

  detail = [self timeZoneDetailForDate: when];
  return [detail timeZoneSecondsFromGMT];
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
  

@implementation NSTimeZoneDetail

- (NSString*) description
{
  return [NSString
	   stringWithFormat: @"%@(%@, %s%d)",
	   [self name],
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
  NSString *dir = [NSString stringWithFormat: @"%@/%@", TIME_ZONE_DIR, ZONES_DIR];
  NSString *path = [NSBundle pathForGNUstepResource: name
					     ofType: @""
				        inDirectory: dir];
  return path;
}

@end
