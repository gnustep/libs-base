#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import "GNUstepBase/GSConfig.h"

/* Test text node handling - specifically that they DON'T merge unintentionally
 * This is the critical test for the libxml2 2.12.0+ fix
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  START_SET("NSXMLNode text node handling (no merging)")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else

  // Create parent element
  NSXMLElement *parent = [NSXMLElement elementWithName:@"parent"];
  
  // Test 1: Add multiple text nodes - they should NOT merge automatically
  NSXMLNode *text1 = [NSXMLNode textWithStringValue:@"Hello"];
  NSXMLNode *text2 = [NSXMLNode textWithStringValue:@"World"];
  
  [parent addChild:text1];
  [parent addChild:text2];
  
  NSUInteger childCount = [parent childCount];
  PASS(childCount == 2, "Two adjacent text nodes remain separate (no automatic merging)");
  
  // Test 2: Verify each text node has correct value
  NSXMLNode *retrieved1 = [parent childAtIndex:0];
  NSXMLNode *retrieved2 = [parent childAtIndex:1];
  
  PASS_EQUAL([retrieved1 stringValue], @"Hello", "First text node has correct value");
  PASS_EQUAL([retrieved2 stringValue], @"World", "Second text node has correct value");
  
  // Test 3: Insert text node between two others
  NSXMLElement *parent2 = [NSXMLElement elementWithName:@"parent2"];
  NSXMLNode *textA = [NSXMLNode textWithStringValue:@"A"];
  NSXMLNode *textB = [NSXMLNode textWithStringValue:@"B"];
  NSXMLNode *textC = [NSXMLNode textWithStringValue:@"C"];
  
  [parent2 addChild:textA];
  [parent2 addChild:textC];
  [parent2 insertChild:textB atIndex:1];
  
  PASS([parent2 childCount] == 3, "Three text nodes after insertion (no merging)");
  
  // Test 4: Verify order after insertion
  PASS([[parent2 childAtIndex:0] isEqual:textA], "First text node in correct position");
  PASS([[parent2 childAtIndex:1] isEqual:textB], "Inserted text node in correct position");
  PASS([[parent2 childAtIndex:2] isEqual:textC], "Last text node in correct position");

#endif
  END_SET("NSXMLNode text node handling (no merging)")
  [arp release];
  return 0;
}
