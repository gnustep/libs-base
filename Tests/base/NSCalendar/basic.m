#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/NSCalendar.h>

#if	defined(GS_USE_ICU)
#define	NSCALENDAR_SUPPORTED	GS_USE_ICU
#else
#define	NSCALENDAR_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{  
  START_SET(NSCALENDAR_SUPPORTED)
  id testObj = [NSCalendar currentCalendar];

  test_NSObject(@"NSCalendar", [NSArray arrayWithObject: testObj]);
  test_NSCoding([NSArray arrayWithObject: testObj]);
  test_NSCopying(@"NSCalendar", @"NSCalendar",
    [NSArray arrayWithObject: testObj], NO, NO);
  
  END_SET("NSCalendar basic")
  return 0;
}
