/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>

int
main ()
{
  id detail;

  printf("time zones for PST:\n%@\n",
	 [[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description]);
  printf("time zones:\n%@\n", [[NSTimeZone timeZoneArray] description]);
  printf("local time zone:\n%@\n", [[NSTimeZone localTimeZone] description]);
  return 0;
}
