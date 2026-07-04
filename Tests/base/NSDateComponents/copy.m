#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendar.h>

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("copy is an independent object")
    NSDateComponents	*dc = [[NSDateComponents new] autorelease];
    NSDateComponents	*c;

    [dc setYear: 1999];
    [dc setMonth: 12];
    [dc setDay: 31];
    [dc setLeapMonth: YES];

    c = [[dc copy] autorelease];

    /* NSDateComponents is mutable, so a copy must be a separate object. */
    PASS(c != dc, "copy returns a distinct object");
    PASS(1999 == [c year], "copy preserves year");
    PASS(12 == [c month], "copy preserves month");
    PASS(31 == [c day], "copy preserves day");
    PASS(YES == [c leapMonth], "copy preserves leapMonth");

    /* Mutating the copy must not reach back into the original. */
    [c setYear: 2020];
    PASS(2020 == [c year], "the copy is independently mutable");
    PASS(1999 == [dc year], "mutating the copy leaves the original unchanged");
  END_SET("copy is an independent object")

  [arp release]; arp = nil;
  return 0;
}
