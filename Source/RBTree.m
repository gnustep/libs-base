/* Implementation for Objective-C Red-Black Tree collection object
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

#include <objects/RBTree.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/RBTreeNode.h>

#define NODE_IS_RED(NODE) ([NODE isRed])
#define NODE_IS_BLACK(NODE) (![NODE isRed])

/* sentinal */
static id nilRBNode;

@implementation RBTree

+ initialize
{
  if (self == [RBTree class])
    {
      [self setVersion:0];	/* beta release */
      nilRBNode = [[RBTreeNode alloc] init];
      [nilRBNode setBlack];
    }
  return self;
}

- nilNode
{
  return nilRBNode;
}

- sortAddElement: (elt)newElement byCalling: (int(*)(elt,elt))aFunc
{
  id y;

  [super sortAddElement:newElement byCalling:aFunc];
  [newElement.id_u setRed];
  while (newElement.id_u != _contents_root 
	 && [[newElement.id_u parentNode] isRed])
    {
      if ([newElement.id_u parentNode] == 
	  [[[newElement.id_u parentNode] parentNode] leftNode])
	{
	  y = [[[newElement.id_u parentNode] parentNode] leftNode];
	  if ([y isRed])
	    {
	      [[newElement.id_u parentNode] setBlack];
	      [y setBlack];
	      [[[newElement.id_u parentNode] parentNode] setRed];
	      newElement.id_u = [[newElement.id_u parentNode] parentNode];
	    }
	  else 
	    {
	      if (newElement.id_u == [[newElement.id_u parentNode] rightNode])
		{
		  newElement.id_u = [newElement.id_u parentNode];
		  [self leftRotateAroundNode:newElement.id_u];
		}
	      [[newElement.id_u parentNode] setBlack];
	      [[[newElement.id_u parentNode] parentNode] setRed];
	      [self rightRotateAroundNode:
		    [[newElement.id_u parentNode] parentNode]];
	    }
	}
      else
	{
	  y = [[[newElement.id_u parentNode] parentNode] rightNode];
	  if ([y isRed])
	    {
	      [[newElement.id_u parentNode] setBlack];
	      [y setBlack];
	      [[[newElement.id_u parentNode] parentNode] setRed];
	      newElement.id_u = [[newElement.id_u parentNode] parentNode];
	    }
	  else 
	    {
	      if (newElement.id_u == [[newElement.id_u parentNode] leftNode])
		{
		  newElement.id_u = [newElement.id_u parentNode];
		  [self rightRotateAroundNode:newElement.id_u];
		}
	      [[newElement.id_u parentNode] setBlack];
	      [[[newElement.id_u parentNode] parentNode] setRed];
	      [self leftRotateAroundNode:
		    [[newElement.id_u parentNode] parentNode]];
	    }
	}
    }
  [_contents_root setBlack];
  return self;
}

- _RBTreeDeleteFixup: x
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
  return self;
}

- (elt) removeElement: (elt)oldElement
{
  id x, y;

  if ([oldElement.id_u leftNode] == [self nilNode] 
      || [oldElement.id_u rightNode] == [self nilNode])
    y = oldElement.id_u;
  else
    y = [self successorOfElement:oldElement].id_u;

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

  if (y != oldElement.id_u)
    {
      /* put y in the place of oldElement.id_u */
      [y setParentNode:[oldElement.id_u parentNode]];
      [y setLeftNode:[oldElement.id_u leftNode]];
      [y setRightNode:[oldElement.id_u rightNode]];
      if (oldElement.id_u == [[oldElement.id_u parentNode] leftNode])
	[[oldElement.id_u parentNode] setLeftNode:y];
      else
	[[oldElement.id_u parentNode] setRightNode:oldElement.id_u];
      [[oldElement.id_u leftNode] setParentNode:y];
      [[oldElement.id_u rightNode] setParentNode:y];
    }

  if (NODE_IS_BLACK(y))
    [self _RBTreeDeleteFixup:x];

  [oldElement.id_u setRightNode:[self nilNode]];
  [oldElement.id_u setLeftNode:[self nilNode]];
  [oldElement.id_u setParentNode:[self nilNode]];
  _count--;
  return AUTORELEASE_ELT(oldElement);
}

/* Override methods that could violate assumptions of RBTree structure.
   Perhaps I shouldn't DISALLOW this, let users have the power to do 
   whatever they want.  I mention this in the QUESTIONS section of the
   TODO file. */

/***
Or perhaps instead of calling INSERTION_ERROR we could fix up the RB 
property of the tree.

- insertElement: (elt)newElement before: (elt)oldElement
{
  INSERTION_ERROR();
  return self;
}

- insertElement: (elt)newElement after: (elt)oldElement
{
  INSERTION_ERROR();
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  INSERTION_ERROR();
  return self;
}

- appendElement: (elt)newElement
{
  INSERTION_ERROR();
  return self;
}
****/

@end

