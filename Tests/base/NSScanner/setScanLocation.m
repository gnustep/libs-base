#import <Foundation/Foundation.h>
#import "Testing.h"

/* -setScanLocation: validated the current _scanLocation (which is essentially
   always within range) instead of the supplied index, so it accepted indices
   beyond the end of the string and never raised the documented
   NSRangeException. */

int main(void)
{
  START_SET("NSScanner setScanLocation: bounds")
  NSScanner		*sc = [NSScanner scannerWithString: @"hello"];   /* length 5 */

  [sc setScanLocation: 3];
  PASS([sc scanLocation] == 3,
    "setScanLocation: accepts an index within the string")

  [sc setScanLocation: 5];
  PASS([sc scanLocation] == 5,
    "setScanLocation: accepts the end of the string")

  [sc setScanLocation: 2];
  PASS_EXCEPTION([sc setScanLocation: 6], NSRangeException,
    "setScanLocation: beyond the end raises NSRangeException")
  PASS([sc scanLocation] == 2,
    "scan location is unchanged after a rejected out-of-range set")

  END_SET("NSScanner setScanLocation: bounds")
  return 0;
}
