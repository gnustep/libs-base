#if     defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

@interface GSMimeHeader (Testing)
+ (NSUInteger) appendString: (NSString*)str
                         to: (NSMutableData*)m
                         at: (NSUInteger)offset
                       fold: (NSUInteger)fold
                         ok: (BOOL*)ok;
@end

static GSMimeDocument *
parse(GSMimeParser **parserPointer, NSData *data)
{
  GSMimeParser	*parser;
  unsigned	length = [data length];
  unsigned	index;

  if (0 == parserPointer)
    {
      parser = [[GSMimeParser new] autorelease];
    }
  else
    {
      if (nil == *parserPointer)
	{
	  *parserPointer = [[GSMimeParser new] autorelease];
	}
      parser = *parserPointer;
    }

  for (index = 0; index < length-1; index++)
    {
      NSAutoreleasePool	*arp = [NSAutoreleasePool new];
      NSData		*d;

      d = [data subdataWithRange: NSMakeRange(index, 1)];
      if ([parser parse: d] == NO)
	{
	  return [parser mimeDocument];
	}
      [arp release];
    }
  data = [data subdataWithRange: NSMakeRange(index, 1)];
  if ([parser parse: data] == YES && NO == [parser isComplete])
    {
      [parser parse: nil];
    }
  return [parser mimeDocument];
}

static GSMimeDocument *
exact(GSMimeParser **parserPointer, NSData *data)
{
  GSMimeParser	*parser = nil;
  GSMimeDocument *doc;

  if (0 == parserPointer)
    {
      parserPointer = &parser;
    }
  doc = parse(parserPointer, data);  
  if (nil != [parser excess])
    {
      NSLog(@"Excess data in parser after parse completed");
      doc = nil;
    }
  return doc;
}

int main()
{
  ENTER_POOL
  NSData *cr;
  NSData *data;
  NSData *orig;
  NSString *obj0;
  NSString *obj1;
  NSString *str;
  GSMimeParser *parser;
  GSMimeDocument *doc;
  GSMimeDocument *idoc;
  GSMimeHeader *hdr;
  BOOL  oldStyleFolding;

  oldStyleFolding = [[NSUserDefaults standardUserDefaults]
    boolForKey: @"GSMimeOldStyleFolding"];

  cr = [NSData dataWithBytes: "\r" length: 1];

  hdr = [GSMimeHeader headerWithName: @"Subject"
    value: @"Someone is testing the length of the field so it doesn't create issues with email sending <emailtesting@emailtest-dragontest2.brainstorm.co.uk>" parameters: nil];
  data = [hdr rawMimeData];
  PASS_EQUAL([data description], @"<5375626a 6563743a 20536f6d 656f6e65 20697320 74657374 696e6720 74686520 6c656e67 7468206f 66207468 65206669 656c6420 736f2069 7420646f 65736e27 74206372 65617465 0d0a2069 73737565 73207769 74682065 6d61696c 2073656e 64696e67 0d0a203c 656d6169 6c746573 74696e67 40656d61 696c7465 73742d64 7261676f 6e746573 74322e62 7261696e 73746f72 6d2e636f 2e756b3e 0d0a>",
    "encode long header ok")

  data = [NSData dataWithBytes: "DQ==" length: 4];
  PASS_EQUAL([GSMimeDocument decodeBase64: data], cr,
    "decodeBase64 works for padded data");

  data = [NSData dataWithBytes: "DQ" length: 2];
  PASS_EQUAL([GSMimeDocument decodeBase64: data], cr,
    "decodeBase64 works for unpadded data");

  data = [NSData dataWithContentsOfFile: @"mime1.dat"];
  idoc = exact(0, data);
  PASS_EQUAL([[[idoc content] objectAtIndex:0] content], @"a",
       "can parse one char base64 mime1.dat incrementally");
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL([[[doc content] objectAtIndex:0] content], @"a",
       "can parse one char base64 mime1.dat in one go");
  PASS_EQUAL(idoc, doc, "mime1.dat documents are the same");

  parser = [GSMimeParser new];
  data = [[data mutableCopy] autorelease];
  [(NSMutableData*)data appendBytes: "\r\n\r\n" length: 4];
  [parser parse: data];
  doc = [parser mimeDocument];

  PASS([[parser excess] length] == 5 || [[parser excess] length] == 6,
  "Can detect excess data in multipart");
  [parser release];
  
  data = [NSData dataWithContentsOfFile: @"mime2.dat"];
  idoc = exact(0, data);
  PASS_EQUAL([idoc content], @"aa",
    "can parse two char base64 mime2.dat incrementally");
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL([doc content], @"aa",
    "can parse two char base64 mime2.dat in one go");
  PASS_EQUAL(idoc, doc, "mime2.dat documents are the same");
 
  data = [NSData dataWithContentsOfFile: @"mime3.dat"];
  idoc = exact(0, data);
  PASS(([[idoc content] isEqual: @"aaa"]),
    "can parse three char base64 mime3.dat incrementally");
  doc = [GSMimeParser documentFromData: data];
  PASS(([[doc content] isEqual: @"aaa"]),
    "can parse three char base64 mime3.dat in one go");
  PASS([idoc isEqual: doc], "mime3.dat documents are the same");
   
  data = [NSData dataWithContentsOfFile: @"mime4.dat"];
  idoc = exact(0, data);

  obj0 = [[[idoc content] objectAtIndex:0] content];
  obj1 = [[[idoc content] objectAtIndex:1] content];

  PASS(([obj0 isEqual: @"hello\n"] && [obj1 isEqual: @"there\n"])
    || ([obj0 isEqual: @"hello\r\n"] && [obj1 isEqual: @"there\r\n"]),
   "can parse multi-part text mime4.dat incrementally");

  PASS(([[[[idoc content] objectAtIndex:0] contentFile] isEqual: @"a.a"]),
   "can extract content file name from mime4.dat (incrementally parsed)");
  PASS(([[[[idoc content] objectAtIndex:0] contentType] isEqual: @"text"]),
   "can extract content type from mime4.dat (incrementally parsed)");
  PASS(([[[[idoc content] objectAtIndex:0] contentSubtype] isEqual: @"plain"]),
   "can extract content sub type from mime4.dat (incrementally parsed)");
    
  doc = [GSMimeParser documentFromData: data];
  
  obj0 = [[[doc content] objectAtIndex:0] content];
  obj1 = [[[doc content] objectAtIndex:1] content];

  PASS(([obj0 isEqual: @"hello\n"] && [obj1 isEqual: @"there\n"])
    || ([obj0 isEqual: @"hello\r\n"] && [obj1 isEqual: @"there\r\n"]),
    "can parse multi-part text mime4.dat in one go");

  PASS(([[[[doc content] objectAtIndex:0] contentFile] isEqual: @"a.a"]),
   "can extract content file name from mime4.dat (parsed in one go)");
  PASS(([[[[doc content] objectAtIndex:0] contentType] isEqual: @"text"]),
   "can extract content type from mime4.dat (parsed in one go)");
  PASS(([[[[doc content] objectAtIndex:0] contentSubtype] isEqual: @"plain"]),
   "can extract content sub type from mime4.dat (parsed in one go)");
  PASS([idoc isEqual: doc], "mime4.dat documents are the same");
    
  data = [NSData dataWithContentsOfFile: @"mime5.dat"];
  idoc = exact(0, data);
  PASS(([[idoc contentSubtype] isEqual: @"xml"]),
   "can parse http document mime5.dat incrementally"); 
  doc = [GSMimeParser documentFromData: data];
  PASS(([[doc contentSubtype] isEqual: @"xml"]),
   "can parse http document mime5.dat in one go"); 
  PASS([idoc isEqual: doc], "mime5.dat documents are the same");
  
  data = [NSData dataWithContentsOfFile: @"mime6.dat"];
  idoc = exact(0, data);
  PASS(([[idoc content] count] == 3),
    "can parse multipart mixed mime6.dat incrementally"); 
  doc = [GSMimeParser documentFromData: data];
  PASS(([[doc content] count] == 3),
    "can parse multipart mixed mime6.dat in one go"); 
  PASS([idoc isEqual: doc], "mime6.dat documents are the same");
 
  data = [NSData dataWithContentsOfFile: @"mime7.dat"];
  PASS(([[[[doc content] objectAtIndex:1] content] isEqual: data]),
   "mime6.dat binary data part matches mime7.dat");

  data = [NSData dataWithContentsOfFile: @"mime9.dat"];
  idoc = exact(0, data);

  if (YES == oldStyleFolding)
    {
      str = @"first second third";
    }
  else
    {
      str = @"first\tsecond\tthird";
    }
  PASS(([[[idoc headerNamed: @"Long"] value] isEqual: str]),
   "mime9.dat folded header unfolds correctly incrementally");
  doc = [GSMimeParser documentFromData: data];
//NSLog(@"'%@'", [[doc headerNamed: @"Long"] value]);
  PASS(([[[doc headerNamed: @"Long"] value] isEqual: str]),
   "mime9.dat folded header unfolds correctly in one go");
  PASS([idoc isEqual: doc], "mime9.dat documents are the same");

  /* Test a document containing nested multipart documents
   */
  data = [NSData dataWithContentsOfFile: @"mime10.dat"];
  idoc = exact(0, data);
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "mime10.dat documents are the same");
  data = [idoc rawMimeData];
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "rawMimeData reproduces document");

  /* Test parse of a document containing encoded words in header.
   * Use JavaMail encoded words (different format from those GSMime
   * produces).
   */
  data = [NSData dataWithContentsOfFile: @"mime11.dat"];
  idoc = exact(0, data);
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "mime11.dat documents are the same");

  NSData *oData = [doc rawMimeData: YES foldedAt: 78];
  GSMimeDocument *oDoc = [GSMimeParser documentFromData: oData];
  PASS_EQUAL(doc, oDoc, "mime11.dat (folded and quoted boundary header) equal after writing and re-parsing");

  /* Test a document with adjacent encoded words in headers, as
   * produced by GSMime
   */
  orig = [NSData dataWithContentsOfFile: @"mime12.dat"];
  idoc = exact(0, orig);
  if (YES == oldStyleFolding)
    {
      str = @"Avant de partir, n'oubliez pas de préparer votre séjour à Paris";
    }
  else
    {
      str = @"Avant de partir, n'oubliez pas de préparer votre\tséjour à Paris";
    }
  doc = [GSMimeDocument documentWithContent: @"hello"
                                       type: @"text/plain"
                                       name: nil];
  [doc setHeader: @"MIME-Version" value: @"1.0" parameters: nil];
  [doc setHeader: @"Subject" value: str parameters: nil];
  PASS_EQUAL(idoc, doc, "mime12.dat same as internally generated content");
  doc = [GSMimeParser documentFromData: orig];
  PASS_EQUAL(idoc, doc, "mime12.dat documents are the same");
  data = [idoc rawMimeData];
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "rawMimeData reproduces document with 'Q' header");
//  NSLog(@"Made\n%@\nOrig\n%@", data, orig);

  /* Check embedded newline in subject
   */
  str = @"Embedded\r\nNewline";
  idoc = [GSMimeDocument documentWithContent: @"hello"
                                        type: @"text/plain"
                                        name: nil];
  [idoc setHeader: @"MIME-Version" value: @"1.0" parameters: nil];
  [idoc setHeader: @"Subject" value: str parameters: nil];
  data = [idoc rawMimeData];
  doc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "can encode and parse a header with embedded CRLF")

  if (NO == oldStyleFolding)
    {
      [idoc setHeader: @"Subject" value: @"==répà==" parameters: nil];
      data = [idoc rawMimeData];
//      NSLog(@"Made\n%@", data);
      doc = [GSMimeParser documentFromData: data];
      PASS_EQUAL(doc, idoc, "rawMimeData reproduces document with 'B' header");

      /* Header where Euro character would cross folding boundary */
      [idoc setHeader: @"Subject" value:
        @"Benefit from 6.1% APR rate 111111on los over €20,000"
        parameters: nil];
      data = [idoc rawMimeData];
//      NSLog(@"Made\n%@", data);
      doc = [GSMimeParser documentFromData: data];
      PASS_EQUAL(doc, idoc, "rawMimeData reproduces document with long header");
    }

  orig = [NSData dataWithContentsOfFile: @"mime13.dat"];
  doc = [GSMimeParser documentFromData: orig];
  PASS([[doc content] count] == 3, "parsed document with empty part")
  doc = [[doc content] lastObject];
  PASS([[doc allHeaders] count] == 0, "empty document part has no headers")
  PASS_EQUAL([doc content], nil, "empty document part has no content")

  orig = [NSData dataWithContentsOfFile: @"mime14.dat"];
  doc = [GSMimeParser documentFromData: orig];
  PASS([[doc allHeaders] count] == 6, "special character doc has 6 headers")
  PASS_EQUAL([[doc headerNamed: @"from"] value],
    @"José\r\nAdmin <jose@example.com>", 
    "special character doc decodes from header correctly")
  PASS_EQUAL([[doc headerNamed: @"subject"] value],
    @"Hello\r\nWorld — Café",
    "special character doc decodes subject header correctly")
  data = [doc rawMimeData];
  idoc = [GSMimeParser documentFromData: data];
  PASS_EQUAL(idoc, doc, "encode/parse cycle OK for special character doc")
  [data writeToFile: @"xxx" atomically: NO];

  LEAVE_POOL
  return 0;
}
#else
int main(int argc,char **argv)
{
  return 0;
}
#endif
