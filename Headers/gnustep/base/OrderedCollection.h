/* Interface for Objective-C Ordered Collection object.
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: February 1996

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

#ifndef __OrderedCollection_h_INCLUDE_GNU
#define __OrderedCollection_h_INCLUDE_GNU

#include <gnustep/base/preface.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/OrderedCollecting.h>

@interface OrderedCollection : IndexedCollection
@end


/* Put this on category instead of class to avoid bogus complaint from gcc */
@interface OrderedCollection (Protocol) <OrderedCollecting>
@end

#endif /* __OrderedCollection_h_INCLUDE_GNU */
