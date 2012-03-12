/* Implementation for NSXMLNamespace for GNUStep
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

#define GSInternal	NSXMLNamespaceInternal
#define	GS_XMLNODETYPE	xmlNs

#import "NSXMLPrivate.h"

@interface NSXMLNamespace : NSXMLNode
{
@public GS_NSXMLNamespace_IVARS
  /* The pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available is inherited from
   * NSXMLNode.  See Source/GSInternal.h for details.
   */
}
@end

#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLNamespace)

#if defined(HAVE_LIBXML)



static void
clearPrivatePointers(xmlNodePtr aNode)
{
  if (!aNode)
    return;
  aNode->_private = NULL;
  clearPrivatePointers(aNode->children);
  clearPrivatePointers(aNode->next);
  if (aNode->type == XML_ELEMENT_NODE)
    clearPrivatePointers((xmlNodePtr)(aNode->properties));
  // FIXME: Handle more node types
}

@implementation NSXMLNamespace

- (NSString*) canonicalXMLStringPreservingComments: (BOOL)comments
{
  return [self notImplemented: _cmd];	// FIXME ... generate from libxml
}

- (NSXMLNode*) childAtIndex: (NSUInteger)index
{
  return nil;
}

- (NSUInteger) childCount
{
  return 0;
}

- (NSArray*) children
{
  return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSXMLNamespace *c = [[self class] allocWithZone: zone];

// FIXME

  GSIVar(c, options) = internal->options;
  if (nil != internal->objectValue)
    {
      /*
        Only copy the objectValue when externally set.
        The problem here are nodes created by parsing XML.
        There the stringValue may be set, but the objectValue isn't.
        This should rather be solved by creating a suitable objectValue,
        when the node gets instantiated.
      */
      [c setObjectValue: internal->objectValue];
    }
  [c setURI: [self URI]];
//  [c setName: [self name]];
//  [c setStringValue: [self stringValue]];

  return c;
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"<%@ %@ %d>%@\n",
    NSStringFromClass([self class]),
    [self name], [self kind], [self XMLString]];
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      xmlNs	*old = internal->node;
// FIXME
      if (old)
	{
	  old->_private = NULL;
	  xmlFreeNs(old);
	}
      GS_DESTROY_INTERNAL(NSXMLNode);
    }
  [super dealloc];
}

- (void) detach
{
  xmlNsPtr ns = internal->node;

  if (ns)
    {
// FIXME
    }
}

- (NSUInteger) hash
{
  return [[self name] hash];
}

- (NSUInteger) index
{
  return 0;
}

- (id) init
{
  return [self initWithKind: NSXMLNamespaceKind];
}

- (NSUInteger) level
{
  return 0;
}

- (NSString*) localName
{
  return [[self class] localNameForName: [self name]];
}

- (NSString*) name
{
  return nil;
}

- (NSXMLNode*) nextNode
{
  return nil;
}

- (NSXMLNode*) nextSibling
{
  return nil;
}

- (id) objectValue
{
  return nil;
}

- (NSXMLNode*) parent
{
  return nil;
}

- (NSString*) prefix
{
  return StringFromXMLStringPtr(internal->node->prefix);
}

- (NSXMLNode*) previousNode
{
  return nil;
}

- (NSXMLNode*) previousSibling
{
  return nil;
}

- (NSXMLDocument*) rootDocument
{
  return nil;
}

- (NSString*) stringValue
{
  return StringFromXMLStringPtr(internal->node->href);
}

- (void) setObjectValue: (id)value
{
  return;
}

- (void) setName: (NSString *)name
{
  return;
}

- (void) setStringValue: (NSString*)string
{
  [self setStringValue: string resolvingEntities: NO];
}

- (void) setStringValue: (NSString*)string resolvingEntities: (BOOL)resolve
{
  return;
}

- (void) setURI: (NSString*)URI
{
  //xmlNodeSetBase(internal->node, XMLSTRING(URI));
}

- (NSString*) URI
{
  return StringFromXMLStringPtr(internal->node->href);
}

- (NSString*) XMLString
{
  return [self XMLStringWithOptions: NSXMLNodeOptionsNone];
}

- (NSString*) XMLStringWithOptions: (NSUInteger)options
{
  return nil;
}

- (NSString*) XPath
{
  return nil;
}

- (NSArray*) nodesForXPath: (NSString*)anxpath error: (NSError**)error
{
  return nil;
}

 - (NSArray*) objectsForXQuery: (NSString*)xquery
		     constants: (NSDictionary*)constants
		         error: (NSError**)error
{
  return nil;
}

- (NSArray*) objectsForXQuery: (NSString*)xquery error: (NSError**)error
{
  return nil;
}
@end

#endif
