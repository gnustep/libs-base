/* IndexedCollection definitions for the use of subclass implementations only
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

#ifndef __IndexedCollectionPrivate_h_INCLUDE_GNU
#define __IndexedCollectionPrivate_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/CollectionPrivate.h>

/* To be used inside a method for making sure that index
   is not above range.
*/
#define CHECK_INDEX_RANGE_ERROR(INDEX, OVER) \
({if (INDEX >= OVER) \
  [self error:"in %s, index out of range", sel_get_name(_cmd)];})


/* For use with subclasses of IndexedCollections that allow elements to
   be added, but not added at particular indices---the collection itself 
   determines the order.
*/
#define INSERTION_ERROR() \
([self error:"in %s, this collection does not allow insertions", \
	sel_get_name(aSel)];)


#endif /* __IndexedCollectionPrivate_h_INCLUDE_GNU */
