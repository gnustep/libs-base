/* Implementation for Objective-C Red-Black Tree collection object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

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

#include <gnustep/base/RBTree.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/RBTreeNode.h>

#define NODE_IS_RED(NODE) ([NODE isRed])
#define NODE_IS_BLACK(NODE) (![NODE isRed])

/* sentinal */
static id nilRBNode;

@implementation RBTree

+ (void) initialize
{
  if (self == [RBTree class])
    {
      nilRBNode = [[RBTreeNode alloc] init];
      [nilRBNode setBlack];
    }
}

- nilNode
{
  return nilRBNode;
}

- (void) sortAddObject: newObject
{
  id y;

  [super sortAddObject: newObject];
  [newObject setRed];
  while (newObject != _contents_root 
	 && [[newObject parentNode] isRed])
    {
      if ([newObject parentNode] == 
	  [[[newObject parentNode] parentNode] leftNode])
	{
	  y = [[[newObject parentNode] parentNode] leftNode];
	  if ([y isRed])
	    {
	      [[newObject parentNode] setBlack];
	      [y setBlack];
	      [[[newObject parentNode] parentNode] setRed];
	      newObject = [[newObject parentNode] parentNode];
	    }
	  else 
	    {
	      if (newObject == [[newObject parentNode] rightNode])
		{
		  newObject = [newObject parentNode];
		  [self leftRotateAroundNode:newObject];
		}
	      [[newObject parentNode] setBlack];
	      [[[newObject parentNode] parentNode] setRed];
	      [self rightRotateAroundNode:
		    [[newObject parentNode] parentNode]];
	    }
	}
      else
	{
	  y = [[[newObject parentNode] parentNode] rightNode];
	  if ([y isRed])
	    {
	      [[newObject parentNode] setBlack];
	      [y setBlack];
	      [[[newObject parentNode] parentNode] setRed];
	      newObject = [[newObject parentNode] parentNode];
	    }
	  else 
	    {
	      if (newObject == [[newObject parentNode] leftNode])
		{
		  newObject = [newObject parentNode];
		  [self rightRotateAroundNode:newObject];
		}
	      [[newObject parentNode] setBlack];
	      [[[newObject parentNode] parentNode] setRed];
	      [self leftRotateAroundNode:
		    [[newObject parentNode] parentNode]];
	    }
	}
    }
  [_contents_root setBlack];
}

- (void) _RBTreeDeleteFixup: x
{
  id w;

  while (x != _contents_root && NODE_IS_BLACK(x))
    {
      if (NODE_IS_LEFTCHILD(x))
	{
	  w = [[x parentNode] rightNode];
	  if (NODE_IS_RED(w))
	    {
	      [w setBlack];
	      [[x parentNode] setRed];
	      [self leftRotateAroundNode:[x parentNode]];
	      w = [[x parentNode] rightNode];
	    }
	  if (NODE_IS_BLACK([w leftNode]) && NODE_IS_BLACK([w rightNode]))
	    {
	      [w setRed];
	      x = [x parentNode];
	    }
	  else 
	    {
	      if (NODE_IS_BLACK([w rightNode]))
		{
		  [[w leftNode] setBlack];
		  [w setRed];
		  [self rightRotateAroundNode:w];
		  w = [[x parentNode] rightNode];
		}
	      if (NODE_IS_BLACK([x parentNode]))
		[w setBlack];
	      else
		[w setRed];
	      [[x parentNode] setBlack];
	      [[w rightNode] setBlack];
	      [self leftRotateAroundNode:[x parentNode]];
	      x = _contents_root;
	    }
	}
      else
	{
	  w = [[x parentNode] leftNode];
	  if (NODE_IS_RED(w))
	    {
	      [w setBlack];
	      [[x parentNode] setRed];
	      [self rightRotateAroundNode:[x parentNode]];
	      w = [[x parentNode] leftNode];
	    }
	  if (NODE_IS_BLACK([w rightNode]) && NODE_IS_BLACK([w leftNode]))
	    {
	      [w setRed];
	      x = [x parentNode];
	    }
	  else 
	    {
	      if (NODE_IS_BLACK([w leftNode]))
		{
		  [[w rightNode] setBlack];
		  [w setRed];
		  [self leftRotateAroundNode:w];
		  w = [[x parentNode] leftNode];
		}
	      if (NODE_IS_BLACK([x parentNode]))
		[w setBlack];
	      else
		[w setRed];
	      [[x parentNode] setBlack];
	      [[w leftNode] setBlack];
	      [self rightRotateAroundNode:[x parentNode]];
	      x = _contents_root;
	    }
	}
    }
  [x setBlack];
}

- (void) removeObject: oldObject
{
  id x, y;

  if ([oldObject leftNode] == [self nilNode] 
      || [oldObject rightNode] == [self nilNode])
    y = oldObject;
  else
    y = [self successorOfObject: oldObject];

  if ([y leftNode] != [self nilNode])
    x = [y leftNode];
  else
    x = [y rightNode];

  [x setParentNode:[y parentNode]];

  if ([y parentNode] == [self nilNode])
    _contents_root = x;
  else
    {
      if (y == [[y parentNode] leftNode])
	[[y parentNode] setLeftNode:x];
      else
	[[y parentNode] setRightNode:x];
    }

  if (y != oldObject)
    {
      /* put y in the place of oldObject */
      [y setParentNode:[oldObject parentNode]];
      [y setLeftNode:[oldObject leftNode]];
      [y setRightNode:[oldObject rightNode]];
      if (oldObject == [[oldObject parentNode] leftNode])
	[[oldObject parentNode] setLeftNode:y];
      else
	[[oldObject parentNode] setRightNode:oldObject];
      [[oldObject leftNode] setParentNode:y];
      [[oldObject rightNode] setParentNode:y];
    }

  if (NODE_IS_BLACK(y))
    [self _RBTreeDeleteFixup:x];

  _count--;

  /* Release ownership of the object. */
#if 0
  [oldObject setRightNode: [self nilNode]];
  [oldObject setLeftNode: [self nilNode]];
  [oldObject setParentNode: [self nilNode]];
#else
  [oldObject setLeftNode: NO_OBJECT];
  [oldObject setRightNode: NO_OBJECT];
  [oldObject setParentNode: NO_OBJECT];
#endif
  [oldObject setBinaryTree: NO_OBJECT];
  [oldObject release];
}

@end

