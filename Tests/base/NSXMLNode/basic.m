#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSValue.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLNode             *node;
  NSXMLNode             *other;
  NSXMLNode             *attr;
  NSNumber *number;

  node = [[NSXMLNode alloc] initWithKind: NSXMLInvalidKind];
  other = [[NSXMLNode alloc] initWithKind: NSXMLElementKind];
  // We need to set the name, otherwise isEqual: wont work.
  [other setName: @"test"];
  attr = [NSXMLNode attributeWithName: @"key"
			  stringValue: @"value"];

  test_alloc(@"NSXMLNode");
  test_NSObject(@"NSXMLNode", [NSArray arrayWithObjects: node, other, attr, nil]);
  test_NSCopying(@"NSXMLNode", @"NSXMLNode", [NSArray arrayWithObjects: node, other, attr, nil], NO, YES);

  PASS(NO == [other isEqual: node], "different node kinds are not equal");
  [other release];

  other = [[NSXMLNode alloc] initWithKind: NSXMLInvalidKind];
  PASS([other isEqual: node], "invalid nodes are equal");

  // Tests on invalid node
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
  PASS([node childCount] == 0, "No child after setting object value");
  // Per documentation on NSXMLNode setObjectValue/objectValue, 
  // On 10.6 this returns nil not @""
  PASS_EQUAL([node objectValue], nil,
    "setting nil object value on invalid node works");
  PASS_EQUAL([node stringValue], @"",
    "setting nil object value on invalid node gives empty string");
    
  number = [NSNumber numberWithInt: 12];
  [node setObjectValue: number];
  PASS_EQUAL([node objectValue], number,
    "setting object value on invalid node works");
  testHopeful = YES;
  PASS_EQUAL([node stringValue], @"1,2E1",
    "setting object value on invalid node sets string value");
  testHopeful = NO;
  [node setObjectValue: nil];
  
  [node setStringValue: @"aString"];
  PASS_EQUAL([node stringValue], @"aString",
    "setting string value on invalid node works");
  PASS_EQUAL([node objectValue], @"aString",
    "setting string value on invalid node sets object value");
   [node setStringValue: nil];
  PASS_EQUAL([node stringValue], @"",
    "setting nil string value on invalid node gives empty string");
  PASS_EQUAL([node objectValue], nil,
    "setting nil string value on invalid node sets object value to nil");

  [node release];
  [other release];

  // Tests on attribute node
  attr = [NSXMLNode attributeWithName: @"key"
			  stringValue: @"value"];
  PASS(NSXMLAttributeKind == [attr kind], "attr node kind is correct");
  PASS(0 == [attr level], "attr node level is zero");
  PASS_EQUAL([attr name], @"key", "name on attr node works");
  PASS_EQUAL([attr URI], nil, "attr node URI is nil");
  PASS_EQUAL([attr objectValue], @"value", "attr node object value works");
  PASS_EQUAL([attr stringValue], @"value", "string value on attr node works");
  // In libxml2 the value is on a child node
  //PASS_EQUAL([attr children], nil, "attr node children is nil");

  [attr setName: @"name"];
  PASS_EQUAL([attr name], @"name",
    "setting name on attr node works");
  [attr setStringValue: @"aString"];
  PASS_EQUAL([attr stringValue], @"aString",
    "setting string value on attr node works");
  // In libxml2 the value is on a child node
  //PASS([attr childCount] == 0, "No child on attr node");

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
