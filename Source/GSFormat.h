/* GSFormat - printf-style formatting
    
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Kai Henningsen <kai@cats.ms>
   Created: Jan 2001

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
*/

#ifndef __GSFormat_h_GNUSTEP_BASE_INCLUDE_PRIVATE
#define __GSFormat_h_GNUSTEP_BASE_INCLUDE_PRIVATE

#include	<Foundation/NSZone.h>
#include	"GSPrivate.h"

@class	NSDictionary;

void
GSFormat(GSStr fb, const unichar *fmt, va_list ap, NSDictionary *loc);

#endif /* __GSFormat_h_GNUSTEP_BASE_INCLUDE_PRIVATE */

