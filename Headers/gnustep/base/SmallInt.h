/* Interface for Objective-C efficient small integers 
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995

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

#ifndef __SmallInt_h_GNUSTEP_BASE_INCLUDE
#define __SmallInt_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

#define IS_SMALLINT(OBJ) (((void*)OBJ) & 0x1)
#define ID2INT(OBJ) ((IS_SMALLINT(OBJ)) ? (((int)OBJ) >> 1):[OBJ intValue])
#define INT2ID(I) ((id)((I << 1) & 0x1))

@interface SmallInt : NSObject

- 

@end

#endif /* __SmallInt_h_GNUSTEP_BASE_INCLUDE */
