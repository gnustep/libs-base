/* Implementation for Objective-C BinaryTree collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

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
#include <objects/NSString.h>

/* the sentinal */
static id nilBinaryTreeNode;

@implementation BinaryTree

+ (void) initialize
{
  if (self == [BinaryTree class])
    {
      nilBinaryTreeNode = [[BinaryTreeNode alloc] init];
    }
}

/* This is the designated initializer of this class */
- init
{
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

/* Archiving must mimic the above designated initializer */

/* xxx See Collection _decodeContentsWithCoder:.
   We shouldn't do an -addElement.  finishEncodingInterconnectedObjects
   should take care of all that. */

- _initCollectionWithCoder: aCoder
{
  [self notImplemented:_cmd];
  [super _initCollectionWithCoder:aCoder];
  _count = 0;
  _contents_root = [self nilNode];
  return self;
}

- (void) _encodeContentsWithCoder: (id <Encoding>)aCoder
{
  [aCoder startEncodingInterconnectedObjects];
  [super _encodeContentsWithCoder:aCoder];
  [aCoder finishEncodingInterconnectedObjects];
}

- (void) _decodeContentsWithCoder: (id <Decoding>)aCoder
{
  [aCoder startDecodingInterconnectedObjects];
  [super _decodeContentsWithCoder:aCoder];
  [aCoder finishDecodingInterconnectedObjects];
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
- (void) _empty
{
  _count = 0;
  _contents_root = [self nilNode];
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

- firstObject
{
  return [self leftmostNodeFromNode: _contents_root];
}

- lastObject
{
  return [self rightmostNodeFromNode: _contents_root];
}

/* This is correct only if the tree is sorted.  How to deal with this? */
- maxObject
{
  return [self rightmostNodeFromNode: _contents_root];
}

/* This is correct only is the tree is sorted.  How to deal with this? */
- minObject
{
  return [self leftmostNodeFromNode: _contents_root];
}

- successorOfObject: anObject
{
  id tmp;

  /* Make sure we actually own the anObject. */
  assert ([anObject binaryTree] == self);

  // here tmp is the right node;
  if ((tmp = [anObject rightNode]) != [self nilNode])
    return [self leftmostNodeFromNode: tmp];
  // here tmp is the parent;
  tmp = [anObject parentNode];
  while (tmp != [self nilNode] && anObject == [tmp rightNode])
    {
      anObject = tmp;
      tmp = [tmp parentNode];
    }
  if (tmp == [self nilNode])
    return NO_OBJECT;
  return tmp;
}

// I should make sure that [_contents_root parentNode] == [self nilNode];
// Perhaps I should make [_contents_root parentNode] == binaryTreeObj ??;

- predecessorObject: anObject
{
  id tmp;

  /* Make sure we actually own the anObject. */
  assert ([anObject binaryTree] == self);

  // here tmp is the left node;
  if ((tmp = [anObject leftNode]) != [self nilNode])
    return [self rightmostNodeFromNode:tmp];
  // here tmp is the parent;
  tmp = [anObject parentNode];
  while (tmp != [self nilNode] && anObject == [tmp leftNode])
    {
      anObject = tmp;
      tmp = [tmp parentNode];
    }
  if (tmp == [self nilNode])
    return NO_OBJECT;
  return tmp;
}

/* This relies on [_contents_root parentNode] == [self nilNode] */
- rootFromNode: aNode
{
  id parentNode;

  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

  while ((parentNode = [aNode parentNode]) != [self nilNode])
    aNode = parentNode;
  return aNode;
}

/* This relies on [_contents_root parentNode] == [self nilNode] */
- (unsigned) depthOfNode: aNode
{
  unsigned count = 0;
  
  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

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

  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

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

  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

  if ([aNode leftNode] != [self nilNode])
    count += 1 + [self nodeCountUnderNode:[aNode leftNode]];
  if ([aNode rightNode] != [self nilNode])
    count += 1 + [self nodeCountUnderNode:[aNode rightNode]];
  return count;
}

- leftRotateAroundNode: aNode
{
  id y;

  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

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

  /* Make sure we actually own the aNode. */
  assert ([aNode binaryTree] == self);

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

- objectAtIndex: (unsigned)index
{
  id ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret = [self firstObject];
  // Not very efficient;  Should be rewritten;
  while (index--)
    ret = [self successorOfObject: ret];
  return ret;
}

- (void) sortAddObject: newObject
{
  id theParent, tmpChild;

  /* Make sure no one else already owns the newObject. */
  assert ([newObject binaryTree] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setBinaryTree: self];

  [newObject setLeftNode:[self nilNode]];
  [newObject setRightNode:[self nilNode]];
  theParent = [self nilNode];
  tmpChild = _contents_root;
  while (tmpChild != [self nilNode])
    {
      theParent = tmpChild;
      if ([newObject compare: theParent] < 0)
	tmpChild = [tmpChild leftNode];
      else
	tmpChild = [tmpChild rightNode];
    }
  [newObject setParentNode:theParent];
  if (theParent == [self nilNode])
    _contents_root = newObject;
  else
    {
      if ([newObject compare: theParent] < 0)
	[theParent setLeftNode:newObject];
      else
	[theParent setRightNode:newObject];
    }
  _count++;
}

- (void) addObject: newObject
{
  // By default insert in sorted order.
  [self sortAddObject: newObject];
}

- (void) removeObject: oldObject
{
  id x, y;

  /* Make sure we actually own the aNode. */
  assert ([oldObject binaryTree] == self);

  /* Extract the oldObject and sew up the cut. */
  if ([oldObject leftNode] == [self nilNode] 
      || [oldObject rightNode] == [self nilNode])
    y = oldObject;
  else
    y = [self successorOfObject: oldObject];

  if ([y leftNode] != [self nilNode])
    x = [y leftNode];
  else
    x = [y rightNode];

  if (x != [self nilNode])
    [x setParentNode: [y parentNode]];

  if ([y parentNode] == [self nilNode])
    _contents_root = x;
  else
    {
      if (y == [[y parentNode] leftNode])
	[[y parentNode] setLeftNode: x];
      else
	[[y parentNode] setRightNode: x];
    }

  if (y != oldObject)
    {
      /* put y in the place of oldObject */
      [y setParentNode: [oldObject parentNode]];
      [y setLeftNode: [oldObject leftNode]];
      [y setRightNode: [oldObject rightNode]];
      if (oldObject == [[oldObject parentNode] leftNode])
	[[oldObject parentNode] setLeftNode: y];
      else
	[[oldObject parentNode] setRightNode: y];
      [[oldObject leftNode] setParentNode: y];
      [[oldObject rightNode] setParentNode: y];
    }
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


// ENUMERATING;

- nextObjectWithEnumState: (void**)enumState
{
  if (!(*enumState)) 
    *enumState = [self leftmostNodeFromNode:_contents_root];
  else
    *enumState = [self successorOfObject:*enumState];
  return (id) *enumState;
}

- prevObjectWithEnumState: (void**)enumState
{
  if (!(*enumState)) 
    *enumState = [self rightmostNodeFromNode:_contents_root];
  else
    *enumState = [self predecessorObject:*enumState];
  return (id) *enumState;
}

- (unsigned) count
{
  return _count;
}


/* replace this with something better eventually */
- _tmpPrintFromNode: aNode indent: (int)count
{
  printf("%-*s", count, "");
  printf("%s\n", [[aNode description] cStringNoCopy]);
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



/* These methods removed because they belong to an 
   OrderedCollection implementation, not an IndexedCollection
   implementation. */

#if 0
// NOTE: This gives you the power to put elements in unsorted order;
- insertObject: newObject before: oldObject
{
  id tmp;

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setBinaryTree: self];

  [newObject setRightNode:[self nilNode]];
  [newObject setLeftNode:[self nilNode]];
  if ((tmp = [oldObject leftNode]) != [self nilNode])
    {
      [(tmp = [self rightmostNodeFromNode:tmp]) setRightNode:newObject];
      [newObject setParentNode:tmp];
    }
  else if (newObject != [self nilNode])
    {
      [oldObject setLeftNode:newObject];
      [newObject setParentNode:oldObject];
    }
  else
    {
      _contents_root = newObject;
      [newObject setParentNode:[self nilNode]];
    }
  _count++;
  RETAIN_ELT(newObject);
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- insertObject: newObject after: oldObject
{
  id tmp;

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setBinaryTree: self];

  [newObject setRightNode:[self nilNode]];
  [newObject setLeftNode:[self nilNode]];
  if ((tmp = [oldObject rightNode]) != [self nilNode])
    {
      [(tmp = [self leftmostNodeFromNode:tmp]) setLeftNode:newObject];
      [newObject setParentNode:tmp];
    }
  else if (newObject != [self nilNode])
    {
      [oldObject setRightNode:newObject];
      [newObject setParentNode:oldObject];
    }
  else
    {
      _contents_root = newObject;
      [newObject setParentNode:[self nilNode]];
    }
  _count++;
  RETAIN_ELT(newObject);
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);

  if (index == _count)
    [self appendObject:newObject];
  else
    [self insertObject:newObject before:[self ObjectAtIndex:index]];
  return self;
}

// NOTE: This gives you the power to put elements in unsorted order;
- appendObject: newObject
{
  if (_count == 0)
    {
      /* Make sure no one else already owns the newObject. */
      assert ([newObject linkedList] == NO_OBJECT);

      /* Claim ownership of the newObject. */
      [newObject retain];
      [newObject setBinaryTree: self];

      _contents_root = newObject;
      _count = 1;
      [newObject setLeftNode:[self nilNode]];
      [newObject setRightNode:[self nilNode]];
      [newObject setParentNode:[self nilNode]];
    }
  else 
    [self insertObject:newObject after:[self lastObject]];
  return self;
}
#endif
