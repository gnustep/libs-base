/* NSRange - range functions

*/

#include <config.h>

#define	IN_NSRANGE_M 1
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRange.h>

@class	NSString;

NSRange
NSMakeRange(unsigned int location, unsigned int length)
{
  NSRange range;
  unsigned int end = location + length;

  if (end < location || end < length)
    {
      [NSException raise: NSRangeException
                  format: @"Range location + length too great"];
    }
  range.location = location;
  range.length   = length;
  return range;
}

NSString *
NSStringFromRange(NSRange range)
{
  return [NSString stringWithFormat: @"{location = %d, length = %d}",
    		range.location, range.length];
}

