/* Structure counters and functions for getting at them.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Dec  3 00:23:13 EST 1995
 * Updated: Mon Mar 11 02:40:00 EST 1996
 * Serial: 96.03.11.03
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  */ 

/**** Included Headers *******************************************************/

#include <objects/numbers.h>

/**** Type, Constant, and Macro Definitions **********************************/

size_t ___objects_number_allocated = 0;
size_t ___objects_number_deallocated = 0;
size_t ___objects_number_serialized = 0;

/**** Function Implementations ***********************************************/

/* Returns the number of Libobjects structures allocated. */
size_t
_objects_number_allocated(void)
{
  return ___objects_number_allocated;
}

/* Returns the number of Libobjects structures deallocated. */
size_t
_objects_number_deallocated(void)
{
  return ___objects_number_deallocated;
}

/* Returns the next serial number to be handed out. */
size_t
_objects_number_serialized(void)
{
  return ___objects_number_serialized;
}

size_t
_objects_next_power_of_two(size_t bound)
{
  size_t start = 1;
  while ((start <= bound) && (start <<= 1));
  return start;
}
