#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSXMLDocument *node;
  NSXMLElement *elem;

  node = [NSXMLDocument alloc];
  PASS_EXCEPTION([node initWithData: nil options: 0 error: 0],
    NSInvalidArgumentException,
    "Cannot initialise an XML document with nil data");

  node = [NSXMLDocument alloc];
  PASS_EXCEPTION([node initWithData: (NSData*)@"bad" options: 0 error: 0],
    NSInvalidArgumentException,
    "Cannot initialise an XML document with bad data class");

  node = [[NSXMLDocument alloc] init];
  test_alloc(@"NSXMLDocument");
  test_NSObject(@"NSXMLDocument", [NSArray arrayWithObject: node]);

  elem = [[NSXMLElement alloc] initWithName: @"elem1"];
  [node addChild: elem];
  PASS_EQUAL([[node children] lastObject], elem, "can add elem to doc");
  [elem release];
  elem = [[NSXMLElement alloc] initWithName: @"root"];
  [node setRootElement: elem];
  PASS_EQUAL([[node children] lastObject], elem, "can set elem as root");
  PASS([[node children] count] == 1, "set root removes other children");
  
  PASS_RUNS([node setRootElement: nil], "setting a nil root is ignored");
  PASS_EQUAL([node rootElement], elem, "root element remains");

  [arp release];
  arp = nil;

  [elem release];
  [node release];
  return 0;
}
