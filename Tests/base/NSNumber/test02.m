#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDecimalNumber.h>

#include <stdlib.h>
#include <limits.h>

#if	!defined(LLONG_MAX)
#  if	defined(__LONG_LONG_MAX__)
#    define LLONG_MAX __LONG_LONG_MAX__
#    define LLONG_MIN	(-LLONG_MAX-1)
#    define ULLONG_MAX	(LLONG_MAX * 2ULL + 1)
#  else
#    error Neither LLONG_MAX nor __LONG_LONG_MAX__ found
#  endif
#endif

int main()
{
  NSNumber	*n;
  NSNumber	*zero;

  START_SET("zero checks")

  zero = [NSDecimalNumber zero];

  n = [NSNumber numberWithFloat: 0.0];
  PASS([n compare: zero] == YES, "0.0 is zero")

  n = [NSNumber numberWithFloat: -1.01];
  PASS([n compare: zero] == NO, "-1.01 is not zero")

  END_SET("zero checks")
  return 0;
}
