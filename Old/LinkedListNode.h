/* Interface for Objective-C LinkedListNode object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

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

#ifndef __LinkedListNode_h_GNUSTEP_BASE_INCLUDE
#define __LinkedListNode_h_GNUSTEP_BASE_INCLUDE

#include <base/LinkedList.h>
#include <base/Coding.h>

@interface LinkedListNode : NSObject <LinkedListComprising>
{
  id <LinkedListComprising> _next;
  id <LinkedListComprising> _prev;
  id _linked_list;
}
@end

#endif /* __LinkedListNode_h_GNUSTEP_BASE_INCLUDE */
