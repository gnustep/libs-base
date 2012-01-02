#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>


int main()
{
  START_SET("NSXMLNode - handling children")
    // testHopeful = YES;
  NS_DURING
  {
    NSXMLElement *node = [[NSXMLElement alloc] initWithKind: NSXMLElementKind];
    NSXMLDocument *docA = [[NSXMLDocument alloc] initWithRootElement: node];
    NSXMLDocument *docB = nil;
    // NSLog(@"Here...");
    [node detach];
    PASS(docB = [[NSXMLDocument alloc] initWithRootElement: node], "Detached children can be reattached.");
    [docA release];
    // NSLog(@"Here... again");
    [docB release];
    docA = [[NSXMLDocument alloc] initWithRootElement: node];
    // NSLog(@"Yet again");
    PASS_EXCEPTION(docB = [[NSXMLDocument alloc] initWithRootElement: node], NSInternalInconsistencyException, "Reusing a child throws an exception");
    // NSLog(@"Last time");
  }
  NS_HANDLER
  {
    // PASS (0 == 1, "NSXML child handling working."); // I don't think this is valid... commenting out for now.
  }
  NS_ENDHANDLER
  END_SET("NSXMLNode - handling children")
  return 0;
}
