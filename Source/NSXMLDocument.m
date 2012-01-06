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

#define GSInternal              NSXMLDocumentInternal
#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLDocument)

#import <Foundation/NSXMLParser.h>

@interface NSXMLDocument (Debug)
- (id) elementStack;
@end

@implementation NSXMLDocument (Debug)
- (id) elementStack
{
  return internal->elementStack;
}
@end

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
  if (GS_EXISTS_INTERNAL)
    {
      [internal->encoding release]; 
      [internal->version release];
      [internal->docType release];
      [internal->MIMEType release];
      [internal->elementStack release];
      [internal->xmlData release];
    }
  [super dealloc];
}

- (NSString*) characterEncoding
{
  return internal->encoding;
}

- (NSXMLDocumentContentKind) documentContentKind
{
  return internal->contentKind;
}

- (NSXMLDTD*) DTD
{
  return internal->docType;
}

- (id) init
{
  return [self initWithKind: NSXMLDocumentKind options: 0];
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
  if (NO == [data isKindOfClass: [NSData class]])
    {
      DESTROY(self);
      if (nil == data)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[NSXMLDocument-%@] nil argument",
	    NSStringFromSelector(_cmd)];
	}
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] invalid argument",
	NSStringFromSelector(_cmd)];
    }
  GS_CREATE_INTERNAL(NSXMLDocument)
  if ((self = [super initWithKind: NSXMLDocumentKind options: 0]) != nil)
    {
      NSXMLParser *parser = [[NSXMLParser alloc] initWithData: data];

      internal->standalone = YES;
      internal->elementStack = [[NSMutableArray alloc] initWithCapacity: 10];
      ASSIGN(internal->xmlData, data); 
      if (nil == parser)
	{
	  DESTROY(self);
	}
      else
	{
	  [parser setDelegate: self];
	  [parser parse];
	  RELEASE(parser);
	}
    }
  return self;
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLDocumentKind == kind)
    {
      /* Create holder for internal instance variables so that we'll have
       * all our ivars available rather than just those of the superclass.
       */
      GS_CREATE_INTERNAL(NSXMLDocument)
    }
  return [super initWithKind: kind options: theOptions];
}

- (id) initWithRootElement: (NSXMLElement*)element
{
  if ([element parent] != nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"%@ cannot be used as root of %@", 
		   element, 
		   self];
    }
  self = [self initWithKind: NSXMLDocumentKind options: 0];
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
  return internal->standalone;
}

- (NSString*) MIMEType
{
  return internal->MIMEType;
}

- (NSXMLElement*) rootElement
{
  return internal->rootElement;
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  ASSIGNCOPY(internal->encoding, encoding);
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)kind
{
  internal->contentKind = kind;
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  ASSIGNCOPY(internal->docType, documentTypeDeclaration);
}

- (void) setMIMEType: (NSString*)MIMEType
{
  ASSIGNCOPY(internal->MIMEType, MIMEType);
}

- (void) setRootElement: (NSXMLNode*)root
{
  NSAssert(internal->rootElement == nil, NSGenericException);
  [self insertChild: root atIndex: [internal->children count]];
  internal->rootElement = (NSXMLElement*)root;
}

- (void) setStandalone: (BOOL)standalone
{
  internal->standalone = standalone;
}

- (void) setVersion: (NSString*)version
{
  if ([version isEqualToString: @"1.0"] || [version isEqualToString: @"1.1"])
    {
      ASSIGNCOPY(internal->version, version);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad XML version (%@)", version];
    }
}

- (NSString*) version
{
  return internal->version;
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  [child setParent: self];
  [(NSMutableArray *)internal->children insertObject: child atIndex: index];
  // internal->childrenHaveMutated = YES;
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
  [(NSMutableArray *)internal->children removeObjectAtIndex: index];
  // internal->childrenHaveMutated = YES;
}

- (void) setChildren: (NSArray*)children
{
  unsigned	count;

  while ((count = [internal->children count]) > 0)
    {
      [self removeChildAtIndex: count - 1];
    }
  [self insertChildren: children atIndex: 0];
}

- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: [internal->children count]];
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

- (NSData *) XMLDataWithOptions: (NSUInteger)options
{
  NSString *xmlString = [self XMLStringWithOptions: options];
  NSData *data = [NSData dataWithBytes: [xmlString UTF8String]
				length: [xmlString length]];
  return data;
}

- (NSString *) XMLStringWithOptions: (NSUInteger)options
{
  NSMutableString	*string = [NSMutableString string];
  NSEnumerator		*en = [internal->children objectEnumerator];
  id			obj = nil;

  if (internal->version || internal->standalone || internal->encoding)
    {
      NSString *version = internal->version;
      if (!version)
	version = @"1.0";
      [string appendString: @"<?xml version=\""];
      [string appendString: version];
      [string appendString: @"\""];
      if (internal->encoding)
	{
	  [string appendString: @" encoding=\""];
	  [string appendString: internal->encoding];
	  [string appendString: @"\""];
	}
      if (YES == internal->standalone)
        {
          [string appendString: @" standalone=\"yes\""];
        }
      else
        {
          [string appendString: @" standalone=\"no\""];
        }
      [string appendString: @"?>\n"];
    }
  while ((obj = [en nextObject]) != nil)
    {
      [string appendString: [obj XMLStringWithOptions: options]];
    }
  return string;
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

- (id) copyWithZone: (NSZone *)zone
{
  id c = [super copyWithZone: zone];
  [c setStandalone: internal->standalone];
  [c setRootElement: internal->rootElement];
  [c setDTD: internal->docType];
  [c setMIMEType: internal->MIMEType];
  return c;
}

@end

@implementation NSXMLDocument (NSXMLParserDelegate)

- (void)   parser: (NSXMLParser *)parser
  didStartElement: (NSString *)elementName 
     namespaceURI: (NSString *)namespaceURI 
    qualifiedName: (NSString *)qualifiedName 
       attributes: (NSDictionary *)attributeDict
{
  NSXMLElement *lastElement = [internal->elementStack lastObject];
  NSXMLElement *currentElement = 
    [[NSXMLElement alloc] initWithName: elementName];
  
  [lastElement addChild: currentElement];
  [internal->elementStack addObject: currentElement];
  [currentElement release];
  if (internal->rootElement == nil)
    {
      [self setRootElement: currentElement];
    }
  [currentElement setAttributesAsDictionary: attributeDict];
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName 
{
  if ([internal->elementStack count] > 0)
    { 
      NSXMLElement *currentElement = [internal->elementStack lastObject];
      if ([[currentElement name] isEqualToString: elementName])
	{
	  [internal->elementStack removeLastObject];
	} 
    }
}

- (void) parser: (NSXMLParser *)parser
foundCharacters: (NSString *)string
{
  NSXMLElement *currentElement = [internal->elementStack lastObject];
  [currentElement setStringValue: string];
}
@end
