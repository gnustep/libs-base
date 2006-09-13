/** Additional functions for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: 2005
   
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
 
   AutogsdocSource:	Additions/GSFunctions.m
   */ 

#ifndef __GSFunctions_h_GNUSTEP_BASE_INCLUDE
#define __GSFunctions_h_GNUSTEP_BASE_INCLUDE

#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSObjCRuntime.h"
#include "GNUstepBase/GNUstep.h"

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSArray;
@class	NSString;

/** 
 * Try to locate file/directory (aName).(anExtension) in paths.
 * Will return the first found or nil if nothing is found.
 */
GS_EXPORT NSString *GSFindNamedFile(NSArray *paths, NSString *aName,
  NSString *anExtension);

#if	defined(__cplusplus)
}
#endif

#endif /* __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE */
