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
  START_SET(YES)
  NSNumber	*n;
  NSNumber	*nan;

  n = [NSNumber numberWithInt: 2];
  nan = [NSDecimalNumber notANumber];

  PASS(NO == [n isEqualToNumber: nan], "2 is not equal to NaN");
  PASS(YES == [nan isEqualToNumber: nan], "NaN is equal to NaN");

  PASS([n compare: nan] == NSOrderedDescending, "2 is greater than NaN") 
  PASS([nan compare: n] == NSOrderedAscending, "NaN is less than 2") 

  END_SET("not-a-number checks")
  return 0;
}
