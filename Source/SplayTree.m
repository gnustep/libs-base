/* Implementation for Objective-C SplayTree collection object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNUstep Base Library.

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

#include <config.h>
#include <gnustep/base/SplayTree.h>
#include <gnustep/base/IndexedCollectionPrivate.h>

@implementation SplayTree

/* Make this a function ? */
- (void) _doSplayOperationOnNode: aNode
{
  id parent = [aNode parentNode];
  id parentRightChild = 
    ((parent == [self nilNode]) ? [self nilNode] : [parent rightNode]);

  if (aNode == _contents_root || aNode == [self nilNode])
    {
      return;
    }
  else if (aNode == parentRightChild)
    {
      if (parent == _contents_root)
	{
	  [self leftRotateAroundNode:parent];
	}
      else if (NODE_IS_RIGHTCHILD(parent))
	{
	  [self leftRotateAroundNode:[parent parentNode]];
	  [self leftRotateAroundNode:parent];
	}
      else
	/* NODE_IS_LEFTCHILD(parent) */
	{
	  [self leftRotateAroundNode:parent];
	  [self rightRotateAroundNode:[aNode parentNode]];
	}
    }
  else
    /* aNode == parentLeftChild */
    {
      if (parent == _contents_root)
	{
	  [self rightRotateAroundNode:parent];
	}
      else if (NODE_IS_LEFTCHILD(parent))
	{
	  [self rightRotateAroundNode:[parent parentNode]];
	  [self rightRotateAroundNode:parent];
	}
      else
	/* NODE_IS_RIGHTCHILD(parent) */
	{
	  [self rightRotateAroundNode:parent];
	  [self leftRotateAroundNode:[aNode parentNode]];
	}
    }
}

- (void) splayNode: aNode
{
  while (aNode != _contents_root)
    [self _doSplayOperationOnNode:aNode];
}

/* We could make this a little more efficient by doing the splay as
   we search down the tree for the correct insertion point. */
- (void) sortAddObject: newObject
{
  [super sortAddObject: newObject];
  [self splayNode: newObject];
}

- (void) removeObject: anObject
{
  id parent = [anObject parentNode];
  [super removeObject: anObject];
  if (parent && parent != [self nilNode])
    [self splayNode:parent];
}

@end
