/* Interface for Objective-C EltNodeCollector collection object
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

/* EltNodeCollector */

#ifndef __EltNodeCollector_h_INCLUDE_GNU
#define __EltNodeCollector_h_INCLUDE_GNU

#include <gnustep/base/prefix.h>
#include <gnustep/base/IndexedCollection.h>

/* Protocol for a node that also holds an element */
@protocol EltHolding
- initElement: (elt)anElement 
    encoding: (const char *)eltEncoding;
- (elt) elementData;
@end


/* It's is a bit unfortunate that we insist that the underlying
   collector conform to IndexedCollecting. */

@interface EltNodeCollector : IndexedCollection
{
  @private
  id _contents_collector;
  id _node_class;
  int (*_comparison_function)(elt,elt);
}


- initWithType: (const char *)contentEncoding
    nodeCollector: aNodeCollector
    nodeClass: aNodeClass;

// The class of the autocreated link objects, must conform to <EltHolding>;
- eltNodeClass;

// Getting the underlying node collector that holds the contents;
- contentsCollector;

// Finding the node that contains anElement;
- (id <EltHolding>) eltNodeWithElement: (elt)anElement;

@end

#endif /* __EltNodeCollector_h_INCLUDE_GNU */
