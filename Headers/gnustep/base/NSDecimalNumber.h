/* Interface of NSDecimalNumber class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: November 1998

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */

#ifndef __NSDecimalNumber_h_GNUSTEP_BASE_INCLUDE
#define __NSDecimalNumber_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

#ifndef	STRICT_OPENSTEP

#include	<Foundation/NSDecimal.h>

@class	NSDecimalNumber;

@protocol	NSDecimalNumberBehaviors
- (NSDecimalNumber*) exceptionDuringOperation: (SEL)method 
					error: (NSCalculationError)error 
				  leftOperand: (NSDecimalNumber*)leftOperand 
				 rightOperand: (NSDecimalNumber*)rightOperand; 
- (NSRoundingMode) roundingMode;
- (short) scale;
@end


@interface	NSDecimalNumber : NSObject <NSCopying, NSCoding>
{
}
@end

#endif
#endif

