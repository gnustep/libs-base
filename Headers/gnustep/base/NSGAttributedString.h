/* 
   NSGAttributedString.h

   Concrete subclass of a string class with attributes

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

#ifndef _NSGAttributedString_h_INCLUDE
#define _NSGAttributedString_h_INCLUDE

#include "NSAttributedString.h"

@interface NSGAttributedString : NSAttributedString
{
  NSString *textChars;
  NSMutableArray *attributeArray;
  NSMutableArray *locateArray;
}

- _setAttributesFrom:(NSAttributedString *)attributedString range:(NSRange)aRange;
- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes;
- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange;

@end

@interface NSGMutableAttributedString : NSMutableAttributedString
{
  NSMutableString *textChars;
  NSMutableArray *attributeArray;
  NSMutableArray *locateArray;
}

- _setAttributesFrom:(NSAttributedString *)attributedString range:(NSRange)aRange;
- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes;
- (NSString *)string;
- (NSMutableString *)mutableString;
- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString;

@end

#endif /* _NSGAttributedString_h_INCLUDE */
