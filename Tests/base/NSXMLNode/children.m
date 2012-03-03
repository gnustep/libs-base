#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>


int main()
{
  START_SET("NSXMLNode - handling children")
  NS_DURING
  {
    NSXMLElement *node = [[NSXMLElement alloc] initWithKind: NSXMLElementKind];
    NSXMLDocument *docA = [[NSXMLDocument alloc] initWithRootElement: node];
    NSXMLDocument *docB = nil;
    NSXMLNode *attr;
    
    // NSLog(@"Here...");
    [node detach];
    PASS(docB = [[NSXMLDocument alloc] initWithRootElement: node], "Detached children can be reattached.");
    [docA release];

    // NSLog(@"Here... again");
    PASS(docB == [node parent], "Parent is set to docB");
 
    [node setName: @"name"];
    attr = [NSXMLNode attributeWithName: @"key" stringValue: @"value"];
    [node addAttribute: attr];

    PASS(node == [attr parent], "Attr parent is set to node");
    [docB release];
    PASS(nil == [node parent], "Parent is set to nil");
    docA = [[NSXMLDocument alloc] initWithRootElement: node];
    // NSLog(@"Yet again");
    PASS_EXCEPTION(docB = [[NSXMLDocument alloc] initWithRootElement: node], NSInternalInconsistencyException, "Reusing a child throws an exception");
    // NSLog(@"Last time");
    
    //[node release];
    //[docA release];
   }
  NS_HANDLER
  {
    PASS (NO, "NSXML child handling working."); // I don't think this is valid... commenting out for now.
  }
  NS_ENDHANDLER
  END_SET("NSXMLNode - handling children")
  return 0;
}
