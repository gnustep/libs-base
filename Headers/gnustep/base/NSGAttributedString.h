/* 
   NSGAttributedString.h

   Concrete subclass of a string class with attributes

   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: November 1997
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: April 1999
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/


/* Warning -	[-initWithString:attributes:] is the designated initialiser,
 *		but it doesn't provide any way to perform the function of the
 *		[-initWithAttributedString:] initialiser.
 *		In order to work youd this, the string argument of the
 *		designated initialiser has been overloaded such that it
 *		is expected to accept an NSAttributedString here instead of
 *		a string.  If you create an NSAttributedString subclass, you
 *		must make sure that your implementation of the initialiser
 *		copes with either an NSString or an NSAttributedString.
 *		If it receives an NSAttributedString, it should ignore the
 *		attributes argument and use the values from the string.
 */


#ifndef _NSGAttributedString_h_INCLUDE
#define _NSGAttributedString_h_INCLUDE

#include "NSAttributedString.h"

@interface NSGAttributedString : NSAttributedString
{
  NSString		*textChars;
  NSMutableArray	*infoArray;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes;
- (NSString*) string;
- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange;

@end

@interface NSGMutableAttributedString : NSMutableAttributedString
{
  NSMutableString	*textChars;
  NSMutableArray	*infoArray;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes;
- (NSString*) string;
- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange;
- (void) setAttributes: (NSDictionary*) attributes
		 range: (NSRange)range;
- (void) replaceCharactersInRange: (NSRange)range
		       withString: (NSString*)aString;

@end

#endif /* _NSGAttributedString_h_INCLUDE */
