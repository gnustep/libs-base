/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSTimeZone.h>
#include <Foundation/NSCalendarDate.h>

int
main ()
{
  NSTimeZone *system;
  NSTimeZone *other;
  NSCalendarDate *date;
  CREATE_AUTORELEASE_POOL(pool);

  GSPrintf(stdout, @"GMT time zone %x\n",
    [NSTimeZone timeZoneWithAbbreviation:@"GMT"]);
  GSPrintf(stdout, @"System time zone\n");
  system = [NSTimeZone systemTimeZone];
  GSPrintf(stdout, @"  %@\n\n", [system description]);

  GSPrintf(stdout, @"Local time zone:\n  %@\n\n",
	   [[NSTimeZone localTimeZone] description]);

  GSPrintf(stdout, @"Time zone for PST (from dict):\n  %@\n",
	   [[NSTimeZone abbreviationDictionary] objectForKey: @"PST"]);
  GSPrintf(stdout, @"Time zones for PST (from map):\n  %@\n",
	   [[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description]);

  other = [NSTimeZone timeZoneWithAbbreviation: @"CEST"];
  GSPrintf(stdout, @"Time zone for CEST:\n  %@\n", other);

  date = [[NSCalendarDate alloc] initWithString:@"09/04/2003 17:58:45 CEST"
                                calendarFormat:@"%m/%d/%Y %H:%M:%S %Z"];
  GSPrintf(stdout, @"Date in CEST:\n  %@\n", date);


  RELEASE(pool);
  return 0;
}
