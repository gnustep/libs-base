#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import "GNUstepBase/GSConfig.h"

int main()
{
  START_SET("NSXMLNode string values are text")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSString              *tricky = @"A&B <\"x\"> &amp; ]]>";
  NSXMLNode             *attribute;
  NSXMLElement          *element;
  NSXMLDocument         *doc;

  attribute = [NSXMLNode attributeWithName: @"Name" stringValue: tricky];
  PASS_EQUAL([attribute stringValue], tricky,
    "an attribute's string value is kept as it is given");
  PASS_EQUAL([attribute XMLString],
    @"Name=\"A&amp;B &lt;&quot;x&quot;&gt; &amp;amp; ]]&gt;\"",
    "an attribute's string value is escaped in XML");

  element = [NSXMLNode elementWithName: @"E"];
  [element setStringValue: tricky];
  PASS_EQUAL([element stringValue], tricky,
    "an element's string value is kept as it is given");
  PASS_EQUAL([element XMLString],
    @"<E>A&amp;B &lt;\"x\"&gt; &amp;amp; ]]&gt;</E>",
    "an element's string value is escaped in XML");

  [element addAttribute: attribute];
  doc = [[NSXMLDocument alloc] initWithXMLString: [element XMLString]
                                         options: 0
                                           error: NULL];
  PASS_EQUAL([[doc rootElement] stringValue], tricky,
    "an element's string value survives a round trip");
  PASS_EQUAL([[[doc rootElement] attributeForName: @"Name"] stringValue], tricky,
    "an attribute's string value survives a round trip");
  [doc release];

  [element setStringValue: @"&lt;b&gt;" resolvingEntities: YES];
  PASS_EQUAL([element stringValue], @"<b>",
    "resolving entities replaces the references");

  [element setStringValue: @""];
  PASS([element childCount] == 0, "an empty string value leaves no text node");

  [arp release];
#endif
  END_SET("NSXMLNode string values are text")
  return 0;
}
