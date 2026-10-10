#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import "GNUstepBase/GSConfig.h"

static NSXMLElement *
element(NSString *name)
{
  return [[[NSXMLElement alloc] initWithName: name URI: @"urn:u"] autorelease];
}

static NSXMLDocument *
document()
{
  return [[[NSXMLDocument alloc]
    initWithXMLString: @"<d xmlns=\"urn:u\"><rule/></d>"
              options: 0
                error: NULL] autorelease];
}

int main()
{
  START_SET("NSXMLElement default namespace descendants")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSXMLDocument         *doc;
  NSXMLDocument         *parsed;
  NSXMLElement          *rule;
  NSXMLElement          *c;
  NSXMLElement          *g;
  NSXMLElement          *h;
  NSXMLNode             *t;

  /* Built while detached, then added under the declaration. */
  doc = document();
  rule = [[[doc rootElement] elementsForName: @"rule"] objectAtIndex: 0];
  c = element(@"c");
  g = element(@"g");
  h = element(@"h");
  [g addChild: h];
  [c addChild: g];
  [rule addChild: c];
  PASS_EQUAL([[doc rootElement] XMLString],
    @"<d xmlns=\"urn:u\"><rule><c><g><h></h></g></c></rule></d>",
    "descendants of an element added under a default namespace declare nothing");
  PASS_EQUAL([h URI], @"urn:u", "a descendant stays in its namespace");

  /* Added under the declaration first, given children afterwards. */
  c = element(@"c");
  [rule addChild: c];
  [c addChild: element(@"g")];
  PASS_EQUAL([c XMLString], @"<c><g></g></c>",
    "a child added to an element already under the declaration declares nothing");

  /* Never under a declaration. */
  c = [[[NSXMLElement alloc] initWithName: @"r"] autorelease];
  g = element(@"g");
  [g addChild: element(@"h")];
  [c addChild: g];
  PASS_EQUAL([c XMLString], @"<r><g><h></h></g></r>",
    "a detached tree declares no namespace it was not given");
  PASS_EQUAL([[[g children] objectAtIndex: 0] URI], @"urn:u",
    "a detached descendant stays in its namespace");

  /* A declaration that was parsed stays. */
  parsed = [[NSXMLDocument alloc]
    initWithXMLString: @"<x><t xmlns=\"urn:u\"/></x>"
              options: 0
                error: NULL];
  t = [[[parsed rootElement] children] objectAtIndex: 0];
  [t detach];
  c = element(@"c");
  [c addChild: t];
  [rule addChild: c];
  PASS_EQUAL([c XMLString], @"<c><t xmlns=\"urn:u\"></t></c>",
    "a parsed declaration is kept");
  [parsed release];

  [arp release];
#endif
  END_SET("NSXMLElement default namespace descendants")
  return 0;
}
