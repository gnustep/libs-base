/* 
   NSDecimal functions
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: July 2000

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

#include <math.h>
#include <ctype.h>
#include <Foundation/NSDecimal.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>

/*
  This file provides two implementations of the NSDecimal functions. 
  One is based on pure simple decimal mathematics, as we all learned it 
  in school. This version is rather slow and may be inexact in the extrem 
  cases. 
  THIS IS TESTED AND WORKING.

  The second implemenation requieres the GMP library, the GNU math package,
  to do the hard work. This is very fast and accurate. But as GMP is not 
  available on all computers this has to be switched on at compile time.
  THIS IS STILL NOT IMPLEMENTED.
 */

#ifdef HAVE_GMP

// Define GSDecimal as using a character vector
typedef struct {
  char	exponent;	/* Signed exponent - -128 to 127	*/
  BOOL	isNegative;	/* Is this negative?			*/
  BOOL	validNumber;	/* Is this a valid number?		*/
  char	length;		/* digits in mantissa.			*/
  char  cMantissa[NSDecimalMaxDigit];
} GSDecimal;

#else
// Make GSDecimal a synonym of NSDecimal
typedef NSDecimal GSDecimal;

#endif


void
NSDecimalCopy(NSDecimal *destination, const NSDecimal *source)
{
  memcpy(destination, source, sizeof(NSDecimal));
}

static void
GSDecimalCompact(GSDecimal *number)
{
  int i, j;

  if (!number->validNumber)
    return;

  // Cut off trailing 0's
  for (i = number->length-1; i >= 0; i--)
    {
      if (number->cMantissa[i] == 0)
        {
	  if (number->exponent == 127)
	    {
	      // Overflow in compacting!!
	      // Leave the remaining 0s there.
	      break;
	    }
	  number->length--;
	  number->exponent++;
	}
      else
	break;
    }

  // Cut off leading 0's
  for (i = 0; i < number->length; i++)
    {
      if (number->cMantissa[i] != 0)
	break;
    }
  if (i > 0)
    {
      for (j = 0; j < number->length-i; j++)
	{
	  number->cMantissa[j] = number->cMantissa[j+i];
	}
      number->length -= i;
    }

  if (!number->length)
    {
      number->exponent = 0;
      number->isNegative = NO;
    }
}

static NSComparisonResult
GSDecimalCompare(const GSDecimal *leftOperand, const GSDecimal *rightOperand)
{
  int i, l;
  int s1 = leftOperand->exponent + leftOperand->length;
  int s2 = rightOperand->exponent + rightOperand->length;

  if (leftOperand->isNegative != rightOperand->isNegative)
    {
      if (rightOperand->isNegative)
	return NSOrderedDescending;
      else
	return NSOrderedAscending;
    }

  // Same sign, check size
  if (s1 < s2)
    { 
      if (rightOperand->isNegative)
	return NSOrderedDescending;
      else
	return NSOrderedAscending;
    }
  if (s1 > s2)
    { 
      if (rightOperand->isNegative)
	return NSOrderedAscending;
      else
	return NSOrderedDescending;
    }
  
  // Same size, check digits
  l = MIN(leftOperand->length, rightOperand->length);
  for (i = 0; i < l; i++)
    {
      int d = rightOperand->cMantissa[i] - leftOperand->cMantissa[i];
      
      if (d > 0)
        {
	  if (rightOperand->isNegative)
	    return NSOrderedDescending;
	  else
	    return NSOrderedAscending;
	}
      if (d < 0)
        {
	  if (rightOperand->isNegative)
	    return NSOrderedAscending;
	  else
	    return NSOrderedDescending;
	}
    }

  // Same digits, check length
  if (leftOperand->length > rightOperand->length)
    {
      if (rightOperand->isNegative)
	return NSOrderedDescending;
      else
	return NSOrderedAscending;
    }

  if (leftOperand->length < rightOperand->length)
    {
      if (rightOperand->isNegative)
	return NSOrderedAscending;
      else
	return NSOrderedDescending;
    }

  return NSOrderedSame;
}

void
GSDecimalRound(GSDecimal *result, int scale, NSRoundingMode mode)
{
  int i;
  // last valid digit in number
  int l = scale + result->exponent + result->length;

  if (scale == NSDecimalNoScale)
      return;

  if (!result->validNumber)
    return;

  if (result->length <= l)
    return;
  else if (l <= 0)
    {
      result->length = 0;
      result->exponent = 0;
      result->isNegative = NO;
      return;
    }
  else
    {
      int c, n;
      BOOL up;

      // Adjust length and exponent
      result->exponent += result->length - l;
      result->length = l;

      switch (mode)
        {
	  case NSRoundDown: 
	    up = result->isNegative;
	    break;
	  case NSRoundUp: 
	    up = !result->isNegative;
	    break;
	  case NSRoundPlain: 
	    n = result->cMantissa[l];
	    up = (n >= 5);
	    break;
	  case NSRoundBankers: 
	    n = result->cMantissa[l];
	    if (n > 5)
	      up = YES;
	    else if (n < 5)
	      up = NO;
	    else 
	      {
		if (l == 0)
		  c = 0;
		else
		  c = result->cMantissa[l-1];
		up = ((c % 2) != 0);    
	      }
	    break;
	  default: // No way to get here
	    up = NO;
	    break;
	}

      if (up)
      {
	for (i = l-1; i >= 0; i--)
	  {
	    if (result->cMantissa[i] != 9)
	      {
		result->cMantissa[i]++;
		break;
	      }
	    result->cMantissa[i] = 0;
	  }
	// Final overflow?
	if (i == -1)
	  {
	    // As all digits are zeros, just change the first
	    result->cMantissa[0] = 1;
	    if (result->exponent == 127)
	      {
		// Overflow in rounding!!
		// Add one zero add the end. There must be space as
		// we just cut off some digits.
		result->cMantissa[l] = 0;
		result->length++;
	      }
	    else
	      result->exponent++;;   
	  }  
      }
    }

  GSDecimalCompact(result);
}

NSCalculationError
GSDecimalNormalize(GSDecimal *n1, GSDecimal *n2, NSRoundingMode mode)
{
  int e1 = n1->exponent;
  int e2 = n2->exponent;
  int i, l;

  if (!n1->validNumber || !n2->validNumber)
    return NSCalculationNoError;

  // Do they have the same exponent already?
  if (e1 == e2)
    return NSCalculationNoError;

  // make sure n2 has the bigger exponent
  if (e1 > e2)
    {
      GSDecimal *t;

      t = n1;
      n1 = n2;
      n2 = t;
      i = e2;
      e2 = e1;
      e1 = i;
    }

  // Add zeros to n2, as far as possible
  l = MIN(NSDecimalMaxDigit - n2->length, e2 - e1);
  for (i = 0; i < l; i++)
    {
      n2->cMantissa[i + n2->length] = 0;
    }
  n2->length += l;
  n2->exponent -= l;
  
  if (l != e2 - e1)
    {
      // Round of some digit from n1 to increase exponent
      GSDecimalRound(n1, -n2->exponent, mode);
      if (n1->exponent != n2->exponent)
	{
	  // Some zeros where cut of again by compacting
	  l = MIN(NSDecimalMaxDigit - n1->length, n1->exponent - n2->exponent);
	  for (i = 0; i < l; i++)
	    {
		n1->cMantissa[(int)n1->length] = 0;
		n1->length++;
	    } 
	  n1->exponent = n2->exponent;
	}
      return NSCalculationLossOfPrecision;
    }

  return NSCalculationNoError;
}

#ifdef HAVE_GMP

static void CharvecToDecimal(GSDecimal *m, NSDecimal *n)
{
  // Convert form a GSDecimal to a NSDecimal  
  n->exponent = m->exponent;
  n->isNegative = m->isNegative;
  n->validNumber = m->validNumber;

  n->size = mpn_set_str(n->mantissa, m->cMantissa, m->length, 10);
}

static void DecimalToCharvec(NSDecimal *n, GSDecimal *m)
{
  // Convert form a NSDecimal to a GSDecimal  
  m->exponent = n->exponent;
  m->isNegative = n->isNegative;
  m->validNumber = n->validNumber;

  m->lenght = mpn_get_str(m->cMantissa, 10, n->mantissa, n->size);
}

void
NSDecimalCompact(NSDecimal *number)
{
  GSDecimal m;

  DecimalToCharvec(number, &m);
  GSDecimalCompact(&m);
  CharvecToDecimal(&m, number);
}

NSComparisonResult
NSDecimalCompare(const NSDecimal *leftOperand, const NSDecimal *rightOperand)
{
  GSDecimal m1;
  GSDecimal m2;

  DecimalToCharvec(leftOperand, &m1);
  DecimalToCharvec(rightOperand, &m2);
  return GSDecimalCompare(&m1, &m2);
}

void
NSDecimalRound(NSDecimal *result, const NSDecimal *number, int scale, 
	       NSRoundingMode mode)
{
  GSDecimal m;

  DecimalToCharvec(number, &m);
  GSDecimalRound(&m, scale, mode);
  CharvecToDecimal(&m, result);
}

NSCalculationError
NSDecimalNormalize(NSDecimal *n1, NSDecimal *n2, NSRoundingMode mode)
{
  NSCalculationError error;
  GSDecimal m1;
  GSDecimal m2;

  DecimalToCharvec(n1, &m1);
  DecimalToCharvec(n2, &m2);
  error = GSDecimalNormalize(&m1, &m2, mode);
  CharvecToDecimal(&m1, n1);
  CharvecToDecimal(&m2, n2);
}

NSCalculationError
NSDecimalAdd(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, 
	     NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  NSDecimal n1;
  NSDecimal n2;
  NSDecimal n3;
  mp_limb_t carry;

  NSDecimalCopy(&n1, left);
  NSDecimalCopy(&n2, right);
  error = NSDecimalNormalize(&n1, &n2, mode);
  
  if (n1.size >= n2.size)
    {
      carry = mpn_add(n3.lMantissa, n1.lMantissa, n1.size, n2.lMantissa, n2.size); 
      n3.size = n1.size;
    }
  else
    {
      carry = mpn_add(n3.lMantissa, n2.lMantissa, n2.size, n1.lMantissa, n1.size); 
      n3.size = n2.size;
    }
  //FIXME: check carry
  
  return error;
}

#else

// First implementations of the functions defined in NSDecimal.h
static NSDecimal zero = {0, NO, YES, 0, {0}};

void
NSDecimalCompact(NSDecimal *number)
{
  GSDecimalCompact(number); 
}

NSComparisonResult
NSDecimalCompare(const NSDecimal *leftOperand, const NSDecimal *rightOperand)
{
  return GSDecimalCompare(leftOperand, rightOperand);
}

void
NSDecimalRound(NSDecimal *result, const NSDecimal *number, int scale, 
	       NSRoundingMode mode)
{
  NSDecimalCopy(result, number);
  
  GSDecimalRound(result, scale, mode); 
}

NSCalculationError
NSDecimalNormalize(NSDecimal *n1, NSDecimal *n2, NSRoundingMode mode)
{
  return GSDecimalNormalize(n1, n2, mode);
}

NSCalculationError
NSDecimalAdd(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, 
	     NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  int i, j, l, d;
  int carry = 0;
  NSDecimal n1;
  NSDecimal n2;
  NSDecimal *n;
  BOOL neg;

  if (!left->validNumber || !right->validNumber)
    {
      result->validNumber = NO;
      return NSCalculationNoError;
    }

  // For different signs use subtraction
  if (left->isNegative != right->isNegative)
    {
      if (left->isNegative)
        {
	  NSDecimalCopy(&n1, left);
	  n1.isNegative = NO;
	  return NSDecimalSubtract(result, right, &n1, mode);
	}
      else
        {
	  NSDecimalCopy(&n1, right);
	  n1.isNegative = NO;
	  return NSDecimalSubtract(result, left, &n1, mode);
	}
    }

  if (!left->length)
    {
      NSDecimalCopy(result, right);
      return error;
    }
  if (!right->length)
    {
      NSDecimalCopy(result, left);
      return error;
    }
  NSDecimalCopy(&n1, left); 
  NSDecimalCopy(&n2, right); 
  error = NSDecimalNormalize(&n1, &n2, mode);

  if (!n1.length)
    {
      NSDecimalCopy(result, right);
      return error;
    }
  if (!n2.length)
    {
      NSDecimalCopy(result, left);
      return error;
    }

  j = n1.length - n2.length;
  if (j >= 0)
    {
      // Use sign from input as n1 might be zero
      neg = left->isNegative;
      NSDecimalCopy(result, &n1); 
      result->isNegative = neg; 
      n = &n2;
      l = n2.length;
    }
  else
    {
      // Use sign from input as n2 might be zero
      neg = left->isNegative;
      NSDecimalCopy(result, &n2); 
      result->isNegative = neg; 
      n = &n1;
      l = n1.length;
      j = -j; 
    }

  // Add all the digits
  for (i = l-1; i >= 0; i--)
    {
      d = n->cMantissa[i] + result->cMantissa[i + j] + carry;
      if (d >= 10)
        {
	  d = d % 10;
	  carry = 1;
	}
      else
	carry = 0;

      result->cMantissa[i + j] = d;
    }

  if (carry)
    {
      for (i = j-1; i >= 0; i--)
	{
	  if (result->cMantissa[i] != 9)
	    {
	      result->cMantissa[i]++;
	      carry = 0;
	      break;
	    }
	  result->cMantissa[i] = 0;
	}

      if (carry)
	{
	  // The number must be shifted to the right
	  if (result->length == NSDecimalMaxDigit) 
	    {
	      NSDecimalRound(result, result, 
			     NSDecimalMaxDigit - 1 - result->exponent, 
			     mode);
	    }

	  if (result->exponent == 127)
	    {
	      result->validNumber = NO;
	      if (result->isNegative)
		return NSCalculationUnderflow;
	      else
		return NSCalculationOverflow;
	    } 

	  for (i = result->length-1; i >= 0; i--)
	    {
	      result->cMantissa[i+1] = result->cMantissa[i];
	    }
	  result->cMantissa[0] = 1;
	  result->length++;
	}
    }

  NSDecimalCompact(result);

  return error;
}

NSCalculationError
NSDecimalSubtract(NSDecimal *result, const NSDecimal *left, 
		  const NSDecimal *right, NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  int i, j, l, d;
  int carry = 0;
  NSDecimal n1;
  NSDecimal n2;
  NSDecimal *n;
  NSComparisonResult comp;

  if (!left->validNumber || !right->validNumber)
    {
      result->validNumber = NO;
      return NSCalculationNoError;
    }

  // For different signs use addition
  if (left->isNegative != right->isNegative)
    {
      if (left->isNegative)
        {
	  NSDecimalCopy(&n1, left);
	  n1.isNegative = NO;
	  error = NSDecimalAdd(result, &n1, right, mode);
	  result->isNegative = YES;
	  return error;
	}
      else
        {
	  NSDecimalCopy(&n1, right);
	  n1.isNegative = NO;
	  return NSDecimalAdd(result, left, &n1, mode);
	}
    }

  // both negative, make positive and change order
  if (left->isNegative)
    {
      NSDecimalCopy(&n1, left);
      n1.isNegative = NO;
      NSDecimalCopy(&n2, right);
      n2.isNegative = NO;
      return NSDecimalSubtract(result, &n2, &n1, mode);
    }

  comp = NSDecimalCompare(left, right);
  if (comp == NSOrderedSame)
    { 
      NSDecimalCopy(result, &zero);
      return NSCalculationNoError;
    }

  if (comp == NSOrderedAscending)
    {
      error = NSDecimalSubtract(result, right, left, mode);
      result->isNegative = YES;
      return error;
    }

  if (!right->length)
    {
      NSDecimalCopy(result, left);
      return error;
    }

  // Now left is the bigger number
  NSDecimalCopy(&n1, left); 
  NSDecimalCopy(&n2, right); 
  error = NSDecimalNormalize(&n1, &n2, mode);

  if (!n2.length)
    {
      NSDecimalCopy(result, left);
      return error;
    }

  j = n1.length - n2.length;
  if (j >= 0)
    {
      NSDecimalCopy(result, &n1); 
      n = &n2;
      l = n2.length;
    }
  else
    {
      NSLog(@"Wrong order in subtract");
      NSLog(@"The left is %@, %@", NSDecimalString(left, nil), NSDecimalString(&n1, nil));
      NSLog(@"The right is %@, %@", NSDecimalString(right, nil), NSDecimalString(&n2, nil));
      NSDecimalCopy(result, &n2); 
      n = &n1;
      l = n1.length;
      j = -j; 
    }

  // Now subtract all digits
  for (i = l-1; i >= 0; i--)
    {
      d = result->cMantissa[i + j] - n->cMantissa[i] - carry;
      if (d < 0)
        {
	  d = d + 10;
	  carry = 1;
	}
      else
	carry = 0;

      result->cMantissa[i + j] = d;
    }

  if (carry)
    {
      for (i = j-1; i >= 0; i--)
	{
	  if (result->cMantissa[i] != 0)
	    {
	      result->cMantissa[i]--;
	      carry = 0;
	      break;
	    }
	  result->cMantissa[i] = 9;
	}

      if (carry)
	{
	  NSLog(@"Impossible error in substraction");
	}
    }

  NSDecimalCompact(result);

  return error;
}

NSCalculationError
NSDecimalMultiply(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  int i, j, d, e;
  int carry = 0;
  NSDecimal n1;
  NSDecimal n2;
  NSDecimal n;
  int exp;
  BOOL neg = l->isNegative != r->isNegative;

  if (!l->validNumber || !r->validNumber)
    {
      result->validNumber = NO;
      return error;
    }

  exp = l->exponent + r->exponent;
  if (exp > 127)
    {
      result->validNumber = NO;
      if (neg)
	return NSCalculationUnderflow;
      else
	return NSCalculationOverflow;
    }
  else
    {
      NSDecimalCopy(&n1, l);
      NSDecimalCopy(&n2, r);
    }

  NSDecimalCopy(result, &zero);
  n.validNumber = YES;
  n.isNegative = NO;

  // if l->length = 38 round one off
  if (n1.length == NSDecimalMaxDigit)
    {
      NSDecimalRound(&n1, &n1, -1-n1.exponent, mode);
      // This might changed more than one
      exp = n1.exponent + n2.exponent;
    }

  // Do every digit of the second number
  for (i = 0; i < n2.length; i++)
    {
      n.length = n1.length+1;
      n.exponent = n2.length - i - 1;
      carry = 0;
      d = n2.cMantissa[i];

      for (j = n1.length-1; j >= 0; j--)
        {
	  e = n1.cMantissa[j] * d + carry;

	  if (e >= 10)
	    {
	      carry = e / 10;
	      e = e % 10;
	    }
	  else
	    carry = 0;
	  // This is one off to allow final carry
	  n.cMantissa[j+1] = e;
	}
      n.cMantissa[0] = carry;
      NSDecimalCompact(&n);
      error = NSDecimalAdd(result, result, &n, mode);
    }

  if (result->exponent + exp > 127)
    {
      result->validNumber = NO;
      if (neg)
	return NSCalculationUnderflow;
      else
	return NSCalculationOverflow;
    }
  else if (result->exponent + exp < -127)
    {
      // We must cut off some digits
      NSDecimalRound(result, result, exp+127, mode);
      error = NSCalculationLossOfPrecision;

      if (result->exponent + exp < -127)
        {
	  NSDecimalCopy(result, &zero);
	  return error;
        }
    }

  result->exponent += exp;
  result->isNegative = neg;
  NSDecimalCompact(result);

  return error;
}

NSCalculationError
NSDecimalDivide(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  int k, m;
  int used; // How many digits of l have been used?
  NSDecimal n1;
  NSDecimal n2;
  NSDecimal n3;
  int exp;
  BOOL neg = l->isNegative != r->isNegative;

  if (!l->validNumber || !r->validNumber)
    {
      result->validNumber = NO;
      return NSCalculationNoError;
    }

  // Check for zero
  if (!r->length)
    {
      result->validNumber = NO;
      return NSCalculationDivideByZero;
    }

  // Should also check for one

  exp = l->exponent - r->exponent;
  NSDecimalCopy(&n1, &zero);
  NSDecimalCopy(&n2, r);
  n2.exponent = 0;
  n2.isNegative = NO;
  NSDecimalCopy(&n3, l);
  NSDecimalCopy(result, &zero);
  m = n2.length;
  k = 0;
  used = 0;

  while ((k < n3.length ) || (n1.length))
    {
      while (NSDecimalCompare(&n1, &n2) == NSOrderedAscending)
        {
	  if (k == NSDecimalMaxDigit-1)
	    break;
	  if (n1.exponent)
	    {
              // Put back removed zeros
	      n1.cMantissa[(int)n1.length] = 0;
	      n1.length++;
	      n1.exponent--;
	    }
	  else
	    {
	      if (used < n3.length)
	        {
		  // Fill up with own digits
		  n1.cMantissa[(int)n1.length] = n3.cMantissa[used];
		  used++;
		}
	      else
	        {
		  if (exp == -127)
		    {
		      // use this as a end flag
		      k = NSDecimalMaxDigit-1;
		      break;
		    }
		  // Borrow one digit
		  n1.cMantissa[(int)n1.length] = 0;
		  exp--;
		}
	      n1.length++;
	      k++;
	      result->cMantissa[k-1] = 0; 
	      result->length++;
	    }
	}

      if (k == NSDecimalMaxDigit-1)
        {
	  error = NSCalculationLossOfPrecision;
	  break;
	}

      error = NSDecimalSubtract(&n1, &n1, &n2, mode);
      result->cMantissa[k-1]++; 
      NSDecimalCompact(&n1);
    }

  if (result->exponent + exp > 127)
    {
      result->validNumber = NO;
      if (neg)
	return NSCalculationUnderflow;
      else
	return NSCalculationOverflow;
    }
  else if (result->exponent + exp < -127)
    {
      NSDecimalCopy(result, &zero);
      return NSCalculationLossOfPrecision;
    }

  result->exponent += exp;
  result->isNegative = neg;
  NSDecimalCompact(result);

  return error;
}
    
NSCalculationError
NSDecimalPower(NSDecimal *result, const NSDecimal *l, unsigned power, NSRoundingMode mode)
{
  NSCalculationError error = NSCalculationNoError;
  unsigned int e = power;
  NSDecimal n1;
  BOOL neg = (l->isNegative && (power % 2));

  NSDecimalCopy(&n1, l);
  n1.isNegative = NO;
  NSDecimalCopy(result, &zero);
  result->length = 1;
  result->cMantissa[0] = 1;

  while (e)
    {
      if (e & 1)
        {
	  error = NSDecimalMultiply(result, result, &n1, mode);
	}
      // keep on squaring the number
      error = NSDecimalMultiply(&n1, &n1, &n1, mode);
      e >>= 1;
    }

  result->isNegative = neg;
  NSDecimalCompact(result);

  return error;
}

NSCalculationError
NSDecimalMultiplyByPowerOf10(NSDecimal *result, const NSDecimal *n, short power, NSRoundingMode mode)
{
  int p = result->exponent + power;

  NSDecimalCopy(result, n);
  if (p > 127)
    {
      result->validNumber = NO;
      return NSCalculationOverflow;
    }
  if (p < -127)  
    {
      result->validNumber = NO;
      return NSCalculationUnderflow;
    }
  result->exponent += power;
  return NSCalculationNoError;
}

NSString*
NSDecimalString(const NSDecimal *number, NSDictionary *locale)
{
  int i;
  int d;
  NSString *s;
  NSMutableString *string;
  NSString *sep;
  int size;

  if (!number->validNumber)
    return @"NaN";

  if ((locale == nil) || 
      (sep = [locale objectForKey: NSDecimalSeparator]) == nil)
    sep = @".";

  string = [NSMutableString stringWithCapacity: 45];

  if (!number->length)
    {
      [string appendString: @"0"];
      [string appendString: sep];
      [string appendString: @"0"];
      return string;
    }

  if (number->isNegative)
    [string appendString: @"-"];

  size = number->length + number->exponent;
  if ((number->length <= 6) && (0 < size) && (size < 7))
    {
      // For small numbers use the normal format
      for (i = 0; i < number->length; i++)
        {
	  if (size == i)
	    [string appendString: sep];
	  d = number->cMantissa[i];
	  s = [NSString stringWithFormat: @"%d", d];
	  [string appendString: s];
	}
      for (i = 0; i < number->exponent; i++)
        {
	  [string appendString: @"0"];
	}
    }
  else if ((number->length <= 6) && (0 >= size) && (size > -3))
    {
      // For small numbers use the normal format
      [string appendString: @"0"];
      [string appendString: sep];

      for (i = 0; i > size; i--)
        {
	  [string appendString: @"0"];
	}
      for (i = 0; i < number->length; i++)
        {
	  d = number->cMantissa[i];
	  s = [NSString stringWithFormat: @"%d", d];
	  [string appendString: s];
	}  
    }
  else
    {
      // Scientific format
      for (i = 0; i < number->length; i++)
        {
	  if (i == 1)
	    [string appendString: sep];
	  d = number->cMantissa[i];
	  s = [NSString stringWithFormat: @"%d", d];
	  [string appendString: s];
	}
      if (size != 1)
        {
	  s = [NSString stringWithFormat: @"E%d", size-1];
	  [string appendString: s];
	}
    }

  return string;
}

// GNUstep extensions to make the implementation of NSDecimalNumber totaly 
// independent for NSDecimals internal representation

// Give back the biggest NSDecimal
GS_EXPORT void
NSDecimalMax(NSDecimal *result)
{
  NSDecimalFromComponents(result, 9, 127, NO);
}

// Give back the smallest NSDecimal
GS_EXPORT void
NSDecimalMin(NSDecimal *result)
{
  // FIXME: Should this be the smallest possible or the smallest positive number
  NSDecimalFromComponents(result, 9, 127, YES);
}

// Give back the value of a NSDecimal as a double
GS_EXPORT double
NSDecimalDouble(NSDecimal *number)
{
  double d = 0.0;
  int i;

  if (!number->validNumber)
    return d;

  // Sum up the digits
  for (i = 0; i < number->length; i++)
    {
      d *= 10;
      d += number->cMantissa[i];
    }

  // multiply with the exponent
  // There is also a GNU extension pow10!!
  d *= pow(10, number->exponent);

  if (number->isNegative)
    d = -d;

  return d;
}

// Create a NSDecimal with a cMantissa, exponent and a negative flag
GS_EXPORT void
NSDecimalFromComponents(NSDecimal *result, unsigned long long mantissa, 
		      short exponent, BOOL negative)
{
  char digit;
  int i, j;
  result->isNegative = negative;
  result->exponent = exponent;
  result->validNumber = YES;

  i = 0;
  while (mantissa)
    {
      digit = mantissa % 10;
      // Store the digit starting from the end of the array
      result->cMantissa[NSDecimalMaxDigit-i-1] = digit;
      mantissa = mantissa / 10;
      i++;
    }

  for (j = 0; j < i; j++)
    {
      // Move the digits to the beginning
      result->cMantissa[j] = result->cMantissa[j + NSDecimalMaxDigit-i];
    }

  result->length = i;

  NSDecimalCompact(result);
}

// Create a NSDecimal from a string using the local
GS_EXPORT void
NSDecimalFromString(NSDecimal *result, NSString *numberValue, 
		    NSDictionary *locale)
{
  NSRange found;
  NSString *sep = [locale objectForKey: NSDecimalSeparator];
  const char *s;
  int i;

  if (sep == nil)
    sep = @".";

  NSDecimalCopy(result, &zero);
  found = [numberValue rangeOfString: sep];
  if (found.length)
    {
      s = [[numberValue substringToIndex: found.location] cString];
      while ((*s) && (!isdigit(*s))) s++;
      i = 0;
      while ((*s) && (isdigit(*s)))
        {
	  result->cMantissa[i++] = *s - '0';
	  result->length++;
	  s++;  
	}
      s = [[numberValue substringFromIndex: NSMaxRange(found)] cString];
      while ((*s) && (isdigit(*s)))
        {
	  result->cMantissa[i++] = *s - '0';
	  result->length++;
	  result->exponent--;
	  s++;  
	}	
    }
  else
    {
      s = [numberValue cString];
      while ((*s) && (!isdigit(*s))) s++;
      i = 0;
      while ((*s) && (isdigit(*s)))
        {
	  result->cMantissa[i++] = *s - '0';
	  result->length++;
	  s++;  
	}      
    }

  if ((*s == 'e') || (*s == 'E'))
    {
      s++; 
      result->exponent += atoi(s); 
    }

  if (!result->length)
    result->validNumber = NO;

  NSDecimalCompact(result);
}

#endif
