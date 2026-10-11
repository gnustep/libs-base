#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import "GNUstepBase/GSConfig.h"

static NSXMLElement *
root()
{
  NSXMLElement  *r = [NSXMLNode elementWithName: @"a:root"];

  [r addNamespace: [NSXMLNode namespaceWithName: @"a" stringValue: @"urn:a"]];
  [r addNamespace: [NSXMLNode namespaceWithName: @"b" stringValue: @"urn:b"]];
  return r;
}

int main()
{
  START_SET("NSXMLElement prefixed descendants")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLElement          *r;
  NSXMLElement          *parent;
  NSXMLElement          *child;
  NSXMLDocument         *doc;

  /* A grandchild whose prefix is declared only on the root, built from
   * the bottom up: named before the tree it joins declares its prefix. */
  r = root();
  parent = [NSXMLNode elementWithName: @"a:parent"];
  child = [NSXMLNode elementWithName: @"a:child"];
  [parent addChild: child];
  [r addChild: parent];
  doc = [[NSXMLDocument alloc] initWithRootElement: r];
  PASS_EQUAL([r XMLString],
    @"<a:root xmlns:a=\"urn:a\" xmlns:b=\"urn:b\"><a:parent><a:child></a:child></a:parent></a:root>",
    "a prefixed grandchild uses the root's declaration");
  PASS_EQUAL([child URI], @"urn:a", "the grandchild is in the root's namespace");
  [doc release];

  /* Two attributes with the same prefix on a grandchild. */
  r = root();
  parent = [NSXMLNode elementWithName: @"a:parent"];
  child = [NSXMLNode elementWithName: @"a:child"];
  [child addAttribute: [NSXMLNode attributeWithName: @"b:one" stringValue: @"1"]];
  [child addAttribute: [NSXMLNode attributeWithName: @"b:two" stringValue: @"2"]];
  [parent addChild: child];
  [r addChild: parent];
  doc = [[NSXMLDocument alloc] initWithRootElement: r];
  PASS_EQUAL([r XMLString],
    @"<a:root xmlns:a=\"urn:a\" xmlns:b=\"urn:b\"><a:parent><a:child b:one=\"1\" b:two=\"2\"></a:child></a:parent></a:root>",
    "prefixed attributes of a grandchild use the root's declaration");
  PASS_EQUAL([[child attributeForLocalName: @"two" URI: @"urn:b"] stringValue], @"2",
    "the second attribute is in the root's namespace");

  [doc release];

  [arp release];
#endif
  END_SET("NSXMLElement prefixed descendants")
  return 0;
}
