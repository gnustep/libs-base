/* Implementation for Objective-C TreeNode object
   Copyright (C) 1993,1994, 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <gnustep/base/TreeNode.h>
#include <gnustep/base/Array.h>

@implementation TreeNode

+ initialize
{
  if (self == [TreeNode class])
    [self setVersion:0];	/* beta release */
  return self;
}

+ defaultChildrenCollectionClass
{
  return [Array class];
}

- initWithChildren: (id <Collecting>)kids
{
  [super init];
  _parent = [self nilNode];
  _children = kids;
  return self;
}

- init
{
  [self initWithChildren:[[[self defaultChildrenCollectionClass] alloc] init]];
  return self;
}

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeObjectReference:_parent withName:@"Parent Tree Node"];
  [aCoder encodeObject:_children withName:@"Children of Tree Node"];
}

- initWithCoder: aCoder
{
  [self initWithCoder:aCoder];
  [aCoder decodeObjectAt:&_parent withName:NULL];
  [aCoder decodeObjectAt:&_children withName:NULL];
  return n;
}

- children
{
  return _children;
}

- parentNode
{
  return _parent;
}

- (void) setChildren: (id <IndexedCollecting>)kids
{
  /* xxx
  [kids retain];
  [_children release];
  */
  _children = kids;
  return self;
}

- (void) setParentNode: aNode
{
  _parent = aNode;
  return self;
}

@end

