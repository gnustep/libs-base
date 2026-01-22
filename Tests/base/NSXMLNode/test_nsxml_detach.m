#import <Foundation/Foundation.h>

/* Test detaching nodes from their parents
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
      
      // Test 1: Detach middle child
      [child2 detach];
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 children after detach, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      if ([child2 parent] != nil)
        {
          GSPrintf(stderr, @"ERROR: Detached child still has parent\n");
          exitCode = 1;
        }
      
      // Test 2: Verify remaining children
      if (![[parent childAtIndex:0] isEqual:child1] ||
          ![[parent childAtIndex:1] isEqual:child3])
        {
          GSPrintf(stderr, @"ERROR: Wrong children after detach\n");
          exitCode = 1;
        }
      
      // Test 3: Reattach detached child
      [parent insertChild:child2 atIndex:1];
      
      if ([parent childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Expected 3 children after reattach\n");
          exitCode = 1;
        }
      
      if ([child2 parent] != parent)
        {
          GSPrintf(stderr, @"ERROR: Reattached child has wrong parent\n");
          exitCode = 1;
        }
      
      // Test 4: Detach and add to different parent
      NSXMLElement *newParent = [NSXMLElement elementWithName:@"newParent"];
      [child1 detach];
      [newParent addChild:child1];
      
      if ([child1 parent] != newParent)
        {
          GSPrintf(stderr, @"ERROR: Child not properly moved to new parent\n");
          exitCode = 1;
        }
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Original parent still has detached child\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Detach tests passed\n");
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
