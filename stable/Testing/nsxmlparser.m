/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/Foundation.h>

@interface	MyDelegate : NSObject
{
  BOOL		problem;
  unsigned	startDoc;
  unsigned	endDoc;
  unsigned	startElem;
  unsigned	endElem;
}
- (BOOL) check;
@end

@implementation	MyDelegate
- (BOOL) check
{
  if (startDoc != 1)
    {
      problem = YES;
      NSLog(@"Missing start doc");
    }
  if (endDoc != 1)
    {
      problem = YES;
      NSLog(@"Missing end doc");
    }
  if (startElem != 1)
    {
      problem = YES;
      NSLog(@"Missing start element");
    }
  if (endElem != 1)
    {
      problem = YES;
      NSLog(@"Missing end element");
    }
  return problem;
}

- (void) parserDidEndDocument: (NSXMLParser*)aParser
{
  endDoc++;
}
- (void) parserDidStartDocument: (NSXMLParser*)aParser
{
  startDoc++;
}

- (void) parser: (NSXMLParser*)aParser
  didStartElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
  attributes: (NSDictionary*)anAttributeDict
{
  if (startElem == 0)
    {
      startElem++;
      if ([anElementName isEqual: @"example"] == NO)
	NSLog(@"Bad start element '%@' in namespace '%@' '%@' attributes '%@'",
	anElementName, aNamespaceURI, aQualifierName, anAttributeDict);
    }
  else
    {
      NSLog(@"Extra start element '%@' in namespace '%@' '%@' attributes '%@'",
	anElementName, aNamespaceURI, aQualifierName, anAttributeDict);
    }
}


- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
{
  if (endElem == 0)
    {
      endElem++;
      if ([anElementName isEqual: @"example"] == NO)
	NSLog(@"Bad end element '%@' in namespace '%@' '%@'",
	anElementName, aNamespaceURI, aQualifierName);
    }
  else
    {
      NSLog(@"Extra end element '%@' in namespace '%@' '%@'",
	anElementName, aNamespaceURI, aQualifierName);
    }
}


@end

int main ()
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSData	*document;
  MyDelegate	*delegate;
  NSXMLParser	*parser;
  const char	*str =
"<?xml version=\"1.0\"?>"
"<example>"
"</example>";

  document = [NSData dataWithBytes: str length: strlen(str)];
  parser = [[NSXMLParser alloc] initWithData: document];
  delegate = [MyDelegate new];
  [parser setDelegate: delegate];
  [parser setShouldProcessNamespaces: YES];

  if ([parser parse] == NO)
    {
      NSLog(@"Failed to parse example document");
    }
  else if ([delegate check] == NO)
    {
      NSLog(@"All correct.");
    }
  [parser release];
  [pool release];
  return 0;
}

