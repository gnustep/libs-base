/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSTimeZone.h>

int
main ()
{
  id detail;

  printf("time zones for PST:\n%s\n",
[[[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description] UTF8String]);
  printf("time zones:\n%s\n",
[[[NSTimeZone timeZoneArray] description] UTF8String]);
  printf("local time zone:\n%s\n",
[[[NSTimeZone localTimeZone] description] UTF8String]);
  return 0;
}
