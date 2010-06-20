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
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSUInteger) childCount
{
  [self notImplemented: _cmd];	// FIXME ... fetch from libxml
  return 0;
}

- (NSArray*)children
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (id) copyWithZone: (NSZone*)zone
{
  return [self notImplemented: _cmd];
}

- (void) dealloc
{
  [self detach];
  [_objectValue release];
  [super dealloc];
}

- (void) detach
{
  if (_parent != nil)
    {
      [self notImplemented: _cmd];	// FIXME ... remove from libxml
    }
}

- (NSUInteger) index
{
  return _index;
}

- (id) initWithKind:(NSXMLNodeKind) kind
{
  self = [self initWithKind: kind options: 0];
  return self;
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)options
{
  if ((self = [super init]) != nil)
    {
      [self notImplemented: _cmd];	// FIXME ... use libxml
    }
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

- (NSXMLNode*) nextNode
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSXMLNode*) nextSibling
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
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
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSXMLNode*) previousSibling
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
}

- (NSXMLDocument*) rootDocument
{
  return [self notImplemented: _cmd];	// FIXME ... fetch from libxml
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

