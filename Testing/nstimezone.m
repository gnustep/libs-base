/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include    <Foundation/NSAutoreleasePool.h>

int
main ()
{
  id detail;
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  NSLog(@"time zones for PST:\n%@\n",
	 [[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description]);
  NSLog(@"time zones:\n%@\n", [[NSTimeZone timeZoneArray] description]);
  NSLog(@"local time zone:\n%@\n", [[NSTimeZone localTimeZone] description]);
  [arp release];
  return 0;
}
