/* NSDecimal types and functions
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

#ifndef __NSDecimal_h_GNUSTEP_BASE_INCLUDE
#define __NSDecimal_h_GNUSTEP_BASE_INCLUDE

#ifndef	STRICT_OPENSTEP

#include <GSConfig.h>

#if	HAVE_GMP
#include <gmp.h>
#endif

#include <Foundation/NSObject.h>

typedef	enum {
  NSRoundDown,
  NSRoundUp,
  NSRoundPlain,		/* Round .5 up		*/
  NSRoundBankers	/* Make last digit even	*/
} NSRoundingMode;

typedef enum {
  NSCalculationNoError = 0,
  NSCalculationUnderflow,	/* result became zero */
  NSCalculationOverflow,
  NSCalculationLossOfPrecision,
  NSCalculationDivideByZero
} NSCalculationError;

/*
 *	Give a precision of at least 38 decimal digits
 *	requires 128 bits.
 */
#define NSDecimalMaxSize (16/sizeof(mp_limb_t))

#define NSDecimalMaxDigit 38
#define NSDecimalNoScale 128

typedef struct {
  signed char	exponent;	/* Signed exponent - -128 to 127	*/
  BOOL	isNegative;	/* Is this negative?			*/
  BOOL	validNumber;	/* Is this a valid number?		*/
#if	HAVE_GMP
  mp_size_t size;
  mp_limb_t lMantissa[NSDecimalMaxSize];
#else
  unsigned char	length;		/* digits in mantissa.			*/
  unsigned char cMantissa[NSDecimalMaxDigit];
#endif
} NSDecimal;

static inline BOOL
NSDecimalIsNotANumber(const NSDecimal *decimal)
{
  return (decimal->validNumber == NO);
}

GS_EXPORT void
NSDecimalCopy(NSDecimal *destination, const NSDecimal *source);

GS_EXPORT void
NSDecimalCompact(NSDecimal *number);

GS_EXPORT NSComparisonResult
NSDecimalCompare(const NSDecimal *leftOperand, const NSDecimal *rightOperand);

GS_EXPORT void
NSDecimalRound(NSDecimal *result, const NSDecimal *number, int scale, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalNormalize(NSDecimal *n1, NSDecimal *n2, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalAdd(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalSubtract(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalMultiply(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalDivide(NSDecimal *result, const NSDecimal *l, const NSDecimal *rr, NSRoundingMode mode);
    
GS_EXPORT NSCalculationError
NSDecimalPower(NSDecimal *result, const NSDecimal *n, unsigned power, NSRoundingMode mode);

GS_EXPORT NSCalculationError
NSDecimalMultiplyByPowerOf10(NSDecimal *result, const NSDecimal *n, short power, NSRoundingMode mode);

GS_EXPORT NSString*
NSDecimalString(const NSDecimal *decimal, NSDictionary *locale);


// GNUstep extensions to make the implementation of NSDecimalNumber totaly 
// independent for NSDecimals internal representation

// Give back the biggest NSDecimal
GS_EXPORT void
NSDecimalMax(NSDecimal *result);

// Give back the smallest NSDecimal
GS_EXPORT void
NSDecimalMin(NSDecimal *result);

// Give back the value of a NSDecimal as a double
GS_EXPORT double
NSDecimalDouble(NSDecimal *number);

// Create a NSDecimal with a mantissa, exponent and a negative flag
GS_EXPORT void
NSDecimalFromComponents(NSDecimal *result, unsigned long long mantissa, 
		      short exponent, BOOL negative);

// Create a NSDecimal from a string using the local
GS_EXPORT void
NSDecimalFromString(NSDecimal *result, NSString *numberValue, 
		    NSDictionary *locale);

#endif
#endif

