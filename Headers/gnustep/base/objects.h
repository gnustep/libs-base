/* Includes interfaces for all concrete objects classes
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

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

#ifndef __objects_h_OBJECTS_INCLUDE
#define __objects_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>

/* Collection objects */
#include <objects/Set.h>
#include <objects/Bag.h>
#include <objects/Dictionary.h>
#include <objects/Array.h>
#include <objects/Stack.h>
#include <objects/Queue.h>
#include <objects/GapArray.h>
#include <objects/CircularArray.h>
#include <objects/DelegatePool.h>
#include <objects/MappedCollector.h>
#include <objects/Heap.h>
#include <objects/LinkedList.h>
#include <objects/LinkedListNode.h>
#include <objects/BinaryTree.h>
#include <objects/BinaryTreeNode.h>
#include <objects/RBTree.h>
#include <objects/RBTreeNode.h>
#include <objects/SplayTree.h>

#include <objects/EltNodeCollector.h>
#include <objects/LinkedListEltNode.h>
#include <objects/BinaryTreeEltNode.h>
#include <objects/RBTreeEltNode.h>

/* Magnitude objects */
#include <objects/Magnitude.h>
#include <objects/Random.h>
#include <objects/Time.h>

/* Stream objects */
#include <objects/Stream.h>
#include <objects/StdioStream.h>
#include <objects/MemoryStream.h>

/* Coder objects */
#include <objects/Coder.h>
#include <objects/BinaryCStream.h>
#include <objects/TextCStream.h>

/* Port objects */
#include <objects/Port.h>
#include <objects/SocketPort.h>

/* Remote messaging support objects */
#include <objects/Connection.h>
#include <objects/Proxy.h>
#include <objects/ConnectedCoder.h>

#endif /* __objects_h_OBJECTS_INCLUDE */
