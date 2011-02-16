#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main(void)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSDateFormatter *inFmt;
  NSDateFormatter *outFmt;
  NSDate *date;
  NSString *str;
  NSLocale *locale;
  NSCalendar *cal;
  unsigned int components;
  NSInteger year;
  
  [NSTimeZone setDefaultTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  
  inFmt = [[NSDateFormatter alloc] init];
  [inFmt setDateFormat: @"yyyy-MM-dd 'at' HH:mm"];
  date = [inFmt dateFromString: @"2011-01-27 at 17:36"];
  outFmt = [[NSDateFormatter alloc] init];
  [outFmt setLocale: [[NSLocale alloc] initWithLocaleIdentifier: @"pt_BR"]];
  [outFmt setDateFormat: @"HH:mm 'on' EEEE MMMM d"];
  str = [outFmt stringFromDate: date];
  PASS_EQUAL(str, @"17:36 on quinta-feira janeiro 27",
    "Output has the same format as Cocoa.");
  RELEASE(outFmt);
  RELEASE(inFmt);
  
  locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"];
  inFmt = [NSDateFormatter new];
  [inFmt setDateStyle: NSDateFormatterShortStyle];
  [inFmt setTimeStyle: NSDateFormatterNoStyle];
  [inFmt setLocale: locale];
  [inFmt setTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  date = [inFmt dateFromString: @"15/06/1982"];
  PASS_EQUAL([date description], @"1982-06-15 00:00:00 +0000",
    "GMT time zone is correctly accounted for.");
  [inFmt setTimeZone: [NSTimeZone timeZoneWithName: @"EST"]];
  date = [inFmt dateFromString: @"15/06/1982"];
  PASS_EQUAL([date description], @"1982-06-15 05:00:00 +0000",
    "EST time zone is correctly accounted for.");
  RELEASE(inFmt);
  
  cal = [[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar];
  [cal setTimeZone: [NSTimeZone timeZoneWithName: @"CST"]];
  [cal setLocale: locale];
  components = NSYearCalendarUnit;
  year = [[cal components: components fromDate: date] year];
  inFmt = [NSDateFormatter new];
  [inFmt setLocale: locale];
  [inFmt setDateStyle: NSDateFormatterLongStyle];
  [inFmt setTimeStyle: NSDateFormatterNoStyle];
  str = [inFmt stringFromDate: date];
  PASS (year == 1982, "Year is 1982");
  PASS_EQUAL(str, @"15 June 1982", "Date is formatted correctly.");
  RELEASE(cal);
  RELEASE(inFmt);
  
  str = [NSDateFormatter dateFormatFromTemplate: @"MMMdd"
    options: 0 locale: locale];
  PASS_EQUAL(str, @"dd MMM", "Convert date format as Cocoa.");
  RELEASE(locale);
  
  RELEASE(pool);
  return 0;
}

