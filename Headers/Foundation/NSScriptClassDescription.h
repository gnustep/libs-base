/* Definition of class NSScriptClassDescription
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

#ifndef _NSScriptClassDescription_h_GNUSTEP_BASE_INCLUDE
#define _NSScriptClassDescription_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSClassDescription.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSString, NSAttributedString, NSDictionary,
        NSError, NSLocale, NSNumber;

@interface NSScriptClassDescription : NSFormatter
{
#if	GS_EXPOSE(NSScriptClassDescription)
#endif
#if     GS_NONFRAGILE
#  if	defined(GS_NSScriptClassDescription_IVARS)
@public
GS_NSScriptClassDescription_IVARS;
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
  
- (instancetype) initWithSuiteName: (NSString *)suiteName 
                         className: (NSString *)className 
                        dictionary: (NSDictionary *)classDeclaration;
+ (NSScriptClassDescription *) classDescriptionForClass: (Class)aClass;
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSByteCountFormatter_h_GNUSTEP_BASE_INCLUDE */

