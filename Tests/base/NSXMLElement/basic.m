#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLElement.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLElement          *node;
  NSXMLElement          *other;

  node = [[NSXMLElement alloc] initWithName: @"node"];
  test_alloc(@"NSXMLElement");
  test_NSObject(@"NSXMLElement", [NSArray arrayWithObject: node]);

  other = [[NSXMLElement alloc] initWithName: @"other"];
  PASS(NO == [other isEqual: node], "differently named elements are not equal");

  [other setName: @"node"];
  PASS_EQUAL([other name], @"node", "setting name of element works");
  PASS([other isEqual: node], "elements with same name are equal");

  [other release];
  [node release];

  [arp release];
  arp = nil;

  return 0;
}
