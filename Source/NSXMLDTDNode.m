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

#import	"NSXMLPrivate.h"

@implementation NSXMLDTDNode

- (void) dealloc
{
  [_name release];
  [_notationName release];
  [_publicID release];
  [_systemID release];
  [super dealloc];
}

- (NSXMLDTDNodeKind) DTDKind
{
  return _DTDKind;
}

- (id) initWithXMLString: (NSString*)string
{
  [self notImplemented: _cmd];
  return nil;
}

- (BOOL) isExternal
{
  if (_systemID != nil)
    {
// FIXME ... libxml integration?
      return YES;
    }
  return NO;
}

- (NSString*) notationName
{
  if (_notationName == nil)
    {
      [self notImplemented: _cmd];
    }
  return _notationName;
}

- (NSString*) publicID
{
  if (_publicID == nil)
    {
      [self notImplemented: _cmd];
    }
  return _publicID;
}

- (void) setDTDKind: (NSXMLDTDNodeKind)kind
{
  _DTDKind = kind;
  // FIXME ... libxml integration?
}

- (void) setNotationName: (NSString*)notationName
{
  ASSIGNCOPY(_notationName, notationName);
  // FIXME ... libxml integration?
}

- (void) setPublicID: (NSString*)publicID
{
  ASSIGNCOPY(_publicID, publicID);
  // FIXME ... libxml integration?
}

- (void) setSystemID: (NSString*)systemID
{
  ASSIGNCOPY(_systemID, systemID);
  // FIXME ... libxml integration?
}

- (NSString*) systemID
{
  if (_systemID == nil)
    {
      [self notImplemented: _cmd];
    }
  return _systemID;
}

@end

