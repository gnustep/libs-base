/* Interface to NSUser functions for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Martin Michlmayer 
   Date: 1995
 
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

   See NSUser.c for additional information. */


#ifndef __NSUser_h_GNUSTEP_BASE_INCLUDE
#define __NSUser_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

NSString* NSUserName (void);
NSString* NSHomeDirectory (void);
NSString* NSDirectoryForUser (char * userName);

#endif /* __NSUser_h_GNUSTEP_BASE_INCLUDE */

