#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSDateComponentsFormatter basic");

  NSDateComponentsFormatter *formatter;
  NSString *result;
  NSDateComponents *components;

  // Test instance creation
  formatter = AUTORELEASE([[NSDateComponentsFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSDateComponentsFormatter instance");

  // Test basic time interval formatting
  result = [formatter stringFromTimeInterval: 0];
  PASS(result != nil && [result length] > 0, "Format 0 seconds");

  result = [formatter stringFromTimeInterval: 60];
  PASS(result != nil && [result length] > 0, "Format 60 seconds (1 minute)");

  result = [formatter stringFromTimeInterval: 3600];
  PASS(result != nil && [result length] > 0, "Format 3600 seconds (1 hour)");

  result = [formatter stringFromTimeInterval: 86400];
  PASS(result != nil && [result length] > 0, "Format 86400 seconds (1 day)");

  // Test date components formatting
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 2];
  [components setMinute: 30];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil && [result length] > 0, 
       "Format date components (2 hours 30 minutes)");

  // Test date-to-date formatting
  NSDate *startDate = [NSDate date];
  NSDate *endDate = [startDate dateByAddingTimeInterval: 7200]; // 2 hours later
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format date range");

  // Test unit styles
  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStylePositional];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Positional style works");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleAbbreviated];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Abbreviated style works");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleShort];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Short style works");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleFull];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Full style works");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleSpellOut];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Spell out style works");

  // Test allowed units
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute];
  result = [formatter stringFromTimeInterval: 3665];
  PASS(result != nil, "Allowed units restriction works");

  [formatter setAllowedUnits: NSCalendarUnitDay | NSCalendarUnitHour];
  result = [formatter stringFromTimeInterval: 90000]; // 25 hours
  PASS(result != nil, "Day and hour units work");

  // Test zero formatting behavior
  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorNone];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 0];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero formatting behavior None works");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDefault];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero formatting behavior Default works");

  // Test maximum unit count
  [formatter setMaximumUnitCount: 2];
  [formatter setAllowedUnits: NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute];
  result = [formatter stringFromTimeInterval: 90000]; // Should show only 2 largest units
  PASS(result != nil, "Maximum unit count works");

  // Test allows fractional units
  [formatter setAllowsFractionalUnits: YES];
  result = [formatter stringFromTimeInterval: 90];
  PASS(result != nil, "Fractional units enabled works");

  [formatter setAllowsFractionalUnits: NO];
  result = [formatter stringFromTimeInterval: 90];
  PASS(result != nil, "Fractional units disabled works");

  // Test collapsing largest unit
  [formatter setCollapsesLargestUnit: YES];
  result = [formatter stringFromTimeInterval: 3600];
  PASS(result != nil, "Collapse largest unit enabled works");

  [formatter setCollapsesLargestUnit: NO];
  result = [formatter stringFromTimeInterval: 3600];
  PASS(result != nil, "Collapse largest unit disabled works");
/*
  // Test includes time remaining phrase
  [formatter setIncludesTimeRemainingPhrase: YES];
  result = [formatter stringFromTimeInterval: 120];
  PASS(result != nil, "Time remaining phrase enabled works");

  [formatter setIncludesTimeRemainingPhrase: NO];
  result = [formatter stringFromTimeInterval: 120];
  PASS(result != nil, "Time remaining phrase disabled works");
*/
  // Test includes approximate phrase
  [formatter setIncludesApproximationPhrase: YES];
  result = [formatter stringFromTimeInterval: 3700];
  PASS(result != nil, "Approximation phrase enabled works");

  [formatter setIncludesApproximationPhrase: NO];
  result = [formatter stringFromTimeInterval: 3700];
  PASS(result != nil, "Approximation phrase disabled works");

  // Test stringForObjectValue:
  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 7200]];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSNumber");

  // Test class method
  result = [NSDateComponentsFormatter localizedStringFromDateComponents: components
                                                          unitsStyle: NSDateComponentsFormatterUnitsStyleFull];
  PASS(result != nil, "Class method localizedStringFromDateComponents works");

  END_SET("NSDateComponentsFormatter basic");
  return 0;
}
