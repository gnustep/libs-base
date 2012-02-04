/* Copyright (C) 2011 Free Software Foundation, Inc.
   
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

#import "NSObject.h"
#import "NSGeometry.h"

@class NSArray;
@class NSDate;
@class NSDictionary;
@class NSOrthography;
@class NSRegularExpression;
@class NSString;
@class NSTimeZone;
@class NSURL;

typedef uint64_t NSTextCheckingType;
static const NSTextCheckingType NSTextCheckingTypeRegularExpression  = 1ULL<<10;

/**
 * NSTextCheckingResult is an abstract class encapsulating the result of some
 * operation that checks 
 */
@interface NSTextCheckingResult : NSObject
#if GS_HAS_DECLARED_PROPERTIES
@property(readonly) NSDictionary *addressComponents;
@property(readonly) NSDictionary *components;
@property(readonly) NSDate *date;
@property(readonly) NSTimeInterval duration;
@property(readonly) NSArray *grammarDetails;
@property(readonly) NSUInteger numberOfRanges;
@property(readonly) NSOrthography *orthography;
@property(readonly) NSString *phoneNumber;
@property(readonly) NSRange range;
@property(readonly) NSRegularExpression *regularExpression;
@property(readonly) NSString *replacementString;
@property(readonly) NSTextCheckingType resultType;
@property(readonly) NSTimeZone *timeZone;
@property(readonly) NSURL *URL;
#else
- (NSDictionary*) addressComponents;
- (NSDictionary*) components;
- (NSDate*) date;
- (NSTimeInterval) duration;
- (NSArray*) grammarDetails;
- (NSUInteger) numberOfRanges;
- (NSOrthography*) orthography;
- (NSString*) phoneNumber;
- (NSRange) range;
- (NSRegularExpression*) regularExpression;
- (NSString*) replacementString;
- (NSTextCheckingType) resultType;
- (NSTimeZone*) timeZone;
- (NSURL*) URL;
#endif
+ (NSTextCheckingResult*)
  regularExpressionCheckingResultWithRanges: (NSRangePointer)ranges
  count: (NSUInteger)count
  regularExpression: (NSRegularExpression*)regularExpression;
- (NSRange) rangeAtIndex: (NSUInteger)idx;
- (NSTextCheckingResult*) resultByAdjustingRangesWithOffset: (NSInteger)offset;
@end
