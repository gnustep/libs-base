/* Implementation for Objective-C LinkedListNode object
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

#include <objects/LinkedListNode.h>
#include <objects/Coder.h>

@implementation LinkedListNode

+ (void) initialize
{
  if (self == [LinkedListNode class])
    [self setVersion:0];	/* beta release */
}

- init
{
  [super init];
  _next = _prev = nil;
  return self;
}

- (void) encodeWithCoder: (Coder*)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeObjectReference:_next withName:"Next LinkedList Node"];
  [aCoder encodeObjectReference:_prev withName:"Prev LinkedList Node"];
}

+ newWithCoder: (Coder*)aCoder
{
  LinkedListNode *n = [super newWithCoder:aCoder];
  [aCoder decodeObjectAt:&(n->_next) withName:NULL];
  [aCoder decodeObjectAt:&(n->_prev) withName:NULL];
  return n;
}

- (id <LinkedListComprising>) nextLink
{
  return _next;
}

- (id <LinkedListComprising>) prevLink
{
  return _prev;
}

- setNextLink: (id <LinkedListComprising>)aLink
{
  _next = aLink;
  return self;
}

- setPrevLink: (id <LinkedListComprising>)aLink
{
  _prev = aLink;
  return self;
}

@end

