/* Test time zone code. */

#include <stdio.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAutoreleasePool.h>

int
main ()
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  NSLog(@"time zones:\n%@\n", [[NSTimeZone timeZoneArray] description]);
  NSLog(@"time zones for PST:\n%@\n",
	 [[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description]);
  NSLog(@"local time zone:\n%@\n", [[NSTimeZone localTimeZone] description]);

  [pool release];
  return 0;
}
