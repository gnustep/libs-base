/* Interface for NSCharacterSet for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995
   
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

#ifndef __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE
#define __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

@class NSData;

@interface NSCharacterSet : NSObject <NSCoding, NSCopying, NSMutableCopying>

// Creating standard character sets
+ (NSCharacterSet *)alphanumericCharacterSet;
+ (NSCharacterSet *)controlCharacterSet;
+ (NSCharacterSet *)decimalDigitCharacterSet;
+ (NSCharacterSet *)decomposableCharacterSet;
+ (NSCharacterSet *)illegalCharacterSet;
+ (NSCharacterSet *)letterCharacterSet;
+ (NSCharacterSet *)lowercaseLetterCharacterSet;
+ (NSCharacterSet *)nonBaseCharacterSet;
+ (NSCharacterSet *)punctuationCharacterSet;
+ (NSCharacterSet *)symbolAndOperatorCharacterSet;
+ (NSCharacterSet *)uppercaseLetterCharacterSet;
+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet;
+ (NSCharacterSet *)whitespaceCharacterSet;

// Creating custom character sets
+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data;
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)aString;
+ (NSCharacterSet *)characterSetWithRange:(NSRange)aRange;

- (NSData *)bitmapRepresentation;
- (BOOL)characterIsMember:(unichar)aCharacter;
- (NSCharacterSet *)invertedSet;

#ifndef	STRICT_MACOS_X
+ (NSCharacterSet*) characterSetWithContentsOfFile: (NSString*)file;
#endif
@end

@interface NSMutableCharacterSet : NSCharacterSet

- (void)addCharactersInRange:(NSRange)aRange;
- (void)addCharactersInString:(NSString *)aString;
- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void)removeCharactersInRange:(NSRange)aRange;
- (void)removeCharactersInString:(NSString *)aString;
- (void)invert;

@end

#endif /* __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE */
