#import <Foundation/Foundation.h>

/* Test inserting children at specific positions
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
      
      // Test 1: Insert at index 0 (empty parent)
      NSXMLElement *child1 = [NSXMLElement elementWithName:@"child1"];
      [parent insertChild:child1 atIndex:0];
      
      if ([parent childCount] != 1 || ![[parent childAtIndex:0] isEqual:child1])
        {
          GSPrintf(stderr, @"ERROR: Insert at index 0 failed\n");
          exitCode = 1;
        }
      
      // Test 2: Insert at index 0 (prepend)
      NSXMLElement *child0 = [NSXMLElement elementWithName:@"child0"];
      [parent insertChild:child0 atIndex:0];
      
      if ([parent childCount] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 children after prepend\n");
          exitCode = 1;
        }
      
      if (![[parent childAtIndex:0] isEqual:child0] || 
          ![[parent childAtIndex:1] isEqual:child1])
        {
          GSPrintf(stderr, @"ERROR: Wrong order after prepend\n");
          exitCode = 1;
        }
      
      // Test 3: Insert in middle
      NSXMLElement *child05 = [NSXMLElement elementWithName:@"child05"];
      [parent insertChild:child05 atIndex:1];
      
      if ([parent childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Expected 3 children after middle insert\n");
          exitCode = 1;
        }
      
      if (![[parent childAtIndex:0] isEqual:child0] || 
          ![[parent childAtIndex:1] isEqual:child05] ||
          ![[parent childAtIndex:2] isEqual:child1])
        {
          GSPrintf(stderr, @"ERROR: Wrong order after middle insert\n");
          exitCode = 1;
        }
      
      // Test 4: Insert at end (append)
      NSXMLElement *child2 = [NSXMLElement elementWithName:@"child2"];
      [parent insertChild:child2 atIndex:3];
      
      if ([parent childCount] != 4 || ![[parent childAtIndex:3] isEqual:child2])
        {
          GSPrintf(stderr, @"ERROR: Insert at end failed\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Insert child tests passed\n");
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
