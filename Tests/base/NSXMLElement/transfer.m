#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSXMLElement *elem1 = [[NSXMLElement alloc] initWithXMLString: @"<num>6</num>" error: NULL];
  NSXMLElement *elem2 = [[NSXMLElement alloc] initWithXMLString: @"<num>7</num>" error: NULL];
  NSXMLElement *copy1 = [elem1 copy];
  NSXMLElement *copy2 = [elem2 copy];

  [copy1 setStringValue: @"7"];
  PASS_EQUAL(copy1, copy2, "equal after setStringValue:");

  [arp drain];
  arp = nil;

  return 0;
}
