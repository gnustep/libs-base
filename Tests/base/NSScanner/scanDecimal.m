/*
 * scanDecimal.m - tests for -[NSScanner scanDecimal:], which scans a decimal
 * number into an NSDecimal, honouring the locale decimal separator and an
 * optional e/E exponent.  Results are checked through NSDecimalString.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static NSString *
scan(NSString *s)
{
  NSScanner	*sc = [NSScanner scannerWithString: s];
  NSDecimal	d;

  return [sc scanDecimal: &d] ? NSDecimalString(&d, nil) : nil;
}

int main(void)
{
  START_SET("scanDecimal values")
    PASS_EQUAL(scan(@"3.14"), @"3.14", "a fractional value is scanned");
    PASS_EQUAL(scan(@"-2.5"), @"-2.5", "a negative value keeps its sign");
    PASS_EQUAL(scan(@"42"), @"42", "an integer value is scanned");
    PASS_EQUAL(scan(@".5"), @"0.5", "a leading separator is accepted");
    PASS_EQUAL(scan(@"+7"), @"7", "a leading plus is accepted");
  END_SET("scanDecimal values")

  START_SET("scanDecimal exponent")
    PASS_EQUAL(scan(@"1.5e3"), @"1500", "a positive exponent scales the value");
    PASS_EQUAL(scan(@"1e-2"), @"0.01", "a negative exponent scales the value");
    PASS_EQUAL(scan(@"2E2"), @"200", "an uppercase E exponent is accepted");
  END_SET("scanDecimal exponent")

  START_SET("scanDecimal rejects and positions")
    NSScanner	*sc;
    NSDecimal	d;

    sc = [NSScanner scannerWithString: @"abc"];
    PASS(![sc scanDecimal: &d] && [sc scanLocation] == 0,
      "non-numeric input is not scanned and the location is unchanged");

    sc = [NSScanner scannerWithString: @"  12.5 rest"];
    PASS([sc scanDecimal: &d] && [sc scanLocation] == 6,
      "whitespace is skipped and scanning stops after the number");
  END_SET("scanDecimal rejects and positions")

  START_SET("scanDecimal honours the locale separator")
    NSDictionary	*loc;
    NSScanner		*sc;
    NSDecimal		d;

    loc = [NSDictionary dictionaryWithObject: @"," forKey: NSDecimalSeparator];
    sc = [NSScanner scannerWithString: @"3,14"];
    [sc setLocale: loc];
    PASS([sc scanDecimal: &d]
      && [NSDecimalString(&d, nil) isEqualToString: @"3.14"],
      "a comma decimal separator from the locale is used");
  END_SET("scanDecimal honours the locale separator")

  return 0;
}
