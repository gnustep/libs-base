/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSTimeZone.h>

int
main ()
{
  id detail;
  CREATE_AUTORELEASE_POOL(pool);

  printf("time zones for PST:\n%s\n",
[[[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description] UTF8String]);
  printf("time zones:\n%s\n",
[[[NSTimeZone timeZoneArray] description] UTF8String]);
  printf("local time zone:\n%s\n",
[[[NSTimeZone localTimeZone] description] UTF8String]);
  RELEASE(pool);
  return 0;
}
