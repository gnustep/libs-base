/* Interface to NSString implementation with C-string backing
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
*/

#ifndef __NSGCString_h_GNUSTEP_BASE_INCLUDE
#define __NSGCString_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <Foundation/NSString.h>

/*
 *	NSGCString and NSGMutableCString must have the same initial ivar layout
 *	because of class_add_behavior() in NSGMutableCString's +initialize
 *	and because the various string classes (and NSGDictionary) examine and
 *	set each others _hash ivar directly for performance reasons!
 */

@interface NSGCString : NSString
{
  unsigned char	*_contents_chars;
  unsigned	_count;
  NSZone	*_zone;
  unsigned	_hash;
}
@end

@interface NSGMutableCString : NSMutableString
{
  unsigned char	* _contents_chars;
  unsigned	_count;
  NSZone	*_zone;
  unsigned	_hash;
  unsigned	_capacity;
}
@end

#endif /* __NSGCString_h_GNUSTEP_BASE_INCLUDE */
