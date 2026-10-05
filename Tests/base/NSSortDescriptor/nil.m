#import "ObjectTesting.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSortDescriptor.h>
#import <Foundation/NSValue.h>

/* A missing value sorts before every value, as on macOS. */
int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSSortDescriptor	*up;
  NSSortDescriptor	*down;
  NSDictionary		*none;
  NSDictionary		*one;
  NSDictionary		*two;
  NSArray		*all;
  NSArray		*sorted;

  up = [NSSortDescriptor sortDescriptorWithKey: @"age" ascending: YES];
  down = [NSSortDescriptor sortDescriptorWithKey: @"age" ascending: NO];
  none = [NSDictionary dictionary];
  one = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 1]
				    forKey: @"age"];
  two = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 2]
				    forKey: @"age"];

  PASS(([up compareObject: none toObject: one] == NSOrderedAscending),
    "nil is less than a value");
  PASS(([up compareObject: one toObject: none] == NSOrderedDescending),
    "a value is greater than nil");
  PASS(([up compareObject: none toObject: none] == NSOrderedSame),
    "nil is the same as nil");
  PASS(([down compareObject: none toObject: one] == NSOrderedDescending),
    "nil comes after a value in descending order");

  all = [NSArray arrayWithObjects: two, none, one, nil];
  sorted = [all sortedArrayUsingDescriptors: [NSArray arrayWithObject: up]];
  PASS_EQUAL(sorted, ([NSArray arrayWithObjects: none, one, two, nil]),
    "nil sorts first in ascending order");
  sorted = [all sortedArrayUsingDescriptors: [NSArray arrayWithObject: down]];
  PASS_EQUAL(sorted, ([NSArray arrayWithObjects: two, one, none, nil]),
    "nil sorts last in descending order");

  [arp release];
  return 0;
}
