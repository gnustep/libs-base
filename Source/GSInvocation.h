/* Interface for NSInvocation concrete classes for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written: Adam Fedor <fedor@gnu.org>
   Date: Nov 2000
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#ifndef __GSInvocation_h_GNUSTEP_BASE_INCLUDE
#define __GSInvocation_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSInvocation.h>

@interface GSFFIInvocation : NSInvocation
{
  uint8_t	_retbuf[32];	// Store return values of up to 32 bytes here.
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

#define CLEAR_RETURN_VALUE_IF_OBJECT  do { if (_validReturn && *_info[0].type == _C_ID) \
                                            { \
                                            RELEASE (*(id*) _retval); \
                                            *(id*) _retval = nil; \
                                            _validReturn = NO; \
                                            }\
                                        } while (0)

#define RETAIN_RETURN_VALUE IF_NO_GC(do { if (*_info[0].type == _C_ID) RETAIN (*(id*) _retval);} while (0))                                         

#endif
