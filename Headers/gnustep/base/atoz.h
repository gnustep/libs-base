/* Handling the interface between allocs and zones.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Oct 15 10:40:40 EDT 1994
 * Updated: Sat Feb 10 15:11:01 EST 1996
 * Serial: 96.02.10.03
 * 
 * This file is part of the GNU Objective C Class Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 
 */ 

/**** Included Headers *******************************************************/

#include <objects/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/**** Function Implementations ***********************************************/

#ifndef __???_h_OBJECTS_INCLUDE
#define __???_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <objects/allocs.h>
#include <objects/callbacks.h>

/**** Function Prototypes ****************************************************/

/** Translating from Zones to Allocs **/

objects_allocs_t
objects_allocs_for_zone (NSZone * zone);

#endif /* __???_h_OBJECTS_INCLUDE */
