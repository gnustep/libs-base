/* Includes interfaces for all concrete objects classes
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the Gnustep Base Library.

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

#ifndef __o_h_GNUSTEP_BASE_INCLUDE
#define __o_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

/* Collection objects */
#include <gnustep/base/Set.h>
#include <gnustep/base/Bag.h>
#include <gnustep/base/Dictionary.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Stack.h>
#include <gnustep/base/Queue.h>
#include <gnustep/base/GapArray.h>
#include <gnustep/base/CircularArray.h>
#include <gnustep/base/DelegatePool.h>
#include <gnustep/base/MappedCollector.h>
#include <gnustep/base/Heap.h>
#include <gnustep/base/LinkedList.h>
#include <gnustep/base/LinkedListNode.h>
#include <gnustep/base/BinaryTree.h>
#include <gnustep/base/BinaryTreeNode.h>
#include <gnustep/base/RBTree.h>
#include <gnustep/base/RBTreeNode.h>
#include <gnustep/base/SplayTree.h>

/* Magnitude objects */
#include <gnustep/base/Magnitude.h>
#include <gnustep/base/Random.h>
#include <gnustep/base/Time.h>

/* Stream objects */
#include <gnustep/base/Stream.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/MemoryStream.h>

/* Coder objects */
#include <gnustep/base/Coder.h>
#include <gnustep/base/BinaryCStream.h>
#include <gnustep/base/TextCStream.h>

/* Port objects */
#include <gnustep/base/Port.h>

/* Remote messaging support objects */
#include <gnustep/base/Connection.h>
#include <gnustep/base/Proxy.h>
#include <gnustep/base/ConnectedCoder.h>

#include <gnustep/base/Invocation.h>

#endif /* __o_h_GNUSTEP_BASE_INCLUDE */
