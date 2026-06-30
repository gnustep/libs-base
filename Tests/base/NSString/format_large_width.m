#import "Testing.h"
#import <Foundation/NSString.h>

/* A field width larger than GSFormat's internal work_buffer takes the
   buffer-grow path.  That path used to point the conversion cursor at the
   START of the freshly allocated buffer while the integer converter writes
   BACKWARDS, overflowing the allocation (AddressSanitizer reports a
   heap-buffer-overflow in _itowa_word).  Check that a large field-width
   conversion produces the expected result. */
int main()
{
  START_SET("GSFormat large field width")
  NSString	*s = [NSString stringWithFormat: @"%100000d", 5];

  PASS([s length] == 100000,
    "a %%100000d field-width conversion has the expected length");
  PASS([s hasSuffix: @"5"],
    "a large field-width integer conversion ends with the formatted value");
  PASS([s characterAtIndex: 0] == ' ',
    "a large field-width integer conversion is space-padded");
  END_SET("GSFormat large field width")
  return 0;
}
