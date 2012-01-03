/* Implementation for NSXMLDocument for GNUStep
   Copyright (C) 2008 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: September 2008

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#import "common.h"

#import "NSXMLPrivate.h"
#import <Foundation/NSXMLParser.h>

// Forward declaration of interface for NSXMLParserDelegate
@interface NSXMLDocument (NSXMLParserDelegate)
@end

@implementation	NSXMLDocument

+ (Class) replacementClassForClass: (Class)cls
{
  return Nil;
}

- (void) dealloc
{
  RELEASE(_encoding); 
  RELEASE(_version);
  RELEASE(_docType);
  RELEASE(_children);
  RELEASE(_URI);
  RELEASE(_MIMEType);
  RELEASE(_elementStack);
  RELEASE(_xmlData);
  [super dealloc];
}

- (NSString*) characterEncoding
{
  return _encoding;
}

- (NSXMLDocumentContentKind) documentContentKind
{
  return _contentKind;
}

- (NSXMLDTD*) DTD
{
  return _docType;
}

- (id) initWithContentsOfURL: (NSURL*)url
                     options: (NSUInteger)mask
                       error: (NSError**)error
{
  NSData	*data;
  NSXMLDocument	*doc;

  data = [NSData dataWithContentsOfURL: url];
  doc = [self initWithData: data options: 0 error: 0];
  [doc setURI: [url absoluteString]];
  return doc;
}


- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  if ((self = [super init]) != nil)
    {
      NSXMLParser *parser = [[NSXMLParser alloc] initWithData: data];
      if (parser != nil)
	{
	  _standalone = YES;
	  _children = [[NSMutableArray alloc] initWithCapacity: 10];
	  _elementStack = [[NSMutableArray alloc] initWithCapacity: 10];
	  ASSIGN(_xmlData, data); 
	  [parser setDelegate: self];
	  [parser parse];
	  RELEASE(parser);
	}
    }
  return self;
}

- (id) initWithRootElement: (NSXMLElement*)element
{
  if ([_children containsObject: element] || [element parent] != nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"%@ cannot be used as root of %@", 
		   element, 
		   self];
    }
  self = [self initWithData: nil options: 0 error: 0];
  if (self != nil)
    {
      [self setRootElement: (NSXMLNode*)element];
    }
  return self;
}

- (id) initWithXMLString: (NSString*)string
                 options: (NSUInteger)mask
                   error: (NSError**)error
{
  NSData *data = [NSData dataWithBytes: [string UTF8String]
				length: [string length]];
  self = [self initWithData: data
		    options: mask
		      error: error];
  return self;
}

- (BOOL) isStandalone
{
  return _standalone;
}

- (NSString*) MIMEType
{
  return _MIMEType;
}

- (NSXMLElement*) rootElement
{
  return _rootElement;
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  ASSIGNCOPY(_encoding, encoding);
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)kind
{
  _contentKind = kind;
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  ASSIGNCOPY(_docType, documentTypeDeclaration);
}

- (void) setMIMEType: (NSString*)MIMEType
{
  ASSIGNCOPY(_MIMEType, MIMEType);
}

- (void) setRootElement: (NSXMLNode*)root
{
  NSAssert(_rootElement == nil, NSGenericException);
  [self insertChild: root atIndex: [_children count]];
  _rootElement = (NSXMLElement*)root;
}

- (void) setStandalone: (BOOL)standalone
{
  _standalone = standalone;
}

- (void) setVersion: (NSString*)version
{
  if ([version isEqualToString: @"1.0"] || [version isEqualToString: @"1.1"])
    {
      ASSIGNCOPY(_version, version);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad XML version (%@)", version];
    }
}

- (NSString*) version
{
  return _version;
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  [child setParent: self];
  [(NSMutableArray *)_children insertObject: child atIndex: index];
  _childrenHaveMutated = YES;
}

- (void) insertChildren: (NSArray*)children atIndex: (NSUInteger)index
{
  NSEnumerator	*enumerator = [children objectEnumerator];
  NSXMLNode	*node;

  while ((node = [enumerator nextObject]) != nil)
    {
      [self insertChild: node atIndex: index++];
    }
}

- (void) removeChildAtIndex: (NSUInteger)index
{
  [(NSMutableArray *)_children removeObjectAtIndex: index];
  _childrenHaveMutated = YES;
}

- (void) setChildren: (NSArray*)children
{
  unsigned	count;

  while ((count = [_children count]) > 0)
    {
      [self removeChildAtIndex: count - 1];
    }
  [self insertChildren: children atIndex: 0];
}

- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: [_children count]];
}

- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)node
{
  [self removeChildAtIndex: index];
  [self insertChild: node atIndex: index];
}

- (NSData*) XMLData
{ 
  return [self XMLDataWithOptions: NSXMLNodeOptionsNone]; 
}

- (NSData*) XMLDataWithOptions: (NSUInteger)options
{
  // TODO: Apply options to data.
  return _xmlData;
}

- (id) objectByApplyingXSLT: (NSData*)xslt
                  arguments: (NSDictionary*)arguments
                      error: (NSError**)error
{
  [self notImplemented: _cmd];
  return nil;
}

- (id) objectByApplyingXSLTString: (NSString*)xslt
                        arguments: (NSDictionary*)arguments
                            error: (NSError**)error
{
  [self notImplemented: _cmd];
  return nil;
}

- (id) objectByApplyingXSLTAtURL: (NSURL*)xsltURL
                       arguments: (NSDictionary*)argument
                           error: (NSError**)error
{
  [self notImplemented: _cmd];
  return nil;
}

- (BOOL) validateAndReturnError: (NSError**)error
{
  [self notImplemented: _cmd];
  return NO;
}

@end

@implementation NSXMLDocument (NSXMLParserDelegate)

- (void)   parser: (NSXMLParser *)parser
  didStartElement: (NSString *)elementName 
     namespaceURI: (NSString *)namespaceURI 
    qualifiedName: (NSString *)qualifiedName 
       attributes: (NSDictionary *)attributeDict
{
  NSXMLElement *currentElement = 
    [[NSXMLElement alloc] initWithName: elementName];
  
  [_elementStack addObject: currentElement];
  if (_rootElement == nil)
    {
      [self setRootElement: currentElement];
    }

  [currentElement setAttributesAsDictionary: 
		    attributeDict];
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName 
{
  if ([_elementStack count] > 0)
    { 
      NSXMLElement *currentElement = [_elementStack lastObject];
      if ([[currentElement name] isEqualToString: elementName])
	{
	  [_elementStack removeLastObject];
	} 
    }
}

- (void) parser: (NSXMLParser *)parser
foundCharacters: (NSString *)string
{
  NSXMLElement *currentElement = [_elementStack lastObject];
  [currentElement setStringValue: string];
}
@end
