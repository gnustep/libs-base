/* Structure counters and functions for getting at them.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Dec  3 00:28:01 EST 1995
 * Updated: Sat Feb 10 15:51:02 EST 1996
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

#ifndef __number_h_OBJECTS_INCLUDE
#define __number_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>

/**** Type, Constant, and Macro Definitions **********************************/

extern size_t ___objects_number_allocated;
extern size_t ___objects_number_deallocated;
extern size_t ___objects_number_serial;

/**** Function Prototypes ****************************************************/

size_t _objects_number_allocated(void);

size_t _objects_number_deallocated(void);

size_t _objects_number_serial(void);

#endif /* __number_h_OBJECTS_INCLUDE */

