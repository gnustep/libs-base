/* Macros for bit-wise operations.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 21:17:10 EST 1996
 * Updated: Sat Feb 10 21:17:10 EST 1996
 * Serial: 96.02.10.01
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

#ifndef __bits_h_OBJECTS_INCLUDE
#define __bits_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

/**** Type, Constant, and Macro Definitions **********************************/

/** Bit operations **/

/* Set the Nth bit of V to one. */
#define OBJECTS_BIT_POKE(V,N)  ((V) |= (1 << (N)))

/* Set the Nth bit of V to zero. */
#define OBJECTS_BIT_NOCK(V,N)  ((V) &= ~(1 << (N)))

/* Toggle the Nth bit of V. */
#define OBJECTS_BIT_PLUK(V,N)  ((V) ^= (1 << (N)))

/* Grab the Nth bit of V. */
#define OBJECTS_BIT_PEEK(V,N)  ((V) & (1 << (N)))

/**** Function Prototypes ****************************************************/

#endif /* __bits_h_OBJECTS_INCLUDE */

