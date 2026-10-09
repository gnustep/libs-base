#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import "GNUstepBase/GSConfig.h"

int main()
{
  START_SET("NSXMLNode default namespaces")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLElement          *schema;
  NSXMLNode             *ns;
  NSXMLDocument         *doc;

  schema = [NSXMLNode elementWithName: @"Schema"];
  ns = [NSXMLNode namespaceWithName: @"" stringValue: @"urn:x"];
  PASS_EQUAL([ns name], @"", "a default namespace has an empty name");
  [schema addNamespace: ns];
  [schema addChild: [NSXMLNode elementWithName: @"Type"]];
  PASS_EQUAL([schema XMLString],
    @"<Schema xmlns=\"urn:x\"><Type></Type></Schema>",
    "a default namespace is declared as xmlns");
  PASS_EQUAL([schema URI], @"urn:x", "the element is in its default namespace");
  PASS([[schema elementsForLocalName: @"Type" URI: @"urn:x"] count] == 1,
    "a child is found in the default namespace");

  [schema addNamespace: [NSXMLNode namespaceWithName: @"" stringValue: @"urn:y"]];
  PASS([[schema namespaces] count] == 1, "a second default namespace replaces the first");

  doc = [[NSXMLDocument alloc] initWithXMLString: @"<Schema xmlns=\"urn:x\"><Type/></Schema>"
                                         options: 0
                                           error: NULL];
  PASS_EQUAL([[doc rootElement] name], @"Schema",
    "a parsed element in a default namespace keeps its name");
  PASS_EQUAL([[doc rootElement] URI], @"urn:x",
    "a parsed element in a default namespace is in it");
  [doc release];

  [arp release];
#endif
  END_SET("NSXMLNode default namespaces")
  return 0;
}
