#import <Foundation/Foundation.h>

/* Test setting children array on NSXMLElement
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      NSXMLElement *parent = [NSXMLElement elementWithName:@"parent"];
      NSXMLElement *oldChild1 = [NSXMLElement elementWithName:@"old1"];
      NSXMLElement *oldChild2 = [NSXMLElement elementWithName:@"old2"];
      
      [parent addChild:oldChild1];
      [parent addChild:oldChild2];
      
      // Test 1: Replace all children with new array
      NSXMLElement *newChild1 = [NSXMLElement elementWithName:@"new1"];
      NSXMLElement *newChild2 = [NSXMLElement elementWithName:@"new2"];
      NSXMLElement *newChild3 = [NSXMLElement elementWithName:@"new3"];
      
      NSArray *newChildren = [NSArray arrayWithObjects:newChild1, newChild2, newChild3, nil];
      [parent setChildren:newChildren];
      
      if ([parent childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Expected 3 children after setChildren, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 2: Verify new children
      if (![[parent childAtIndex:0] isEqual:newChild1] ||
          ![[parent childAtIndex:1] isEqual:newChild2] ||
          ![[parent childAtIndex:2] isEqual:newChild3])
        {
          GSPrintf(stderr, @"ERROR: Wrong children after setChildren\n");
          exitCode = 1;
        }
      
      // Test 3: Verify old children are detached
      if ([oldChild1 parent] != nil || [oldChild2 parent] != nil)
        {
          GSPrintf(stderr, @"ERROR: Old children still have parent\n");
          exitCode = 1;
        }
      
      // Test 4: Set children to empty array
      [parent setChildren:[NSArray array]];
      
      if ([parent childCount] != 0)
        {
          GSPrintf(stderr, @"ERROR: Expected 0 children after setting empty array\n");
          exitCode = 1;
        }
      
      // Test 5: Set children with text nodes
      NSXMLNode *text1 = [NSXMLNode textWithStringValue:@"Text1"];
      NSXMLNode *text2 = [NSXMLNode textWithStringValue:@"Text2"];
      NSArray *textChildren = [NSArray arrayWithObjects:text1, text2, nil];
      
      [parent setChildren:textChildren];
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 text children, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 6: Verify text nodes didn't merge
      if (![[parent childAtIndex:0] isEqual:text1] ||
          ![[parent childAtIndex:1] isEqual:text2])
        {
          GSPrintf(stderr, @"ERROR: Text nodes merged in setChildren\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Set children tests passed\n");
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
