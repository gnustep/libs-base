#import <Foundation/Foundation.h>

/* Test replacing children in NSXMLElement
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
      
      // Test 1: Replace middle child
      NSXMLElement *newChild = [NSXMLElement elementWithName:@"newChild"];
      [parent replaceChildAtIndex:1 withNode:newChild];
      
      if ([parent childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Expected 3 children after replace\n");
          exitCode = 1;
        }
      
      if (![[parent childAtIndex:1] isEqual:newChild])
        {
          GSPrintf(stderr, @"ERROR: Child not replaced correctly\n");
          exitCode = 1;
        }
      
      // Test 2: Verify order preserved
      if (![[parent childAtIndex:0] isEqual:child1] ||
          ![[parent childAtIndex:2] isEqual:child3])
        {
          GSPrintf(stderr, @"ERROR: Other children affected by replacement\n");
          exitCode = 1;
        }
      
      // Test 3: Verify old child detached
      if ([child2 parent] != nil)
        {
          GSPrintf(stderr, @"ERROR: Replaced child still has parent\n");
          exitCode = 1;
        }
      
      // Test 4: Verify new child has correct parent
      if ([newChild parent] != parent)
        {
          GSPrintf(stderr, @"ERROR: New child doesn't have correct parent\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Replace child tests passed\n");
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
