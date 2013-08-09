#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLElement.h>

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSString *docString = @"<root><node><![CDATA[How to read this text ?]]></node></root>";
  NSData *data = [docString dataUsingEncoding: NSUTF8StringEncoding];
  NSError *outError = nil;
  NSXMLDocument *document = [[[NSXMLDocument alloc]
                               initWithData: data
                                    options: (NSXMLNodePreserveCDATA | NSXMLNodePreserveWhitespace)
                                      error: &outError] autorelease];
  NSXMLElement *rootElement = [document rootElement];
  NSXMLNode *childNode = [rootElement childAtIndex: 0];
  NSString *cData = [childNode stringValue];
  PASS_EQUAL(cData, @"How to read this text ?", "CDATA element is correct");

  [arp release];
  arp = nil;

  return 0;
}
