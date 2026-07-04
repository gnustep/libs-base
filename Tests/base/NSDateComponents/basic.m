#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSTimeZone.h>

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("defaults")
    NSDateComponents	*dc = [[NSDateComponents new] autorelease];

    /* Every component is undefined until it is set. */
    PASS(NSDateComponentUndefined == [dc year], "year defaults to undefined");
    PASS(NSDateComponentUndefined == [dc month], "month defaults to undefined");
    PASS(NSDateComponentUndefined == [dc day], "day defaults to undefined");
    PASS(NSDateComponentUndefined == [dc hour], "hour defaults to undefined");
    PASS(NSDateComponentUndefined == [dc minute],
      "minute defaults to undefined");
    PASS(NSDateComponentUndefined == [dc second],
      "second defaults to undefined");
    PASS(NSDateComponentUndefined == [dc nanosecond],
      "nanosecond defaults to undefined");
    PASS(NO == [dc leapMonth], "leapMonth defaults to NO");
    PASS(nil == [dc calendar], "calendar defaults to nil");
    PASS(nil == [dc timeZone], "timeZone defaults to nil");
  END_SET("defaults")

  START_SET("accessor round-trip")
    NSDateComponents	*dc = [[NSDateComponents new] autorelease];

    [dc setEra: 1];
    [dc setYear: 2001];
    [dc setMonth: 2];
    [dc setDay: 3];
    [dc setHour: 4];
    [dc setMinute: 5];
    [dc setSecond: 6];
    [dc setNanosecond: 7];
    [dc setWeekday: 3];
    [dc setWeekdayOrdinal: 2];
    [dc setQuarter: 1];
    [dc setWeekOfMonth: 2];
    [dc setWeekOfYear: 9];
    [dc setYearForWeekOfYear: 2000];

    PASS(1 == [dc era], "era round-trips");
    PASS(2001 == [dc year], "year round-trips");
    PASS(2 == [dc month], "month round-trips");
    PASS(3 == [dc day], "day round-trips");
    PASS(4 == [dc hour], "hour round-trips");
    PASS(5 == [dc minute], "minute round-trips");
    PASS(6 == [dc second], "second round-trips");
    PASS(7 == [dc nanosecond], "nanosecond round-trips");
    PASS(3 == [dc weekday], "weekday round-trips");
    PASS(2 == [dc weekdayOrdinal], "weekdayOrdinal round-trips");
    PASS(1 == [dc quarter], "quarter round-trips");
    PASS(2 == [dc weekOfMonth], "weekOfMonth round-trips");
    PASS(9 == [dc weekOfYear], "weekOfYear round-trips");
    PASS(2000 == [dc yearForWeekOfYear], "yearForWeekOfYear round-trips");

    [dc setLeapMonth: YES];
    PASS(YES == [dc leapMonth], "leapMonth round-trips");
  END_SET("accessor round-trip")

  START_SET("valueForComponent: symmetry")
    NSDateComponents	*dc = [[NSDateComponents new] autorelease];

    /* setValue:forComponent: is visible through the property accessor... */
    [dc setValue: 2011 forComponent: NSCalendarUnitYear];
    [dc setValue: 7 forComponent: NSCalendarUnitMonth];
    [dc setValue: 42 forComponent: NSCalendarUnitNanosecond];
    PASS(2011 == [dc year], "setValue:forComponent: sets the year property");
    PASS(7 == [dc month], "setValue:forComponent: sets the month property");
    PASS(42 == [dc nanosecond],
      "setValue:forComponent: sets the nanosecond property");

    /* ...and the property setter is visible through valueForComponent:. */
    [dc setDay: 15];
    PASS(15 == [dc valueForComponent: NSCalendarUnitDay],
      "valueForComponent: reads the day property");
    PASS(2011 == [dc valueForComponent: NSCalendarUnitYear],
      "valueForComponent: reads the year property");

    /* weekOfYear and the deprecated week share storage. */
    [dc setValue: 5 forComponent: NSCalendarUnitWeekOfYear];
    PASS(5 == [dc weekOfYear],
      "NSCalendarUnitWeekOfYear maps to the weekOfYear property");
    PASS(5 == [dc week],
      "NSCalendarUnitWeekOfYear shares storage with the deprecated week");
  END_SET("valueForComponent: symmetry")

  START_SET("isValidDate without a calendar")
    NSDateComponents	*dc = [[NSDateComponents new] autorelease];

    [dc setYear: 2001];
    [dc setMonth: 1];
    [dc setDay: 1];
    PASS(NO == [dc isValidDate],
      "isValidDate is NO when no calendar is attached");
    PASS(nil == [dc date],
      "date is nil when no calendar is attached");
  END_SET("isValidDate without a calendar")

  START_SET("date through a Gregorian calendar")
    NSCalendar	*cal = [[[NSCalendar alloc]
      initWithCalendarIdentifier: NSCalendarIdentifierGregorian] autorelease];

    if (nil == cal)
      {
	SKIP("Gregorian calendar unavailable")
      }
    else
      {
	NSDateComponents	*dc = [[NSDateComponents new] autorelease];
	NSTimeZone		*utc = [NSTimeZone timeZoneWithName: @"UTC"];
	NSDate			*date;
	NSDateComponents	*back;

	[cal setTimeZone: utc];
	[dc setYear: 2001];
	[dc setMonth: 1];
	[dc setDay: 1];
	[dc setHour: 12];
	[dc setMinute: 30];
	[dc setSecond: 0];

	date = [cal dateFromComponents: dc];
	PASS(date != nil, "dateFromComponents: builds a date");

	back = [cal components:
	  NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
	  | NSCalendarUnitHour | NSCalendarUnitMinute
	  fromDate: date];
	PASS(2001 == [back year], "the year survives the calendar round-trip");
	PASS(1 == [back month], "the month survives the calendar round-trip");
	PASS(1 == [back day], "the day survives the calendar round-trip");
	PASS(12 == [back hour], "the hour survives the calendar round-trip");
	PASS(30 == [back minute],
	  "the minute survives the calendar round-trip");

	/* -[NSDateComponents date] uses its own attached calendar. */
	[dc setCalendar: cal];
	PASS_EQUAL(date, [dc date],
	  "-[NSDateComponents date] uses the attached calendar");
      }
  END_SET("date through a Gregorian calendar")

  [arp release]; arp = nil;
  return 0;
}
