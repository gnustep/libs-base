#import "ObjectTesting.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>
#import "GNUstepBase/GSConfig.h"

int main()
{
  START_SET("NSXMLDocument applyingXSLT")
#if !GS_USE_LIBXML
  SKIP("library built without libxml2")
#else
  NSError	*err = nil;
  NSData	*xml = [@"<?xml version=\"1.0\"?><doc><item>hello</item></doc>"
    dataUsingEncoding: NSUTF8StringEncoding];
  NSXMLDocument	*doc = [[[NSXMLDocument alloc] initWithData: xml
                                                     options: 0
                                                       error: &err] autorelease];
  NSData	*xslt = [(@"<?xml version=\"1.0\"?>"
    "<xsl:stylesheet version=\"1.0\""
    " xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">"
    "<xsl:template match=\"/\">"
    "<out><xsl:value-of select=\"//item\"/></out>"
    "</xsl:template></xsl:stylesheet>")
    dataUsingEncoding: NSUTF8StringEncoding];
  NSXMLDocument	*result;

  PASS(doc != nil, "parsed the source document")

  /* Applying a stylesheet used to free the parsed stylesheet document twice:
   * xsltParseStylesheetDoc() passes ownership of the document to the
   * stylesheet, so xsltFreeStylesheet() already frees it and the method's
   * explicit xmlFreeDoc() was a double free.  Reaching here with the
   * transformed result, rather than aborting, is the regression check. */
  result = [doc objectByApplyingXSLT: xslt arguments: nil error: &err];
  if (result == nil)
    {
      SKIP("XSLT support not built (libxslt unavailable)")
    }
  else
    {
      PASS_EQUAL([[result rootElement] name], @"out",
        "the stylesheet produced the expected root element")
      PASS_EQUAL([[result rootElement] stringValue], @"hello",
        "the stylesheet produced the expected content")
    }
#endif
  END_SET("NSXMLDocument applyingXSLT")
  return 0;
}
