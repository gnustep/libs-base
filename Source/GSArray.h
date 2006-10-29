/** Concrete implementation of NSArray
   Copyright (C) 1995-2006 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   Rewrite by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Header by:   Sheldon Gill <sheldon@westnet.net.au>

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date: 2006-08-13 19:25:13 +0800 (Sun, 13 Aug 2006) $ $Revision: 23275 $
*/

#ifndef __GSArray_h_GNUSTEP_BASE_INCLUDE_PRIVATE
#define __GSArray_h_GNUSTEP_BASE_INCLUDE_PRIVATE

/* ********************************************************* */
/* **** Internal Header for Private use by gnustep-base **** */
/* ********************************************************* */

@class	GSArray;

@interface GSArrayEnumerator : NSEnumerator
{
  GSArray	*array;
  unsigned	pos;
}
- (id) initWithArray: (GSArray*)anArray;
@end

@interface GSArrayEnumeratorReverse : GSArrayEnumerator
@end


@interface GSArray : NSArray
{
@public
  id		*_contents_array;
  unsigned	_count;
}
@end

@interface GSInlineArray : GSArray
{
}
@end

@interface GSMutableArray : NSMutableArray
{
@public
  id		*_contents_array;
  unsigned	_count;
  unsigned	_capacity;
  int		_grow_factor;
}
@end

@interface GSPlaceholderArray : NSArray
{
}
@end

#endif /* __GSArray_h_GNUSTEP_BASE_INCLUDE_PRIVATE */
