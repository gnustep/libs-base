/* IndexedCollection definitions for the use of subclass implementations only
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#ifndef __IndexedCollectionPrivate_h_GNUSTEP_BASE_INCLUDE
#define __IndexedCollectionPrivate_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/CollectionPrivate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

/* To be used inside a method for making sure that index
   is not above range.
*/
#define CHECK_INDEX_RANGE_ERROR(INDEX, OVER) \
if (INDEX >= OVER) \
  [NSException raise: NSRangeException \
               format: @"in %s, index %d is out of range", \
               sel_get_name (_cmd), INDEX]

#endif /* __IndexedCollectionPrivate_h_GNUSTEP_BASE_INCLUDE */
