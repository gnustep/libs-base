/* Implementation Objective-C object providing randoms in uniform distribution
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

/* TODO:
   RNGBerkeley nextRandom returns only positive numbers
   RNGAdditiveCongruential nextRandom returns positive and negative numbers
*/

#include <config.h>
#include <gnustep/base/Random.h>
#include <gnustep/base/RNGBerkeley.h>
#include <gnustep/base/Time.h>
#include <gnustep/base/Coder.h>
#include <Foundation/NSException.h>
#include <limits.h>

typedef union {
  float f;
  unsigned long u;
} float_and_long_u;

typedef union {
  double d;
  unsigned long u[2];
} double_and_long_u;

static float_and_long_u singleMantissa;
static double_and_long_u doubleMantissa;

static id defaultRNG = nil;
@class RNGBerkeley;

@implementation Random

+ initialize
{
  if (self == [Random class])
    {
      defaultRNG = [RNGBerkeley class];
      NSAssert(sizeof(double) == 2 * sizeof(long), NSInternalInconsistencyException);
      NSAssert(sizeof(float) == sizeof(long), NSInternalInconsistencyException);
      
      /* Following taken from libg++ */
      
      /*
	 The following is a hack that I attribute to
	 Andres Nowatzyk at CMU. The intent of the loop
	 is to form the smallest number 0 <= x < 1.0,
	 which is then used as a mask for two longwords.
	 this gives us a fast way way to produce double
	 precision numbers from longwords.
	 
	 I know that this works for IEEE and VAX floating
	 point representations.
	 
	 A further complication is that gnu C will blow
	 the following loop, unless compiled with -ffloat-store,
	 because it uses extended representations for some of
	 of the comparisons. Thus, we have the following hack.
	 If we could specify #pragma optimize, we wouldn't need this.
	 */
      {
	double_and_long_u t;
	float_and_long_u s;

#if _IEEE == 1
	
	t.d = 1.5;
	if ( t.u[1] == 0 ) {		// sun word order?
					  t.u[0] = 0x3fffffff;
					  t.u[1] = 0xffffffff;
					}
	else {
	  t.u[0] = 0xffffffff;	// encore word order?
	    t.u[1] = 0x3fffffff;
	}

	s.u = 0x3fffffff;
#else
	volatile double x = 1.0; /* volatile needed when fp hardware used,
				    and has greater precision than memory
				    doubles */
	double y = 0.5;
	volatile float xx = 1.0; /* volatile needed when fp hardware used,
				    and has greater precision than memory 
				    floats */
	float yy = 0.5;
	do {			    /* find largest fp-number < 2.0 */
	  t.d = x;
	  x += y;
	  y *= 0.5;
	} while (x != t.d && x < 2.0);

	do {			    /*find largest fp-number < 2.0 */
	  s.f = xx;
	  xx += yy;
	  yy *= 0.5;
	} while (xx != s.f && xx < 2.0);
#endif
	// set doubleMantissa to 1 for each doubleMantissa bit;
	doubleMantissa.d = 1.0;
	doubleMantissa.u[0] ^= t.u[0];
	doubleMantissa.u[1] ^= t.u[1];

	// set singleMantissa to 1 for each singleMantissa bit;
	singleMantissa.f = 1.0;
	singleMantissa.u ^= s.u;
      }
    }
  return self;
}

+ setDefaultRandomGeneratorClass: (id <RandomGenerating>)aRNG
{
  defaultRNG = aRNG;
  return self;
}

+ (id <RandomGenerating>) defaultRandomGeneratorClass
{
  return defaultRNG;
}

/* For testing randomness of a random generator,
   the closer to r the returned value is, the better the randomness. */

+ (float) chiSquareOfRandomGenerator: (id <RandomGenerating>)aRNG
   iterations: (int)n
   range: (long)r
{
  long table[r];
  int i, j;

  for (i = 0; i < r; i++)
    table[i] = 0;
  for (i = 0; i < n; i++)
    {
      j = ABS([aRNG nextRandom]) % r;
      table[j]++;
    }
  j = 0;
  for (i = 0; i < r; i++)
    j += table[i] * table[i];
  return ((((float)r * j) / n) - n);
}

/* For testing randomness of a random generator,
   the closer to 1.0 the returned value is, the better the randomness. */

+ (float) chiSquareOfRandomGenerator: (id <RandomGenerating>)aRNG
{
  return [self chiSquareOfRandomGenerator:aRNG
	       iterations:1000
	       range:100] / 100.0;
}

- initWithRandomGenerator: (id <RandomGenerating>)aRNG
{
  [super init];
  rng = aRNG;
  return self;
}

- init
{
  /* Without the (id) we get:
     Random.m: In function `_i_Random__init':
     Random.m:172: warning: method `alloc' not implemented by protocol.
     This is a bug in gcc.
     */
  return [self initWithRandomGenerator:
	       [[(id)[[self class] defaultRandomGeneratorClass] alloc] init]];
}

- setRandomSeedFromClock
{
  [self setRandomSeed:[Time secondClockValue]];
  return self;
}

- setRandomSeed: (long)seed
{
  [rng setRandomSeed:seed];
  return self;
}

- (long) randomInt
{
  return [rng nextRandom];
}

- (long) randomIntBetween: (long)lowBound and: (long)highBound
{
  return ([rng nextRandom] % (highBound - lowBound + 1) + lowBound);
}

/* return between 0 and numSides-1 */
- (long) randomDie: (long)numSides
{
  return ([rng nextRandom] % numSides);
}

- (BOOL) randomCoin
{
  return ([rng nextRandom] % 2);
}

- (BOOL) randomCoinWithProbability: (double)p
{
  return (p >= [self randomDoubleProbability]);
}

/* Returns 0.0 <= r < 1.0.  Is this what people want?
   I'd like it to return 1.0 also. */
- (float) randomFloat
{
  union {long i; float f;} result;
  result.f = 1.0;
  result.i |= ([rng nextRandom] & singleMantissa.u);
  result.f -= 1.0;
  NSAssert(result.f < 1.0 && result.f >= 0, NSInternalInconsistencyException);
  return result.f;
}

- (float) randomFloatBetween: (float)lowBound and: (float)highBound
{
  return ([self randomFloat] * (highBound - lowBound) + lowBound);
}

- (float) randomFloatProbability
{
  return [self randomFloat];
}

/* Returns 0.0 <= r < 1.0.  Is this what people want? 
   I'd like it to return 1.0 also. */
- (double) randomDouble
{
  union {unsigned long u[2]; double d;} result;

  result.d = 1.0;
  result.u[0] |= ([rng nextRandom] & doubleMantissa.u[0]);
  result.u[1] |= ([rng nextRandom] & doubleMantissa.u[1]);
  result.d -= 1.0;
  NSAssert(result.d < 1.0 && result.d >= 0, NSInternalInconsistencyException);
  return result.d;
}

- (double) randomDoubleBetween: (double)lowBound and: (double)highBound
{
  return [self randomDouble] * (highBound - lowBound);
}

- (double) randomDoubleProbability
{
  return [self randomDouble];
}

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

- initWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- write: (TypedStream*)aStream
{
  [super write:aStream];
  //  [rng read:aStream];
  [self notImplemented:_cmd];
  return self;
}

- read: (TypedStream*)aStream
{
  [super read:aStream];
  //  [rng read:aStream];
  [self notImplemented:_cmd];
  return self;
}

@end
