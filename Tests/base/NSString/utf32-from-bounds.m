#import "ObjectTesting.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

int main()
{
  START_SET("NSString -> UTF-32 output bounds")

  /* Converting to UTF-32 writes four bytes per character but only checked
   * that one byte of space remained.  Once the destination buffer has been
   * grown to the character count (which happens for a long string) and that
   * count is not a multiple of four, the four-byte write overran the buffer.
   * A string of 20001 characters reproduces it; the conversion must complete
   * and produce 4 bytes per character. */
  NSUInteger	n = 20001;	/* > internal grow threshold, not a multiple of 4 */
  NSString	*s = [@"" stringByPaddingToLength: n withString: @"A"
                                    startingAtIndex: 0];
  NSData	*d = [s dataUsingEncoding: NSUTF32LittleEndianStringEncoding];

  PASS([d length] == n * 4,
    "a long string converts to UTF-32 without overrunning the buffer")

  END_SET("NSString -> UTF-32 output bounds")
  return 0;
}
