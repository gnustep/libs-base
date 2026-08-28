/* Detaching a node moves it to a document of its own, and the strings of its
   subtree move with it.  A parser puts short strings in the dictionary of the
   document it builds and allocates the rest, so both kinds have to survive the
   move and the release of the document they were parsed into.
*/
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLNode.h>
#import <GNUstepBase/GNUstep.h>

#import "Testing.h"

int
main(int argc, char **argv)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString      *source =
    @"<document type=\"com.apple.InterfaceBuilder3.Cocoa.XIB\">"
     "<objects id=\"a\" customClass=\"NSObject\">text of the element</objects>"
     "</document>";
  NSData        *data = [source dataUsingEncoding: NSUTF8StringEncoding];
  NSXMLDocument *doc;
  NSXMLElement  *root;
  NSXMLNode     *child;

  doc = [[NSXMLDocument alloc] initWithData: data options: 0 error: NULL];
  PASS(doc != nil, "a document is parsed from data");

  root = [doc rootElement];
  PASS_EQUAL([[root attributeForName: @"type"] stringValue],
    @"com.apple.InterfaceBuilder3.Cocoa.XIB",
    "an attribute value longer than the parser interns is read back");

  child = [root childAtIndex: 0];
  [child retain];
  [child detach];
  DESTROY(doc);

  /* Everything below reads strings that were parsed into the document just
     released. */
  PASS_EQUAL([child name], @"objects",
    "a detached node keeps its name once the document is released");
  PASS_EQUAL([[(NSXMLElement *)child attributeForName: @"id"] stringValue],
    @"a", "a detached node keeps a short attribute value");
  PASS_EQUAL([[(NSXMLElement *)child attributeForName: @"customClass"]
    stringValue], @"NSObject",
    "a detached node keeps an attribute value the parser allocated");
  PASS_EQUAL([child stringValue], @"text of the element",
    "a detached node keeps its text");

  [child release];
  DESTROY(arp);
  return 0;
}
