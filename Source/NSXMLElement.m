/* Implementation for NSXMLElement for GNUStep
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

#define GSInternal              NSXMLElementInternal
#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLElement)

extern void clearPrivatePointers(xmlNodePtr aNode);

// Private methods to manage libxml pointers...
@interface NSXMLNode (Private)
- (void *) _node;
- (void) _setNode: (void *)_anode;
+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node;
- (void) _addSubNode:(NSXMLNode *)subNode;
- (void) _removeSubNode:(NSXMLNode *)subNode;
- (id) _initWithNode:(xmlNodePtr)node kind:(NSXMLNodeKind)kind;
@end

@implementation NSXMLElement

- (void) dealloc
{
  /*
  if (GS_EXISTS_INTERNAL && _internal != nil)
    {
      while ([self childCount] > 0)
	{
	  [self removeChildAtIndex: [self childCount] - 1];
	}
    }
  */
  [super dealloc];
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLElement);
}

- (id) init
{
  return [self initWithKind: NSXMLElementKind options: 0];
}

- (id) initWithName: (NSString*)name
{
  return [self initWithName: name URI: nil];
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLElementKind == kind)
    {
      /* Create holder for internal instance variables so that we'll have
       * all our ivars available rather than just those of the superclass.
       */
      NSString *name = @"";
      GS_CREATE_INTERNAL(NSXMLElement)
      internal->node = (void *)xmlNewNode(NULL,(xmlChar *)[name UTF8String]);
      ((xmlNodePtr)internal->node)->_private = self;
      internal->objectValue = @"";
      // return self;
    }
  return [super initWithKind: kind options: theOptions];
}

- (id) initWithName: (NSString*)name URI: (NSString*)URI
{
  /* Create holder for internal instance variables so that we'll have
   * all our ivars available rather than just those of the superclass.
   */
  GS_CREATE_INTERNAL(NSXMLElement)
  if ((self = [super initWithKind: NSXMLElementKind]) != nil)
    {
      internal->node = (void *)xmlNewNode(NULL,(xmlChar *)[name UTF8String]);
      ((xmlNodePtr)internal->node)->_private = self;
      ASSIGNCOPY(internal->URI, URI);
      internal->objectValue = @"";
    }
  return self;
}

- (id) initWithName: (NSString*)name stringValue: (NSString*)string
{
  if ([self initWithName: name URI: nil] != nil)
    {
      [self setObjectValue: string];
    }
  return nil;
}

- (id) initWithXMLString: (NSString*)string error: (NSError**)error
{
  [self notImplemented: _cmd];
  return nil;
}

- (NSArray*) elementsForName: (NSString*)name
{
  [self notImplemented: _cmd];
  return nil;
}

- (NSArray*) elementsForLocalName: (NSString*)localName URI: (NSString*)URI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) addAttribute: (NSXMLNode*)attribute
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  xmlAttrPtr attr = (xmlAttrPtr)[attribute _node];
  xmlAttrPtr oldAttr = xmlHasProp(node, attr->name);
  if (nil != [attribute parent])
  {
	[NSException raise: @"NSInvalidArgumentException"
	            format: @"Tried to add attribute to multiple parents."];
  }

  if (NULL != oldAttr)
  {
	/*
	 * As per Cocoa documentation, we only add the attribute if it's not
	 * already set. xmlHasProp() also looks at the DTD for default attributes
	 * and we need  to make sure that we only bail out here on #FIXED
	 * attributes.
	 */

	// Do not replace plain attributes.
	if (XML_ATTRIBUTE_NODE == oldAttr->type)
	{
	  return;
	}
	else if (XML_ATTRIBUTE_DECL == oldAttr->type)
	{
		// If the attribute is from a DTD, do not replace it if it's #FIXED
		xmlAttributePtr attrDecl = (xmlAttributePtr)oldAttr;
		if (XML_ATTRIBUTE_FIXED == attrDecl->def)
		{
			return;
		}
	}
  }
  xmlAddChild(node, (xmlNodePtr)attr);
  [self _addSubNode:attribute];
}

- (void) removeAttributeForName: (NSString*)name
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  xmlUnsetProp(node,(xmlChar *)[name UTF8String]);
}

- (void) setAttributes: (NSArray*)attributes
{
  NSEnumerator	*enumerator = [attributes objectEnumerator];
  NSXMLNode	*attribute;

  while ((attribute = [enumerator nextObject]) != nil)
    {
      [self addAttribute: attribute];
    }
}

- (void) setAttributesAsDictionary: (NSDictionary*)attributes
{
  [self setAttributesWithDictionary: attributes];
}

- (void) setAttributesWithDictionary: (NSDictionary*)attributes
{
  NSEnumerator	*en = [attributes keyEnumerator];
  NSString	*key;

  // [internal->attributes removeAllObjects];
  while ((key = [en nextObject]) != nil)
    {
      NSString	*val = [[attributes objectForKey: key] stringValue];
      NSXMLNode	*attribute = [NSXMLNode attributeWithName: key
					      stringValue: val];
      [self addAttribute: attribute];
    }
}

- (NSArray*) attributes
{
  NSMutableArray *attributes = [NSMutableArray array];
  xmlNodePtr node = MY_NODE;
  struct _xmlAttr *	attributeNode = node->properties;
  while (attributeNode)
    {
      NSXMLNode *attribute = [NSXMLNode _objectForNode:(xmlNodePtr)attributeNode];
      [attributes addObject:attribute];
      attributeNode = attributeNode->next;
    }
  return attributes;
}

- (NSXMLNode*) attributeForName: (NSString*)name
{
  NSXMLNode *result = nil;
  xmlChar *xmlName = xmlCharStrdup([name UTF8String]);
  xmlAttrPtr attributeNode = xmlHasProp(MY_NODE, xmlName);
  if (NULL != attributeNode)
  {
	result = [NSXMLNode _objectForNode:(xmlNodePtr)attributeNode];
  }
  xmlFree(xmlName);
  xmlName = NULL;
  return result; // [internal->attributes objectForKey: name];
}

- (NSXMLNode*) attributeForLocalName: (NSString*)localName
                                 URI: (NSString*)URI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) addNamespace: (NSXMLNode*)aNamespace
{
  [self notImplemented: _cmd];
}

- (void) removeNamespaceForPrefix: (NSString*)name
{
  [self notImplemented: _cmd];
}

- (void) setNamespaces: (NSArray*)namespaces
{
  NSEnumerator *en = [namespaces objectEnumerator];
  NSString *namespace = nil;
  xmlNsPtr cur = NULL;

  while((namespace = (NSString *)[en nextObject]) != nil)
    {
      xmlNsPtr ns = xmlNewNs([self _node], NULL, XMLSTRING(namespace));
      if(MY_NODE->ns == NULL)
	{
	  MY_NODE->ns = ns;
	  cur = ns;
	}
      else
	{
	  cur->next = ns;
	  cur = ns;
	}
    }
}

- (NSArray*) namespaces
{
  NSMutableArray *result = nil;
  xmlNsPtr ns = MY_NODE->ns;

  if(ns)
    {
      xmlNsPtr cur = NULL;
      result = [NSMutableArray array];
      for(cur = ns; cur != NULL; cur = cur->next)
	{
	  [result addObject: StringFromXMLStringPtr(cur->prefix)];
	}
    }

  // [self notImplemented: _cmd];
  return result; // nil; // internal->namespaces;
}

- (NSXMLNode*) namespaceForPrefix: (NSString*)name
{
  [self notImplemented: _cmd];
  return nil;
}

- (NSXMLNode*) resolveNamespaceForName: (NSString*)name
{
  [self notImplemented: _cmd];
  return nil;
}

- (NSString*) resolvePrefixForNamespaceURI: (NSString*)namespaceURI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  NSXMLNodeKind	kind = [child kind];
  NSXMLNode *cur = nil;
  xmlNodePtr curNode = NULL;
  xmlNodePtr thisNode = (xmlNodePtr)[self _node];
  xmlNodePtr childNode = (xmlNodePtr)[child _node];
  NSUInteger childCount = [self childCount];

  // Check to make sure this is a valid addition...
  NSAssert(nil != child, NSInvalidArgumentException);
  NSAssert(index <= childCount, NSInvalidArgumentException);
  NSAssert(nil == [child parent], NSInvalidArgumentException);
  NSAssert(NSXMLAttributeKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDTDKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDocumentKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLElementDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLEntityDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNotationDeclarationKind != kind, NSInvalidArgumentException);

  // Get all of the nodes...
  childNode = ((xmlNodePtr)[child _node]);
  cur = [self childAtIndex: index];
  curNode = ((xmlNodePtr)[cur _node]);

  if(0 == childCount || index == childCount)
    {
      xmlAddChild(thisNode, childNode);
    }
  else if(index < childCount)
    {
      xmlAddNextSibling(curNode, childNode);
    }

  [self _addSubNode:child];
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
  int count = [self childCount];
  [self insertChild: child atIndex: count];
}

- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)node
{
  [self insertChild: node atIndex: index];
  [self removeChildAtIndex: index + 1];
}

- (void) normalizeAdjacentTextNodesPreservingCDATA: (BOOL)preserve
{
  // FIXME: Implement this method...
}

- (id) copyWithZone: (NSZone *)zone
{
  NSXMLElement *c = [[self class] alloc]; ///(NSXMLElement*)[super copyWithZone: zone];
  xmlNodePtr newNode = (xmlNodePtr)xmlCopyNode(MY_NODE, 1); // copy recursively
  clearPrivatePointers(newNode); // clear out all of the _private pointers in the entire tree
  c = [c _initWithNode:newNode kind:internal->kind];
  return c;
/*
  NSXMLElement	*c = (NSXMLElement*)[super copyWithZone: zone];
  NSEnumerator	*en;
  id obj;

  en = [[self namespaces] objectEnumerator];
  while ((obj = [en nextObject]) != nil)
    {
      NSXMLNode *ns = [obj copyWithZone: zone];

      [c addNamespace: ns];
      [ns release];
    }

  en = [[self attributes] objectEnumerator];
  while ((obj = [en nextObject]) != nil)
    {
      NSXMLNode *attr = [obj copyWithZone: zone];

      [c addAttribute: attr];
      [attr release];
    }

  en = [[self children] objectEnumerator];
  while ((obj = [en nextObject]) != nil)
    {
      NSXMLNode *child = [obj copyWithZone: zone];

      [c addChild: child];
      [child release];
    }

  return c;
*/
}

@end

