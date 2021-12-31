#import "Testing.h"
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#include "./western.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSTimeInterval time1, time2, time3, time4, time5, time6, time7, time8, time9;
  NSCalendarDate *date1;
  NSDictionary *locale;

  locale = westernLocale();

  date1 = [NSCalendarDate dateWithString: @"Nov 29 06 01:25:38" 
                          calendarFormat: @"%b %d %y %H:%M:%S"
				  locale: locale];
  PASS([date1 timeIntervalSinceReferenceDate] + 1 == [[date1 addTimeInterval:1]
  						timeIntervalSinceReferenceDate],
       "-addTimeInterval: works on a NSCalendarDate parsed with no timezone");

  [arp release]; arp = nil;
  return 0;
}
