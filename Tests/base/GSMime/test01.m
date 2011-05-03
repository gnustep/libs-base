#if     defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  GSMimeParser *parser = [GSMimeParser mimeParser];
  NSStringEncoding enc = [GSMimeDocument encodingFromCharset: @"utf-8"];
  NSData *data;
  GSMimeDocument *doc = [[parser mimeDocument] retain];
  GSMimeHeader  *hdr;
  NSString      *val;
  NSString      *raw;
  BOOL		complete;

  data = [@"Content-type: application/xxx\r\n" dataUsingEncoding: enc];
  PASS([parser parse:data] && [parser isInHeaders] && (doc != nil),
       "can parse one header");

  PASS([doc contentType] == nil, "First Header not complete until next starts");

  data = [@"Content-id: <" dataUsingEncoding:enc];
  PASS([parser parse: data] &&
       [parser isInHeaders],
       "Adding partial headers is ok");

  PASS([[doc contentType] isEqual: @"application"] &&
       [[doc contentSubtype] isEqual:@"xxx"],"Parsed first header as expected");

  data = [@"hello>\r\n" dataUsingEncoding: enc];
  PASS([parser parse: data] &&
       [parser isInHeaders],
       "Completing partial header is ok");

  PASS([doc contentID] == nil, "Partial header not complete until next starts");

  data = [@"Folded\r\n : testing\r\n" dataUsingEncoding:enc];
  PASS([parser parse:data] && [parser isInHeaders], "Folded header is ok");
  
  PASS([@"<hello>" isEqual: [doc contentID]],"Parsed partial header as expected %s",[[doc contentID] cString]);
 
  PASS([doc headerNamed: @"Folded"] == nil,"Folded header not complete until next starts");

  data = [@"\r" dataUsingEncoding:enc];
  PASS([parser parse:data] && [parser isInHeaders], "partial end-of-line is ok");

  PASS([[[doc headerNamed:@"Folded"] value] isEqual: @"testing"],"Parsed folded header as expected %s",[[[doc headerNamed:@"Folded"] value] cString]);

  data = [@"\n" dataUsingEncoding:enc];
  PASS([parser parse:data] && ![parser isInHeaders], "completing end-of-line is ok");
  
  doc = [GSMimeDocument documentWithContent:[@"\"\\UFE66???\"" propertyList]
  					type:@"text/plain"
					name:nil];
  [doc rawMimeData];
  PASS([[[doc headerNamed:@"content-type"] parameterForKey:@"charset"] isEqual:@"utf-8"],"charset is inferred");

  
  val = @"by mail.turbocat.net (Postfix, from userid 1002) id 90885422ECBF; Sat, 22 Dec 2007 15:40:10 +0100 (CET)";
  raw = @"Received: by mail.turbocat.net (Postfix, from userid 1002) id 90885422ECBF;\r\n\tSat, 22 Dec 2007 15:40:10 +0100 (CET)\r\n";
  hdr = [[GSMimeHeader alloc] initWithName: @"Received" value: val];
  data = [hdr rawMimeDataPreservingCase: YES];
//NSLog(@"Header: '%*.*s'", [data length], [data length], [data bytes]);
  PASS([data isEqual: [raw dataUsingEncoding: NSASCIIStringEncoding]],
    "raw mime data for long header is OK");
  
  data = [NSData dataWithContentsOfFile: @"HTTP1.dat"];
  parser = [GSMimeParser mimeParser];
  PASS ([parser parse: data] == NO, "can parse HTTP 200 reponse in one go");
  PASS ([parser isComplete], "parse is complete");

  [arp release]; arp = nil;
  return 0;
}
#else
int main(int argc,char **argv)
{
  return 0;
}
#endif
