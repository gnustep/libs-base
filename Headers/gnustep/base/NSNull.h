/* Interface for NSNull for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2000
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __NSNull_h_GNUSTEP_BASE_INCLUDE
#define __NSNull_h_GNUSTEP_BASE_INCLUDE

/*
 * An object to use as a placeholder - in collections for instance.
 */
#ifndef	NO_MACOS_X
#include <Foundation/NSObject.h>

@interface	NSNull : NSObject <NSCoding, NSCopying>
+ (NSNull*) null;
@end

#endif

#endif /* __NSNull_h_GNUSTEP_BASE_INCLUDE */
