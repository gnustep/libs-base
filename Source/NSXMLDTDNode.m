/* Implementation for NSXMLDTDNode for GNUStep
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

#define GS_XMLNODETYPE	xmlDtd
#define GSInternal	NSXMLDTDNodeInternal

#import	"NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLDTDNode)

@implementation NSXMLDTDNode

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
    }
  [super dealloc];
}

- (NSXMLDTDNodeKind) DTDKind
{
  return internal->DTDKind;
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLDTDNode);
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  if (NSXMLEntityDeclarationKind == kind
      || NSXMLElementDeclarationKind == kind
      || NSXMLNotationDeclarationKind == kind)
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

- (id) initWithXMLString: (NSString*)string
{
  // internal->node = xmlNewDtd(NULL,NULL,NULL);
  // TODO: Parse the string and get the info to create this...

  [self notImplemented: _cmd];
  return nil;
}

- (BOOL) isExternal
{
  if ([self systemID])
    {
      return YES;
    }
  return NO;
}

- (NSString*) notationName
{
  return StringFromXMLStringPtr(internal->node->name);
}

- (NSString*) publicID
{
 return StringFromXMLStringPtr(internal->node->ExternalID);
}

- (void) setDTDKind: (NSXMLDTDNodeKind)kind
{
  internal->DTDKind = kind;
}

- (void) setNotationName: (NSString*)notationName
{
  internal->node->name = XMLSTRING(notationName);
}

- (void) setPublicID: (NSString*)publicID
{
  internal->node->ExternalID = XMLSTRING(publicID);
}

- (void) setSystemID: (NSString*)systemID
{
  internal->node->ExternalID = XMLSTRING(systemID);
}

- (NSString*) systemID
{
  return StringFromXMLStringPtr(internal->node->SystemID);
}

@end

