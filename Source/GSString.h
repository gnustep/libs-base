/* Definition for GNUStep of NSString concrete subclasses
   Copyright (C) 1997-2006 Free Software Foundation, Inc.

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

   $Date: 2006-10-28 16:43:48 +0800 (Sat, 28 Oct 2006) $ $Revision: 23979 $
*/

#ifndef __GSString_h_GNUSTEP_BASE_INCLUDE_PRIVATE
#define __GSString_h_GNUSTEP_BASE_INCLUDE_PRIVATE

/*
 * Type to hold either UTF-16 (unichar) or 8-bit encodings,
 * while satisfying alignment constraints.
 */
typedef union {
  unichar *u;       // 16-bit unicode characters.
  unsigned char *c; // 8-bit characters.
} GSCharPtr;

/*
 * Private concrete string classes.
 * NB. All these concrete string classes MUST have the same initial ivar
 * layout so that we can swap between them as necessary.
 * The initial layout must also match that of NXConstantString (which is
 * determined by the compiler) - an initial pointer to the string data
 * followed by the string length (number of characters).
 */
@interface GSString : NSString
{
  GSCharPtr _contents;
  unsigned int	_count;
  struct {
    unsigned int	wide: 1;	// 16-bit characters in string?
    unsigned int	free: 1;	// Set if the instance owns the
                                // _contents buffer
    unsigned int    fixed:  1;  // is fixed buffer
    unsigned int	unused: 1;
    unsigned int	hash: 28;
  } _flags;
}
@end

/*
 * GSMutableString - concrete mutable string, capable of changing its storage
 * from holding 8-bit to 16-bit character set.
 */
@interface GSMutableString : NSMutableString
{
  union {
    unichar		*u;
    unsigned char	*c;
  } _contents;
  unsigned int	_count;
  struct {
    unsigned int	wide: 1;
    unsigned int	free: 1;
    unsigned int    fixed:  1;
    unsigned int	unused: 1;
    unsigned int	hash: 28;
  } _flags;
  NSZone	*_zone;
  unsigned int	_capacity;
}
@end

/*
 * Typedef for access to internals of concrete string objects.
 */
typedef struct {
  @defs(GSMutableString)
} GSStr_t;
typedef	GSStr_t	*GSStr;

/*
 * Functions to append to GSStr
 */
extern void GSStrAppendUnichar(GSStr s, unichar);
extern void GSStrAppendUnichars(GSStr s, const unichar *u, unsigned l);

#endif /* __GSString_h_GNUSTEP_BASE_INCLUDE_PRIVATE */
