#import <Foundation/Foundation.h>

/* Test attribute handling on NSXMLElement
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      NSXMLElement *elem = [NSXMLElement elementWithName:@"element"];
      
      // Test 1: Add attribute
      NSXMLNode *attr1 = [NSXMLNode attributeWithName:@"id" stringValue:@"test"];
      [elem addAttribute:attr1];
      
      NSArray *attributes = [elem attributes];
      if ([attributes count] != 1)
        {
          GSPrintf(stderr, @"ERROR: Expected 1 attribute, got %lu\n",
                   (unsigned long)[attributes count]);
          exitCode = 1;
        }
      
      // Test 2: Get attribute by name
      NSXMLNode *retrieved = [elem attributeForName:@"id"];
      if (retrieved == nil || ![[retrieved stringValue] isEqualToString:@"test"])
        {
          GSPrintf(stderr, @"ERROR: Couldn't retrieve attribute\n");
          exitCode = 1;
        }
      
      // Test 3: Add another attribute
      NSXMLNode *attr2 = [NSXMLNode attributeWithName:@"class" stringValue:@"main"];
      [elem addAttribute:attr2];
      
      if ([[elem attributes] count] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 attributes\n");
          exitCode = 1;
        }
      
      // Test 4: Remove attribute
      [elem removeAttributeForName:@"id"];
      
      if ([[elem attributes] count] != 1)
        {
          GSPrintf(stderr, @"ERROR: Expected 1 attribute after remove\n");
          exitCode = 1;
        }
      
      if ([elem attributeForName:@"id"] != nil)
        {
          GSPrintf(stderr, @"ERROR: Attribute should be removed\n");
          exitCode = 1;
        }
      
      // Test 5: Set attributes array
      NSXMLNode *newAttr1 = [NSXMLNode attributeWithName:@"name" stringValue:@"value1"];
      NSXMLNode *newAttr2 = [NSXMLNode attributeWithName:@"type" stringValue:@"value2"];
      [elem setAttributes:[NSArray arrayWithObjects:newAttr1, newAttr2, nil]];
      
      if ([[elem attributes] count] != 2)
        {
          GSPrintf(stderr, @"ERROR: Expected 2 attributes after setAttributes\n");
          exitCode = 1;
        }
      
      if ([elem attributeForName:@"class"] != nil)
        {
          GSPrintf(stderr, @"ERROR: Old attribute should be gone\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Attribute tests passed\n");
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
