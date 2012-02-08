#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLDTD.h>
#import <Foundation/NSXMLDTDNode.h>

#define NODE_KIND_HAS_CLASS(node, kind, theClass) \
  do \
  { \
    node = [[NSXMLNode alloc] initWithKind: kind]; \
    PASS([node isKindOfClass: [theClass class]], "Initializing with " #kind " produces instances of " #theClass "."); \
    [node release]; \
    node = nil; \
  } while (0)

int main()
{
  START_SET("NSXMLNode -initWithKind: initializer")
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLNode           *node;
  NS_DURING
  {
    NODE_KIND_HAS_CLASS(node, NSXMLDocumentKind, NSXMLDocument);
    NODE_KIND_HAS_CLASS(node, NSXMLElementKind, NSXMLElement);
    NODE_KIND_HAS_CLASS(node, NSXMLDTDKind, NSXMLDTD);
    NODE_KIND_HAS_CLASS(node, NSXMLEntityDeclarationKind, NSXMLDTDNode);
    NODE_KIND_HAS_CLASS(node, NSXMLElementDeclarationKind, NSXMLDTDNode);
    NODE_KIND_HAS_CLASS(node, NSXMLNotationDeclarationKind, NSXMLDTDNode);
    node = [[NSXMLNode alloc] initWithKind: NSXMLAttributeDeclarationKind];
    PASS (NO == [node isKindOfClass: [NSXMLDTDNode class]], "Does not instantiate NSXMLAttributeDeclarations through -initWithKind:");
    [node release];
  }
  NS_HANDLER
  {
    PASS(YES == NO, "NSXMLNode kinds working");
  }
  NS_ENDHANDLER
  [arp release];
  arp = nil;
  END_SET("NSXMLNode -initWithKind: initializer")
  return 0;
}
