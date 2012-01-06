#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLElement          *root;
  NSXMLElement          *child1;
  NSXMLElement          *child2;

  root = [[NSXMLElement alloc] initWithName: @"root"];

  child1 = [[NSXMLElement alloc] initWithName: @"child1"];
  child2 = [[NSXMLElement alloc] initWithName: @"child2"];

/* In OSX (snow leopard) an attempt to add a child beyond the legal range
 * actally causes the data structures to be corrupted so that subsequent
 * operations go horribly wrong ... so we can['t run these tests.
 *
  PASS_EXCEPTION([root insertChild: child1 atIndex: 1],
    NSRangeException, "may not add a child at a bad index");
  PASS(0 == [[root children] count], "parent has no child after failed insert");
  PASS(nil == [child1 parent], "child has no parent after failed insert");
  PASS_RUNS([child1 detach], "May detach");
*/

  PASS_RUNS([root insertChild: child2 atIndex: 0],
    "may add a child at index 0");
  PASS(1 == [[root children] count], "parent has a child after insertion");
  PASS_EQUAL([child2 parent], root, "child has correct parent");
  PASS_RUNS([root removeChildAtIndex: 0],
   "removing child works");
  PASS_EQUAL([root children], nil, "children is nil after removal");
  PASS_EQUAL([child2 parent], nil, "child has no parent");
  PASS_RUNS([root insertChild: child2 atIndex: 0],
    "may reinsert a child at index 0");

  PASS_RUNS([root insertChild: child1 atIndex: 0],
    "may add a child at index 0");
  PASS(2 == [[root children] count], "parent has a child after insertion");

  {
    NSXMLNode   *c;

    c = [[[NSXMLNode alloc] initWithKind: NSXMLElementKind] autorelease];
    PASS_RUNS([root insertChild: c atIndex: 0],
      "may add NSXMLElementKind child");

    c = [[[NSXMLNode alloc] initWithKind:
      NSXMLProcessingInstructionKind] autorelease];
    PASS_RUNS([root insertChild: c atIndex: 0],
      "may add NSXMLProcessingInstructionKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLTextKind] autorelease];
    PASS_RUNS([root insertChild: c atIndex: 0],
      "may add NSXMLTextKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLCommentKind] autorelease];
    PASS_RUNS([root insertChild: c atIndex: 0],
      "may add NSXMLCommentKind child");

    c = [[[NSXMLNode alloc] initWithKind:
      NSXMLAttributeDeclarationKind] autorelease];
    PASS_RUNS([root insertChild: c atIndex: 0],
      "may add NSXMLAttributeDeclarationKind child");

    c = [[[NSXMLNode alloc] initWithKind:
      NSXMLEntityDeclarationKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0], nil,
      "may not add NSXMLEntityDeclarationKind child");

    c = [[[NSXMLNode alloc] initWithKind:
      NSXMLElementDeclarationKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0], nil,
      "may not add NSXMLElementDeclarationKind child");

    c = [[[NSXMLNode alloc] initWithKind:
      NSXMLNotationDeclarationKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0], nil,
      "may not add NSXMLNotationDeclarationKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLInvalidKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0],
      nil, "may not add NSXMLInvalidKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLDocumentKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0],
      nil, "may not add NSXMLDocumentKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLDTDKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0],
      nil, "may not add NSXMLDTDKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLNamespaceKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0],
      nil, "may not add NSXMLNamespaceKind child");

    c = [[[NSXMLNode alloc] initWithKind: NSXMLAttributeKind] autorelease];
    PASS_EXCEPTION([root insertChild: c atIndex: 0],
      nil, "may not add NSXMLAttributeKind child");
  }

  PASS(1 == [child1 level], "child element node level is one");

  PASS_EXCEPTION([root removeChildAtIndex: 100], NSRangeException,
   "removing child from invalid index raises");


  [root release];
  [child1 release];
  [child2 release];

  [arp release];
  arp = nil;

  return 0;
}
