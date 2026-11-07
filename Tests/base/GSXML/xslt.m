#import <Foundation/Foundation.h>
#import "Testing.h"
#if     defined(GNUSTEP_BASE_LIBRARY) && (GS_USE_LIBXML == 1)
#import <GNUstepBase/GSXML.h>

static GSXMLDocument *
parse(NSString *xml)
{
  GSXMLParser	*parser;

  parser = [GSXMLParser parserWithData:
    [xml dataUsingEncoding: NSUTF8StringEncoding]];
  return [parser parse] ? [parser document] : nil;
}

int main()
{
  ENTER_POOL
  GSXMLDocument		*xslt;
  GSXMLDocument		*doc;
  GSXMLDocument		*res;
  NSString		*before;
  int			i;

  /* Whitespace and comments are stripped by libxslt when it compiles
   * a stylesheet document: they show whether the document was modified.
   */
  xslt = parse(@"<?xml version=\"1.0\"?>\n"
    @"<xsl:stylesheet version=\"1.0\""
    @" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">\n"
    @"  <!-- copy the root element under another name -->\n"
    @"  <xsl:template match=\"/a\">\n"
    @"    <b><xsl:value-of select=\".\"/></b>\n"
    @"  </xsl:template>\n"
    @"</xsl:stylesheet>\n");
  doc = parse(@"<a>text</a>");
  before = [xslt description];

  START_SET("GSXMLDocument XSLT")
    res = [doc xsltTransform: xslt];
    if (res == nil)
      SKIP("XSLT support unavailable");

    PASS_EQUAL([[res root] name], @"b",
      "-xsltTransform: applies the stylesheet");
    PASS_EQUAL([[res root] content], @"text",
      "-xsltTransform: result has the expected content");
    PASS_EQUAL([xslt description], before,
      "-xsltTransform: does not modify the stylesheet document");

    for (i = 0; i < 100; i++)
      {
	NSAutoreleasePool	*pool = [NSAutoreleasePool new];

	res = [parse(@"<a>again</a>") xsltTransform: xslt];
	if (NO == [[[res root] content] isEqual: @"again"])
	  {
	    [pool release];
	    break;
	  }
	[pool release];
      }
    PASS(i == 100, "-xsltTransform: stylesheet can be applied repeatedly");
    PASS_EQUAL([xslt description], before,
      "repeated -xsltTransform: leaves the stylesheet document intact");

    PASS([doc xsltTransform: parse(@"<notxslt/>")] == nil,
      "-xsltTransform: returns nil for a document which is not a stylesheet");
    PASS([doc xsltTransform: nil] == nil,
      "-xsltTransform: returns nil for a nil stylesheet");
  END_SET("GSXMLDocument XSLT")

  LEAVE_POOL
  return 0;
}
#else
int main(int argc,char **argv)
{
  START_SET("GSXMLDocument XSLT")
    SKIP("GSXML support unavailable");
  END_SET("GSXMLDocument XSLT")
  return 0;
}
#endif

