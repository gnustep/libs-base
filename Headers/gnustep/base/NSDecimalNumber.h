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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef __NSDecimalNumber_h_GNUSTEP_BASE_INCLUDE
#define __NSDecimalNumber_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

#ifndef	STRICT_OPENSTEP

#include	<Foundation/NSDecimal.h>
#include	<Foundation/NSValue.h>

@class	NSDecimalNumber;

@protocol	NSDecimalNumberBehaviors
- (NSDecimalNumber*) exceptionDuringOperation: (SEL)method 
					error: (NSCalculationError)error 
				  leftOperand: (NSDecimalNumber*)leftOperand 
				 rightOperand: (NSDecimalNumber*)rightOperand; 
- (NSRoundingMode) roundingMode;
- (short) scale;
@end

@interface	NSDecimalNumberHandler : NSObject <NSDecimalNumberBehaviors>
{
  NSRoundingMode _roundingMode;
  short _scale;
  BOOL _raiseOnExactness;
  BOOL _raiseOnOverflow; 
  BOOL _raiseOnUnderflow;
  BOOL _raiseOnDivideByZero;
}

+ (id)defaultDecimalNumberHandler;
+ (id)decimalNumberHandlerWithRoundingMode:(NSRoundingMode)roundingMode 
				     scale:(short)scale
			  raiseOnExactness:(BOOL)raiseOnExactness 
			   raiseOnOverflow:(BOOL)raiseOnOverflow 
			  raiseOnUnderflow:(BOOL)raiseOnUnderflow
		       raiseOnDivideByZero:(BOOL)raiseOnDivideByZero;

- (id)initWithRoundingMode:(NSRoundingMode)roundingMode 
		     scale:(short)scale 
	  raiseOnExactness:(BOOL)raiseOnExactness
	   raiseOnOverflow:(BOOL)raiseOnOverflow 
	  raiseOnUnderflow:(BOOL)raiseOnUnderflow
       raiseOnDivideByZero:(BOOL)raiseOnDivideByZero;
@end

@interface	NSDecimalNumber : NSNumber <NSDecimalNumberBehaviors>
{
  NSDecimal data;
}

+ (id <NSDecimalNumberBehaviors>)defaultBehavior;
+ (void)setDefaultBehavior:(id <NSDecimalNumberBehaviors>)behavior;

+ (NSDecimalNumber *)maximumDecimalNumber;
+ (NSDecimalNumber *)minimumDecimalNumber;
+ (NSDecimalNumber *)notANumber;
+ (NSDecimalNumber *)one;
+ (NSDecimalNumber *)zero;

+ (NSDecimalNumber *)decimalNumberWithDecimal:(NSDecimal)decimal;
+ (NSDecimalNumber *)decimalNumberWithMantissa:(unsigned long long)mantissa 
				      exponent:(short)exponent
				    isNegative:(BOOL)isNegative;
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)numericString;
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)numericString 
				      locale:(NSDictionary *)locale;

- (id)initWithDecimal:(NSDecimal)decimal;
- (id)initWithMantissa:(unsigned long long)mantissa 
	      exponent:(short)exponent 
	    isNegative:(BOOL)flag;
- (id)initWithString:(NSString *)numberValue;
- (id)initWithString:(NSString *)numberValue 
	      locale:(NSDictionary *)locale;

- (const char *)objCType;

- (NSDecimal)decimalValue;
- (NSString *)descriptionWithLocale:(NSDictionary *)locale;
- (double)doubleValue;

- (NSComparisonResult)compare:(NSNumber *)decimalNumber;

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)decimalNumber 
			      withBehavior:(id<NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)decimalNumber 
				  withBehavior:(id <NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)decimalNumber 
				     withBehavior:(id <NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)power;
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)power 
					      withBehavior:(id <NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(unsigned)power;
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(unsigned)power 
				      withBehavior:(id <NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberByRoundingAccordingToBehavior:(id <NSDecimalNumberBehaviors>)behavior;
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)decimalNumber;
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)decimalNumber 
				   withBehavior:(id <NSDecimalNumberBehaviors>)behavior;

@end

#endif
#endif
