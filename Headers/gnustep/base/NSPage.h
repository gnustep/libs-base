/* Page memory management. -*- Mode: ObjC -*-
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@power1.snu.ac.kr>
   Date: November 1996

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#ifndef __NSPage_h_GNUSTEP_BASE_INCLUDE
#define __NSPage_h_GNUSTEP_BASE_INCLUDE

extern unsigned NSPageSize (void) __attribute__ ((const));

extern unsigned NSLogPageSize (void) __attribute__ ((const));

extern unsigned NSRoundDownToMultipleOfPageSize (unsigned bytes)
  __attribute__ ((const));

extern unsigned NSRoundUpToMultipleOfPageSize (unsigned bytes)
  __attribute__ ((const));

extern unsigned NSRealMemoryAvailable (void);

extern void* NSAllocateMemoryPages (unsigned bytes);

extern void NSDeallocateMemoryPages (void *ptr, unsigned bytes);

extern void NSCopyMemoryPages (const void *src, void *dest, unsigned bytes);

#endif /* not __NSPage_h_GNUSTEP_BASE_INCLUDE */
