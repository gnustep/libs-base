#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>

#include <math.h>

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("equal numbers hash equally regardless of type")
    /* -isEqual: on NSNumber is defined by -compare:, which promotes to
     * double when the two numbers have different types, so numbers with
     * the same value held as int, long long, unsigned, float or double
     * all compare equal and therefore must hash equally. */
    NSMutableArray	*nums = [NSMutableArray array];
    long long		iv[] = {0, 1, -1, 42, -42, 255, 256, 65536,
      2147483647LL, 2147483648LL, 4294967296LL};
    unsigned		i;
    NSUInteger		a, b, n;
    BOOL		ok = YES;

    for (i = 0; i < sizeof(iv) / sizeof(iv[0]); i++)
      {
	long long	v = iv[i];

	[nums addObject: [NSNumber numberWithInt: (int)v]];
	[nums addObject: [NSNumber numberWithLongLong: v]];
	if (v >= 0)
	  {
	    [nums addObject: [NSNumber numberWithUnsignedLongLong:
	      (unsigned long long)v]];
	  }
	[nums addObject: [NSNumber numberWithFloat: (float)v]];
	[nums addObject: [NSNumber numberWithDouble: (double)v]];
      }

    n = [nums count];
    for (a = 0; a < n && ok; a++)
      {
	for (b = 0; b < n && ok; b++)
	  {
	    NSNumber	*x = [nums objectAtIndex: a];
	    NSNumber	*y = [nums objectAtIndex: b];

	    if ([x isEqual: y] && [x hash] != [y hash])
	      {
		NSLog(@"%@ isEqual: %@ but %lu != %lu", x, y,
		  (unsigned long)[x hash], (unsigned long)[y hash]);
		ok = NO;
	      }
	  }
      }
    PASS(ok, "equal numbers of differing types produce equal hashes")

    PASS([[NSNumber numberWithInt: 42] hash]
      == [[NSNumber numberWithDouble: 42.0] hash]
      && [[NSNumber numberWithInt: 42] hash]
      == [[NSNumber numberWithFloat: 42.0f] hash],
      "an integer and a floating point 42 hash equally")
  END_SET("equal numbers hash equally regardless of type")

  START_SET("the fractional part is not discarded")
    /* Distinct fractional values must hash distinctly rather than all
     * folding onto their common integral part. */
    NSNumber	*a = [NSNumber numberWithDouble: 1.5];
    NSNumber	*b = [NSNumber numberWithDouble: 1.7];
    NSNumber	*c = [NSNumber numberWithDouble: 1.9];
    unsigned	distinct = 0;
    unsigned	i;
    NSUInteger	seen[100];

    PASS([a hash] != [b hash] && [b hash] != [c hash] && [a hash] != [c hash],
      "1.5, 1.7 and 1.9 hash distinctly")

    /* A scattering sanity check: the hashes of 0.5 .. 99.5 are mostly
     * distinct rather than all folding onto their integral part. */
    for (i = 0; i < 100; i++)
      {
	NSUInteger	h = [[NSNumber numberWithDouble: i + 0.5] hash];
	unsigned	j;
	BOOL		dup = NO;

	for (j = 0; j < distinct; j++)
	  {
	    if (seen[j] == h)
	      {
		dup = YES;
		break;
	      }
	  }
	if (!dup)
	  {
	    seen[distinct++] = h;
	  }
      }
    PASS(distinct > 95, "fractional values scatter across the hash range")
  END_SET("the fractional part is not discarded")

  START_SET("non-finite values are handled")
    NSNumber	*pinf = [NSNumber numberWithDouble: INFINITY];
    NSNumber	*ninf = [NSNumber numberWithDouble: -INFINITY];
    NSNumber	*nan = [NSNumber numberWithDouble: NAN];

    PASS([pinf hash] == [[NSNumber numberWithDouble: INFINITY] hash],
      "+infinity hashes consistently")
    PASS([pinf hash] != [ninf hash],
      "+infinity and -infinity hash distinctly")
    PASS([nan hash] == [nan hash], "a NaN hash does not crash")
  END_SET("non-finite values are handled")

  [arp release];
  return 0;
}
