/* Protocol for GNU Objective-C objects that understand an invalidation msg
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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
   */ 

#ifndef __InvalidationListening_h_GNUSTEP_BASE_INCLUDE
#define __InvalidationListening_h_GNUSTEP_BASE_INCLUDE

/* This protocol is just temporary.  It will disappear when GNU writes
   a more general notification system.
   It is not recommended that you use it in your code. */

@protocol InvalidationListening

- senderIsInvalid: sender;

@end

#endif /* __InvalidationListening_h_GNUSTEP_BASE_INCLUDE */
