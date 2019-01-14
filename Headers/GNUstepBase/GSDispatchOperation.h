/**Interface for GSDispatchOperation for GNUStep
   Copyright (C) 2019 Free Software Foundation, Inc.

   Written by:  Gregory Casamento <greg.casamento@gmail.com>
   Date: Jan 2019

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

#ifndef __GSDispatchOperation_h_GNUSTEP_BASE_INCLUDE
#define __GSDispatchOperation_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSOperation.h>

#if	defined(__cplusplus)
extern "C" {
#endif
  
@interface GSDispatchOperation : NSOperation
@end

@interface GSDispatchOperationQueue : NSOperationQueue
@end

#if	defined(__cplusplus)
}
#endif

#endif /* __GSDispatchQueue_h_GNUSTEP_BASE_INCLUDE */
