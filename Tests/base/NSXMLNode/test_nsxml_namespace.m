#import <Foundation/Foundation.h>

/* Test namespace handling on NSXMLElement
 * Returns 0 on success, 1 on failure
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  NS_DURING
    {
      // Test 1: Create element with namespace
      NSXMLElement *elem = [NSXMLElement elementWithName:@"root"];
      NSXMLNode *ns = [NSXMLNode namespaceWithName:@"h" 
                                       stringValue:@"http://www.w3.org/1999/xhtml"];
      
      [elem addNamespace:ns];
      
      NSArray *namespaces = [elem namespaces];
      if ([namespaces count] != 1)
        {
          GSPrintf(stderr, @"ERROR: Expected 1 namespace, got %lu\n",
                   (unsigned long)[namespaces count]);
          exitCode = 1;
        }
      
      // Test 2: Get namespace by prefix
      NSXMLNode *retrieved = [elem namespaceForPrefix:@"h"];
      if (retrieved == nil)
        {
          GSPrintf(stderr, @"ERROR: Couldn't retrieve namespace\n");
          exitCode = 1;
        }
      
      // Test 3: Resolve namespace URI
      NSXMLNode *resolved = [elem resolveNamespaceForName:@"h:body"];
      if (resolved == nil)
        {
          GSPrintf(stderr, @"ERROR: Couldn't resolve namespace\n");
          exitCode = 1;
        }
      
      // Test 4: Add element in namespace
      NSXMLElement *child = [NSXMLElement elementWithName:@"h:body"];
      [elem addChild:child];
      
      if ([elem childCount] != 1)
        {
          GSPrintf(stderr, @"ERROR: Expected 1 child\n");
          exitCode = 1;
        }
      
      // Test 5: Remove namespace
      [elem removeNamespaceForPrefix:@"h"];
      
      if ([[elem namespaces] count] != 0)
        {
          GSPrintf(stderr, @"ERROR: Namespace should be removed\n");
          exitCode = 1;
        }
      
      if (exitCode == 0)
        {
          GSPrintf(stdout, @"PASS: Namespace tests passed\n");
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
