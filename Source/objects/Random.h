/* Interface for Objective-C object providing randoms in uniform distribution
   Copyright (C) 1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

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

#ifndef __Random_h_INCLUDE_GNU
#define __Random_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/RandomGenerating.h>

@interface Random : NSObject
{
  id <RandomGenerating> rng;
}

+ initialize;
+ (id <RandomGenerating>) defaultRandomGeneratorClass;
+ setDefaultRandomGeneratorClass: (id <RandomGenerating>)aRNG;

+ (float) chiSquareOfRandomGenerator: (id <RandomGenerating>)aRNG
   iterations: (int)n
   range: (long)r;
+ (float) chiSquareOfRandomGenerator: (id <RandomGenerating>)aRNG;

- init;

- setRandomSeedFromClock;
- setRandomSeed: (long)seed;

- (long) randomInt;
- (long) randomIntBetween: (long)lowBound and: (long)highBound;
- (long) randomDie: (long)numSides; /* between 0 and numSides-1 */

- (BOOL) randomCoin;
- (BOOL) randomCoinWithProbability: (double)p;

- (float) randomFloat;
- (float) randomFloatBetween: (float)lowBound and: (float)highBound;
- (float) randomFloatProbability;

- (double) randomDouble;
- (double) randomDoubleBetween: (double)lowBound and: (double)highBound;
- (double) randomDoubleProbability;

- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;

@end

#endif /* __Random_h_INCLUDE_GNU */
