/* Interface for relase pools for delayed disposal
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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

#ifndef __AutoreleasePool_m_GNUSTEP_BASE_INCLUDE
#define __AutoreleasePool_m_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/ObjectRetaining.h>

@interface AutoreleasePool : Object
{
  AutoreleasePool *parent;
  unsigned released_count;
  unsigned released_size;
  id *released;
}

+ currentPool;
+ (void) autoreleaseObject: anObj;
- (void) autoreleaseObject: anObj;

- init;

@end

@interface Object (Retaining) <Retaining>
@end

void objc_retain_object (id anObj);
void objc_release_object (id anObj);
unsigned objc_retain_count (id anObj);

#endif /* __AutoreleasePool_m_GNUSTEP_BASE_INCLUDE */
