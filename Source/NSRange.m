/* NSRange - range functions

*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

NSRange	
NSMakeRange(unsigned int location, unsigned int length)
{
    NSRange range;
    unsigned int end = location + length;

    if (end < location || end < length) {
	[NSException raise:NSRangeException
		    format:@"Range location + length too great"];
    }
    range.location = location;
    range.length   = length;
    return range;
}

/* Query a Range */
BOOL	
NSEqualRanges(NSRange range1, NSRange range2)
{
    return ((range1.location == range2.location)
    		&& (range1.length == range2.length));
}

/* Compute a Range from Two Other Ranges */
NSRange 
NSUnionRange(NSRange aRange, NSRange bRange)
{
    NSRange range;
    
    range.location = MIN(aRange.location, bRange.location);
    range.length   = MAX(NSMaxRange(aRange), NSMaxRange(bRange)) 
    		- range.location;
    return range;
}

NSRange 
NSIntersectionRange (NSRange aRange, NSRange bRange)
{
    NSRange range;
    
    if (NSMaxRange(aRange) < bRange.location
    		|| NSMaxRange(bRange) < aRange.location)
	return NSMakeRange(0, 0);
	
    range.location = MAX(aRange.location, bRange.location);
    range.length   = MIN(NSMaxRange(aRange), NSMaxRange(bRange)) 
    		- range.location;
    return range;
}

NSString *
NSStringFromRange(NSRange range)
{
    return [NSString stringWithFormat:@"{location = %d, length = %d}",
    		range.location, range.length];
}
