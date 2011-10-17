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

/*
 * Description of internal ivars:
 * - `children': The primary storage for the descendant nodes. We use an NSArray
 *   here until somebody finds out it's not fast enough.
 * - `childCount': For efficiency, we cache the count. This means we need to
 *   update it whenever the children change.
 * - `previousSibling', `nextSibling': Tree walking is a common operation for
 *   XML. [_parent->internal->children objectAtIndex: index + 1] would be a
 *   straightforward way to obtain the next sibling of the node, but it hurts
 *   performance quite a bit. So we cache the siblings and update them when the
 *   nodes are changed.
 */
#define GS_NSXMLNode_IVARS \
  NSMutableArray *children; \
  NSUInteger childCount; \
  NSXMLNode *previousSibling; \
  NSXMLNode *nextSibling; \
  NSUInteger options;

#define GSInternal              NSXMLNodeInternal
#include        "GSInternal.h"
@class NSXMLNode;
GS_PRIVATE_INTERNAL(NSXMLNode)

#import "NSXMLPrivate.h"

@implementation NSXMLNode

+ (id) attributeWithName: (NSString*)name
	     stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

+ (id) attributeWithName: (NSString*)name
		     URI: (NSString*)URI
	     stringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setURI: URI];
  [n setStringValue: stringValue];
  return n;
}

+ (id) commentWithStringValue: (NSString*)stringValue
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLCommentKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

+ (id) DTDNodeWithXMLString: (NSString*)string
{
  NSXMLNode	*n;

  n = [[[self alloc] initWithKind: NSXMLDTDKind] autorelease];
  [n setStringValue: string];
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
  return [internal->children objectAtIndex: index];
}

- (NSUInteger) childCount
{
  return internal->childCount;
}

- (NSArray*)children
{
  return internal->children;
}

- (id) copyWithZone: (NSZone*)zone
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) dealloc
{
  [self detach];
  [internal->children release];
  GS_DESTROY_INTERNAL(NSXMLNode)
  [_objectValue release];
  [super dealloc];
}

- (void) detach
{
  if (_parent != nil)
    {
      [(NSXMLElement*)_parent removeChildAtIndex: _index];
      _parent = nil;
    }
}

- (NSUInteger) index
{
  return _index;
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

  GS_CREATE_INTERNAL(NSXMLNode)

  /*
   * We find the correct subclass for specific node kinds:
   */
  switch (kind)
  {
    case NSXMLDocumentKind:
    {
      theSubclass = [NSXMLDocument class];
      break;
    }
    case NSXMLElementKind:
    {
      theSubclass = [NSXMLElement class];
      break;
    }
    case NSXMLDTDKind:
    {
      theSubclass = [NSXMLDTD class];
      break;
    }
    case NSXMLEntityDeclarationKind:
    case NSXMLElementDeclarationKind:
    case NSXMLNotationDeclarationKind:
    {
      theSubclass = [NSXMLDTDNode class];
      break;
    }
    default:
    {
      break;
    }
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

  /*
   * If we are initializing for the correct class, we can actually perform
   * initializations:
   */

  _kind = kind;
  internal->options = theOptions;
  internal->children = [NSMutableArray new];
  return self;
}

- (NSXMLNodeKind) kind
{
  return _kind;
}

- (NSUInteger) level
{
  NSUInteger	level = 0;
  NSXMLNode	*tmp = _parent;

  while (tmp != nil)
    {
      level++;
      tmp = tmp->_parent;
    }
  return level;
}

- (NSString*) localName
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSString*) name
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSXMLNode*) _nodeFollowingInNaturalDirection: (BOOL)forward
{
  NSXMLNode *ancestor = _parent;
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
    ancestor = ancestor->_parent;
  }

  /* No children, no next siblings, no next siblings for any ancestor: We are
   * the last node */
  if (nil == candidate)
  {
    return nil;
  }

  /* Sanity check: Namespace and attribute nodes are skipped: */
  if ((NSXMLAttributeKind == candidate->_kind)
    || (NSXMLNamespaceKind == candidate->_kind))
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
  return _objectValue;
}

- (NSXMLNode*) parent
{
  return _parent;
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
  NSXMLNode *ancestor = _parent;
  /*
   * Short-circuit evaluation gurantees that the nil-pointer is not
   * dereferenced:
   */
  while ((ancestor != nil) && (NSXMLDocumentKind != ancestor->_kind))
  {
    ancestor = ancestor->_parent;
  }
  return (NSXMLDocument*)ancestor;
}


- (NSString*) stringValue
{
  // FIXME
  return _objectValue;
}

- (NSString*) URI
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSString*) XMLString
{
  return [self XMLStringWithOptions: 0];
}

- (NSString*) XMLStringWithOptions: (NSUInteger)options
{
  return [self notImplemented: _cmd];	// FIXME ... generate from libxml
}

- (void) setObjectValue: (id)value
{
  ASSIGN(_objectValue, value);
}

- (void) setName: (NSString*)name
{
  [self notImplemented: _cmd];	// FIXME ... set in libxml
}

- (void) setStringValue: (NSString*)string
{
  [self setStringValue: string resolvingEntities: NO];
}

- (void) setURI: (NSString*)URI
{
  [self notImplemented: _cmd];	// FIXME ... set in libxml
}

- (void) setStringValue: (NSString*)string resolvingEntities: (BOOL)resolve
{
  [self notImplemented: _cmd];	// FIXME ... set in libxml
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

