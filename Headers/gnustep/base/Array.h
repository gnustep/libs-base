/* Interface for Objective-C Array collection object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

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

#ifndef __Array_h_INCLUDE_GNU
#define __Array_h_INCLUDE_GNU

#include <gnustep/base/prefix.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/OrderedCollecting.h>

@interface ConstantArray : ConstantIndexedCollection
{
  @public
  id *_contents_array;
  unsigned int _count;
}
@end

@interface Array : ConstantArray
{
  @public
  unsigned int _capacity;
  int _grow_factor;
}

+ (unsigned) defaultCapacity;
+ (int) defaultGrowFactor;

- initWithCapacity: (unsigned) aCapacity;

- (void) setCapacity: (unsigned)newCapacity;
- (int) growFactor;
- (void) setGrowFactor: (int)aNum;

@end

/* Put this on category instead of class to avoid bogus complaint from gcc */
@interface Array (Ordering)  <OrderedCollecting>
@end

#define FOR_ARRAY(ARRAY, ELEMENT_VAR)                                  \
{                                                                      \
  unsigned _FOR_ARRAY_i;                                               \
  for (_FOR_ARRAY_i = 0;                                               \
       _FOR_ARRAY_i < ((Array*)ARRAY)->_count;                         \
       _FOR_ARRAY_i++)                                                 \
    {                                                                  \
      ELEMENT_VAR =                                                    \
	(((Array*)ARRAY)->_contents_array[_FOR_ARRAY_i]);

#define END_FOR_ARRAY(ARRAY) }}

#endif /* __Array_h_INCLUDE_GNU */
