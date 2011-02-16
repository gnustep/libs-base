#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLocale.h>
#import "ObjectTesting.h"

#if	defined(GS_USE_ICU)
#define	NSLOCALE_SUPPORTED	GS_USE_ICU
#else
#define	NSLOCALE_SUPPORTED	1 /* Assume Apple support */
#endif

int main(void)
{
  START_SET(NSLOCALE_SUPPORTED)

  NSLocale *locale;
  
  locale = [NSLocale systemLocale];
  PASS (locale != nil, "+systemLocale returns non-nil");
  TEST_FOR_CLASS(@"NSLocale", locale, "+systemLocale return a NSLocale");
  
  locale = [NSLocale currentLocale];
  PASS (locale != nil, "+currentLocale return non-nil");
  TEST_FOR_CLASS(@"NSLocale", locale, "+currentLocale return a NSLocale");
  
  END_SET("NSLocale create")

  return 0;
}
