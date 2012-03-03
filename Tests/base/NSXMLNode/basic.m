#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLNode             *node;
  NSXMLNode             *other;
  NSXMLNode             *attr; 

  node = [[NSXMLNode alloc] initWithKind: NSXMLInvalidKind];
  other = [[NSXMLNode alloc] initWithKind: NSXMLElementKind];
  // We need to set the name, otherwise isEqual: wont work.
  [other setName: @"test"];
  test_alloc(@"NSXMLNode");
  test_NSObject(@"NSXMLNode", [NSArray arrayWithObjects: node, other, nil]);
  test_NSCopying(@"NSXMLNode", @"NSXMLNode", [NSArray arrayWithObjects: node, other, nil], NO, YES);

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
  // On 10.6 this returns nil not @""
  PASS_EQUAL([node objectValue], nil,
    "setting nil object value on invalid node works");
  [node setStringValue: @"aString"];
  PASS_EQUAL([node stringValue], @"aString",
    "setting string value on invalid node works");
  [node setStringValue: nil];
  PASS_EQUAL([node stringValue], @"",
    "setting nil string value on invalid node gives empty string");

  [node release];
  [other release];

  // Equality tests.
  node = [[NSXMLNode alloc] initWithKind: NSXMLElementKind];
  other = [[NSXMLNode alloc] initWithKind: NSXMLElementKind];
  [other setName: @"test"];
  [node setName: @"test"];
  PASS([node isEqual: other], 
       "Nodes with the same name are equal");
  
  attr = [NSXMLNode attributeWithName: @"key"
			  stringValue: @"value"];
  [node addAttribute:attr];
  PASS(![node isEqual: other],
       "Nodes with different attributes are NOT equal");

  attr = [NSXMLNode attributeWithName: @"key"
			  stringValue: @"value"];
  [other addAttribute:attr];
  PASS([node isEqual: other], 
       "Nodes with the same attributes are equal");

  [other setStringValue: @"value"];
  PASS(![node isEqual: other],
       "Nodes with different values are NOT equal");

  [node setStringValue: @"value"];
  PASS([node isEqual: other],
       "Nodes with different values are equal");

  [node release];
  [other release];

  [arp release];
  arp = nil;

  return 0;
}
