/* Interface for Objective-C Sequential Collection object.
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

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

#ifndef __IndexedCollection_h_GNUSTEP_BASE_INCLUDE
#define __IndexedCollection_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/KeyedCollection.h>
#include <gnustep/base/IndexedCollecting.h>

@interface ConstantIndexedCollection : ConstantCollection 
@end

@interface IndexedCollection : ConstantIndexedCollection
@end

@interface ReverseEnumerator : Enumerator
@end

/* Put this on category instead of class to avoid bogus complaint from gcc */
@interface ConstantIndexedCollection (Protocol) <ConstantIndexedCollecting>
@end
@interface IndexedCollection (Protocol) <IndexedCollecting>
@end

#define FOR_INDEXED_COLLECTION(ACOLL, ELT) \
{ \
   void *_es = [ACOLL newEnumState]; \
   while ((ELT = [ACOLL nextObjectWithEnumState: &_es])) \
     {

#define END_FOR_INDEXED_COLLECTION(ACOLL) \
     } \
   [ACOLL freeEnumState: &_es]; \
}

#define FOR_INDEXED_COLLECTION_REVERSE(ACOLL, ELT) \
{ \
   void *_es = [ACOLL newEnumState]; \
   while ((ELT = [ACOLL prevObjectWithEnumState: &_es])) \
     {

#define END_FOR_INDEXED_COLLECTION_REVERSE(ACOLL) \
     } \
   [ACOLL freeEnumState: &_es]; \
}

#define FOR_INDEXED_COLLECTION_WHILE_TRUE(ACOLL, ELT, FLAG) \
{ \
   void *_es = [ACOLL newEnumState]; \
   while (FLAG && (ELT = [ACOLL nextObjectWithEnumState: &_es])) \
     {

#define END_FOR_INDEXED_COLLECTION_WHILE_TRUE(ACOLL) \
     } \
   [ACOLL freeEnumState: &_es]; \
}


/* The only subclassResponsibilities in IndexedCollection are:

      insertElement:atIndex:
      removeElementAtIndex:
      elementAtIndex:

   but subclass will want to override others as well in order to 
   increase efficiency.  The following are especially important if
   the subclass's implementation of "elementAtIndex:" is not efficient:

      replaceElementAtIndex:with:
      swapAtIndeces::
      shallowCopyReplaceFrom:to:with:
      sortAddElement:byCalling:
      removeElement:
      firstElement
      lastElement
      shallowCopyFrom:to:
      withElementsCall:whileTrue:
      withElementsInReverseCall:whileTrue:

   and perhaps:

      appendElement:
      prependElement:
      indexOfElement:
      withElementsInReverseCall:

*/


#endif /* __IndexedCollection_h_GNUSTEP_BASE_INCLUDE */
