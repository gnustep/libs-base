/* Definition of class NSHFSFileTypes
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Fri Nov  1 00:25:22 EDT 2019

   This file is part of the GNUstep Library.
   
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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSHFSFileTypes_h_GNUSTEP_BASE_INCLUDE
#define _NSHFSFileTypes_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif
  
@class NSString;

GS_EXPORT NSString *NSFileTypeForHFSTypeCode(NSUInteger hfsFileTypeCode);

GS_EXPORT NSUInteger NSHFSTypeCodeFromFileType(NSString *fileTypeString);

GS_EXPORT NSString *NSHFSTypeOfFile(NSString *fullFilePath);

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSHFSFileTypes_h_GNUSTEP_BASE_INCLUDE */

