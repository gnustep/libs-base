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

#if defined(HAVE_LIBXML)

extern void clearPrivatePointers(xmlNodePtr aNode);

// Private methods to manage libxml pointers...
@interface NSXMLNode (Private)
- (void *) _node;
- (void) _setNode: (void *)_anode;
+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node;
- (void) _addSubNode:(NSXMLNode *)subNode;
- (void) _removeSubNode:(NSXMLNode *)subNode;
- (id) _initWithNode:(xmlNodePtr)node kind:(NSXMLNodeKind)kind;
- (void) _insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index;
- (void) _updateExternalRetains;
- (void) _invalidate;
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

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLElementKind == kind)
    {
      if ((self = [super initWithKind:kind options:theOptions]))
	{
	  internal->objectValue = @"";
	}
      return self;
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
  if ((self = [super initWithKind: NSXMLElementKind]) != nil)
    {
      [self setName:name];
      ASSIGNCOPY(internal->URI, URI);
      internal->objectValue = @"";
    }
  return self;
}

- (id) initWithName: (NSString*)name stringValue: (NSString*)string
{
  if ([self initWithName: name URI: nil] != nil)
    {
      NSXMLNode *t;
      t = [[NSXMLNode alloc] initWithKind: NSXMLTextKind];
      [t setStringValue: string];
      [self addChild: t];
      [t release];
    }
  return nil;
}

- (id) initWithXMLString: (NSString*)string 
		   error: (NSError**)error
{
  NSXMLElement *result = nil;
  if((self = [super init]) != nil)
    {
      NSXMLDocument *tempDoc = 
	[[NSXMLDocument alloc] initWithXMLString:string
					 options:0
					   error:error];
      if(tempDoc != nil)
	{
	  result = RETAIN([tempDoc rootElement]);
	  [result detach]; // detach from document.
	}
      [tempDoc release];
    }
  return result;
}

- (NSArray*) elementsForName: (NSString*)name
{
  NSMutableArray *results = [NSMutableArray arrayWithCapacity: 10];
  xmlNodePtr cur = NULL;

  for (cur = MY_NODE->children; cur != NULL; cur = cur->next)
    {
      NSString *n = StringFromXMLStringPtr(cur->name);
      if([n isEqualToString: name])
	{
	  NSXMLNode *node = (NSXMLNode *)(cur->_private);
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
  xmlAttrPtr attr = xmlHasProp(node, (xmlChar *)[name UTF8String]);
  xmlAttrPtr newAttr = NULL;
  NSXMLNode *attrNode = nil;
  if (NULL == attr)
  {
	  return;
  }

  // We need a copy of the node because xmlRemoveProp() frees attr:
  newAttr = xmlCopyProp(NULL, attr);
  attrNode = [NSXMLNode _objectForNode: (xmlNodePtr)attr];

  // This is supposed to return failure for DTD defined attributes
  if (0 == xmlRemoveProp(attr))
  {
	  [attrNode _setNode: newAttr];
	  [self _removeSubNode: attrNode];
  }
  else
  {
	  // In this case we throw away our copy again.
	  xmlFreeProp(newAttr);
  }
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
  free(xmlName); // Free the name string since it's no longer needed.
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
  [self _removeSubNode:child];
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

static void joinTextNodes(xmlNodePtr nodeA, xmlNodePtr nodeB, NSMutableArray *nodesToDelete)
{
  NSXMLNode *objA = (nodeA->_private), *objB = (nodeB->_private);

  xmlTextMerge(nodeA, nodeB); // merge nodeB into nodeA

  if (objA != nil) // objA gets the merged node
    {
      if (objB != nil) // objB is now invalid
	{
	  [objB _invalidate]; // set it to be invalid and make sure it's not pointing to a freed node
	  [nodesToDelete addObject:objB];
	}
    }
  else if (objB != nil) // there is no objA -- objB gets the merged node
    {
      [objB _setNode:nodeA]; // nodeA is the remaining (merged) node
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
	[(NSXMLElement *)subNode normalizeAdjacentTextNodesPreservingCDATA:preserve];
      else if (node->type == XML_TEXT_NODE || (node->type == XML_CDATA_SECTION_NODE && !preserve))
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
	      //combine node->prev & node
		// join the text of both nodes
		// assign the joined text to the earlier of the two nodes that has an ObjC object
		// unlink the other node
		// delete the other node's object (maybe add it to a list of nodes to delete when we're done? -- or just set its node to null, and then remove it from our subNodes when we're done iterating it) (or maybe we need to turn it into an NSInvalidNode too??)
	      joinTextNodes(node->prev, node, nodesToDelete);
	    }

	}
    }
  if ([nodesToDelete count] > 0)
    {
      subEnum = [nodesToDelete objectEnumerator];
      while ((subNode = [subEnum nextObject]))
	{
	  [self _removeSubNode:subNode];
	}
      [self _updateExternalRetains];
    }
}

- (id) copyWithZone: (NSZone *)zone
{
  NSXMLElement *c = [[self class] alloc]; ///(NSXMLElement*)[super copyWithZone: zone];
  xmlNodePtr newNode = (xmlNodePtr)xmlCopyNode(MY_NODE, 1); // copy recursively
  clearPrivatePointers(newNode); // clear out all of the _private pointers in the entire tree
  c = [c _initWithNode:newNode kind:internal->kind];
  return c;
}

@end

#endif
