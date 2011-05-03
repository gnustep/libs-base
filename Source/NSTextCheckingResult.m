#import "Foundation/NSTextCheckingResult.h"
#import "Foundation/NSRegularExpression.h"

/**
 * Private class encapsulating a regular expression match.
 */
@interface GSRegularExpressionCheckingResult : NSTextCheckingResult
{
	// TODO: This could be made more efficient by adding a variant that only
	// contained a single range.
	@public
		/** The number of ranges matched */
		NSUInteger rangeCount;
		/** The array of ranges. */
		NSRange *ranges;
		/** The regular expression object that generated this match. */
		NSRegularExpression *regularExpression;
}
@end

@implementation NSTextCheckingResult
+ (NSTextCheckingResult*)regularExpressionCheckingResultWithRanges: (NSRangePointer)ranges
                                                             count: (NSUInteger)count
                                                 regularExpression: (NSRegularExpression*)regularExpression
{
	GSRegularExpressionCheckingResult *result = [GSRegularExpressionCheckingResult new];
	result->rangeCount = count;
	result->ranges = calloc(sizeof(NSRange), count);
	memcpy(result->ranges, ranges, (sizeof(NSRange) * count));
	ASSIGN(result->regularExpression, regularExpression);
	return [result autorelease];
}
- (NSDictionary*)addressComponents { return 0; }
- (NSDictionary*)components { return 0; }
- (NSDate*)date { return 0; }
- (NSTimeInterval) duration { return 0; }
- (NSArray*)grammarDetails { return 0; }
- (NSUInteger) numberOfRanges { return 0; }
- (NSOrthography*)orthography { return 0; }
- (NSString*)phoneNumber { return 0; }
- (NSRange) range { return NSMakeRange(0, NSNotFound); }
- (NSRegularExpression*)regularExpression { return 0; }
- (NSString*)replacementString { return 0; }
- (NSTextCheckingType)resultType { return -1; }
- (NSTimeZone*)timeZone { return 0; }
- (NSURL*)URL { return 0; }
@end



@implementation GSRegularExpressionCheckingResult
- (NSUInteger)rangeCount
{
	return rangeCount;
}
- (NSRange)range
{
	return ranges[0];
}
- (NSRange)rangeAtIndex: (NSUInteger)idx
{
	if (idx >= rangeCount)
	{
		return NSMakeRange(0, NSNotFound);
	}
	return ranges[idx];
}
- (NSTextCheckingType)resultType
{
	return NSTextCheckingTypeRegularExpression;
}
- (void)dealloc
{
	[regularExpression release];
	free(ranges);
	[super dealloc];
}
@end

