/* Interface for NSValueTransformer for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written Dr. H. Nikolaus Schaller
   Created on Mon Mar 21 2005.
   
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

#ifndef __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE
#define __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(100300,GS_API_LATEST) && GS_API_VERSION(010200,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

GS_EXPORT NSString* const NSNegateBooleanTransformerName;
GS_EXPORT NSString* const NSIsNilTransformerName;
GS_EXPORT NSString* const NSIsNotNilTransformerName; 
GS_EXPORT NSString* const NSUnarchiveFromDataTransformerName;

@class NSString;

@interface NSValueTransformer : NSObject

+ (BOOL) allowsReverseTransformation;
+ (void) setValueTransformer: (NSValueTransformer *)transformer
		     forName: (NSString *)name;
+ (Class) transformedValueClass;
+ (NSValueTransformer *) valueTransformerForName: (NSString *)name;
+ (NSArray *) valueTransformerNames;

- (id) reverseTransformedValue: (id)value;
- (id) transformedValue: (id)value;

@end

// builtin transformers

@interface NSNegateBooleanTransformer : NSValueTransformer
@end

@interface NSIsNilTransformer : NSValueTransformer
@end

@interface NSIsNotNilTransformer : NSValueTransformer
@end

@interface NSUnarchiveFromDataTransformer : NSValueTransformer
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION */

#endif /* __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE */
