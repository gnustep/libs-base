#import "ObjectTesting.h"
#include <Foundation/NSTimeZone.h>

#define PREFIX "./"

int main(void)
{
   NSAutoreleasePool   *arp = [NSAutoreleasePool new];
   NSTimeZone *timeZone;
   NSDate *date;
   NSData *tzdata;

   timeZone =  [NSTimeZone timeZoneWithName: @"Europe/Paris"];
   PASS(timeZone != nil && [timeZone isKindOfClass: [NSTimeZone class]],
       "+timeZoneWithName works");

   /* Before last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"1981-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600, 
	"pre-1996 standard time offset vs UTC found for System Europe/Paris");

   date = [NSDate dateWithString: @"1981-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"pre-1996 DST time offset vs UTC found for System Europe/Paris");

   /* After last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"2021-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-1996 standard time offset vs UTC found for System Europe/Paris");

   date = [NSDate dateWithString: @"2021-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"post-1996 DST time offset vs UTC found for System Europe/Paris");

   /* Test using TZDB file known as being v1 */
   tzdata = [NSData dataWithContentsOfFile: @ PREFIX "Paris.tzdbv1"];
   PASS(tzdata != nil && [tzdata isKindOfClass: [NSData class]] && 
     [tzdata length] > 0, "Loading user-supplied Paris TZDBv1 works");

   timeZone =  [NSTimeZone timeZoneWithName: @"Paris.tzdb1" data: tzdata];
   PASS(timeZone != nil && [timeZone isKindOfClass: [NSTimeZone class]],
       "+timeZoneWithName data works");

   /* Before last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"1981-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"pre-1996 standard time offset vs UTC found for user Paris TZDBv1");

   date = [NSDate dateWithString: @"1981-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"pre-1996 DST time offset vs UTC found for user Paris TZDBv1");

   /* After last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"2021-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-1996 standard time offset vs UTC found for user Paris TZDBv1");

   date = [NSDate dateWithString: @"2021-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"post-1996 DST time offset vs UTC found for user Paris TZDBv1");

   /* Test using TZDB file known as being v2 */
   tzdata = [NSData dataWithContentsOfFile: @ PREFIX "Paris.tzdbv2"];
   PASS(tzdata != nil && [tzdata isKindOfClass: [NSData class]] && 
     [tzdata length] > 0, "Loading user-supplied Paris TZDBv2 works");

   timeZone =  [NSTimeZone timeZoneWithName: @"Paris.tzdbv2" data: tzdata];
   PASS(timeZone != nil && [timeZone isKindOfClass: [NSTimeZone class]],
       "+timeZoneWithName data works");

   /* Before last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"1981-01-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600, 
	"pre-1996 standard time offset vs UTC found for user Paris TZDBv2");

   date = [NSDate dateWithString: @"1981-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"pre-1996 DST time offset vs UTC found for user Paris TZDBv2");

   /* After last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"2021-01-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-1996 DST time offset vs UTC found for user Paris TZDBv2");

   date = [NSDate dateWithString: @"2021-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"post-1996 DST time offset vs UTC found for user Paris TZDBv2");

   /* After 32bit value seconds-since-1970 using TZDB v2+ file */
   date = [NSDate dateWithString: @"2039-01-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-2038 DST time offset vs UTC found for user Paris TZDBv2");

   [arp release]; arp = nil;
   return 0;
}
