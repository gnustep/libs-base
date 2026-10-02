#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSString.h"
#import "Foundation/NSXMLDocument.h"
#import "Foundation/NSXMLElement.h"
#import "Foundation/NSXMLNode.h"

/* An attribute in a namespace is named with its prefix, as an element is:
 * c:x, whose prefix is c and whose local name is x. */

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSXMLDocument		*doc;
  NSXMLElement		*e;
  NSXMLNode		*prefixed;
  NSXMLNode		*plain;
  NSXMLNode		*made;
  NSXMLElement		*copy;

  doc = [[NSXMLDocument alloc]
    initWithXMLString: @"<r xmlns:c=\"urn:c\"><e c:x=\"1\" y=\"2\"/></r>"
	      options: 0
		error: NULL];
  e = (NSXMLElement *)[[doc rootElement] childAtIndex: 0];
  prefixed = [e attributeForName: @"c:x"];
  plain = [e attributeForName: @"y"];

  PASS_EQUAL([prefixed name], @"c:x",
    "a parsed attribute in a namespace is named with its prefix")
  PASS_EQUAL([prefixed prefix], @"c", "its prefix is the namespace's")
  PASS_EQUAL([prefixed localName], @"x", "its local name has no prefix")
  PASS_EQUAL([prefixed URI], @"urn:c", "and it is in the namespace")
  PASS_EQUAL([plain name], @"y", "an attribute in no namespace has no prefix")
  PASS_EQUAL([plain prefix], @"", "not even an empty one in its name")
  copy = [[e copy] autorelease];
  PASS_EQUAL([[copy attributeForName: @"c:x"] name], @"c:x",
    "a copy's attribute is named as the original's")

  made = [NSXMLNode attributeWithName: @"c:z" URI: @"urn:c" stringValue: @"3"];
  [e addAttribute: made];
  PASS_EQUAL([[e attributeForName: @"c:z"] name], @"c:z",
    "so is one added in the namespace")

  [doc release];
  [arp release];
  return 0;
}
