/* GCC macros for minimum and maximum.
 * Copyright (C) 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 21:13:04 EST 1996
 * Updated: Sat Feb 10 21:13:04 EST 1996
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

#ifndef __minmax_h_OBJECTS_INCLUDE
#define __minmax_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

/**** Type, Constant, and Macro Definitions **********************************/

#ifdef MIN
#undef MIN
#endif /* !MIN */

#define MIN(X, Y) \
({ typeof (X) __x = (X), __y = (Y); \
   (__x < __y) ? __x : __y; })

#ifdef MAX
#undef MAX
#endif /* !MAX */

#define MAX(X, Y) \
({ typeof (X) __x = (X), __y = (Y); \
   (__x > __y) ? __x : __y; })

#endif /* __minmax_h_OBJECTS_INCLUDE */

