#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLNode             *node;
  NSXMLNode             *other;

  node = [[NSXMLNode alloc] initWithKind: NSXMLInvalidKind];
  test_alloc(@"NSXMLNode");
  test_NSObject(@"NSXMLNode", [NSArray arrayWithObject: node]);

  other = [[NSXMLNode alloc] initWithKind: NSXMLElementKind];
  PASS(NO == [other isEqual: node], "different node kinds are not equal");
  [other release];

  other = [[NSXMLNode alloc] initWithKind: NSXMLInvalidKind];
  PASS([other isEqual: node], "empty nodes are equal");
  [node release];

  [other setName: @"other"];
  PASS(nil == [other name], "setting name on invalid node gives a nil name");
  [other release];

  [arp release];
  arp = nil;

  return 0;
}
