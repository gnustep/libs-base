#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/NSLocale.h>

#if	defined(GS_USE_ICU)
#define	NSLOCALE_SUPPORTED	GS_USE_ICU
#else
#define	NSLOCALE_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{  
  START_SET(NSLOCALE_SUPPORTED)
  id testObj = [NSLocale currentLocale];

  test_NSObject(@"NSLocale", [NSArray arrayWithObject: testObj]);
  test_keyed_NSCoding([NSArray arrayWithObject: testObj]);
  test_NSCopying(@"NSLocale", @"NSLocale",
    [NSArray arrayWithObject: testObj], NO, NO);
  
  END_SET("NSLocale not supported.\nThe ICU library was not provided when GNUstep-base was configured/built.")
  return 0;
}
