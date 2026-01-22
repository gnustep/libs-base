#import <Foundation/Foundation.h>

/* Test complex tree operations with multiple levels
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      // Create a complex tree structure
      NSXMLElement *root = [NSXMLElement elementWithName:@"root"];
      NSXMLElement *section1 = [NSXMLElement elementWithName:@"section"];
      NSXMLElement *section2 = [NSXMLElement elementWithName:@"section"];
      
      [root addChild:section1];
      [root addChild:section2];
      
      // Add text and elements to section1
      NSXMLNode *text1 = [NSXMLNode textWithStringValue:@"Intro: "];
      NSXMLElement *para1 = [NSXMLElement elementWithName:@"para"];
      NSXMLNode *paraText1 = [NSXMLNode textWithStringValue:@"First paragraph"];
      
      [section1 addChild:text1];
      [section1 addChild:para1];
      [para1 addChild:paraText1];
      
      // Add multiple text nodes to section2
      NSXMLNode *textA = [NSXMLNode textWithStringValue:@"A"];
      NSXMLNode *textB = [NSXMLNode textWithStringValue:@"B"];
      NSXMLNode *textC = [NSXMLNode textWithStringValue:@"C"];
      
      [section2 addChild:textA];
      [section2 addChild:textB];
      [section2 addChild:textC];
      
      // Test 1: Verify structure
      if ([root childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Root should have 2 children\n");
          exitCode = 1;
        }
      
      if ([section1 childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Section1 should have 2 children\n");
          exitCode = 1;
        }
      
      if ([section2 childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Section2 should have 3 children, got %lu\n",
                   (unsigned long)[section2 childCount]);
          exitCode = 1;
        }
      
      // Test 2: Verify text nodes in section2 didn't merge
      NSArray *section2Children = [section2 children];
      if ([section2Children count] != 3)
        {
          GSPrintf(stderr, @"ERROR: Text nodes merged in section2\n");
          exitCode = 1;
        }
      
      if (![[section2Children objectAtIndex:0] isEqual:textA] ||
          ![[section2Children objectAtIndex:1] isEqual:textB] ||
          ![[section2Children objectAtIndex:2] isEqual:textC])
        {
          GSPrintf(stderr, @"ERROR: Section2 children are wrong\n");
          exitCode = 1;
        }
      
      // Test 3: Move para1 to section2
      [para1 detach];
      [section2 insertChild:para1 atIndex:1];
      
      if ([section1 childCount] != 1)
        {
          GSPrintf(stderr, @"ERROR: Section1 should have 1 child after detach\n");
          exitCode = 1;
        }
      
      if ([section2 childCount] != 4)
        {
          GSPrintf(stderr, @"ERROR: Section2 should have 4 children after insert\n");
          exitCode = 1;
        }
      
      if ([para1 parent] != section2)
        {
          GSPrintf(stderr, @"ERROR: para1 should have section2 as parent\n");
          exitCode = 1;
        }
      
      // Test 4: Verify nested child still intact
      if ([para1 childCount] != 1)
        {
          GSPrintf(stderr, @"ERROR: para1 should still have its child\n");
          exitCode = 1;
        }
      
      if (![[para1 childAtIndex:0] isEqual:paraText1])
        {
          GSPrintf(stderr, @"ERROR: para1's child is wrong\n");
          exitCode = 1;
        }
      
      // Test 5: Insert element between text nodes
      NSXMLElement *span = [NSXMLElement elementWithName:@"span"];
      [section2 insertChild:span atIndex:1];
      
      // Should be: textA, span, para1, textB, textC
      if ([section2 childCount] != 5)
        {
          GSPrintf(stderr, @"ERROR: Section2 should have 5 children\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Complex tree tests passed\n");
        }
    }
  NS_HANDLER
    {
      GSPrintf(stderr, @"EXCEPTION: %@: %@\n", [localException name], [localException reason]);
      exitCode = 1;
    }
  NS_ENDHANDLER
  
  [arp release];
  return exitCode;
}
