#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDecimalNumber.h>

#include <stdlib.h>
#include <limits.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846264338327950288
#endif

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
  START_SET("NSNumber")
    NSNumber	*n;

    START_SET("simple-number checks")
      NSNumber	*nn = [NSNumber numberWithFloat: 42.0];

      n = [NSNumber numberWithFloat: M_PI];
      PASS([nn compare: n] == NSOrderedDescending, "42 is greater than pi")
      PASS([n compare: nn] == NSOrderedAscending, "pi is smaller than 42")
      PASS([n compare: n] == NSOrderedSame, "pi is pi")
      PASS([nn compare: nn] == NSOrderedSame, "42 is 42")

    END_SET("simple-number checks")

    START_SET("not-a-number checks")

      NSNumber	*nan = [NSDecimalNumber notANumber];

      PASS(YES == [nan isEqualToNumber: nan], "NaN is equal to NaN");

      n = [NSNumber numberWithInt: 2];
      PASS(NO == [n isEqualToNumber: nan], "2 is not equal to NaN");
      PASS([n compare: nan] == NSOrderedDescending, "2 is greater than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN is less than 2")

      n = [NSNumber numberWithUnsignedLongLong: 2];
      PASS(NO == [n isEqualToNumber: nan], "2LL is not equal to NaN");
      PASS([n compare: nan] == NSOrderedDescending, "2LL is greater than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN is less than 2LL")

      n = [NSNumber numberWithFloat: 2.0];
      PASS(NO == [n isEqualToNumber: nan], "2.0 is not equal to NaN");
      PASS([n compare: nan] == NSOrderedDescending, "2.0 is greater than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN is less than 2.0")

      n = [NSNumber numberWithDouble: 2.0];
      PASS(NO == [n isEqualToNumber: nan], "2.0dd is not equal to NaN");
      PASS([n compare: nan] == NSOrderedDescending, "2.0dd is greater than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN is less than 2.0dd")

      n = [NSNumber numberWithFloat: 0.0];
      PASS(NO == [n isEqualToNumber: nan], "0.0 is not equal to NaN");
      PASS([n compare: nan] == NSOrderedDescending, "0.0 greater than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN less than 0.0")

      n = [NSNumber numberWithFloat: -1.01];
      PASS(NO == [n isEqualToNumber: nan], "-1.01 is not equal to NaN");
      PASS([n compare: nan] == NSOrderedAscending, "-1.01 less than NaN")
      PASS([nan compare: n] == NSOrderedAscending, "NaN less than -1.01")

      END_SET("not-a-number checks")

    START_SET("zero checks")

      NSNumber	*zero = [NSDecimalNumber zero];

      PASS(YES == [zero isEqualToNumber: zero], "zero is equal to zero");

      n = [NSNumber numberWithInt: 2];
      PASS(NO == [n isEqualToNumber: zero], "2 is not equal to zero");
      PASS([n compare: zero] == NSOrderedDescending, "2 is greater than zero")
      PASS([zero compare: n] == NSOrderedAscending, "zero is less than 2")

      n = [NSNumber numberWithUnsignedLongLong: 2];
      PASS(NO == [n isEqualToNumber: zero], "2LL is not equal to zero");
      PASS([n compare: zero] == NSOrderedDescending, "2LL is greater than zero")
      PASS([zero compare: n] == NSOrderedAscending, "zero is less than 2LL")

      n = [NSNumber numberWithFloat: 2.0];
      PASS(NO == [n isEqualToNumber: zero], "2.0 is not equal to zero");
      PASS([n compare: zero] == NSOrderedDescending, "2.0 is greater than zero")
      PASS([zero compare: n] == NSOrderedAscending, "zero is less than 2.0")

      n = [NSNumber numberWithDouble: 2.0];
      PASS(NO == [n isEqualToNumber: zero], "2.0dd is not equal to zero");
      PASS([n compare: zero] == NSOrderedDescending,
	"2.0dd is greater than zero")
      PASS([zero compare: n] == NSOrderedAscending, "zero is less than 2.0dd")

      n = [NSNumber numberWithFloat: 0.0];
      PASS([n isEqualToNumber: zero], "0.0 is equal to zero");
      PASS([n compare: zero] == NSOrderedSame, "0.0 is zero")
      PASS([zero compare: n] == NSOrderedSame, "zero is 0.0")

      n = [NSNumber numberWithFloat: -1.01];
      PASS(NO == [n isEqualToNumber: zero], "-1.01 is not equal to zero");
      PASS([n compare: zero] == NSOrderedAscending, "-1.01 less than zero")
      PASS([zero compare: n] == NSOrderedDescending, "zero greater than -1.01")

    END_SET("zero checks")

    START_SET("hashing")
      // Consistency - a number's hash should be the same every time.
      NSNumber *n = [NSNumber numberWithInt:42];
      PASS([n hash] == [n hash], "hashing is consistent for int");
      n = [NSNumber numberWithFloat:M_PI];
      PASS([n hash] == [n hash], "hashing is consistent for float");
      n = [NSNumber numberWithDouble:M_PI];
      PASS([n hash] == [n hash], "hashing is consistent for double");

      // Equality - equal numbers should have the same hash.
      NSNumber *a = [NSNumber numberWithInt:42];
      NSNumber *b = [NSNumber numberWithInt:42];
      PASS([a hash] == [b hash], "equal int numbers have same hash");
      a = [NSNumber numberWithFloat:42.0f];
      b = [NSNumber numberWithDouble:42.0];
      PASS([a hash] == [b hash], "42.0f and 42.0dd have the same hash");
      a = [NSNumber numberWithLongLong:LLONG_MAX];
      b = [NSNumber numberWithUnsignedLongLong:LLONG_MAX];
      PASS([a hash] == [b hash], "LLONG_MAX and ULLONG_MAX-ish have same hash");

      // Floating point numbers with zero fractional component.
      a = [NSNumber numberWithDouble:42.0];
      b = [NSNumber numberWithInt:42];
      PASS([a hash] == [b hash], "double with zero fractional part hashes like int");
      a = [NSNumber numberWithFloat:123.0f];
      b = [NSNumber numberWithInt:123];
      PASS([a hash] == [b hash], "float with zero fractional part hashes like int");

      // Special Cases - Zero and NaN.
      a = [NSNumber numberWithDouble:0.0];
      PASS([a hash] == 0, "hash for 0.0 is 0");
      a = [NSNumber numberWithDouble:-0.0];
      PASS([a hash] == 0, "hash for -0.0 is 0");
      a = [NSNumber numberWithFloat:0.0f];
      PASS([a hash] == 0, "hash for 0.0f is 0");
      a = [NSDecimalNumber notANumber];
      PASS([a hash] == 0, "hash for NaN is 0");
      
      // Verify different numbers have different hashes.
      NSNumber *n1 = [NSNumber numberWithInt:1];
      NSNumber *n2 = [NSNumber numberWithInt:2];
      PASS([n1 hash] != [n2 hash], "different integers have different hashes");
      
      NSNumber *f1 = [NSNumber numberWithFloat:1.0f];
      NSNumber *f2 = [NSNumber numberWithFloat:1.1f];
      PASS([f1 hash] != [f2 hash], "different floats have different hashes");
      
      NSNumber *d1 = [NSNumber numberWithDouble:3.14159];
      NSNumber *d2 = [NSNumber numberWithDouble:3.14158];
      PASS([d1 hash] != [d2 hash], "different doubles have different hashes");

    END_SET("hashing")

  END_SET("NSNumber")

  return 0;
}
