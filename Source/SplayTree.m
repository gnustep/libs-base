/* Implementation for Objective-C SplayTree collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

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

#include <objects/SplayTree.h>
#include <objects/IndexedCollectionPrivate.h>

@implementation SplayTree

+ (void) initialize
{
  if (self == [SplayTree class])
    [self setVersion:0];	/* beta release */
}

/* Make this a function ? */
- _doSplayOperationOnNode: aNode
{
  id parent = [aNode parentNode];
  id parentRightChild = 
    ((parent == [self nilNode]) ? [self nilNode] : [parent rightNode]);

  if (aNode == _contents_root || aNode == [self nilNode])
    {
      return self;
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
  return self;
}

- splayNode: aNode
{
  while (aNode != _contents_root)
    [self _doSplayOperationOnNode:aNode];
  return self;
}

/* We could make this a little more efficient by doing the splay as
   we search down the tree for the correct insertion point. */
- sortAddElement: (elt)newElement byCalling: (int(*)(elt,elt))aFunc
{
  [super sortAddElement:newElement byCalling:aFunc];
  [self splayNode:newElement.id_u];
  return self;
}

- insertElement: (elt)newElement before: (elt)oldElement
{
  [super insertElement:newElement before:oldElement];
  // ??  [self splayNode:newElement.id_u];
  return self;
}

- insertElement: (elt)newElement after: (elt)oldElement
{
  [super insertElement:newElement after:oldElement];
  // ??  [self splayNode:newElement.id_u];
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  [super insertElement:newElement atIndex:index];
  // ??  [self splayNode:newElement.id_u];
  return self;
}

- (elt) removeElement: (elt)anElement
{
  id parent = [anElement.id_u parentNode];
  [super removeElement:anElement];
  if (parent && parent != [self nilNode])
    [self splayNode:parent];
  return AUTORELEASE_ELT(anElement);
}

@end
