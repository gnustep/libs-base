#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSXMLParser.h>
#include <string.h>

@interface      Handler : NSObject
{
  NSMutableString       *s;
}

- (void)parserDidStartDocument: (NSXMLParser *)parser;
- (void)parserDidEndDocument: (NSXMLParser *)parser;
- (void)parser: (NSXMLParser *)parser foundNotationDeclarationWithName: (NSString *)name publicID: (NSString *)publicID systemID: (NSString *)systemID;
- (void)parser: (NSXMLParser *)parser foundUnparsedEntityDeclarationWithName: (NSString *)name publicID: (NSString *)publicID systemID: (NSString *)systemID notationName: (NSString *)notationName;
- (void)parser: (NSXMLParser *)parser foundAttributeDeclarationWithName: (NSString *)attributeName forElement: (NSString *)elementName type: (NSString *)type defaultValue: (NSString *)defaultValue;
- (void)parser: (NSXMLParser *)parser foundElementDeclarationWithName: (NSString *)elementName model: (NSString *)model;

- (void)parser: (NSXMLParser *)parser foundInternalEntityDeclarationWithName: (NSString *)name value: (NSString *)value;

- (void)parser: (NSXMLParser *)parser foundExternalEntityDeclarationWithName: (NSString *)name publicID: (NSString *)publicID systemID: (NSString *)systemID;

- (void)parser: (NSXMLParser *)parser didStartElement: (NSString *)elementName namespaceURI: (NSString *)namespaceURI qualifiedName: (NSString *)qName attributes: (NSDictionary *)attributeDict;
- (void)parser: (NSXMLParser *)parser didEndElement: (NSString *)elementName namespaceURI: (NSString *)namespaceURI qualifiedName: (NSString *)qName;
- (void)parser: (NSXMLParser *)parser didStartMappingPrefix: (NSString *)prefix toURI: (NSString *)namespaceURI;
- (void)parser: (NSXMLParser *)parser didEndMappingPrefix: (NSString *)prefix;
- (void)parser: (NSXMLParser *)parser foundCharacters: (NSString *)string;
- (void)parser: (NSXMLParser *)parser foundIgnorableWhitespace: (NSString *)whitespaceString;
- (void)parser: (NSXMLParser *)parser foundProcessingInstructionWithTarget: (NSString *)target data: (NSString *)data;
- (void)parser: (NSXMLParser *)parser foundComment: (NSString *)comment;
- (void)parser: (NSXMLParser *)parser foundCDATA: (NSData *)CDATABlock;
- (NSData *)parser: (NSXMLParser *)parser resolveExternalEntityName: (NSString *)name systemID: (NSString *)systemID;
- (void)parser: (NSXMLParser *)parser parseErrorOccurred: (NSError *)parseError;
- (void)parser: (NSXMLParser *)parser validationErrorOccurred: (NSError *)validationError;
@end

@implementation Handler

- (void) dealloc
{
  [s release];
  [super dealloc];
}

- (NSString*) description
{
  return s;
}

- (id) init
{
  s = [NSMutableString new];
  return self;
}

- (void) parserDidStartDocument: (NSXMLParser *)parser
{
  [s appendFormat: @"%@\n", NSStringFromSelector(_cmd)];
}

- (void) parserDidEndDocument: (NSXMLParser *)parser
{
  [s appendFormat: @"%@\n", NSStringFromSelector(_cmd)];
}

- (void) parser: (NSXMLParser *)parser
  foundNotationDeclarationWithName: (NSString *)name
  publicID: (NSString *)publicID
  systemID: (NSString *)systemID
{
  [s appendFormat: @"%@ %@ %@ %@\n", NSStringFromSelector(_cmd), name,
    publicID, systemID];
}

- (void) parser: (NSXMLParser *)parser
  foundUnparsedEntityDeclarationWithName: (NSString *)name
  publicID: (NSString *)publicID
  systemID: (NSString *)systemID
  notationName: (NSString *)notationName
{
  [s appendFormat: @"%@ %@ %@ %@ %@\n", NSStringFromSelector(_cmd), name,
    publicID, systemID, notationName];
}

- (void) parser: (NSXMLParser *)parser
  foundAttributeDeclarationWithName: (NSString *)attributeName
  forElement: (NSString *)elementName
  type: (NSString *)type
  defaultValue: (NSString *)defaultValue
{
  [s appendFormat: @"%@ %@ %@ %@ %@\n", NSStringFromSelector(_cmd),
    attributeName, elementName, type, defaultValue];
}

- (void) parser: (NSXMLParser *)parser
  foundElementDeclarationWithName: (NSString *)elementName
  model: (NSString *)model
{
  [s appendFormat: @"%@ %@ %@\n", NSStringFromSelector(_cmd),
    elementName, model];
}


- (void) parser: (NSXMLParser *)parser
  foundInternalEntityDeclarationWithName: (NSString *)name
  value: (NSString *)value
{
  [s appendFormat: @"%@ %@ %@\n", NSStringFromSelector(_cmd),
    name, value];
}


- (void) parser: (NSXMLParser *)parser
  foundExternalEntityDeclarationWithName: (NSString *)name
  publicID: (NSString *)publicID
  systemID: (NSString *)systemID
{
  [s appendFormat: @"%@ %@ %@ %@\n", NSStringFromSelector(_cmd),
    name, publicID, systemID];
}


- (void) parser: (NSXMLParser *)parser
  didStartElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
  attributes: (NSDictionary *)attributeDict
{
  static NSDictionary	*locale = nil;
  NSString		*d;

  if (nil == locale)
    {
      locale = [[[NSUserDefaults standardUserDefaults]
	dictionaryRepresentation] retain];
    }
  d = [attributeDict descriptionWithLocale: locale];
  [s appendFormat: @"%@ %@ %@ %@ %@\n", NSStringFromSelector(_cmd),
    elementName, namespaceURI, qName, d];
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
  [s appendFormat: @"%@ %@ %@ %@\n", NSStringFromSelector(_cmd),
  elementName, namespaceURI, qName];
}

- (void) parser: (NSXMLParser *)parser
  didStartMappingPrefix: (NSString *)prefix
  toURI: (NSString *)namespaceURI
{
  [s appendFormat: @"%@ %@ %@\n", NSStringFromSelector(_cmd),
  prefix, namespaceURI];
}

- (void) parser: (NSXMLParser *)parser
  didEndMappingPrefix: (NSString *)prefix
{
  [s appendFormat: @"%@ %@\n", NSStringFromSelector(_cmd),
    prefix];
}

- (void) parser: (NSXMLParser *)parser
  foundCharacters: (NSString *)string
{
  [s appendString: string];
}

- (void) parser: (NSXMLParser *)parser
  foundIgnorableWhitespace: (NSString *)whitespaceString
{
  [s appendFormat: @"%@ %@\n", NSStringFromSelector(_cmd),
    whitespaceString];
}

- (void) parser: (NSXMLParser *)parser
  foundProcessingInstructionWithTarget: (NSString *)target
  data: (NSString *)data
{
  [s appendFormat: @"%@ %@ %@\n", NSStringFromSelector(_cmd),
    target, data];
}

- (void) parser: (NSXMLParser *)parser
  foundComment: (NSString *)comment
{
  [s appendFormat: @"%@ %@\n", NSStringFromSelector(_cmd),
    comment];
}

- (void) parser: (NSXMLParser *)parser
  foundCDATA: (NSData *)CDATABlock
{
  [s appendFormat: @"%@ %@\n", NSStringFromSelector(_cmd),
    CDATABlock];
}

- (NSData *) parser: (NSXMLParser *)parser
  resolveExternalEntityName: (NSString *)name
  systemID: (NSString *)systemID
{
  [s appendFormat: @"%@ %@ %@\n", NSStringFromSelector(_cmd),
    name, systemID];
  return nil;
}

- (void) parser: (NSXMLParser *)parser
  parseErrorOccurred: (NSError *)parseError
{
  [s appendFormat: @"%@ %@ at %ld on %ld\n", NSStringFromSelector(_cmd),
    parseError, (long)[parser columnNumber], (long)[parser lineNumber]];
}

- (void) parser: (NSXMLParser *)parser
  validationErrorOccurred: (NSError *)validationError
{
  [s appendFormat: @"%@ %@ at %ld on %ld\n", NSStringFromSelector(_cmd),
    validationError, (long)[parser columnNumber], (long)[parser lineNumber]];
}

- (void) reset
{
  [s setString: @""];
}

@end

/* Use these booleans to control parsing behavior.
 */
static BOOL     setShouldProcessNamespaces = YES;
static BOOL     setShouldReportNamespacePrefixes = YES;
static BOOL     setShouldResolveExternalEntities = NO;

static BOOL
testParse(NSData *xml, NSString *expect)
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  Handler               *handler;
  NSXMLParser           *parser;
  Class                 c = NSClassFromString(@"GSSloppyXMLParser");

  c = Nil;
  if (Nil == c) c = [NSXMLParser class];
  parser = [[c alloc] initWithData: xml];

  [parser setShouldProcessNamespaces: setShouldProcessNamespaces];
  [parser setShouldReportNamespacePrefixes: setShouldReportNamespacePrefixes];
  [parser setShouldResolveExternalEntities: setShouldResolveExternalEntities];

  handler = [[Handler new] autorelease];
  [parser setDelegate: handler];
  if (NO == [parser parse])
    {
      NSLog(@"Parsing failed: %@ at %ld on %ld", [parser parserError],
        (long)[parser columnNumber], (long)[parser lineNumber]);
      [arp release];
      return NO;
    }
  else
    {
      if (NO == [[handler description] isEqual: expect]) 
        {
          NSLog(@"######## Expected:\n%@\n######## Parsed:\n%@\n########\n",
	    expect, [handler description]);
          [arp release];
          return NO;
        }
    }
  [arp release];
  return YES;
}

static BOOL
testParseCString(const char *xmlBytes, NSString *expect)
{
  NSData	*xml;

  xml = [NSData dataWithBytes: xmlBytes length: strlen(xmlBytes)];
  return testParse(xml, expect);
}

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSDirectoryEnumerator	*dir;
  NSString	        *str;
  NSString		*xmlName;
  const char            *x1 = "<?xml version=\"1.0\"?><test x = \"1\"></test>";
  const char            *x1e = "<test x=\"1\"></test>";
  NSString              *e1 =
@"parserDidStartDocument:\nparser:didStartElement:namespaceURI:qualifiedName:attributes: test  test {\n    x = 1;\n}\nparser:didEndElement:namespaceURI:qualifiedName: test  test\nparserDidEndDocument:\n";

  PASS((testParseCString(x1, e1)), "simple document 1")
  PASS((testParseCString(x1e, e1)), "simple document 1 without header")

  /* Now perform any tests using .xml and .result pairs of files in
   * the ParseData subdirectory.
   */
  dir = [mgr enumeratorAtPath: @"ParseData"];
  while ((xmlName = [dir nextObject]) != nil)
    {
      if ([[xmlName pathExtension] isEqualToString: @"xml"])
	{
	  NSString	*xmlPath;
          NSData	*xmlData;
          NSString	*result;

	  xmlPath = [@"ParseData" stringByAppendingPathComponent: xmlName];
	  str = [xmlPath stringByDeletingPathExtension];
	  str = [str stringByAppendingPathExtension: @"result"];
          xmlData = [NSData dataWithContentsOfFile: xmlPath];
          result = [NSString stringWithContentsOfFile: str];
	  PASS((testParse(xmlData, result)), "%s", [xmlName UTF8String])
	}
    }

  {
    NSString    *exp;
    NSData      *dat;

     exp = @"parserDidStartDocument:\n\
parser:didStartElement:namespaceURI:qualifiedName:attributes: file  file {\n}\n\
&Aparser:didEndElement:namespaceURI:qualifiedName: file  file\n\
parserDidEndDocument:\n\
";

    str = [NSString stringWithFormat:
@"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
@"<!DOCTYPE file [<!ENTITY foo SYSTEM \"file://%@/GNUmakefile\">]>\n"
@"<file>&amp;&foo;&#65;</file>", [mgr currentDirectoryPath]];

    dat = [str dataUsingEncoding: NSUTF8StringEncoding];
    PASS((testParse(dat, exp)), "external entity")
  }

  [arp release]; arp = nil;
  return 0;
}
