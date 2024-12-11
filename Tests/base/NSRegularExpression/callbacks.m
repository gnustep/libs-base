#import <Foundation/NSString.h>
#import <Foundation/NSRegularExpression.h>
#import <Foundation/NSTextCheckingResult.h>
#import "ObjectTesting.h"

int main(void)
{
	[NSAutoreleasePool new];
	START_SET("NSRegularExpression + callbacks")

#if !(__APPLE__ || GS_USE_ICU)
		SKIP("NSRegularExpression not built, please install libicu")
#else
  // load source file containing some text repeated 1000 times
  NSString *sourceText = [NSString stringWithContentsOfFile:@"bigSource.txt"];
  NSRegularExpression *simpleRegex = [NSRegularExpression regularExpressionWithPattern: @"ABC"
    options: 0 error: NULL];
  NSRange sourceRange = NSMakeRange(0, [sourceText length] - 1);
  
  // matchesInString:... uses enumerateMatchesInString:... without any callbacks
  NSArray *simpleMatches = [simpleRegex matchesInString: sourceText
                   options: 0
                     range: sourceRange];
  NSLog(@"Simple matches: %ld", [simpleMatches count]);
  PASS([simpleMatches count] == 1000, "1000 matches");
  
  // call enumerateMatchesInString:... directly, with callback
  __block NSInteger matchCount = 0;
  [simpleRegex enumerateMatchesInString:sourceText
                              options:NSMatchingReportProgress
                                range:NSMakeRange(0, [sourceText length] - 1)
                           usingBlock:^(NSTextCheckingResult * result, NSMatchingFlags flags, BOOL * stop) {
                               if (result) {
                                   matchCount++;
                               }
							   else {
							     NSLog(@"FLAGS: %d", flags);
							   }
                           }];

  
  NSLog(@"Number of matches: %ld", matchCount);
  PASS(matchCount == 1000, "enumerate with callback has same count");
  
  NSMutableString *otherString;
  
  
#endif

	END_SET("NSRegularExpression + callbacks")
	return 0;
}
