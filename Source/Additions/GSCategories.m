/* Implementation of extension methods to standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
#include	<Foundation/Foundation.h>

@implementation NSCalendarDate (GSCategories)

/**
 * The ISO standard week of the year is based on the first week of the
 * year being that week (starting on monday) for which the thursday
 * is on or after the first of january.<br />
 * This has the effect that, if january first is a friday, saturday or
 * sunday, the days of that week (up to and including the sunday) are
 * considered to be in week 53 of the preceeding year. Similarly if the
 * last day of the year is a monday tuesday or wednesday, these days are
 * part of week 1 of the next year.
 */
- (int) weekOfYear
{
  int	dayOfWeek = [self dayOfWeek];
  int	dayOfYear;

  /*
   * Whether a week is considered to be in a year or not depends on its
   * thursday ... so find thursday for the receivers week.
   * NB. this may result in a date which is not in the same year as the
   * receiver.
   */
  if (dayOfWeek != 4)
    {
      CREATE_AUTORELEASE_POOL(arp);
      NSCalendarDate	*thursday;

      /*
       * A week starts on monday ... so adjust from 0 to 7 so that a
       * sunday is counted as the last day of the week.
       */
      if (dayOfWeek == 0)
	{
	  dayOfWeek = 7;
	}
      thursday = [self dateByAddingYears: 0
				  months: 0
				    days: 4 - dayOfWeek
				   hours: 0
				 minutes: 0
				 seconds: 0];
      dayOfYear = [thursday dayOfYear];
      RELEASE(arp);
    }
  else
    {
      dayOfYear = [self dayOfYear];
    }
  
  /*
   * Round up to a week boundary, so that when we divide by seven we
   * get a result in the range 1 to 53 as mandated by the ISO standard.
   */
  dayOfYear += (7 - dayOfYear % 7);
  return dayOfYear / 7;
}

@end
