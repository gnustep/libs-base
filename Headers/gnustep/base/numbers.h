/* Structure counters and functions for getting at them.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Dec  3 00:28:01 EST 1995
 * Updated: Mon Mar 18 14:36:49 EST 1996
 * Serial: 96.03.18.03
 * 
 * This file is part of the GNUstep Base Library.
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

#ifndef __numbers_h_GNUSTEP_BASE_INCLUDE
#define __numbers_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>

/**** Type, Constant, and Macro Definitions **********************************/

/** Magic numbers... **/

/* Magic numbers for the different types of structures... */
#define OBJECTS_MAGIC_ARRAY 0x1b658008	/* Thu Mar  2 02:28:50 EST 1994 */
#define OBJECTS_MAGIC_DATA  0x1b651971	/* Fri Nov 24 21:46:14 EST 1995 */
#define OBJECTS_MAGIC_HASH  0x1b653ee5	/* ??? ??? ?? ??:??:?? ??? 1993 */
#define OBJECTS_MAGIC_HEAP  0x1b65beef	/* Tue Sep  5 17:21:34 EDT 1995 */
#define OBJECTS_MAGIC_LIST  0x1b65600d	/* Tue Sep  5 17:23:50 EDT 1995 */
#define OBJECTS_MAGIC_MAP   0x1b65abba	/* ??? ??? ?? ??:??:?? ??? 1993 */

/* WARNING: Don't use these.  They are not guaranteed to remain in future
 * editions of this file.  They are here only as a cheap fix for an
 * annoying little problem. */
/* FIXME: Get rid of these.  See `x-basics.[ch].in'
 * and `x-callbacks.[ch].in'. */
#define _OBJECTS_MAGIC_array      OBJECTS_MAGIC_ARRAY
#define _OBJECTS_MAGIC_data       OBJECTS_MAGIC_DATA
#define _OBJECTS_MAGIC_hash       OBJECTS_MAGIC_HASH
#define _OBJECTS_MAGIC_heap       OBJECTS_MAGIC_HEAP
#define _OBJECTS_MAGIC_list       OBJECTS_MAGIC_LIST
#define _OBJECTS_MAGIC_map        OBJECTS_MAGIC_MAP

/* Internal counters for the three functions below.  They are placed here
 * purely for your viewing pleasure.  WARNING: Do not mess with these
 * unless you know what you're doing. */
extern size_t ___o_number_allocated;
extern size_t ___o_number_deallocated;
extern size_t ___o_number_serialized;

/**** Function Prototypes ****************************************************/

/* Returns the number of hash tables, map tables, lists,
 * and sparse arrays allocated thus far. */
size_t
_o_number_allocated(void);

/* Returns the number of hash tables, map tables, lists,
 * and sparse arrays deallocated thus far. */
size_t 
_o_number_deallocated(void);

/* Returns (but does not increment) the number of hash tables,
 * map tables, lists, and sparse arrays given serial numbers thus far. */
size_t 
_o_number_serialized(void);

/* Returns the least power of two strictly greater than BOUND. */
size_t
_o_next_power_of_two(size_t bound);

#endif /* __numbers_h_GNUSTEP_BASE_INCLUDE */

