#import <Foundation/Foundation.h>

/* Test adding children to NSXMLElement
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      // Create parent element
      NSXMLElement *parent = [NSXMLElement elementWithName:@"parent"];
      
      // Test 1: Add single child
      NSXMLElement *child1 = [NSXMLElement elementWithName:@"child1"];
      [parent addChild:child1];
      
      if ([parent childCount] != 1)
        {
          GSPrintf(stderr, @"ERROR: Expected 1 child, got %lu\n", 
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 2: Verify child is correct
      NSXMLNode *retrieved = [parent childAtIndex:0];
      if (![[retrieved name] isEqualToString:@"child1"])
        {
          GSPrintf(stderr, @"ERROR: Wrong child name: %@\n", [retrieved name]);
          exitCode = 1;
        }
      
      // Test 3: Add second child
      NSXMLElement *child2 = [NSXMLElement elementWithName:@"child2"];
      [parent addChild:child2];
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 children, got %lu\n", 
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 4: Verify order
      NSArray *children = [parent children];
      if (![[children objectAtIndex:0] isEqual:child1] ||
          ![[children objectAtIndex:1] isEqual:child2])
        {
          GSPrintf(stderr, @"ERROR: Children in wrong order\n");
          exitCode = 1;
        }
      
      // Test 5: Verify parent links
      if ([child1 parent] != parent || [child2 parent] != parent)
        {
          GSPrintf(stderr, @"ERROR: Parent links incorrect\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Add child tests passed\n");
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
