/* create-abbrevs.m - Utility to create a list of time zones and their
       associated abbreviations.

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
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSTimeZone.h>

int
main (int argc, char *argv[])
{
  int i;
  id pool, zone, dict, e, details, name;

  pool = [NSAutoreleasePool new];

  for (i = 1; i < argc; i++)
    {
      name = [NSString stringWithCString: argv[i]];
      zone = [NSTimeZone timeZoneWithName: name];
      if (zone != nil)
	{
	  id detail, abbrev;

	  dict = [NSMutableDictionary dictionary];
	  details = [zone timeZoneDetailArray];
	  e = [details objectEnumerator];
	  while ((detail = [e nextObject]) != nil)
	    [dict setObject: name forKey: [detail timeZoneAbbreviation]];
	  e = [dict keyEnumerator];
	  while ((abbrev = [e nextObject]) != nil)
	    printf("%@\t%@\n", abbrev, name);
	}
    }

  [pool release];
  return 0;
}
