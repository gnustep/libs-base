#import <Foundation/NSString.h>
#import <Foundation/NSRegularExpression.h>
#import "ObjectTesting.h"

int main(void)
{
	[NSAutoreleasePool new];
	START_SET("NSString + regex")
	NS_DURING
		[NSRegularExpression new];
	NS_HANDLER
		SKIP("NSRegularExpression not built, please install libicu")
		return 0;
	NS_ENDHANDLER
		
	NSString *regex = @"abcd*";
	NSString *source = @"abcdddddd e f g";
	NSRange r = [source rangeOfString: regex options: NSRegularExpressionSearch];
	PASS(r.length == 9, "Correct length for regex, expected 9 got %d", (int)r.length);
	regex = @"aBcD*";
	r = [source rangeOfString: regex options: (NSRegularExpressionSearch | NSCaseInsensitiveSearch)];
	PASS(r.length == 9, "Correct length for regex, expected 9 got %d", (int)r.length);
	END_SET("NSString + regex")
	return 0;
}
