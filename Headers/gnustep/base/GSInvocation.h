/* Interface for NSInvocation concrete classes for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written: Adam Fedor <fedor@gnu.org>
   Date: Nov 2000
   
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

#ifndef __GSInvocation_h_GNUSTEP_BASE_INCLUDE
#define __GSInvocation_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSInvocation.h>

@interface GSFFIInvocation : NSInvocation
{
}
@end

@interface GSFFCallInvocation : NSInvocation
{
}
@end

@interface GSFrameInvocation : NSInvocation
{
}
@end

@interface NSInvocation (DistantCoding)
- (BOOL) encodeWithDistantCoder: (NSCoder*)coder passPointers: (BOOL)passp;
@end

extern void
GSFFCallInvokeWithTargetAndImp(NSInvocation *inv, id anObject, IMP imp);

extern void
GSFFIInvokeWithTargetAndImp(NSInvocation *inv, id anObject, IMP imp);

#endif
