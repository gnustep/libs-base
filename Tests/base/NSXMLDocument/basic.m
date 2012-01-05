#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLDocument         *node;

  node = [NSXMLDocument alloc];
  PASS_EXCEPTION([node initWithDate: nil options: 0 error: 0],
    NSInvalidArgumentException,
    "Cannot initialise an XML document with nil data");

  node = [NSXMLDocument alloc];
  PASS_EXCEPTION([node initWithDate: (NSData*)@"bad" options: 0 error: 0],
    NSInvalidArgumentException,
    "Cannot initialise an XML document with bad data class");

  node = [[NSXMLDocument alloc] init];
  test_alloc(@"NSXMLNode");
  test_NSObject(@"NSXMLNode", [NSArray arrayWithObject: node]);
  [arp release];
  arp = nil;

  [node release];
  return 0;
}
