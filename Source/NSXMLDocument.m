/* Implementation for NSXMLDocument for GNUStep
   Copyright (C) 2008 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Written by:  Gregory John Casamento <greg.casamento@gmail.com>
   Created/Modified: September 2008,2012
      
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

#define	GS_XMLNODETYPE	xmlDoc
#define GSInternal	NSXMLDocumentInternal

#import "NSXMLPrivate.h"
#import "GSInternal.h"

GS_PRIVATE_INTERNAL(NSXMLDocument)

//#import <Foundation/NSXMLParser.h>
#import <Foundation/NSError.h>

#if defined(HAVE_LIBXML)

@implementation	NSXMLDocument

+ (Class) replacementClassForClass: (Class)cls
{
  return cls;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      [internal->docType release];
      [internal->MIMEType release];
    }
  [super dealloc];
}

- (NSString*) characterEncoding
{
  if (internal->node->encoding)
    return StringFromXMLStringPtr(internal->node->encoding);
  else
    return nil;
}

- (NSXMLDocumentContentKind) documentContentKind
{
  return internal->contentKind;
}

- (NSXMLDTD*) DTD
{
  return internal->docType;
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLDocument);
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
  doc = [self initWithData: data options: mask error: error];
  [doc setURI: [url absoluteString]];
  return doc;
}

- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  // Check for nil data and throw an exception 
  if (nil == data)
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] nil argument",
		   NSStringFromSelector(_cmd)];
    }
  if (![data isKindOfClass: [NSData class]])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] non data argument",
		   NSStringFromSelector(_cmd)];
    }

  if ((self = [self initWithKind: NSXMLDocumentKind options: 0]) != nil)
    {
      char *url = NULL;
      char *encoding = NULL; // "UTF8";
      int options = XML_PARSE_NOERROR;
      xmlDocPtr doc = NULL;

      if (!(mask & NSXMLNodePreserveWhitespace))
        {
          options |= XML_PARSE_NOBLANKS;
          //xmlKeepBlanksDefault(0);
        }
      doc = xmlReadMemory([data bytes], [data length], 
                          url, encoding, options);
      if (doc == NULL)
	{
          DESTROY(self);
	  if (error != NULL)
            {
              *error = [NSError errorWithDomain: @"NSXMLErrorDomain"
                                           code: 0
                                       userInfo: nil]; 
            }
	}
      // FIXME: Free old node
      [self _setNode: doc];
    }
  return self;
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLDocumentKind == kind)
    {
      return [super initWithKind: kind options: theOptions];
    }
  else
    {
      [self release];
      return [[NSXMLNode alloc] initWithKind: kind
                                     options: theOptions];
    }
}

- (id) initWithRootElement: (NSXMLElement*)element
{
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
  if (nil == string)
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
                  format: @"[NSXMLDocument-%@] nil argument",
                   NSStringFromSelector(_cmd)];
    }
  if (NO == [string isKindOfClass: [NSString class]])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] invalid argument",
                   NSStringFromSelector(_cmd)];
    }
  return [self initWithData: [string dataUsingEncoding: NSUTF8StringEncoding]
                    options: mask
                      error: error];
}

- (BOOL) isStandalone
{
  return (internal->node->standalone == 1);
}

- (NSString*) MIMEType
{
  return internal->MIMEType;
}

- (NSXMLElement*) rootElement
{
  xmlNodePtr rootElem = xmlDocGetRootElement(internal->node);
  return (NSXMLElement *)[NSXMLNode _objectForNode: rootElem];
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  internal->node->encoding = XMLStringCopy(encoding);
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)kind
{
  internal->contentKind = kind;
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  NSAssert(documentTypeDeclaration != nil, NSInvalidArgumentException);
  // FIXME: do node house keeping, remove ivar, use intSubset
  ASSIGNCOPY(internal->docType, documentTypeDeclaration);
  internal->node->extSubset = [documentTypeDeclaration _node];
}

- (void) setMIMEType: (NSString*)MIMEType
{
  ASSIGNCOPY(internal->MIMEType, MIMEType);
}

- (void) setRootElement: (NSXMLNode*)root
{
  if (root == nil)
    {
      return;
    }
  if ([root parent] != nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"%@ cannot be used as root of %@", 
		   root, 
		   self];
    }

  // remove all sub nodes
  [self setChildren: nil];

  xmlDocSetRootElement(internal->node, [root _node]);

  // Do our subNode housekeeping...
  [self _addSubNode: root];
}

- (void) setStandalone: (BOOL)standalone
{
  internal->node->standalone = standalone;
}

- (void) setVersion: (NSString*)version
{
  if ([version isEqualToString: @"1.0"] || [version isEqualToString: @"1.1"])
    {
      internal->node->version = XMLStringCopy(version);
   }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad XML version (%@)", version];
    }
}

- (NSString*) version
{
  if (internal->node->version)
    return StringFromXMLStringPtr(internal->node->version);
  else
    return @"1.0";
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  NSXMLNodeKind	kind = [child kind];
  NSUInteger childCount = [self childCount];

  // Check to make sure this is a valid addition...
  NSAssert(nil != child, NSInvalidArgumentException);
  NSAssert(index <= childCount, NSInvalidArgumentException);
  NSAssert(nil == [child parent], NSInvalidArgumentException);
  kind = [child kind];
  NSAssert(NSXMLAttributeKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDTDKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDocumentKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLElementDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLEntityDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNotationDeclarationKind != kind, NSInvalidArgumentException);

  [self _insertChild:child atIndex:index];
}

- (void) insertChildren: (NSArray*)children atIndex: (NSUInteger)index
{
  NSEnumerator	*enumerator = [children objectEnumerator];
  NSXMLNode	*child;
  
  while ((child = [enumerator nextObject]) != nil)
    {
      [self insertChild: child atIndex: index++];
    }
}

- (void) removeChildAtIndex: (NSUInteger)index
{
  NSXMLNode *child;

  if (index >= [self childCount])
    {
      [NSException raise: NSRangeException
                 format: @"index too large"];
    }

  child = [self childAtIndex: index];
  [child detach];
}

- (void) setChildren: (NSArray*)children
{
  NSUInteger count = [self childCount];

  while (count-- > 0)
    {
      [self removeChildAtIndex: count];
    }

  [self insertChildren: children atIndex: 0];
}
 
- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: [self childCount]];
}
 
- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)node
{
  [self insertChild: node atIndex: index];
  [self removeChildAtIndex: index + 1];
}

- (NSData*) XMLData
{ 
  return [self XMLDataWithOptions: NSXMLNodeOptionsNone]; 
}

- (NSData *) XMLDataWithOptions: (NSUInteger)options
{
  NSString *xmlString = [self XMLStringWithOptions: options];

  return [xmlString dataUsingEncoding: NSUTF8StringEncoding
                 allowLossyConversion: NO];
}

- (id) objectByApplyingXSLT: (NSData*)xslt
                  arguments: (NSDictionary*)arguments
                      error: (NSError**)error
{
#ifdef HAVE_LIBXSLT
  xmlChar **params = NULL;
  xmlDocPtr stylesheetDoc = xmlReadMemory([xslt bytes], [xslt length],
                                          NULL, NULL, XML_PARSE_NOERROR);
  xsltStylesheetPtr stylesheet = xsltParseStylesheetDoc(stylesheetDoc);
  xmlDocPtr resultDoc = NULL;
 
  // Iterate over the keys and put them into params...
  if (arguments != nil)
    {
      NSEnumerator *en = [arguments keyEnumerator];
      NSString *key = nil;
      NSUInteger index = 0;
      int count = [[arguments allKeys] count];

      *params = NSZoneCalloc([self zone], ((count + 1) * 2), sizeof(xmlChar *));
      while ((key = [en nextObject]) != nil)
	{
	  params[index] = (xmlChar *)XMLSTRING(key);
	  params[index+1] = (xmlChar *)XMLSTRING([arguments objectForKey: key]);
	  index += 2;
	}
    }

  // Apply the stylesheet and get the result...
  resultDoc
    = xsltApplyStylesheet(stylesheet, internal->node, (const char **)params);
  
  // Cleanup...
  xsltFreeStylesheet(stylesheet);
  xmlFreeDoc(stylesheetDoc);
  xsltCleanupGlobals();
  xmlCleanupParser();
  NSZoneFree([self zone], params);

  return [NSXMLNode _objectForNode: (xmlNodePtr)resultDoc];
#else
  return nil;
#endif
}

- (id) objectByApplyingXSLTString: (NSString*)xslt
                        arguments: (NSDictionary*)arguments
                            error: (NSError**)error
{
  NSData *data =  [xslt dataUsingEncoding: NSUTF8StringEncoding];
  NSXMLDocument *result = [self objectByApplyingXSLT: data
                                           arguments: arguments
                                               error: error];
  return result;
}

- (id) objectByApplyingXSLTAtURL: (NSURL*)xsltURL
                       arguments: (NSDictionary*)arguments
                           error: (NSError**)error
{
  NSData *data = [NSData dataWithContentsOfURL: xsltURL];
  NSXMLDocument *result = [self objectByApplyingXSLT: data
                                           arguments: arguments
                                               error: error];
  return result;
}

- (BOOL) validateAndReturnError: (NSError**)error
{
  xmlValidCtxtPtr ctxt = xmlNewValidCtxt();
  // FIXME: Should use xmlValidityErrorFunc and userData
  // to get the error
  BOOL result = (BOOL)(xmlValidateDocument(ctxt, internal->node));
  xmlFreeValidCtxt(ctxt);
  return result;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSXMLDocument *c = (NSXMLDocument*)[super copyWithZone: zone];

  [c setMIMEType: [self MIMEType]];
  // the extSubset isnt copied by libxml2
  [c setDTD: [self DTD]];
  [c setDocumentContentKind: [self documentContentKind]];
  return c;
}

- (BOOL) isEqual: (id)other
{
  if (self == other)
    {
      return YES;
    }
  // FIXME
  return [[self rootElement] isEqual: [other rootElement]];
}
@end

#endif
