/*
 * scanHexFloat.m - tests for -[NSScanner scanHexDouble:] and -scanHexFloat:,
 * which parse a C hexadecimal floating point value of the form 0xh.hhhp±d.
 * The scanned values are exact powers of two, so they are compared exactly.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("scanHexDouble")
    NSScanner	*sc;
    double	d;

    sc = [NSScanner scannerWithString: @"0x1.8p1"];
    PASS([sc scanHexDouble: &d] && d == 3.0 && [sc isAtEnd],
      "0x1.8p1 scans as 3.0");
    sc = [NSScanner scannerWithString: @"0x1p4"];
    PASS([sc scanHexDouble: &d] && d == 16.0, "0x1p4 scans as 16");
    sc = [NSScanner scannerWithString: @"0xA"];
    PASS([sc scanHexDouble: &d] && d == 10.0, "0xA without an exponent scans as 10");
    sc = [NSScanner scannerWithString: @"0x1p-2"];
    PASS([sc scanHexDouble: &d] && d == 0.25, "0x1p-2 scans as 0.25");
    sc = [NSScanner scannerWithString: @"-0x1.8p1"];
    PASS([sc scanHexDouble: &d] && d == -3.0, "a leading minus is honoured");
    sc = [NSScanner scannerWithString: @"0xf.8p0"];
    PASS([sc scanHexDouble: &d] && d == 15.5, "0xf.8p0 scans as 15.5");
    sc = [NSScanner scannerWithString: @"0X1P4"];
    PASS([sc scanHexDouble: &d] && d == 16.0, "the 0X prefix and P exponent are case insensitive");
  END_SET("scanHexDouble")

  START_SET("scanHexDouble rejects input that is not a hex float")
    NSScanner	*sc;
    double	d = 99.0;

    sc = [NSScanner scannerWithString: @"1.5"];
    PASS(![sc scanHexDouble: &d] && [sc scanLocation] == 0,
      "a value without the 0x prefix is not scanned");
    sc = [NSScanner scannerWithString: @"0x"];
    PASS(![sc scanHexDouble: &d] && [sc scanLocation] == 0,
      "0x with no digits is not scanned");
    sc = [NSScanner scannerWithString: @"hello"];
    PASS(![sc scanHexDouble: &d], "non-numeric input is not scanned");
  END_SET("scanHexDouble rejects input that is not a hex float")

  START_SET("scanHexDouble skips whitespace and stops at the end of the value")
    NSScanner	*sc = [NSScanner scannerWithString: @"  0x2p3 rest"];
    double	d;

    PASS([sc scanHexDouble: &d] && d == 16.0, "leading whitespace is skipped");
    PASS([sc scanLocation] == 7, "scanning stops after the hex float");
  END_SET("scanHexDouble skips whitespace and stops at the end of the value")

  START_SET("scanHexFloat")
    NSScanner	*sc;
    float	f;

    sc = [NSScanner scannerWithString: @"0x1.8p1"];
    PASS([sc scanHexFloat: &f] && f == 3.0f, "0x1.8p1 scans as 3.0");
    sc = [NSScanner scannerWithString: @"0x1p-1"];
    PASS([sc scanHexFloat: &f] && f == 0.5f, "0x1p-1 scans as 0.5");
    sc = [NSScanner scannerWithString: @"1.5"];
    PASS(![sc scanHexFloat: &f], "a value without the 0x prefix is not scanned");
  END_SET("scanHexFloat")

  return 0;
}
