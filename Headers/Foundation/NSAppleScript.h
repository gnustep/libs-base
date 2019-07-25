/* Definition of class NSAppleScript
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Written by: 	Gregory Casamento <greg.casamento@gmail.com>
   Date: 	July 2019
   
   This file is part of the GNUstep Library.
   
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

#ifndef _NSAppleScript_h_GNUSTEP_BASE_INCLUDE
#define _NSAppleScript_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSFormatter.h>
#import	<Foundation/NSDecimalNumber.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSString, NSDictionary, NSAppleEventDescriptor;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
  
@interface NSAppleScript : NSObject
{
#if	GS_EXPOSE(NSAppleScript)
#endif
#if     GS_NONFRAGILE
#  if	defined(GS_NSAppleScript_IVARS)
@public
GS_NSAppleScript_IVARS;
#  endif
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

- (instancetype)initWithContentsOfURL:(NSURL *)url 
                                error:(NSDictionary *)errorInfo;

- (instancetype)initWithSource:(NSString *)source;

- (BOOL) isCompiiled;

- (NSString *) source;

- (BOOL)compileAndReturnError: (NSDictionary *)errorInfo;

- (NSAppleEventDescriptor *)executeAndReturnError: (NSDictionary *)errorInfo;

- (NSAppleEventDescriptor *)executeAppleEvent: (NSAppleEventDescriptor *)event 
                                        error: (NSDictionary *)errorInfo;
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSAppleScript_h_GNUSTEP_BASE_INCLUDE */

