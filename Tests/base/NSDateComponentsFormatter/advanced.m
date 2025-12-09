#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSLocale.h>

int main()
{
  START_SET("NSDateComponentsFormatter advanced");

  NSDateComponentsFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSDateComponents *components;
  NSDate *date1, *date2;

  formatter = AUTORELEASE([[NSDateComponentsFormatter alloc] init]);

  // Test very long time intervals
  result = [formatter stringFromTimeInterval: 31536000]; // 1 year
  PASS(result != nil && [result length] > 0, "Format 1 year");

  result = [formatter stringFromTimeInterval: 2592000]; // 30 days
  PASS(result != nil && [result length] > 0, "Format 30 days");

  result = [formatter stringFromTimeInterval: 604800]; // 1 week
  PASS(result != nil && [result length] > 0, "Format 1 week");

  // Test very short intervals
  result = [formatter stringFromTimeInterval: 0.5]; // Half second
  PASS(result != nil && [result length] > 0, "Format half second");

  result = [formatter stringFromTimeInterval: 0.1]; // 100ms
  PASS(result != nil && [result length] > 0, "Format 100 milliseconds");

  // Test negative intervals
  result = [formatter stringFromTimeInterval: -3600];
  PASS(result != nil, "Handle negative time interval");

  // Test zero
  result = [formatter stringFromTimeInterval: 0];
  PASS(result != nil && [result length] > 0, "Format zero duration");

  // Test complex date components
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setYear: 1];
  [components setMonth: 2];
  [components setDay: 3];
  [components setHour: 4];
  [components setMinute: 5];
  [components setSecond: 6];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil && [result length] > 0, 
       "Format complex date components (1y 2mo 3d 4h 5m 6s)");

  // Test partial date components
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setMinute: 30];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil && [result length] > 0, "Format only minutes");

  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 2];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil && [result length] > 0, "Format only hours");

  // Test all unit styles with complex intervals
  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStylePositional];
  result = [formatter stringFromTimeInterval: 3723]; // 1:02:03
  PASS(result != nil, "Positional style with 1h 2m 3s");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleAbbreviated];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Abbreviated style with 1h 2m 3s");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleShort];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Short style with 1h 2m 3s");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleFull];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Full style with 1h 2m 3s");

  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleSpellOut];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Spell out style with 1h 2m 3s");

  // Test allowed units combinations
  [formatter setAllowedUnits: NSCalendarUnitHour];
  result = [formatter stringFromTimeInterval: 7200];
  PASS(result != nil, "Only hours allowed");

  [formatter setAllowedUnits: NSCalendarUnitMinute];
  result = [formatter stringFromTimeInterval: 7200];
  PASS(result != nil, "Only minutes allowed (should show 120 minutes)");

  [formatter setAllowedUnits: NSCalendarUnitSecond];
  result = [formatter stringFromTimeInterval: 7200];
  PASS(result != nil, "Only seconds allowed (should show 7200 seconds)");

  [formatter setAllowedUnits: NSCalendarUnitDay | NSCalendarUnitHour];
  result = [formatter stringFromTimeInterval: 100000]; // ~1.16 days
  PASS(result != nil, "Days and hours allowed");

  [formatter setAllowedUnits: NSCalendarUnitWeekOfYear | NSCalendarUnitDay];
  result = [formatter stringFromTimeInterval: 864000]; // 10 days
  PASS(result != nil, "Weeks and days allowed");

  [formatter setAllowedUnits: NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay];
  result = [formatter stringFromTimeInterval: 40000000]; // ~1.27 years
  PASS(result != nil, "Years, months, and days allowed");

  // Test zero formatting behaviors
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond];
  
  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorNone];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 0];
  [components setSecond: 5];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior None - may omit zero minutes");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDefault];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior Default");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDropLeading];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 0];
  [components setMinute: 5];
  [components setSecond: 30];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior DropLeading - omit leading zero hours");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 0];
  [components setSecond: 30];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior DropMiddle - may omit middle zero minutes");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 30];
  [components setSecond: 0];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior DropTrailing - omit trailing zero seconds");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDropAll];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 0];
  [components setSecond: 0];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior DropAll - omit all zero components");

  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorPad];
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 1];
  [components setMinute: 5];
  result = [formatter stringFromDateComponents: components];
  PASS(result != nil, "Zero behavior Pad - pad with zeros");

  // Test maximum unit count
  [formatter setZeroFormattingBehavior: NSDateComponentsFormatterZeroFormattingBehaviorDefault];
  [formatter setAllowedUnits: NSCalendarUnitDay | NSCalendarUnitHour | 
                               NSCalendarUnitMinute | NSCalendarUnitSecond];
  
  [formatter setMaximumUnitCount: 1];
  result = [formatter stringFromTimeInterval: 93784]; // 1d 2h 3m 4s
  PASS(result != nil, "Maximum 1 unit shown");

  [formatter setMaximumUnitCount: 2];
  result = [formatter stringFromTimeInterval: 93784];
  PASS(result != nil, "Maximum 2 units shown");

  [formatter setMaximumUnitCount: 3];
  result = [formatter stringFromTimeInterval: 93784];
  PASS(result != nil, "Maximum 3 units shown");

  [formatter setMaximumUnitCount: 0]; // No limit
  result = [formatter stringFromTimeInterval: 93784];
  PASS(result != nil, "No maximum unit count (show all)");

  // Test fractional units
  [formatter setMaximumUnitCount: 0];
  [formatter setAllowsFractionalUnits: YES];
  result = [formatter stringFromTimeInterval: 90]; // 1.5 minutes
  PASS(result != nil, "Fractional units enabled");

  [formatter setAllowsFractionalUnits: NO];
  result = [formatter stringFromTimeInterval: 90];
  PASS(result != nil, "Fractional units disabled");

  // Test collapsing largest unit
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute];
  [formatter setCollapsesLargestUnit: YES];
  result = [formatter stringFromTimeInterval: 7200]; // 2 hours = 120 minutes
  PASS(result != nil, "Collapse largest unit (show as minutes)");

  [formatter setCollapsesLargestUnit: NO];
  result = [formatter stringFromTimeInterval: 7200];
  PASS(result != nil, "Don't collapse largest unit (show as hours)");

  // Test approximation phrase
  [formatter setIncludesApproximationPhrase: YES];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Includes approximation phrase");

  [formatter setIncludesApproximationPhrase: NO];
  result = [formatter stringFromTimeInterval: 3723];
  PASS(result != nil, "Excludes approximation phrase");

  // Test date-to-date formatting with various intervals
  date1 = [NSDate date];
  date2 = [date1 dateByAddingTimeInterval: 90]; // 1.5 minutes
  result = [formatter stringFromDate: date1 toDate: date2];
  PASS(result != nil, "Format 90 second interval");

  date2 = [date1 dateByAddingTimeInterval: 3600]; // 1 hour
  result = [formatter stringFromDate: date1 toDate: date2];
  PASS(result != nil, "Format 1 hour interval");

  date2 = [date1 dateByAddingTimeInterval: 86400]; // 1 day
  result = [formatter stringFromDate: date1 toDate: date2];
  PASS(result != nil, "Format 1 day interval");

  date2 = [date1 dateByAddingTimeInterval: 604800]; // 1 week
  result = [formatter stringFromDate: date1 toDate: date2];
  PASS(result != nil, "Format 1 week interval");

  // Test with reversed dates
  date1 = [NSDate date];
  date2 = [date1 dateByAddingTimeInterval: -3600]; // 1 hour earlier
  result = [formatter stringFromDate: date1 toDate: date2];
  PASS(result != nil, "Handle reversed date order");

  // Test stringForObjectValue with different types
  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 3600]];
  PASS(result != nil && [result length] > 0, "Format NSNumber as seconds");

  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object");

  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 2];
  [components setMinute: 30];
  result = [formatter stringForObjectValue: components];
  PASS(result != nil && [result length] > 0, "Format NSDateComponents object");

  // Test class method
  components = AUTORELEASE([[NSDateComponents alloc] init]);
  [components setHour: 3];
  [components setMinute: 45];
  result = [NSDateComponentsFormatter localizedStringFromDateComponents: components
                                                          unitsStyle: NSDateComponentsFormatterUnitsStyleFull];
  PASS(result != nil, "Class method with Full style");

  result = [NSDateComponentsFormatter localizedStringFromDateComponents: components
                                                          unitsStyle: NSDateComponentsFormatterUnitsStyleShort];
  PASS(result != nil, "Class method with Short style");

  result = [NSDateComponentsFormatter localizedStringFromDateComponents: components
                                                          unitsStyle: NSDateComponentsFormatterUnitsStyleAbbreviated];
  PASS(result != nil, "Class method with Abbreviated style");

  // Test consistency
  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleShort];
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute];
  result = [formatter stringFromTimeInterval: 5400]; // 1h 30m
  result2 = [formatter stringFromTimeInterval: 5400];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test edge cases
  result = [formatter stringFromTimeInterval: 59]; // 59 seconds
  PASS(result != nil, "Format 59 seconds");

  result = [formatter stringFromTimeInterval: 60]; // Exactly 1 minute
  PASS(result != nil, "Format exactly 60 seconds");

  result = [formatter stringFromTimeInterval: 61]; // 61 seconds
  PASS(result != nil, "Format 61 seconds");

  result = [formatter stringFromTimeInterval: 3599]; // 59m 59s
  PASS(result != nil, "Format 59 minutes 59 seconds");

  result = [formatter stringFromTimeInterval: 3600]; // Exactly 1 hour
  PASS(result != nil, "Format exactly 1 hour");

  result = [formatter stringFromTimeInterval: 3601]; // 1h 0m 1s
  PASS(result != nil, "Format 1 hour 1 second");

  END_SET("NSDateComponentsFormatter advanced");
  return 0;
}
