/* 
   NSAttributedString.h

   String class with attributes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: November 1997
   
   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

//FIXME: 1) The NSMutableString object returned from the -mutableString method
//       in NSMutableAttributedString is NOT tracked for changes to update
//       NSMutableAttributedString's attributes as it should.

//FIXME: 2) If out-of-memory exceptions are raised in some methods,
//       inconsistencies may develop, because the two internal arrays in
//       NSGAttributedString and NSGMutableAttributedString called
//       attributeArray and locateArray must always be syncronized.

//FIXME: 3) The method _setAttributesFrom: must be overridden by
//          concrete subclasses of NSAttributedString which is WRONG and
//          VERY bad! I haven't found any other way to make
//          - initWithString:attributes: the designated initializer 
//          in NSAttributedString and still implement
//          - initWithAttributedString: without having to override it
//          in the concrete subclass.

#ifndef _NSXKit_H_NSAttributedString
#define _NSXKit_H_NSAttributedString

#ifndef	STRICT_OPENSTEP
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>

@interface NSAttributedString : NSObject <NSCoding, NSCopying, NSMutableCopying>
{
  
}

//Creating an NSAttributedString
- (id)initWithString:(NSString *)aString;
- (id)initWithAttributedString:(NSAttributedString *)attributedString;
- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes;

//Retrieving character information
- (unsigned int)length;
- (NSString *)string;//Primitive method!

//Retrieving attribute information
- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange;//Primitive method!
- (NSDictionary *)attributesAtIndex:(unsigned int)index longestEffectiveRange:(NSRange *)aRange inRange:(NSRange)rangeLimit;
- (id)attribute:(NSString *)attributeName atIndex:(unsigned int)index effectiveRange:(NSRange *)aRange;
- (id)attribute:(NSString *)attributeName atIndex:(unsigned int)index longestEffectiveRange:(NSRange *)aRange inRange:(NSRange)rangeLimit;

//Comparing attributed strings
- (BOOL)isEqualToAttributedString:(NSAttributedString *)otherString;

//Extracting a substring
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)aRange;

@end //NSAttributedString


@interface NSMutableAttributedString : NSAttributedString
{
}

//Retrieving character information
- (NSMutableString *)mutableString;

//Changing characters
- (void)deleteCharactersInRange:(NSRange)aRange;

//Changing attributes
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange;//Primitive method!
- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)aRange;
- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)aRange;
- (void)removeAttribute:(NSString *)name range:(NSRange)aRange;

//Changing characters and attributes
- (void)appendAttributedString:(NSAttributedString *)attributedString;
- (void)insertAttributedString:(NSAttributedString *)attributedString atIndex:(unsigned int)index;
- (void)replaceCharactersInRange:(NSRange)aRange withAttributedString:(NSAttributedString *)attributedString;
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString;//Primitive method!
- (void)setAttributedString:(NSAttributedString *)attributedString;

//Grouping changes
- (void)beginEditing;
- (void)endEditing;

@end //NSMutableAttributedString

#endif //STRICT_OPENSTEP

#endif //_NSXKit_H_NSAttributedString

