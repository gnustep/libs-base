/* A hookable abort function for Libobjects.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sat Feb 10 12:34:27 EST 1996
 * Updated: Sat Feb 10 15:49:43 EST 1996
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

#ifndef __abort_h_OBJECTS_INCLUDE
#define __abort_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

/**** Type, Constant, and Macro Definitions **********************************/

extern void (*__objects_abort) (void);

/**** Function Prototypes ****************************************************/

void objects_abort (void);

#endif /* __abort_h_OBJECTS_INCLUDE */

