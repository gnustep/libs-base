#ifndef	INCLUDED_GS_CATEGORIES_H
#define	INCLUDED_GS_CATEGORIES_H
/** Declaration of extension methods to standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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

   AutogsdocSource: Additions/GSCategories.m

*/

#ifndef	NO_GNUSTEP

@interface NSCalendarDate (GSCategories)

- (int) weekOfYear;

@end

#endif	/* NO_GNUSTEP */
#endif	/* INCLUDED_GS_CATEGORIES_H */
