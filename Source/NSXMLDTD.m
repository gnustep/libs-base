/* Inmplementation for NSXMLDTD for GNUStep
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

#define	GS_XMLNODETYPE	xmlDtd
#define GSInternal	NSXMLDTDInternal

#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLDTD)

@implementation NSXMLDTD

+ (NSXMLDTDNode*) predefinedEntityDeclarationForName: (NSString*)name
{
  // FIXME: We should cache these instances
  if ([name isEqualToString: @"lt"])
    {
      NSXMLDTDNode *node;
      
      node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind];
      [node setName: @"lt"];
      [node setStringValue: @"<"];
      return AUTORELEASE(node);
    }
  if ([name isEqualToString: @"gt"])
    {
      NSXMLDTDNode *node;
      
      node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind];
      [node setName: @"gt"];
      [node setStringValue: @">"];
      return AUTORELEASE(node);
    }
  if ([name isEqualToString: @"amp"])
    {
      NSXMLDTDNode *node;
      
      node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind];
      [node setName: @"amp"];
      [node setStringValue: @"&"];
      return AUTORELEASE(node);
    }
  if ([name isEqualToString: @"quot"])
    {
      NSXMLDTDNode *node;
      
      node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind];
      [node setName: @"qout"];
      [node setStringValue: @"\""];
      return AUTORELEASE(node);
    }
  if ([name isEqualToString: @"apos"])
    {
      NSXMLDTDNode *node;
      
      node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind];
      [node setName: @"apos"];
      [node setStringValue: @"'"];
      return AUTORELEASE(node);
    }

  return nil;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
    }
  [super dealloc];
}

- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: [self childCount]];
}

- (NSXMLDTDNode*) attributeDeclarationForName: (NSString*)name
                                  elementName: (NSString*)elementName
{
  xmlDtdPtr node = internal->node;
  xmlNodePtr children = NULL;
  const xmlChar *xmlName = XMLSTRING(name);
  const xmlChar *xmlElementName = XMLSTRING(elementName);

  if ((node == NULL) ||
      (node->children == NULL))
    {
      return nil;
    }
     
 for (children = node->children; children; children = children->next)
   {
     if (children->type == XML_ATTRIBUTE_DECL)
       {
         xmlAttributePtr attr = (xmlAttributePtr)children;

         if ((xmlStrcmp(attr->name, xmlName) == 0) &&
             (xmlStrcmp(attr->elem, xmlElementName) == 0))
           {
             return (NSXMLDTDNode*)[NSXMLNode _objectForNode: children];
           }
       }
   }

  return nil;
}

- (NSXMLDTDNode*) elementDeclarationForName: (NSString*)name
{
  xmlDtdPtr node = internal->node;
  xmlNodePtr children = NULL;
  const xmlChar *xmlName = XMLSTRING(name);

  if ((node == NULL) ||
      (node->children == NULL))
    {
      return nil;
    }
     
 for (children = node->children; children; children = children->next)
   {
     if (children->type == XML_ELEMENT_DECL)
       {
         xmlElementPtr elem = (xmlElementPtr)children;

         if (xmlStrcmp(elem->name, xmlName) == 0)
           {
             return (NSXMLDTDNode*)[NSXMLNode _objectForNode: children];
           }
       }
   }

  return nil;
}

- (NSXMLDTDNode*) entityDeclarationForName: (NSString*)name
{
  //xmlGetEntityFromDtd
  xmlDtdPtr node = internal->node;
  xmlNodePtr children = NULL;
  const xmlChar *xmlName = XMLSTRING(name);

  if ((node == NULL) ||
      (node->children == NULL))
    {
      return nil;
    }
     
 for (children = node->children; children; children = children->next)
   {
     if (children->type == XML_ENTITY_DECL)
       {
         xmlEntityPtr entity = (xmlEntityPtr)children;

         if (xmlStrcmp(entity->name, xmlName) == 0)
           {
             return (NSXMLDTDNode*)[NSXMLNode _objectForNode: children];
           }
       }
   }

  return nil;
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLDTD);
}

- (id) init
{
  return [self initWithKind: NSXMLDTDKind options: 0];
}

- (id) initWithContentsOfURL: (NSURL*)url
                     options: (NSUInteger)mask
                       error: (NSError**)error
{
  NSData	*data;
  NSXMLDTD	*doc;

  data = [NSData dataWithContentsOfURL: url];
  doc = [self initWithData: data options: mask error: error];
  [doc setURI: [url absoluteString]];
  return doc;
}

- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  NSXMLDocument *tempDoc = 
    [[NSXMLDocument alloc] initWithData: data
                                options: mask
                                  error: error];
  if (tempDoc != nil)
    {
      NSArray *children = [tempDoc children];
      NSEnumerator *enumerator = [children objectEnumerator];
      NSXMLNode *child;

      self = [self initWithKind: NSXMLDTDKind options: mask];
      
      while ((child = [enumerator nextObject]) != nil)
        {
          [child detach]; // detach from document.
          [self addChild: child];
        }
      [tempDoc release];
    }

  return self;
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLDTDKind == kind)
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

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  NSXMLNodeKind	kind = [child kind];
  NSUInteger childCount = [self childCount];

  // Check to make sure this is a valid addition...
  NSAssert(nil != child, NSInvalidArgumentException);
  NSAssert(index <= childCount, NSInvalidArgumentException);
  NSAssert(nil == [child parent], NSInvalidArgumentException);
  NSAssert(NSXMLAttributeKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDTDKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDocumentKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLElementKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLTextKind != kind, NSInvalidArgumentException);

  [self _insertChild: child atIndex: index];
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

- (NSXMLDTDNode*) notationDeclarationForName: (NSString*)name
{
  xmlDtdPtr node = internal->node;
  xmlNodePtr children = NULL;
  const xmlChar *xmlName = XMLSTRING(name);

  if ((node == NULL) ||
      (node->children == NULL))
    {
      return nil;
    }
     
 for (children = node->children; children; children = children->next)
   {
     if (children->type == XML_NOTATION_NODE)
       {
         if (xmlStrcmp(children->name, xmlName) == 0)
           {
             return (NSXMLDTDNode*)[NSXMLNode _objectForNode: children];
           }
       }
   }

  return nil;
}

- (NSString*) publicID
{
  xmlDtd *node = internal->node;

  return StringFromXMLStringPtr(node->ExternalID); 
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

- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)node
{
  [self insertChild: node atIndex: index];
  [self removeChildAtIndex: index + 1];
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

- (void) setPublicID: (NSString*)publicID
{
  xmlDtd *node = internal->node;

  node->ExternalID = XMLStringCopy(publicID); 
}

- (void) setSystemID: (NSString*)systemID
{
  xmlDtd *node = internal->node;

  node->SystemID = XMLStringCopy(systemID); 
}

- (NSString*) systemID
{
  xmlDtd *node = internal->node;

  return StringFromXMLStringPtr(node->SystemID); 
}

@end

