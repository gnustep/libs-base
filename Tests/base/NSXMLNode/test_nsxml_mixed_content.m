#import <Foundation/Foundation.h>

/* Test mixed content (elements and text nodes)
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      // Test 1: Create element with mixed content
      NSXMLElement *parent = [NSXMLElement elementWithName:@"p"];
      NSXMLNode *text1 = [NSXMLNode textWithStringValue:@"Hello "];
      NSXMLElement *bold = [NSXMLElement elementWithName:@"b"];
      NSXMLNode *boldText = [NSXMLNode textWithStringValue:@"world"];
      NSXMLNode *text2 = [NSXMLNode textWithStringValue:@"!"];
      
      [parent addChild:text1];
      [parent addChild:bold];
      [bold addChild:boldText];
      [parent addChild:text2];
      
      // Test 2: Verify structure
      if ([parent childCount] != 3)
        {
          GSPrintf(stderr, @"ERROR: Expected 3 children in mixed content, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 3: Verify each child
      NSXMLNode *firstChild = [parent childAtIndex:0];
      NSXMLNode *secondChild = [parent childAtIndex:1];
      NSXMLNode *thirdChild = [parent childAtIndex:2];
      
      if ([firstChild kind] != NSXMLTextKind ||
          ![[firstChild stringValue] isEqualToString:@"Hello "])
        {
          GSPrintf(stderr, @"ERROR: First child incorrect\n");
          exitCode = 1;
        }
      
      if ([secondChild kind] != NSXMLElementKind ||
          ![[secondChild name] isEqualToString:@"b"])
        {
          GSPrintf(stderr, @"ERROR: Second child incorrect\n");
          exitCode = 1;
        }
      
      if ([thirdChild kind] != NSXMLTextKind ||
          ![[thirdChild stringValue] isEqualToString:@"!"])
        {
          GSPrintf(stderr, @"ERROR: Third child incorrect\n");
          exitCode = 1;
        }
      
      // Test 4: Insert text between text and element
      NSXMLNode *insertedText = [NSXMLNode textWithStringValue:@"dear "];
      [parent insertChild:insertedText atIndex:1];
      
      if ([parent childCount] != 4)
        {
          GSPrintf(stderr, @"ERROR: Expected 4 children after insert, got %lu\n",
                   (unsigned long)[parent childCount]);
          exitCode = 1;
        }
      
      // Test 5: Verify no unwanted merging occurred
      NSXMLNode *first = [parent childAtIndex:0];
      NSXMLNode *second = [parent childAtIndex:1];
      
      if (![[first stringValue] isEqualToString:@"Hello "] ||
          ![[second stringValue] isEqualToString:@"dear "])
        {
          GSPrintf(stderr, @"ERROR: Text nodes merged when they shouldn't\n");
          GSPrintf(stderr, @"       First: %@, Second: %@\n", 
                   [first stringValue], [second stringValue]);
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Mixed content tests passed\n");
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
