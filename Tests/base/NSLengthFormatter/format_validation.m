#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>

int main()
{
  START_SET("NSLengthFormatter format validation");

  NSLengthFormatter *formatter;
  NSString *result;

  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);
  
  // Test meter formatting
  result = [formatter stringFromMeters: 1.0];
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       ([result rangeOfString: @"m"].location != NSNotFound ||
        [result rangeOfString: @"meter"].location != NSNotFound),
       "1 meter format includes number and unit");

  // Test kilometer formatting
  result = [formatter stringFromValue: 5.0 unit: NSLengthFormatterUnitKilometer];
  PASS([result length] > 0,
       "5 km format produces output");

  // Test inch formatting
  result = [formatter stringFromValue: 12.0 unit: NSLengthFormatterUnitInch];
  PASS([result rangeOfString: @"12"].location != NSNotFound &&
       ([result rangeOfString: @"in"].location != NSNotFound ||
        [result rangeOfString: @"inch"].location != NSNotFound),
       "12 inches format correct");

  // Test foot formatting
  result = [formatter stringFromValue: 6.0 unit: NSLengthFormatterUnitFoot];
  PASS([result rangeOfString: @"6"].location != NSNotFound &&
       ([result rangeOfString: @"ft"].location != NSNotFound ||
        [result rangeOfString: @"foot"].location != NSNotFound ||
        [result rangeOfString: @"feet"].location != NSNotFound),
       "6 feet format correct");

  // Test mile formatting
  result = [formatter stringFromValue: 2.0 unit: NSLengthFormatterUnitMile];
  PASS([result rangeOfString: @"2"].location != NSNotFound &&
       ([result rangeOfString: @"mi"].location != NSNotFound ||
        [result rangeOfString: @"mile"].location != NSNotFound),
       "2 miles format correct");

  // Test unit style variations
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  NSString *shortResult = [formatter stringFromMeters: 100.0];
  
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  NSString *longResult = [formatter stringFromMeters: 100.0];
  
  PASS(![shortResult isEqualToString: longResult] ||
       [shortResult length] > 0,
       "Different unit styles produce different or valid results");

  // Test zero handling
  result = [formatter stringFromMeters: 0.0];
  PASS([result rangeOfString: @"0"].location != NSNotFound,
       "Zero meters shows 0");

  END_SET("NSLengthFormatter format validation");
  return 0;
}
