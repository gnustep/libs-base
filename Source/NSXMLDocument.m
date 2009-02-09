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

#include "NSXMLPrivate.h"

@implementation	NSXMLDocument

+ (Class) replacementClassForClass: (Class)cls
{
  return Nil;
}

- (void) dealloc
{
  [_encoding release];
  [_version release];
  [_docType release];
  [_children release];
  [_URI release];
  [_MIMEType release];
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
  [doc setURI:  [url absoluteString]];
  return doc;
}


- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  [self notImplemented: _cmd];
  _children = [NSMutableArray new];
  return nil;
}

- (id) initWithRootElement: (NSXMLElement*)element
{
  self = [self initWithData: nil options: 0 error: 0];
  [self setRootElement: (NSXMLNode*)element];
  return self;
}

- (id) initWithXMLString: (NSString*)string
                 options: (NSUInteger)mask
                   error: (NSError**)error
{
  [self notImplemented: _cmd];
  return nil;
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
  [self notImplemented: _cmd];
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
  [self notImplemented: _cmd];
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
  [self notImplemented: _cmd];
  return nil;
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

