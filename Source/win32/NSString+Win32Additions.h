/** Category for converting Windows Strings
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Hugo Melder <hugo@algoriddim.com>
   Created: July 2024

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/NSString.h>

#include <wchar.h>

/**
 * Converts a wchar_t list to an array of strings.
 * The list is NULL-delimited and terminated by two NULL (wchar_t) characters.
 *
 * The encoding is Unicode (UTF-16LE).
 */
@interface NSString (Win32Additions)

+ (GS_GENERIC_CLASS(NSArray, NSString *) *) arrayFromWCharList: (wchar_t *)list
						                                      length: (unsigned long)length;

@end
