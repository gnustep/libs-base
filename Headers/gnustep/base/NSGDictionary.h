/* Interface to concrete implementation of NSDictionary based on GNU Array
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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

#ifndef __NSGDictionary_h_GNUSTEP_BASE_INCLUDE
#define __NSGDictionary_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSDictionary.h>
#include <gnustep/base/Dictionary.h>

@interface NSGDictionary : NSDictionary
@end

@interface NSGMutableDictionary : NSMutableDictionary
@end

#endif /* __NSGDictionary_h_GNUSTEP_BASE_INCLUDE */
