/* Interface for Objective-C SplayTree collection object
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

/* 
   Splay Tree.  
   Sleator and Tarjan.  "Self-adjusting binary search trees."
   Journal of the ACM, 32(3):652-686, 1985.

   includesObject:, minObject, maxObject, nextObject:, sortAddObject,
   and removeObject: operations can all be done in O(lg n) amortized time.
*/
   

#ifndef __SplayTree_h_INCLUDE_GNU
#define __SplayTree_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/BinaryTree.h>

@interface SplayTree : BinaryTree
{
}

- splayNode: aNode;

@end

#endif /* __SplayTree_h_INCLUDE_GNU */
