/* create-regions.m - Utility to create a list of time zones and their
       associated latitudinal region.

   Copyright (C) 1997 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSUtilities.h>

#define HOURSECS (60*60) /* Seconds in 1 hour. */
#define DAYSECS (HOURSECS*24) /* Seconds in 24 hours. */
#define N (360/15) /* Each latitudinal region is separated by 15 degrees */

int
main (int argc, char *argv[])
{
  int i;
  id pool, name, zone;
  id zones[N]; 

  pool = [NSAutoreleasePool new];
  for (i = 0; i < N; i++)
    zones[i] = nil;

  /* Obtain the regions for each latitudinal region. */
  for (i = 1; i < argc; i++)
    {
      name = [NSString stringWithCString: argv[i]];
      zone = [NSTimeZone timeZoneWithName: name];
      if (zone != nil)
	{
	  int offset, index;
	  id details, detail, e;

	  details = [zone timeZoneDetailArray];

	  /* Get a standard time. */
	  e = [details objectEnumerator];
	  while ((detail = [e nextObject]) != nil)
	    {
	      if (![detail isDaylightSavingTimeZone])
		break;
	    }

	  if (detail == nil)
	    /* If no standard time. */
	    detail = [details objectAtIndex: 0];

	  offset = [detail timeZoneSecondsFromGMT];

	  /* Get index from normalized offset */
	  index = ((offset+DAYSECS)%DAYSECS)/HOURSECS;

	  if (zones[index] == nil)
	    zones[index] = [NSMutableArray array];
	  [zones[index] addObject: [zone timeZoneName]];
	}
    }

  /* Write regions to file. */
  for (i = 0; i < N; i++)
    {
      id e, name;

      if (zones[i] != nil)
	{
	  e = [zones[i] objectEnumerator];
	  while ((name = [e nextObject]) != nil)
	    printf("%d %@\n", i, name);
	}
    }

  [pool release];
  return 0;
}
