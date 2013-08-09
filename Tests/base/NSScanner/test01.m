#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <Foundation/NSScanner.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <math.h>

static BOOL scanInt(int value, int *retp)
{ 
  NSString *str = [[NSNumber numberWithInt:value] description];
  NSScanner *scn = [NSScanner scannerWithString:str];
  return ([scn scanInt:retp] && value == *retp);
}
/* this didn't seem to be used in any of the NSScanner guile tests 
   so this function is untested.
 */
static BOOL scanIntOverflow(int value, int *retp)
{
  NSString *str = [[NSNumber numberWithFloat:value] description];
  NSScanner *scn = [NSScanner scannerWithString:str];
  int intmax = 2147483647;
  int intmin = (0 - (intmax - 1));
  
  return ([scn scanInt:retp] 
          && (0 > value) ? (intmin == *retp) : (intmax == *retp));
}

#if     defined(GNUSTEP_BASE_LIBRARY)
static BOOL scanRadixUnsigned(NSString *str, 
			      int expectValue,
			      unsigned int expectedValue,
			      int expectedScanLoc,
			      int *retp)
{
  NSScanner *scn = [NSScanner scannerWithString:str];
  [scn scanRadixUnsignedInt:retp];
  return ((expectValue == 1) ? (expectedValue == *retp) : YES
          && expectedScanLoc == [scn scanLocation]);
}
#endif

static BOOL scanHex(NSString *str, 
		    int expectValue,
		    unsigned int expectedValue,
		    int expectedScanLoc,
		    int *retp)
{
  NSScanner *scn = [NSScanner scannerWithString:str];
  [scn scanHexInt:retp];
  return ((expectValue == 1) ? (expectedValue == *retp) : YES
          && expectedScanLoc == [scn scanLocation]);
}
static BOOL scanDouble(NSString *str, 
		    double expectedValue,
		    double *retp)
{
  NSScanner *scn = [NSScanner scannerWithString:str];
  [scn scanDouble:retp];
  return ((0.00000000001 >= fabs(expectedValue - *retp))
          && [str length] == [scn scanLocation]);
}

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  int ret;
  double dret;
  int intmax = 2147483647;
  int intmin = (0 - (intmax - 1));
  NSScanner *scn;
  float flt;
  NSString      *em;

  PASS(scanInt((intmax - 20),&ret), "NSScanner large ints"); 
  PASS(scanInt((intmin + 20),&ret), "NSScanner small ints");
  
  scn = [NSScanner scannerWithString:@"1234F00"];
  PASS(([scn scanInt:&ret] && ([scn scanLocation] == 4)),
       "NSScanner non-digits terminate scan");
  
  scn = [NSScanner scannerWithString:@"junk"];
  PASS((![scn scanInt:&ret] && ([scn scanLocation] == 0)),
       "NSScanner non-digits terminate scan");
  
  scn = [NSScanner scannerWithString:@"junk"];
  PASS(![scn scanInt:&ret] && ([scn scanLocation] == 0),
       "NSScanner non-digits dont consume characters to be skipped");
  
#if     defined(GNUSTEP_BASE_LIBRARY)
  PASS(scanRadixUnsigned(@"1234FOO", 1, 1234, 4, &ret)
       && scanRadixUnsigned(@"01234FOO", 1, 01234, 5, &ret)
       && scanRadixUnsigned(@"0x1234FOO", 1, 0x1234F, 7, &ret)
       && scanRadixUnsigned(@"0X1234FOO", 1, 0x1234F, 7, &ret)
       && scanRadixUnsigned(@"012348FOO", 1, 01234, 5, &ret),
       "NSScanner radiux unsigned (non-digits terminate scan)");
  
  PASS(scanRadixUnsigned(@"FOO", 0, 0, 0, &ret)
       && scanRadixUnsigned(@"  FOO", 0, 0, 0, &ret)
       && scanRadixUnsigned(@" 0x ", 0, 0, 0, &ret),
       "NSScanner radiux unsigned (non-digits dont move scan)");
#endif
  
  PASS(scanHex(@"1234FOO", 1, 0x1234F, 5, &ret)
       && scanHex(@"01234FOO", 1, 0x1234F, 6, &ret),
       "NSScanner hex (non-digits terminate scan)");
 /* dbl1 = 123.456;
  dbl2 = 123.45678901234567890123456789012345678901234567;
  dbl3 = 1.23456789;
  */
  PASS(scanDouble(@"123.456",123.456,&dret) 
       && scanDouble(@"123.45678901234567890123456789012345678901234567",
                       123.45678901234567890123456789012345678901234567,&dret)
       && scanDouble(@"0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000123456789e+100", 1.23456789, &dret),
       "NSScanner scans doubles");
  
  PASS(scanDouble(@"1e0", 1, &dret)
       && scanDouble(@"1e1", 10, &dret)
       && scanDouble(@"1e+1", 10, &dret)
       && scanDouble(@"1e+10", 1e10, &dret)
       && scanDouble(@"1e-1", 1e-1, &dret)
       && scanDouble(@"1e-10", 1e-10, &dret),
       "NSScanner scans double with exponents");

  scn = [NSScanner scannerWithString: @"1.0e+2m"];
  flt = 0.0;
  em = @"";
  [scn scanFloat: &flt];
  [scn scanString: @"m" intoString: &em];
  PASS(flt == 1e+2f, "flt = 1e+2");
  PASS_EQUAL(em, @"m", "e is part of exponent");
  PASS([scn scanLocation] == 7u, "all scanned");
  PASS([scn isAtEnd], "is at end");


  scn = [NSScanner scannerWithString: @"1.0em"];
  flt = 0.0;
  em = @"";
  [scn scanFloat: &flt];
  [scn scanString: @"em" intoString: &em];
  PASS(flt == 1.0f, "flt = 1.0");
  PASS_EQUAL(em, @"em", "em is not part of exponent");
  PASS([scn scanLocation] == 5u, "all scanned");
  PASS([scn isAtEnd], "is at end");

  [arp release]; arp = nil;
  return 0;
}
