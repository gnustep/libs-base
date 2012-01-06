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

  PASS(NSXMLElementKind == [node kind], "invalid node kind is correct");
  PASS(0 == [node level], "element node level is zero");
  PASS_EQUAL([node URI], nil, "element node URI is nil");
  PASS_EQUAL([node objectValue], @"", "element node object value is empty");
  PASS_EQUAL([node stringValue], @"", "element node string value is empty");
  PASS_EQUAL([node children], nil, "element node children is nil");

  [node setURI: @"URI"];
  PASS_EQUAL([node URI], @"URI",
    "setting URI on element node works");
  [node setObjectValue: @"anObject"];
  PASS_EQUAL([node objectValue], @"anObject",
    "setting object value on element node works");
  [node setObjectValue: nil];
  PASS_EQUAL([node objectValue], @"",
    "setting nil object value on element node gives empty string");
  [node setStringValue: @"aString"];
  PASS_EQUAL([node stringValue], @"aString",
    "setting string value on element node works");
  [node setStringValue: nil];
  PASS_EQUAL([node stringValue], @"",
    "setting nil string value on element node gives empty string");

  [node release];

  [arp release];
  arp = nil;

  return 0;
}
