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

#define GSInternal              NSXMLDocumentInternal
#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLDocument)

//#import <Foundation/NSXMLParser.h>
#import <Foundation/NSError.h>

extern void clearPrivatePointers(xmlNodePtr aNode);

// Private methods to manage libxml pointers...
@interface NSXMLNode (Private)
- (void *) _node;
- (void) _setNode: (void *)_anode;
+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node;
- (void) _addSubNode:(NSXMLNode *)subNode;
- (void) _removeSubNode:(NSXMLNode *)subNode;
- (void) _insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index;
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
      [internal->docType release];
      [internal->MIMEType release];
    }
  [super dealloc];
}

- (NSString*) characterEncoding
{
  if (MY_DOC->encoding)
    return [NSString stringWithUTF8String: (const char *)MY_DOC->encoding];
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
  NSString *string = nil;

  // Check for nil data and throw an exception 
  if (![data isKindOfClass: [NSData class]])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] non data argument",
		   NSStringFromSelector(_cmd)];
    }
  if (nil == data)
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] nil argument",
		   NSStringFromSelector(_cmd)];
    }

  // Initialize the string...
  string = [[NSString alloc] initWithData: data
				 encoding: NSUTF8StringEncoding];
  AUTORELEASE(string);
  return [self initWithXMLString:string options:mask error:error];
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
  if (NO == [string isKindOfClass: [NSString class]])
    {
      DESTROY(self);
      if (nil == string)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[NSXMLDocument-%@] nil argument",
	    NSStringFromSelector(_cmd)];
	}
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] invalid argument",
	NSStringFromSelector(_cmd)];
    }
  if ((self = [self initWithKind: NSXMLDocumentKind options: 0]) != nil)
    {
      const char *str = [string UTF8String];
      char *url = NULL;
      char *encoding = NULL; // "UTF8";
      int options = XML_PARSE_NOERROR;
      xmlDocPtr doc = NULL;
      if (!(mask & NSXMLNodePreserveWhitespace))
        options |= XML_PARSE_NOBLANKS;
      //xmlKeepBlanksDefault(0);
      doc = xmlReadDoc((xmlChar *)str, url, encoding, options);
      if(doc == NULL)
	{
	  [self release];
	  self = nil;
	  if (error != NULL)
	    *error = [NSError errorWithDomain:@"NSXMLErrorDomain" code:0 userInfo:nil]; 
	  //[NSException raise:NSInvalidArgumentException
	  //	      format:@"Cannot instantiate NSXMLDocument with invalid data"];
	}
      [self _setNode:doc];
    }
  return self;
}

- (BOOL) isStandalone
{
  return (MY_DOC->standalone == 1);
}

- (NSString*) MIMEType
{
  return internal->MIMEType;
}

- (NSXMLElement*) rootElement
{
  xmlNodePtr rootElem = xmlDocGetRootElement(MY_DOC);
  return (NSXMLElement *)[NSXMLNode _objectForNode:rootElem];
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  MY_DOC->encoding = XMLSTRING(encoding);
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)kind
{
  internal->contentKind = kind;
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  NSAssert(documentTypeDeclaration != nil, NSInvalidArgumentException);
  ASSIGNCOPY(internal->docType, documentTypeDeclaration);
  MY_DOC->extSubset = [documentTypeDeclaration _node];
}

- (void) setMIMEType: (NSString*)MIMEType
{
  ASSIGNCOPY(internal->MIMEType, MIMEType);
}

- (void) setRootElement: (NSXMLNode*)root
{
  id oldElement = [self rootElement];

  if(root == nil)
    {
      return;
    }

  xmlDocSetRootElement(MY_DOC,[root _node]);

  // Do our subNode housekeeping...
  [self _removeSubNode:oldElement];
  [self _addSubNode:root];
}

- (void) setStandalone: (BOOL)standalone
{
  MY_DOC->standalone = standalone;
}

- (void) setVersion: (NSString*)version
{
  if ([version isEqualToString: @"1.0"] || [version isEqualToString: @"1.1"])
    {
      MY_DOC->version = XMLStringCopy(version);
   }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad XML version (%@)", version];
    }
}

- (NSString*) version
{
  if (MY_DOC->version)
    return StringFromXMLStringPtr(MY_DOC->version);
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
  NSXMLNode	*child;
  xmlNodePtr     n;

  if (index >= [self childCount])
    {
      [NSException raise: NSRangeException
		  format: @"index too large"];
    }

  child = [[self children] objectAtIndex: index];
  n = [child _node];
  xmlUnlinkNode(n);
}

- (void) setChildren: (NSArray*)children
{
  NSEnumerator	*en;
  NSXMLNode		*child;
  
  while ([self childCount] > 0)
    {
      [self removeChildAtIndex: [self childCount] - 1];
    }
  en = [[self children] objectEnumerator];
  while ((child = [en nextObject]) != nil)
    {
      [self insertChild: child atIndex: [self childCount]];
    }
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
  NSData *data = [NSData dataWithBytes: [xmlString UTF8String]
				length: [xmlString length]];
  return data;
}

- (NSString *) XMLStringWithOptions: (NSUInteger)options
{
  NSString	*string = nil;
  xmlChar	*buf = NULL;
  int		length;

  xmlDocDumpFormatMemoryEnc(MY_DOC, &buf, &length, "utf-8", 1);

  if (buf != 0 && length > 0)
    {
      string = StringFromXMLString(buf, length);
      free(buf);
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
  NSXMLDocument *c = (NSXMLDocument*)[super copyWithZone: zone];
  internal->node = (xmlDoc *)xmlCopyDoc(MY_DOC, 1); // copy recursively
  clearPrivatePointers(internal->node); // clear out all of the _private pointers in the entire tree
  ((xmlNodePtr)internal->node)->_private = c;
  return c;
}

- (BOOL) isEqual: (id)other
{
  if(self == other)
    {
      return YES;
    }
  return [[self rootElement] isEqual: [other rootElement]];
}
@end
