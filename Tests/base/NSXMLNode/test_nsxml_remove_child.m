#import <Foundation/Foundation.h>

/* Test removing children from NSXMLElement
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
      NSXMLElement *child1 = [NSXMLElement elementWithName:@"child1"];
      NSXMLElement *child2 = [NSXMLElement elementWithName:@"child2"];
      NSXMLElement *child3 = [NSXMLElement elementWithName:@"child3"];
      
      [parent addChild:child1];
      [parent addChild:child2];
      [parent addChild:child3];
      
      // Test 1: Remove middle child
      [parent removeChildAtIndex:1];
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 children after remove, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      if (![[parent childAtIndex:0] isEqual:child1] ||
          ![[parent childAtIndex:1] isEqual:child3])
        {
          GSPrintf(stderr, @"ERROR: Wrong children remain after remove\n");
          exitCode = 1;
        }
      
      // Test 2: Verify removed child has no parent
      if ([child2 parent] != nil)
        {
          GSPrintf(stderr, @"ERROR: Removed child still has parent\n");
          exitCode = 1;
        }
      
      // Test 3: Remove first child
      [parent removeChildAtIndex:0];
      
      if ([parent childCount] != 1 || ![[parent childAtIndex:0] isEqual:child3])
        {
          GSPrintf(stderr, @"ERROR: Wrong child after removing first\n");
          exitCode = 1;
        }
      
      // Test 4: Remove last child
      [parent removeChildAtIndex:0];
      
      if ([parent childCount] != 0)
        {
          GSPrintf(stderr, @"ERROR: Parent should have no children\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Remove child tests passed\n");
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
