/* Definitions for NSScanner class
   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Eric Norum <eric@skatter.usask.ca>
   Created: 1996
   
   This file is part of the GNUstep Objective-C Library.

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

#ifndef __NSScanner_h_GNUSTEP_INCLUDE
#define __NSScanner_h_GNUSTEP_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCharacterSet.h>

//
// NSScanner class
//
@interface NSScanner : NSObject <NSCopying>
{
@private
   NSString        *string;
   unsigned int    len;
   NSCharacterSet  *charactersToBeSkipped;
   NSDictionary    *locale;
   unsigned int    scanLocation;
   BOOL            caseSensitive;
}

/*
 * Creating an NSScanner
 */
+ localizedScannerWithString:(NSString *)aString;
+ scannerWithString:(NSString *)aString;
- initWithString:(NSString *)aString;

/*
 * Getting an NSScanner's string
 */
- (NSString *)string;

/*
 * Configuring an NSScanner
 */
- (unsigned)scanLocation;
- (void)setScanLocation:(unsigned int)anIndex;
- (BOOL)caseSensitive;
- (void)setCaseSensitive:(BOOL)flag;
- (NSCharacterSet *)charactersToBeSkipped;
- (void)setCharactersToBeSkipped:(NSCharacterSet *)aSet;
- (NSDictionary *)locale;
- (void)setLocale:(NSDictionary *)localeDictionary;

/*
 * Scanning a string
 */
- (BOOL)scanInt:(int *)value;
- (BOOL)scanRadixUnsignedInt:(unsigned int *)value;
- (BOOL)scanLongLong:(long long *)value;
- (BOOL)scanFloat:(float *)value;
- (BOOL)scanDouble:(double *)value;
- (BOOL)scanString:(NSString *)string intoString:(NSString **)value;
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)aSet
                   intoString:(NSString **)value;
- (BOOL)scanUpToString:(NSString *)string intoString:(NSString **)value;
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)aSet 
                       intoString:(NSString **)value;
- (BOOL)isAtEnd;

@end

#endif /* __NSScanner_h_GNUSTEP_INCLUDE */
