#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSDateComponentsFormatter encoding");

  NSDateComponentsFormatter *formatter;
  NSDateComponentsFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSCalendar *calendar;

  formatter = AUTORELEASE([[NSDateComponentsFormatter alloc] init]);
  
  // Configure the formatter with basic properties
  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleAbbreviated];
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute];
  [formatter setMaximumUnitCount: 2];
  
  calendar = [NSCalendar currentCalendar];
  [formatter setCalendar: calendar];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSDateComponentsFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSDateComponentsFormatter");
  PASS([decoded isKindOfClass: [NSDateComponentsFormatter class]], 
       "Decoded object is NSDateComponentsFormatter");

  // Verify basic properties are preserved
  PASS([decoded unitsStyle] == NSDateComponentsFormatterUnitsStyleAbbreviated,
       "unitsStyle preserved");
  PASS([decoded allowedUnits] == (NSCalendarUnitHour | NSCalendarUnitMinute),
       "allowedUnits preserved");
  PASS([decoded maximumUnitCount] == 2,
       "maximumUnitCount preserved");
  PASS([decoded calendar] != nil,
       "calendar preserved");

  // Verify formatting behavior is consistent
  result1 = [formatter stringFromTimeInterval: 3665];
  result2 = [decoded stringFromTimeInterval: 3665];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSDateComponentsFormatter encoding");
  return 0;
}
