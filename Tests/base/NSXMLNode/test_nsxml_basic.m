#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import "GNUstepBase/GSConfig.h"

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  START_SET("NSXMLNode basic creation")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else

  // Test 1: Create element node
  NSXMLElement *elem = [NSXMLElement elementWithName:@"root"];
  PASS(elem != nil, "Created element node");
  
  // Test 2: Check kind
  PASS([elem kind] == NSXMLElementKind, "Element has correct kind");
  
  // Test 3: Check name
  PASS_EQUAL([elem name], @"root", "Element has correct name");
  
  // Test 4: Create text node
  NSXMLNode *text = [NSXMLNode textWithStringValue:@"Hello"];
  PASS(text != nil, "Created text node");
  
  // Test 5: Check text node kind and value
  PASS([text kind] == NSXMLTextKind, "Text node has correct kind");
  PASS_EQUAL([text stringValue], @"Hello", "Text node has correct value");

#endif
  END_SET("NSXMLNode basic creation")
  [arp release];
  return 0;
}
