/* GNU extensions to NSArray.
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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

/* You can include this instead of (or in addition to)
   foundation/NSString.h if you want to use the GNU extensions.  The
   primary GNU extention is that NSString objects now conform to
   IndexedCollecting---they are Collection objects just like in
   Smalltalk. */

#ifndef __objects_NSString_h_OBJECTS_INCLUDE
#define __objects_NSString_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/IndexedCollecting.h>
#include <objects/String.h>

/* Eventually we'll make a Contant version of this protocol. */
@interface NSArray (GNU) <IndexedCollecting>
@end

@interface NSMutableArray (GNU)
+ (unsigned) defaultCapacity;
+ (unsigned) defaultGrowFactor;
- setCapacity: (unsigned)newCapacity;
- (unsigned) growFactor;
- setGrowFactor: (unsigned)aNum;
@end

#endif /* __objects_NSString_h_OBJECTS_INCLUDE */
