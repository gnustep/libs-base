/* Interface to NSString implementation with Unicode-string backing
   Copyright (C) 1995 Free Software Foundation, Inc.

   Unicode implementation by: Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997
   
   Based on NSGCSting written by: Andrew Kachites McCallum
   <mccallum@gnu.ai.mit.edu>
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef __NSGString_h_GNUSTEP_BASE_INCLUDE
#define __NSGString_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <Foundation/NSString.h>

/* NSGString and NSGMutableString must have the same initial ivar layout
   because of class_add_behavior() in NSGMutableString's +initialize. */

@interface NSGString : NSString
{
  unichar * _contents_chars;
  int _count;
  NSZone *_zone;
  unsigned _hash;
}
@end

@interface NSGMutableString : NSMutableString
{
  unichar * _contents_chars;
  int _count;
  NSZone *_zone;
  unsigned _hash;
  int _capacity;
}
@end

#endif /* __NSGString_h_GNUSTEP_BASE_INCLUDE */
