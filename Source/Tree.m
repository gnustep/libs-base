/* Implementation for Objective-C Tree collection object
   Copyright (C) 1993,1994, 1995 Free Software Foundation, Inc.

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

#include <gnustep/base/Tree.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/TreeNode.h>

/* sentinal */
static id nilTreeNode;

@implementation Tree

+ initialize
{
  if (self == [Tree class])
    {
      [self setVersion:0];	/* beta release */
      nilTreeNode = [[TreeNode alloc] init];
    }
  return self;
}

/* This is the designated initializer of this class */
- init
{
  [super initWithType:@encode(id)];
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

/* Archiving must mimic the above designated initializer */

- _newCollectionWithCoder: aCoder
{
  [super _initCollectionWithCoder:aCoder];
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

- (void) _encodeContentsWithCoder: (Coder*)aCoder
{
  [aCoder startEncodingInterconnectedObjects];
  [super _encodeContentsWithCoder:aCoder];
  [aCoder finishEncodingInterconnectedObjects];
}

- (void) _decodeContentsWithCoder: (Coder*)aCoder
{
  [aCoder startDecodingInterconnectedObjects];
  [super _decodeContentsWithCoder:aCoder];
  [aCoder finishDecodingInterconnectedObjects];
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Tree *copy = [super emptyCopy];
  copy->_count = 0;
  copy->_contents_root = [self nilNode];
  return copy;
}

/* This must work without sending any messages to content objects */
- _empty
{
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

/* Override the designated initializer for our superclass IndexedCollection
   to make sure we have object contents */
- initWithType: (const char *)contentEncoding
{
  if (!ENCODING_IS_OBJECT(contentEncoding))
    [self error:"Tree contents must be objects."];
  return [self init];
}

- nilNode
{
  return nilTreeNode;
}

- rootNode
{
  return _contents_root;
}

- leftmostNodeFromNode: aNode
{
  id left;

  if (aNode && aNode != [self nilNode])
    {
      while ([[aNode children] count] &&
	     (left = [[aNode children] firstObject]) != [self nilNode])
	aNode = left;
    }
  return aNode;
}

- rightmostNodeFromNode: aNode
{
  id right;

  if (aNode && aNode != [self nilNode])
    while ([[aNode children] count] &&
	   (right = [[aNode children] lastObject]) != [self nilNode])
      {
	aNode = right;
      }
  return aNode;
}

- (elt) firstElement
{
  return [self leftmostNodeFromNode:_contents_root];
}

- (elt) lastElement
{
  return [self rightmostNodeFromNode:_contents_root];
}

/* This is correct only is the tree is sorted.  How to deal with this? */
- (elt) maxElement
{
  return [self rightmostNodeFromNode:_contents_root];
}

/* This is correct only is the tree is sorted.  How to deal with this? */
- (elt) minElement
{
  return [self leftmostNodeFromNode:_contents_root];
}

// returns [self nilNode] is there is no successor;
- (elt) successorOfElement: (elt)anElement
{
  id tmp;

  // here tmp is the right node;
  if ((tmp = [anElement.id_u rightNode]) != [self nilNode])
    return [self leftmostNodeFromNode:tmp];
  // here tmp is the parent;
  tmp = [anElement.id_u parentNode];
  while (tmp != [self nilNode] 
	 [[tmp children] count] &&
	 && anElement.id_u == [[tmp children] lastObject])
    {
      anElement.id_u = tmp;
      tmp = [tmp parentNode];
    }
  return tmp;
}

// I should make sure that [_contents_root parentNode] == [self nilNode];
// Perhaps I should make [_contents_root parentNode] == TreeObj ??;

// returns [self nilNode] is there is no predecessor;
- (elt) predecessorElement: (elt)anElement
{
  id tmp;

  // here tmp is the left node;
  if ((tmp = [anElement.id_u leftNode]) != [self nilNode])
    return [self rightmostNodeFromNode:tmp];
  // here tmp is the parent;
  tmp = [anElement.id_u parentNode];
  while (tmp != [self nilNode] 
	 [[tmp children] count] &&
	 && anElement.id_u == [[tmp children] firstObject])
    {
      anElement.id_u = tmp;
      tmp = [tmp parentNode];
    }
  return tmp;
}

/* This relies on [_contents_root parentNode] == [self nilNode] */
- rootFromNode: aNode
{
  id parentNode;
  while ((parentNode = [aNode parentNode]) != [self nilNode])
    aNode = parentNode;
  return aNode;
}

/* This relies on [_contents_root parentNode] == [self nilNode] */
- (unsigned) depthOfNode: aNode
{
  unsigned count = 0;
  
  if (aNode == nil || aNode == [self nilNode])
    [self error:"in %s, Can't find depth of nil node", sel_get_name(_cmd)];
  do
    {
      aNode = [aNode parentNode];
      count++;
    }
  while (aNode != [self nilNode]);
  return count;
}

#if 0
- (unsigned) heightOfNode: aNode
{
  unsigned leftHeight, rightHeight;
  id tmpNode;

  if (aNode == nil || aNode == [self nilNode])
    {
      [self error:"in %s, Can't find height of nil node", sel_get_name(_cmd)];
      return 0;
    }
  else 
    {
      leftHeight = ((tmpNode = [aNode leftNode])
		    ?
		    (1 + [self heightOfNode:tmpNode])
		    :
		    0);
      rightHeight = ((tmpNode = [aNode rightNode])
		     ?
		     (1 + [self heightOfNode:tmpNode])
		     :
		     0);
      return MAX(leftHeight, rightHeight);
    }
}

- (unsigned) nodeCountUnderNode: aNode
{
  unsigned count = 0;
  if ([aNode leftNode] != [self nilNode])
    count += 1 + [self nodeCountUnderNode:[aNode leftNode]];
  if ([aNode rightNode] != [self nilNode])
    count += 1 + [self nodeCountUnderNode:[aNode rightNode]];
  return count;
}
#endif

- (elt) elementAtIndex: (unsigned)index
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret = [self firstElement];
  // Not very efficient;  Should be rewritten;
  while (index--)
    ret = [self successorOfElement:ret];
  return ret;
}

#if 0
- sortAddElement: (elt)newElement byCalling: (int(*)(elt,elt))aFunc
{
  id theParent, tmpChild;

  [newElement.id_u setLeftNode:[self nilNode]];
  [newElement.id_u setRightNode:[self nilNode]];
  theParent = [self nilNode];
  tmpChild = _contents_root;
  while (tmpChild != [self nilNode])
    {
      theParent = tmpChild;
      if ((*aFunc)(newElement,theParent) < 0)
	tmpChild = [tmpChild leftNode];
      else
	tmpChild = [tmpChild rightNode];
    }
  [newElement.id_u setParentNode:theParent];
  if (theParent == [self nilNode])
    _contents_root = newElement.id_u;
  else
    {
      if (COMPARE_ELEMENTS(newElement, theParent) < 0)
	[theParent setLeftNode:newElement.id_u];
      else
	[theParent setRightNode:newElement.id_u];
    }
  _count++;
  return self;
}
#endif

- addElement: (elt)newElement
{
  // By default add to root node.  Is this what we want?;
  if (_contents_root)
    [[_contents_root children] addObject:newElement.id_u];
  else
    _contents_root = newElement.id_u;
  _count++;
  return self;
}

#if 0
// NOTE: This gives you the power to put elements in unsorted order;
- insertElement: (elt)newElement before: (elt)oldElement
{
  id tmp;

  #ifdef SAFE_Tree
  if ([self rootFromNode:oldElement.id_u] != _contents_root)
    [self error:"in %s, oldElement not in tree!!", sel_get_name(_cmd)];
  #endif

  [newElement.id_u setRightNode:[self nilNode]];
  [newElement.id_u setLeftNode:[self nilNode]];
  if ((tmp = [oldElement.id_u leftNode]) != [self nilNode])
    {
      [(tmp = [self rightmostNodeFromNode:tmp]) setRightNode:newElement.id_u];
      [newElement.id_u setParentNode:tmp];
    }
  else if (newElement.id_u != [self nilNode])
    {
      [oldElement.id_u setLeftNode:newElement.id_u];
      [newElement.id_u setParentNode:oldElement.id_u];
    }
  else
    {
      _contents_root = newElement.id_u;
      [newElement.id_u setParentNode:[self nilNode]];
    }
  _count++;
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- insertElement: (elt)newElement after: (elt)oldElement
{
  id tmp;

  #ifdef SAFE_Tree
  if ([self rootFromNode:oldElement.id_u] != _contents_root)
    [self error:"in %s, !!!!!!!!", sel_get_name(_cmd)];
  #endif

  [newElement.id_u setRightNode:[self nilNode]];
  [newElement.id_u setLeftNode:[self nilNode]];
  if ((tmp = [oldElement.id_u rightNode]) != [self nilNode])
    {
      [(tmp = [self leftmostNodeFromNode:tmp]) setLeftNode:newElement.id_u];
      [newElement.id_u setParentNode:tmp];
    }
  else if (newElement.id_u != [self nilNode])
    {
      [oldElement.id_u setRightNode:newElement.id_u];
      [newElement.id_u setParentNode:oldElement.id_u];
    }
  else
    {
      _contents_root = newElement.id_u;
      [newElement.id_u setParentNode:[self nilNode]];
    }
  _count++;
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  if (index == _count)
    [self appendElement:newElement];
  else
    [self insertElement:newElement before:[self elementAtIndex:index]];
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- appendElement: (elt)newElement
{
  if (_count == 0)
    {
      _contents_root = newElement.id_u;
      _count = 1;
      [newElement.id_u setLeftNode:[self nilNode]];
      [newElement.id_u setRightNode:[self nilNode]];
      [newElement.id_u setParentNode:[self nilNode]];
    }
  else 
    [self insertElement:newElement after:[self lastElement]];
  return self;
}
#endif 

- (elt) removeElement: (elt)oldElement
{
  id parent = [oldElement.id_u parentNode];
  [parent removeObject:oldElement.id_u];
  [parent addContentsOf:[oldElement.id_u children]];
  _count--;
  return oldElement;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag
{
  void traverse(id aNode)
    {
      if (!(*flag) || aNode == [self nilNode] || !aNode)
	return;
      (*aFunc)(aNode);
      [[aNode children] withObjectsCall:traverse];
    }
  traverse(_contents_root);
  return self;
}

- withElementsInReverseCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag
{
  void traverse(id aNode)
    {
      if (*flag || aNode == [self nilNode] || !aNode)
	return;
      [[aNode children] withObjectsCall:traverse];
      (*aFunc)(aNode);
    }
  traverse(_contents_root);
  return self;
}

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  if (!(*enumState)) 
    *enumState = [self leftmostNodeFromNode:_contents_root];
  else
    *enumState = [self successorOfElement:*enumState].id_u;
  *anElementPtr = *enumState;
  if (*enumState)
    return YES;
  return NO;
}

- (BOOL) getPrevElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  if (!(*enumState)) 
    *enumState = [self rightmostNodeFromNode:_contents_root];
  else
    *enumState = [self predecessorElement:*enumState].id_u;
  *anElementPtr = *enumState;
  if (*enumState)
    return YES;
  return NO;
}

- (unsigned) count
{
  return _count;
}

@end
