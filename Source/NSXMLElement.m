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

@implementation NSXMLElement

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL && _internal != nil)
    {
      [internal->attributes release];
      [internal->namespaces release];
    }
  [super dealloc];
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
      GS_CREATE_INTERNAL(NSXMLElement)
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
      ASSIGNCOPY(internal->name, name);
      ASSIGNCOPY(internal->URI, URI);
      internal->attributes = [[NSMutableDictionary alloc] initWithCapacity: 10];
      internal->namespaces = [[NSMutableArray alloc] initWithCapacity: 10];
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
  [internal->attributes setObject: attribute
			   forKey: [attribute name]];
}

- (void) removeAttributeForName: (NSString*)name
{
  [internal->attributes removeObjectForKey: name];
}

- (void) setAttributes: (NSArray*)attributes
{
  NSEnumerator	*enumerator = [attributes objectEnumerator];
  NSXMLNode	*attribute;

  [internal->attributes removeAllObjects];
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
 	 
  [internal->attributes removeAllObjects];
  while ((key = [en nextObject]) != nil)	 
    {	 
      NSString	*val = [attributes objectForKey: key];	 
      NSXMLNode	*attribute = [NSXMLNode attributeWithName: key	 
					      stringValue: val];
      [self addAttribute: attribute];	 
    }
}

- (NSArray*) attributes
{
  return [internal->attributes allValues];
}

- (NSXMLNode*) attributeForName: (NSString*)name
{
  return [internal->attributes objectForKey: name];
}

- (NSXMLNode*) attributeForLocalName: (NSString*)localName
                                 URI: (NSString*)URI
{
  [self notImplemented: _cmd];
  return nil;
}

- (void) addNamespace: (NSXMLNode*)aNamespace
{
  [internal->namespaces addObject: aNamespace]; 
}

- (void) removeNamespaceForPrefix: (NSString*)name
{
  [self notImplemented: _cmd];
}

- (void) setNamespaces: (NSArray*)namespaces
{
  ASSIGNCOPY(internal->namespaces, namespaces);
}

- (void) setObjectValue: (id)value
{
  if (nil == value)
    {
      value = @"";	// May not be nil
    }
  ASSIGN(internal->objectValue, value);
}

- (NSArray*) namespaces
{
  return internal->namespaces;
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
  NSXMLNodeKind	kind;

  NSAssert(nil != child, NSInvalidArgumentException);
  NSAssert(index <= internal->childCount, NSInvalidArgumentException);
  NSAssert(nil == [child parent], NSInvalidArgumentException);
  kind = [child kind];
// FIXME ... should we check for valid kinds rather than invalid ones?
  NSAssert(NSXMLAttributeKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDTDKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLDocumentKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLElementDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLEntityDeclarationKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != kind, NSInvalidArgumentException);
  NSAssert(NSXMLNotationDeclarationKind != kind, NSInvalidArgumentException);

  if (nil == internal->children)
    {
      internal->children = [[NSMutableArray alloc] initWithCapacity: 10];
    }
  [internal->children insertObject: child
			   atIndex: index];
  GSIVar(child, parent) = self;
  internal->childCount++;
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
  NSXMLNode	*child = [internal->children objectAtIndex: index];

  if (nil != child)
    {
      GSIVar(child, parent) = nil;
      [internal->children removeObjectAtIndex: index];
      if (0 == --internal->childCount)
	{
	  /* The -children method must return nil if there are no children,
	   * so we destroy the container.
	   */
	  DESTROY(internal->children);
	}
    }
}

- (void) setChildren: (NSArray*)children
{
  if (children != internal->children)
    {
      NSEnumerator	*en;
      NSXMLNode		*child;

      [children retain];
      while (internal->childCount > 0)
	{
	  [self removeChildAtIndex:internal->childCount - 1];
	}
      en = [children objectEnumerator];
      while ((child = [en nextObject]) != nil)
	{
	  [self insertChild: child atIndex: internal->childCount];
	}
      [children release];
    }
}
 
- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: internal->childCount];
}
 
- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)node
{
  [self insertChild: node atIndex: index];
  [self removeChildAtIndex: index + 1];
}

- (void) normalizeAdjacentTextNodesPreservingCDATA: (BOOL)preserve
{
  [self notImplemented: _cmd];
}

- (NSString *) XMLStringWithOptions: (NSUInteger)options
{
  NSMutableString *result = [NSMutableString string];
  NSEnumerator *en = nil;
  id object = nil;

  // XML Element open tag...
  [result appendString: [NSString stringWithFormat: @"<%@",[self name]]];

  // get the attributes...
  en = [[self attributes] objectEnumerator];
  while ((object = [en nextObject]) != nil)
    {
      [result appendString: @" "];
      [result appendString: [object XMLStringWithOptions: options]];
    }
  // close the brackets...
  [result appendString: @">"];

  [result appendString: [self stringValue]]; // need to escape entities...

  // Iterate over the children...
  en = [[self children] objectEnumerator];
  while ((object = [en nextObject]) != nil)
    {
      [result appendString: @" "];
      [result appendString: [object XMLStringWithOptions: options]];
    }
  
  // Close the entire tag...
  [result appendString: [NSString stringWithFormat: @"</%@>",[self name]]];

  // return 
  return result;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSXMLElement	*c = (NSXMLElement*)[super copyWithZone: zone];
  NSEnumerator	*en = [internal->namespaces objectEnumerator];
  id obj = nil;

  while ((obj = [en nextObject]) != nil)
    {
      [c addNamespace: [obj copyWithZone: zone]];
    }

  en = [internal->attributes objectEnumerator];
  while ((obj = [en nextObject]) != nil)
    {
      NSXMLNode *attr = [obj copyWithZone: zone];
      [c addAttribute: attr];
    }
  
  [c setChildren: [self children]];

  return c;
}

@end

