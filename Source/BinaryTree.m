/* Implementation for Objective-C BinaryTree collection object
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

#include <objects/BinaryTree.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/BinaryTreeNode.h>

// do safety checks;
#define SAFE_BinaryTree 1

/* sentinal */
static id nilBinaryTreeNode;

@implementation BinaryTree

+ (void) initialize
{
  if (self == [BinaryTree class])
    {
      [self setVersion:0];	/* beta release */
      nilBinaryTreeNode = [[BinaryTreeNode alloc] init];
    }
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

+ _newCollectionWithCoder: (Coder*)aCoder
{
  BinaryTree *n;
  n = [super _newCollectionWithCoder:aCoder];
  n->_count = 0;
  n->_contents_root = [self nilNode];
  return n;
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

- _readInit: (TypedStream*)aStream
{
  [super _readInit:aStream];
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

- _writeContents: (TypedStream*)aStream
{
  void archiveElement(elt e)
    {
      objc_write_object(aStream, e.id_u);
    }
  objc_write_type(aStream, @encode(unsigned int), &_count);
  [self withElementsCall:archiveElement];
  // We rely on the nodes to archive their children and parent ptrs;
  objc_write_object_reference(aStream, _contents_root);
  return self;
}

- _readContents: (TypedStream*)aStream
{
  int i;

  objc_read_type(aStream, @encode(unsigned int), &_count);
  for (i = 0; i < _count; i++)
    objc_read_object(aStream, &_contents_root);
  // We rely on the nodes to have archived their children and parent ptrs;
  objc_read_object(aStream, &_contents_root);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  BinaryTree *copy = [super emptyCopy];
  copy->_count = 0;
  copy->_contents_root = [self nilNode];
  return copy;
}

/* This must work without sending any messages to content objects */
- empty
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
    [self error:"BinaryTree contents must be objects."];
  return [self init];
}

- nilNode
{
  return nilBinaryTreeNode;
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
      while ((left = [aNode leftNode]) != [self nilNode])
	aNode = left;
    }
  return aNode;
}

- rightmostNodeFromNode: aNode
{
  id right;

  if (aNode && aNode != [self nilNode])
    while ((right = [aNode rightNode]) != [self nilNode])
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
  while (tmp != [self nilNode] && anElement.id_u == [tmp rightNode])
    {
      anElement.id_u = tmp;
      tmp = [tmp parentNode];
    }
  return tmp;
}

// I should make sure that [_contents_root parentNode] == [self nilNode];
// Perhaps I should make [_contents_root parentNode] == binaryTreeObj ??;

// returns [self nilNode] is there is no predecessor;
- (elt) predecessorElement: (elt)anElement
{
  id tmp;

  // here tmp is the left node;
  if ((tmp = [anElement.id_u leftNode]) != [self nilNode])
    return [self rightmostNodeFromNode:tmp];
  // here tmp is the parent;
  tmp = [anElement.id_u parentNode];
  while (tmp != [self nilNode] && anElement.id_u == [tmp leftNode])
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

- leftRotateAroundNode: aNode
{
  id y;

  y = [aNode rightNode];
  if (y == [self nilNode])
    return self;
  [aNode setRightNode:[y leftNode]];
  if ([y leftNode] != [self nilNode])
    [[y leftNode] setParentNode:aNode];
  [y setParentNode:[aNode parentNode]];
  if ([aNode parentNode] == [self nilNode])
    _contents_root = y;
  else
    {
      if (NODE_IS_LEFTCHILD(aNode))
	[[aNode parentNode] setLeftNode:y];
      else
	[[aNode parentNode] setRightNode:y];
    }
  [y setLeftNode:aNode];
  [aNode setParentNode:y];
  return self;
}

- rightRotateAroundNode: aNode
{
  id y;

  y = [aNode leftNode];
  if (y == [self nilNode])
    return self;
  [aNode setLeftNode:[y rightNode]];
  if ([y rightNode] != [self nilNode])
    [[y rightNode] setParentNode:aNode];
  [y setParentNode:[aNode parentNode]];
  if ([aNode parentNode] == [self nilNode])
    _contents_root = y;
  else
    {
      if (NODE_IS_RIGHTCHILD(aNode))
	[[aNode parentNode] setRightNode:y];
      else
	[[aNode parentNode] setLeftNode:y];
    }
  [y setRightNode:aNode];
  [aNode setParentNode:y];
  return self;
}

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

- addElement: (elt)newElement
{
  // By default insert in sorted order.  Is this what we want?;
  [self sortAddElement:newElement];
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- insertElement: (elt)newElement before: (elt)oldElement
{
  id tmp;

  #if SAFE_BinaryTree
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

  #if SAFE_BinaryTree
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
  [oldElement.id_u setRightNode:[self nilNode]];
  [oldElement.id_u setLeftNode:[self nilNode]];
  [oldElement.id_u setParentNode:[self nilNode]];
  _count--;
  return oldElement;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag
{
  void traverse(id aNode)
    {
      if (!(*flag) || aNode == [self nilNode] || !aNode)
	return;
      traverse([aNode leftNode]);
      (*aFunc)(aNode);
      traverse([aNode rightNode]);
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
      traverse([aNode rightNode]);
      (*aFunc)(aNode);
      traverse([aNode leftNode]);
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

/* replace this with something better eventually */
- _tmpPrintFromNode: aNode indent: (int)count
{
  printf("%-*s", count, "");
  if ([aNode respondsTo:@selector(printForDebugger)])
    [aNode printForDebugger];
  else
    printf("?\n");
  printf("%-*s.", count, "");
  if ([aNode leftNode] != [self nilNode])
    [self _tmpPrintFromNode:[aNode leftNode] indent:count+2];
  else
    printf("\n");
  printf("%-*s.", count, "");
  if ([aNode rightNode] != [self nilNode])
    [self _tmpPrintFromNode:[aNode rightNode] indent:count+2];
  else
    printf("\n");
  return self;
}

- binaryTreePrintForDebugger
{
  [self _tmpPrintFromNode:_contents_root indent:0];
  return self;
}

@end


