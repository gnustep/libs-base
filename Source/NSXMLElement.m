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

#define GSInternal	NSXMLElementInternal
#define	GS_XMLNODETYPE	xmlNode

#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLElement)

#if defined(HAVE_LIBXML)

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

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLElementKind == kind)
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

- (id) initWithName: (NSString*)name
{
  return [self initWithName: name URI: nil];
}

- (id) initWithName: (NSString*)name URI: (NSString*)URI
{
  if ((self = [self initWithKind: NSXMLElementKind]) != nil)
    {
      [self setName: name];
      [self setURI: URI];
    }
  return self;
}

- (id) initWithName: (NSString*)name stringValue: (NSString*)string
{
  if ((self = [self initWithName: name URI: nil]) != nil)
    {
      NSXMLNode *t;

      t = [[NSXMLNode alloc] initWithKind: NSXMLTextKind];
      [t setStringValue: string];
      [self addChild: t];
      [t release];
    }
  return self;
}

- (id) initWithXMLString: (NSString*)string 
		   error: (NSError**)error
{
  NSXMLElement *result = nil;
  NSXMLDocument *tempDoc = 
    [[NSXMLDocument alloc] initWithXMLString: string
                                     options: 0
                                       error: error];
  if (tempDoc != nil)
    {
      result = RETAIN([tempDoc rootElement]);
      [result detach]; // detach from document.
    }
  [tempDoc release];
  [self release];

  return result;
}

- (id) objectValue
{
  if (internal->objectValue == nil)
    {
      return @"";
    }
  return internal->objectValue;
}

- (NSArray*) elementsForName: (NSString*)name
{
  NSMutableArray *results = [NSMutableArray arrayWithCapacity: 10];
  xmlNodePtr cur = NULL;

  for (cur = internal->node->children; cur != NULL; cur = cur->next)
    {
      NSString *n = StringFromXMLStringPtr(cur->name);
      if ([n isEqualToString: name])
	{
	  NSXMLNode *node = [NSXMLNode _objectForNode: cur];
	  [results addObject: node];
	}
    }
  
  return results;
}

- (NSArray*) elementsForLocalName: (NSString*)localName URI: (NSString*)URI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) addAttribute: (NSXMLNode*)attribute
{
  xmlNodePtr node = internal->node;
  xmlAttrPtr attr = (xmlAttrPtr)[attribute _node];
  xmlAttrPtr oldAttr = xmlHasProp(node, attr->name);

  if (nil != [attribute parent])
    {
      [NSException raise: NSInternalInconsistencyException
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
  [self _addSubNode: attribute];
}

- (void) removeAttributeForName: (NSString*)name
{
  NSXMLNode *attrNode = [self attributeForName: name];

  [attrNode detach];
}

- (void) setAttributes: (NSArray*)attributes
{
  NSEnumerator	*enumerator = [attributes objectEnumerator];
  NSXMLNode	*attribute;

  // FIXME: Remove all previous attributes
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

  // FIXME: Remove all previous attributes
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
  xmlNodePtr node = internal->node;
  xmlAttrPtr attributeNode = node->properties;

  while (attributeNode)
    {
      NSXMLNode *attribute;

      attribute = [NSXMLNode _objectForNode: (xmlNodePtr)attributeNode];
      [attributes addObject: attribute];
      attributeNode = attributeNode->next;
    }
  return attributes;
}

- (NSXMLNode*) attributeForName: (NSString*)name
{
  NSXMLNode *result = nil;
  xmlNodePtr node = internal->node;
  xmlAttrPtr attributeNode = xmlHasProp(node, XMLSTRING(name));

  if (NULL != attributeNode)
    {
      result = [NSXMLNode _objectForNode: (xmlNodePtr)attributeNode];
    }

  return result;
}

- (NSXMLNode*) attributeForLocalName: (NSString*)localName
                                 URI: (NSString*)URI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) addNamespace: (NSXMLNode*)aNamespace
{
  xmlNsPtr ns = (xmlNsPtr)[aNamespace _node];

  if (internal->node->nsDef == NULL)
    {
      internal->node->nsDef = ns;
    }
  else
    {
      xmlNsPtr cur = internal->node->nsDef;
      const xmlChar *prefix = ns->prefix;
      
      while (xmlStrcmp(prefix, cur->prefix) != 0)
        {
          if (cur->next == NULL)
            {
              cur->next = ns;
              return;
            }
	  cur = cur->next;
	}
    }
  [self _addSubNode: aNamespace];
}

- (void) removeNamespaceForPrefix: (NSString*)name
{
  if (internal->node->nsDef != NULL)
    {
      xmlNsPtr cur = internal->node->nsDef;
      xmlNsPtr last = NULL;
      const xmlChar *prefix = XMLSTRING(name);
      
      while (cur != NULL)
        {
          if (xmlStrcmp(prefix, cur->prefix) == 0)
            {
              if (last == NULL)
                {
                  internal->node->nsDef = cur->next;
                }
              else
                {
                  last->next = cur->next;
                }
              cur->next = NULL;
              if (cur->_private != NULL)
                {
                  [self _removeSubNode: (NSXMLNode *)cur->_private];
                }
              else
                {
                  xmlFreeNs(cur);
                }
              return;
            }
          last = cur;
	  cur = cur->next;
	}
    }
}

- (void) setNamespaces: (NSArray*)namespaces
{
  NSEnumerator *en = [namespaces objectEnumerator];
  NSXMLNode *namespace = nil;

  // FIXME: Remove old namespaces
  // xmlFreeNsList(internal->node->nsDef);
  // internal->node->nsDef = NULL;
  while ((namespace = (NSXMLNode *)[en nextObject]) != nil)
    {
      [self addNamespace: namespace];
    }
}

- (NSArray*) namespaces
{
  // FIXME: Should use  xmlGetNsList()
  NSMutableArray *result = nil;
  xmlNsPtr ns = internal->node->nsDef;

  if (ns)
    {
      xmlNsPtr cur = NULL;
      result = [NSMutableArray array];
      for (cur = ns; cur != NULL; cur = cur->next)
	{
	  [result addObject: [NSXMLNode _objectForNode: (xmlNodePtr)cur]];
	}
    }

  return result;
}

- (NSXMLNode*) namespaceForPrefix: (NSString*)name
{
  // FIXME: Should use xmlSearchNs()
  xmlNsPtr ns = internal->node->nsDef;

  if (ns)
    {
      const xmlChar *prefix = XMLSTRING(name);
      xmlNsPtr cur = NULL;
      for (cur = ns; cur != NULL; cur = cur->next)
	{
          if (xmlStrcmp(prefix, cur->prefix) == 0)
            {
              return [NSXMLNode _objectForNode: (xmlNodePtr)cur];
            }
	}
    }

  return nil;
}

- (NSXMLNode*) resolveNamespaceForName: (NSString*)name
{
  NSString *prefix = [[self class] prefixForName: name];

  if (nil != prefix)
    {
      return [self namespaceForPrefix: prefix];
    }

  return nil;
}

- (NSString*) resolvePrefixForNamespaceURI: (NSString*)namespaceURI
{
  // FIXME Should use xmlSearchNsByHref()
  xmlNsPtr ns = internal->node->nsDef;

  if (ns)
    {
      const xmlChar *uri = XMLSTRING(namespaceURI);
      xmlNsPtr cur;

      for (cur = ns; cur != NULL; cur = cur->next)
	{
          if (xmlStrcmp(uri, cur->href) == 0)
            {
              return StringFromXMLStringPtr(cur->prefix);
            }
	}
    }

  return nil;
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
  NSAssert(NSXMLElementDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLEntityDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNotationDeclarationKind != kind, NSInvalidArgumentException);

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

static void
joinTextNodes(xmlNodePtr nodeA, xmlNodePtr nodeB, NSMutableArray *nodesToDelete)
{
  NSXMLNode *objA = (nodeA->_private);
  NSXMLNode *objB = (nodeB->_private);

  xmlTextMerge(nodeA, nodeB); // merge nodeB into nodeA

  if (objA != nil) // objA gets the merged node
    {
      if (objB != nil) // objB is now invalid
	{
	  /* set it to be invalid and make sure it's not
	   * pointing to a freed node
	   */
	  [objB _invalidate];
	  [nodesToDelete addObject: objB];
	}
    }
  else if (objB != nil) // there is no objA -- objB gets the merged node
    {
      [objB _setNode: nodeA]; // nodeA is the remaining (merged) node
    }
}

- (void) normalizeAdjacentTextNodesPreservingCDATA: (BOOL)preserve
{
  NSEnumerator *subEnum = [internal->subNodes objectEnumerator];
  NSXMLNode *subNode = nil;
  NSMutableArray *nodesToDelete = [NSMutableArray array];

  while ((subNode = [subEnum nextObject]))
    {
      xmlNodePtr node = [subNode _node];
      xmlNodePtr prev = node->prev;
      xmlNodePtr next = node->next;

      if (node->type == XML_ELEMENT_NODE)
	{
	  [(NSXMLElement *)subNode
	    normalizeAdjacentTextNodesPreservingCDATA:preserve];
	}
      else if (node->type == XML_TEXT_NODE
	|| (node->type == XML_CDATA_SECTION_NODE && !preserve))
	{
	  if (next && (next->type == XML_TEXT_NODE
	    || (next->type == XML_CDATA_SECTION_NODE && !preserve)))
	    {
	      //combine node & node->next
	      joinTextNodes(node, node->next, nodesToDelete);
	    }
	  if (prev && (prev->type == XML_TEXT_NODE
	    || (prev->type == XML_CDATA_SECTION_NODE && !preserve)))
	    {
	      /* combine node->prev & node
	       * join the text of both nodes
	       * assign the joined text to the earlier of the two
	       * nodes that has an ObjC object
	       * unlink the other node
	       * delete the other node's object (maybe add it to a
	       * list of nodes to delete when we're done? --
	       * or just set its node to null, and then remove it
	       * from our subNodes when we're done iterating it)
	       * (or maybe we need to turn it into an NSInvalidNode too??)
	       */
	      joinTextNodes(node->prev, node, nodesToDelete);
	    }

	}
    }
  if ([nodesToDelete count] > 0)
    {
      subEnum = [nodesToDelete objectEnumerator];
      while ((subNode = [subEnum nextObject]))
	{
	  [self _removeSubNode: subNode];
	}
    }
}

@end

#endif
