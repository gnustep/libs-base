/* Implementation for NSXMLNode for GNUStep
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

#define GSInternal              NSXMLNodeInternal
#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLNode)

// Private methods to manage libxml pointers...
@interface NSXMLNode (Private)
- (void *) _node;
- (void) _setNode: (void *)_anode;
+ (id) _newFromNode: (xmlNodePtr)node;
@end

@implementation NSXMLNode (Private)
- (void *) _node
{
  return internal->node;
}

- (void) _setNode: (void *)_anode
{
  ((xmlNodePtr)_anode)->_private = self;
  internal->node = _anode;
}

+ (id) _newFromNode: (xmlNodePtr)node
{
  xmlElementType type = node->type;
  NSXMLNode *result = (id)node->_private;
  xmlChar *name = NULL;
  // NSXMLNodeKind kind = 0;

  if(result == NULL)
    {
      switch(type)
	{
	case(XML_ELEMENT_NODE):
	  name = (xmlChar *)node->name;
	  result = [[self alloc] initWithKind: NSXMLElementKind];
	  break;
	case(XML_ATTRIBUTE_NODE):
	  name = (xmlChar *)node->name;
	  result = [[self alloc] initWithKind: NSXMLAttributeKind];
	  [result setStringValue: StringFromXMLStringPtr(node->content)];
	  break;
	default:
	  break;
	}
    }

  return result;
}
@end

@implementation NSXMLNode

+ (id) attributeWithName: (NSString*)name
	     stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;
  xmlAttrPtr     node;

  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setStringValue: stringValue];
  [n setName: name];
  node = xmlNewProp(NULL,
		    XMLSTRING(name),
		    XMLSTRING(stringValue));
  [n _setNode: node];
  
  return n;
}

+ (id) attributeWithName: (NSString*)name
		     URI: (NSString*)URI
	     stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;
  xmlAttrPtr     node = xmlNewProp(NULL,
				   XMLSTRING(name),
				   XMLSTRING(stringValue));
  
  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setURI: URI];
  [n setStringValue: stringValue];
  [n setName: name];
  [n _setNode: node];
  
  return n;
}

+ (id) commentWithStringValue: (NSString*)stringValue
{
  NSXMLNode	*n;
  xmlNodePtr     node = xmlNewComment(XMLSTRING(stringValue));

  n = [[[self alloc] initWithKind: NSXMLCommentKind] autorelease];
  [n setStringValue: stringValue];
  [n _setNode: node];

  return n;
}

+ (id) DTDNodeWithXMLString: (NSString*)string
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLDTDKind] autorelease];
  [n setStringValue: string];

  // internal->node = xmlNewDtd(NULL,NULL,NULL); // TODO: Parse the string and get the info to create this...

  return n;
}

+ (id) document
{
  NSXMLNode	*n;

  n = [[[NSXMLDocument alloc] initWithKind:NSXMLDocumentKind] autorelease];
  return n;
}

+ (id) documentWithRootElement: (NSXMLElement*)element
{
  NSXMLDocument	*d;

  d = [NSXMLDocument alloc];
  d = [[d initWithRootElement: element] autorelease];
  return d;
}

+ (id) elementWithName: (NSString*)name
{
  NSXMLNode	*n;

  n = [[[NSXMLElement alloc] initWithName: name] autorelease];
  return n;
}

+ (id) elementWithName: (NSString*)name
	      children: (NSArray*)children
	    attributes: (NSArray*)attributes
{
  NSXMLElement *e = [self elementWithName: name];

  [e insertChildren: children atIndex: 0];
  [e setAttributes: attributes];
  return e;
}

+ (id) elementWithName: (NSString*)name
		   URI: (NSString*)URI
{
  NSXMLNode	*n;

  n = [[[NSXMLElement alloc] initWithName: name URI: URI] autorelease];
  return n;
}

+ (id) elementWithName: (NSString*)name
	   stringValue: (NSString*)string
{
  NSXMLElement	*e;
  NSXMLNode	*t;

  e = [self elementWithName: name];
  t = [[self alloc] initWithKind: NSXMLTextKind];
  [t setStringValue: string];
  [e addChild: t];
  [t release];
  return e;
}

+ (NSString*) localNameForName: (NSString*)name
{
  return [self notImplemented: _cmd];
}

+ (id) namespaceWithName: (NSString*)name
	     stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLNamespaceKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

+ (NSXMLNode*) predefinedNamespaceForPrefix: (NSString*)name
{
  return [self notImplemented: _cmd];
}

+ (NSString*) prefixForName: (NSString*)name
{
  return [self notImplemented: _cmd];
}

+ (id) processingInstructionWithName: (NSString*)name
			 stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLProcessingInstructionKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

+ (id) textWithStringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLTextKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

- (NSString*) canonicalXMLStringPreservingComments: (BOOL)comments
{
  return [self notImplemented: _cmd];	// FIXME ... generate from libxml
}

- (NSXMLNode*) childAtIndex: (NSUInteger)index
{
  NSUInteger count = 0;
  xmlNodePtr children = NULL;
  xmlNodePtr node = (xmlNodePtr)(internal->node);

  for (children = node->children; children && count != index; children = children->next)
    {
      count++;
    }

  return (NSXMLNode *)[NSXMLNode _newFromNode: children];
}

- (NSUInteger) childCount
{
  NSUInteger childCount = 0;
  xmlNodePtr children = NULL;
  xmlNodePtr node = (xmlNodePtr)(internal->node);

  for (children = node->children; children; children = children->next)
    {
      childCount++;
    }

  return childCount;
}

- (NSArray*) children
{
  NSMutableArray *childrenArray = [NSMutableArray array];
  xmlNodePtr children = NULL;
  xmlNodePtr node = (xmlNodePtr)(internal->node);

  for (children = node->children; children; children = children->next)
    {
      NSXMLNode *n = [NSXMLNode _newFromNode: children];
      [childrenArray addObject: n];
    }

  return childrenArray;
}

- (id) copyWithZone: (NSZone*)zone
{
  id c = [[self class] allocWithZone: zone];
  xmlNodePtr newNode = xmlCopyNode([self _node], 1); // make a deep copy

  c = [c initWithKind: internal->kind options: internal->options];
  [c _setNode:newNode];

//  [c setName: [self name]];
//  [c setURI: [self URI]];
//  [c setObjectValue: [self objectValue]];
//  [c setStringValue: [self stringValue]];

  return c;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      [self detach];
      [internal->name release];
      [internal->URI release];
      [internal->children release];
      [internal->objectValue release];
      [internal->stringValue release];
      GS_DESTROY_INTERNAL(NSXMLNode);
    }
  [super dealloc];
}

- (void) detach
{
  if (internal->parent != nil)
    {
      [(NSXMLElement*)internal->parent removeChildAtIndex: internal->index];
      internal->parent = nil;
    }
}

- (NSUInteger) hash
{
  return [internal->name hash];
}

- (NSUInteger) index
{
  return internal->index;
}

- (id) init
{
  return [self initWithKind: NSXMLInvalidKind];
}

- (id) initWithKind:(NSXMLNodeKind) kind
{
  self = [self initWithKind: kind options: 0];
  return self;
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  Class theSubclass = [NSXMLNode class];

  if (nil == (self = [super init]))
    {
      return nil;
    }

  /*
   * We find the correct subclass for specific node kinds:
   */
  switch (kind)
    {
      case NSXMLDocumentKind:
	theSubclass = [NSXMLDocument class];
	break;

      case NSXMLElementKind:
	theSubclass = [NSXMLElement class];
	break;

      case NSXMLDTDKind:
	theSubclass = [NSXMLDTD class];
	break;

      case NSXMLEntityDeclarationKind:
      case NSXMLElementDeclarationKind:
      case NSXMLNotationDeclarationKind:
	theSubclass = [NSXMLDTDNode class];
	break;

      default:
	break;
    }

  /*
   * Check whether we are already initializing an instance of the given
   * subclass. If we are not, release ourselves and allocate a subclass instance
   * instead.
   */
  if (NO == [self isKindOfClass: theSubclass])
    {
      [self release];
      return [[theSubclass alloc] initWithKind: kind
				       options: theOptions];
    }

  /* Create holder for internal instance variables if needed.
   */
  GS_CREATE_INTERNAL(NSXMLNode)

  /* If we are initializing for the correct class, we can actually perform
   * initializations:
   */
  internal->kind = kind;
  internal->options = theOptions;
  internal->stringValue = @"";
  return self;
}

- (BOOL) isEqual: (id)other
{
  NSString	*s;
  NSArray	*c;

  if (other == (id)self)
    {
      return YES;
    }

  if (NO == [other isKindOfClass: [self class]])
    {
      return NO;
    }

  if ([(NSXMLNode*)other kind] != internal->kind)
    {
      return NO;
    }

  s = [other name];
  if (s != internal->name && NO == [s isEqual: internal->name])
    {
      return NO;
    }

  s = [other URI];
  if (s != internal->URI && NO == [s isEqual: internal->URI])
    {
      return NO;
    }

  c = [other children];
  if (c != internal->children && NO == [c isEqual: internal->children])
    {
      return NO;
    }

  return YES;
}

- (NSXMLNodeKind) kind
{
  return internal->kind;
}

- (NSUInteger) level
{
  NSUInteger	level = 0;
  NSXMLNode	*tmp = internal->parent;

  while (tmp != nil)
    {
      level++;
      tmp = GSIVar(tmp, parent);
    }
  return level;
}

- (NSString*) localName
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSString*) name
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  if (node->name)
    return StringFromXMLString(node->name,strlen((char *)node->name));
  else
    return @"";
  //return internal->name; 
}

- (NSXMLNode*) _nodeFollowingInNaturalDirection: (BOOL)forward
{
  NSXMLNode *ancestor = internal->parent;
  NSXMLNode *candidate = nil;

  /* Node walking is a depth-first thingy. Hence, we consider children first: */
  if (0 != internal->childCount)
    {
      NSUInteger theIndex = 0;
      if (NO == forward)
	{
	  theIndex = (internal->childCount) - 1;
	}
      candidate = [internal->children objectAtIndex: theIndex];
    }

  /* If there are no children, we move on to siblings: */
  if (nil == candidate)
    {
      if (forward)
	{
	  candidate = internal->nextSibling;
	}
      else
	{
	  candidate = internal->previousSibling;
	}
    }

  /* If there are no siblings left for the receiver, we recurse down to the root
   * of the tree until we find an ancestor with further siblings: */
  while ((nil == candidate) && (nil != ancestor))
    {
      if (forward)
	{
	  candidate = [ancestor nextSibling];
	}
      else
	{
	  candidate = [ancestor previousSibling];
	}
      ancestor = GSIVar(ancestor, parent);
    }

  /* No children, no next siblings, no next siblings for any ancestor: We are
   * the last node */
  if (nil == candidate)
    {
      return nil;
    }

  /* Sanity check: Namespace and attribute nodes are skipped: */
  if ((NSXMLAttributeKind == GSIVar(candidate, kind))
    || (NSXMLNamespaceKind == GSIVar(candidate, kind)))
    {
      return [candidate _nodeFollowingInNaturalDirection: forward];
    }
  return candidate;
}

- (NSXMLNode*) nextNode
{
  return [self _nodeFollowingInNaturalDirection: YES];
}

- (NSXMLNode*) nextSibling
{
  return internal->nextSibling;
}

- (id) objectValue
{
  return internal->objectValue;
}

- (NSXMLNode*) parent
{
  return internal->parent;
}

- (NSString*) prefix
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSXMLNode*) previousNode
{
  return [self _nodeFollowingInNaturalDirection: NO];
}

- (NSXMLNode*) previousSibling
{
  return internal->previousSibling;

}

- (NSXMLDocument*) rootDocument
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  NSXMLDocument *ancestor = (NSXMLDocument *)(node->doc->_private);
  return (NSXMLDocument*)ancestor;
}

- (NSString*) stringValue
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  if (node->content)
    return StringFromXMLString(node->content,strlen((char *)node->content));
  else
    return @"";
}

- (NSString*) URI
{
  return internal->URI;	// FIXME ... fetch from libxml
}

- (NSString*) XMLString
{
  return [self XMLStringWithOptions: 0];
}

- (NSString*) XMLStringWithOptions: (NSUInteger)options
{
  NSString     *string = nil;
  xmlNodePtr   node = (xmlNodePtr)[self _node];
  xmlChar      *buf = NULL;
  xmlDocPtr    doc = node->doc;
  xmlBufferPtr buffer = xmlBufferCreate(); //NULL;
  int error = 0;
  int len = 0;

  error = xmlNodeDump(buffer, doc, node, 1, 1);
  buf = buffer->content;
  len = buffer->size;
  string = StringFromXMLString(buf,len);
  xmlBufferFree(buffer);
  AUTORELEASE(string);

  return string;
}

- (void) setObjectValue: (id)value
{
  ASSIGN(internal->objectValue, value);
}

- (void) setName: (NSString *)name
{
  if (NSXMLInvalidKind != internal->kind)
    {
      xmlNodePtr node = (xmlNodePtr)(internal->node);
      node->name = XMLStringCopy(name);
      //ASSIGNCOPY(internal->name, name);
    }
}

- (void) setStringValue: (NSString*)string
{
  [self setStringValue: string resolvingEntities: NO];
}

- (void) setURI: (NSString*)URI
{
  if (NSXMLInvalidKind != internal->kind)
    {
      ASSIGNCOPY(internal->URI, URI);
    }
}

- (void) setStringValue: (NSString*)string resolvingEntities: (BOOL)resolve
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  if (resolve == NO)
    {
      node->content = (xmlChar *)[string UTF8String];
    }
  else
    {
      // need to actually resolve entities...
      node->content = (xmlChar *)[string UTF8String];
    }
  if (nil == internal->stringValue)
    {
      node->content = (xmlChar *)[@"" UTF8String];	// string value may not be nil
    }
}

- (NSString*) XPath
{
  return [self notImplemented: _cmd];
}

 - (NSArray*) nodesForXPath: (NSString*)xpath error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

 - (NSArray*) objectsForXQuery: (NSString*)xquery
		     constants: (NSDictionary*)constants
		         error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

- (NSArray*) objectsForXQuery: (NSString*)xquery error: (NSError**)error
{
  return [self notImplemented: _cmd];
}
@end

