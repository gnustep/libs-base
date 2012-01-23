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

  PASS(NSXMLInvalidKind == [node kind], "invalid node kind is correct");
  PASS(0 == [node level], "invalid node level is zero");
  PASS_EQUAL([node name], nil, "invalid node name is nil");
  PASS_EQUAL([node URI], nil, "invalid node URI is nil");
  PASS_EQUAL([node objectValue], nil, "invalid node object value is nil");
  PASS_EQUAL([node stringValue], @"", "invalid node string value is empty");
  PASS_EQUAL([node children], nil, "invalid node children is nil");

  [node setName: @"name"];
  PASS_EQUAL([node name], nil,
    "setting name on invalid node gives a nil name");
  [node setURI: @"URI"];
  PASS_EQUAL([node URI], nil,
    "setting URI on invalid node gives a nil URI");
  [node setObjectValue: @"anObject"];
  PASS_EQUAL([node objectValue], @"anObject",
    "setting object value on invalid node works");
  [node setObjectValue: nil];
  // Per documentation on NSXMLNode setObjectValue/objectValue, 
  PASS_EQUAL([node objectValue], @"",
    "setting nil object value on invalid node works");
  [node setStringValue: @"aString"];
  PASS_EQUAL([node stringValue], @"aString",
    "setting string value on invalid node works");
  [node setStringValue: nil];
  PASS_EQUAL([node stringValue], @"",
    "setting nil string value on invalid node gives empty string");

  [node release];
  [other release];

  [arp release];
  arp = nil;

  return 0;
}
