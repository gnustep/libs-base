/* Implementation for Objective-C BinaryTreeNode object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the Gnustep Base Library.

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

#include <gnustep/base/BinaryTreeNode.h>
#include <gnustep/base/NSString.h>

@implementation BinaryTreeNode

+ (void) initialize
{
  if (self == [BinaryTreeNode class])
    [self setVersion:0];	/* beta release */
}

- init
{
  [super init];
  _left = _right = _parent = nil;
  return self;
}

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder:(id)aCoder];
  [aCoder encodeObjectReference:_right withName:@"Right BinaryTree Node"];
  [aCoder encodeObjectReference:_left withName:@"Left BinaryTree Node"];
  [aCoder encodeObjectReference:_parent withName:@"Parent BinaryTree Node"];
  [aCoder encodeObjectReference:_binary_tree
	  withName:@"BinaryTree"];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  [aCoder decodeObjectAt:&_right withName:NULL];
  [aCoder decodeObjectAt:&_left withName:NULL];
  [aCoder decodeObjectAt:&_parent withName:NULL];
  [aCoder decodeObjectAt:&_binary_tree withName:NULL];
  return self;
}

- leftNode
{
  return _left;
}

- rightNode
{
  return _right;
}

- parentNode
{
  return _parent;
}

- (void) setLeftNode: aNode
{
  _left = aNode;
}

- (void) setRightNode: aNode
{
  _right = aNode;
}

- (void) setParentNode: aNode
{
  _parent = aNode;
}

- binaryTree
{
  return _binary_tree;
}

- (void) setBinaryTree: anObject
{
  _binary_tree = anObject;
}

@end

