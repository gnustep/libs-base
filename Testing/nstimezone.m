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
  NSTimeZone *system;
  CREATE_AUTORELEASE_POOL(pool);

  GSPrintf(stdout, @"System time zone\n");
  system = [NSTimeZone systemTimeZone];
  GSPrintf(stdout, @"  %@\n\n", [system description]);
  
  GSPrintf(stdout, @"Local time zone:\n  %@\n\n",
	   [[NSTimeZone localTimeZone] description]);

  GSPrintf(stdout, @"Time zones for PST:\n  %@\n",
	   [[[NSTimeZone abbreviationMap] objectForKey: @"PST"] description]);


  RELEASE(pool);
  return 0;
}
