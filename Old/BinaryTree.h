/* Interface for Objective-C BinaryTree collection object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

/* 
   Binary Tree.  
   Base class for smarter binary trees.
*/

#ifndef __BinaryTree_h_GNUSTEP_BASE_INCLUDE
#define __BinaryTree_h_GNUSTEP_BASE_INCLUDE

#include <base/IndexedCollection.h>

/* The <BinaryTreeComprising> protocol defines the interface to an object
   that may be an element in a BinaryTree. 
*/
@protocol BinaryTreeComprising <NSObject>
- leftNode;
- rightNode;
- parentNode;
- (void) setLeftNode: (id <BinaryTreeComprising>)aNode;
- (void) setRightNode: (id <BinaryTreeComprising>)aNode;
- (void) setParentNode: (id <BinaryTreeComprising>)aNode;
- binaryTree;
- (void) setBinaryTree: anObject;
@end

#define NODE_IS_RIGHTCHILD(NODE) (NODE == [[NODE parentNode] rightNode])
#define NODE_IS_LEFTCHILD(NODE) (NODE == [[NODE parentNode] leftNode])

@interface BinaryTree : IndexedCollection
{
  unsigned int _count;
  id _contents_root;
}

- nilNode;
- rootNode;

- leftmostNodeFromNode: aNode;
- rightmostNodeFromNode: aNode;

- (unsigned) depthOfNode: aNode;
- (unsigned) heightOfNode: aNode;

- (unsigned) nodeCountUnderNode: aNode;

- leftRotateAroundNode: aNode;
- rightRotateAroundNode: aNode;

- binaryTreePrintForDebugger;

@end


#endif /* __BinaryTree_h_GNUSTEP_BASE_INCLUDE */
