/* Implementation for Objective-C Stack object
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

#include <objects/Stack.h>
#include <objects/ArrayPrivate.h>

@implementation Stack 
  
+ initialize
{
  if (self == [Stack class])
    [self setVersion:0];	/* beta release */
  return self;
}

- pushElement: (elt)anElement
{
  [self appendElement:anElement];
  return self;
}

/* Overriding */
- addElement: (elt)anElement
{
  [self pushElement:anElement];
  return self;
}

- (elt) popElement
{
  return [self removeLastElement];
}

- (elt) topElement
{
  return [self lastElement];
}

/* Yipes.  What copying semantics do we want here? */
- duplicateTop
{
  [self pushElement:[self topElement]];
  return self;
}

- exchangeTop
{
  if (_count <= 1)
    return nil;
  [self swapAtIndeces:_count-1 :_count-2];
  return self;
}

// OBJECT-COMPATIBLE MESSAGE NAMES;

- pushObject: anObject
{
  return [self pushElement:anObject];
}

- popObject
{
  return [self popElement].id_u;
}

- topObject
{
  return [self topElement].id_u;
}

@end
