/* Magic numbers for identifying Libobjects structures.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Mar  2 02:10:10 EST 1994
 * Updated: Sat Feb 10 15:42:11 EST 1996
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

#ifndef __magic_h_OBJECTS_INCLUDE
#define __magic_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

/**** Type, Constant, and Macro Definitions **********************************/

/** Magic numbers **/

#define OBJECTS_MAGIC_ARRAY 0xfa138008	/* Thu Mar  2 02:28:50 EST 1994 */
#define OBJECTS_MAGIC_DATA  0xfa131971	/* Fri Nov 24 21:46:14 EST 1995 */
#define OBJECTS_MAGIC_HASH  0xfa133ee5	/* ??? ??? ?? ??:??:?? ??? 1993 */
#define OBJECTS_MAGIC_HEAP  0xfa13beef	/* Tue Sep  5 17:21:34 EDT 1995 */
#define OBJECTS_MAGIC_LIST  0xfa13600d	/* Tue Sep  5 17:23:50 EDT 1995 */
#define OBJECTS_MAGIC_MAP   0xfa13abba	/* ??? ??? ?? ??:??:?? ??? 1993 */

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

#endif /* __magic_h_OBJECTS_INCLUDE */

