/* Includes interfaces for all concrete objects classes
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __o_h_GNUSTEP_BASE_INCLUDE
#define __o_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>

/* Collection objects */
#include <base/Set.h>
#include <base/Bag.h>
#include <base/Dictionary.h>
#include <base/Array.h>
#include <base/Stack.h>
#include <base/Queue.h>
#include <base/GapArray.h>
#include <base/CircularArray.h>
#include <base/DelegatePool.h>
#include <base/MappedCollector.h>
#include <base/Heap.h>
#include <base/LinkedList.h>
#include <base/LinkedListNode.h>
#include <base/BinaryTree.h>
#include <base/BinaryTreeNode.h>
#include <base/RBTree.h>
#include <base/RBTreeNode.h>
#include <base/SplayTree.h>

/* Stream objects */
#include <base/Stream.h>
#include <base/StdioStream.h>
#include <base/MemoryStream.h>

/* Coder objects */
#include <base/Coder.h>
#include <base/BinaryCStream.h>
#include <base/TextCStream.h>

/* Port objects */
#include <base/Port.h>

/* Remote messaging support objects */
#include <base/ConnectedCoder.h>

#include <base/Invocation.h>

#endif /* __o_h_GNUSTEP_BASE_INCLUDE */
