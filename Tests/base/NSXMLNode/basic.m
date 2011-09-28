#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLNode           *node;

  node = [NSXMLNode new];
  test_alloc(@"NSXMLNode");
  test_NSObject(@"NSXMLNode", [NSArray arrayWithObject: node]);
  [arp release];
  arp = nil;

  [node release];
  return 0;
}
