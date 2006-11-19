/** <title>NSAffineTransform.m</title>

   <abstract>
   This class provides a way to perform affine transforms.  It provides 
   a matrix for transforming from one coordinate system to another.
   </abstract>
   Copyright (C) 1996,1999 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: August 1997
   Author: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: March 1999
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include "config.h"
#include <math.h>

#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include "Foundation/NSAffineTransform.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSDebug.h"

/* Private definitions */
#define A _matrix.m11
#define B _matrix.m12
#define C _matrix.m21
#define D _matrix.m22
#define TX _matrix.tX
#define TY _matrix.tY

/* A Postscript matrix looks like this:

  /  a  b  0 \
  |  c  d  0 |
  \ tx ty  1 /

 */

static const float pi = 3.1415926535897932384626434;

/* Quick function to multiply two coordinate matrices. C = AB */
static inline NSAffineTransformStruct 
matrix_multiply (NSAffineTransformStruct MA, NSAffineTransformStruct MB)
{
  NSAffineTransformStruct MC;
  MC.m11 = MA.m11 * MB.m11 + MA.m12 * MB.m21;
  MC.m12 = MA.m11 * MB.m12 + MA.m12 * MB.m22;
  MC.m21 = MA.m21 * MB.m11 + MA.m22 * MB.m21;
  MC.m22 = MA.m21 * MB.m12 + MA.m22 * MB.m22;
  MC.tX  = MA.tX * MB.m11 + MA.tY * MB.m21 + MB.tX;
  MC.tY  = MA.tX * MB.m12 + MA.tY * MB.m22 + MB.tY;
  return MC;
}

@implementation NSAffineTransform

static NSAffineTransformStruct identityTransform = {
   1.0, 0.0, 0.0, 1.0, 0.0, 0.0
};

/**
 * Return an autoreleased instance of this class.
 */
+ (NSAffineTransform*) transform
{
  NSAffineTransform	*t;

  t = (NSAffineTransform*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  t->_matrix = identityTransform;
  return AUTORELEASE(t);
}

/**
 * Return an autoreleased instance of this class.
 */
+ (id) new
{
  NSAffineTransform	*t;

  t = (NSAffineTransform*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  t->_matrix = identityTransform;
  return t;
}

/**
 * Appends the transform matrix to the receiver.  This is done by performing a
 * matrix multiplication of the receiver with aTransform so that aTransform
 * is the first transform applied to the user coordinate. The new
 * matrix then replaces the receiver's matrix.
 */
- (void) appendTransform: (NSAffineTransform*)aTransform
{
  _matrix = matrix_multiply(_matrix, aTransform->_matrix);
}

- (NSString*) description
{
  return [NSString stringWithFormat:
    @"NSAffineTransform ((%f, %f) (%f, %f) (%f, %f))", A, B, C, D, TX, TY];
}

/**
 * Initialize the transformation matrix instance to the identity matrix.
 * The identity matrix transforms a point to itself.
 */ 
- (id) init
{
  _matrix = identityTransform;
  return self;
}

/**
 * Initialize the receiever's instance with the instance represented 
 * by aTransform. 
 */
- (id) initWithTransform: (NSAffineTransform*)aTransform
{
  _matrix = aTransform->_matrix;
  return self;
}

/**
 * Calculates the inverse of the receiver's matrix and replaces the 
 * receiever's matrix with it.
 */
- (void) invert
{
  float newA, newB, newC, newD, newTX, newTY;
  float det;

  det = A * D - B * C;
  if (det == 0)
    {
      NSLog (@"error: determinant of matrix is 0!");
      return;
    }

  newA = D / det;
  newB = -B / det;
  newC = -C / det;
  newD = A / det;
  newTX = (-D * TX + C * TY) / det;
  newTY = (B * TX - A * TY) / det;

  NSDebugLLog(@"NSAffineTransform",
	@"inverse of matrix ((%f, %f) (%f, %f) (%f, %f))\n"
	@"is ((%f, %f) (%f, %f) (%f, %f))",
	A, B, C, D, TX, TY,
	newA, newB, newC, newD, newTX, newTY);

  A = newA; B = newB;
  C = newC; D = newD;
  TX = newTX; TY = newTY;
}

/**
 * Prepends the transform matrix to the receiver.  This is done by performing a
 * matrix multiplication of the receiver with aTransform so that aTransform
 * is the last transform applied to the user coordinate. The new
 * matrix then replaces the receiver's matrix.
 */
- (void) prependTransform: (NSAffineTransform*)aTransform
{
  _matrix = matrix_multiply(aTransform->_matrix, _matrix);
}

/**
 * Applies the rotation specified by angle in degrees.   Points transformed
 * with the transformation matrix of the receiver are rotated counter-clockwise 
 * by the number of degrees specified by angle.
 */
- (void) rotateByDegrees: (float)angle
{
  [self rotateByRadians: pi * angle / 180];
}

/**
 * Applies the rotation specified by angle in radians.   Points transformed
 * with the transformation matrix of the receiver are rotated counter-clockwise 
 * by the number of radians specified by angle.
 */
- (void) rotateByRadians: (float)angleRad
{
  float sine = sin (angleRad);
  float cosine = cos (angleRad);
  NSAffineTransformStruct rotm;
  rotm.m11 = cosine; rotm.m12 = sine; rotm.m21 = -sine; rotm.m22 = cosine;
  rotm.tX = rotm.tY = 0;
  _matrix = matrix_multiply(rotm, _matrix);
}

/**
 * Scales the transformation matrix of the reciever by the factor specified
 * by scale.  
 */
- (void) scaleBy: (float)scale
{
  NSAffineTransformStruct scam = identityTransform;
  scam.m11 = scale; scam.m22 = scale;
  _matrix = matrix_multiply(scam, _matrix);
}

/**
 * Scales the X axis of the receiver's transformation matrix 
 * by scaleX and the Y axis of the transformation matrix by scaleY.
 */
- (void) scaleXBy: (float)scaleX yBy: (float)scaleY
{
  NSAffineTransformStruct scam = identityTransform;
  scam.m11 = scaleX; scam.m22 = scaleY;
  _matrix = matrix_multiply(scam, _matrix);
}

/**
 * <p>
 * Sets the structure which represents the matrix of the reciever. 
 * The struct is of the form:</p>
 * <p>{m11, m12, m21, m22, tX, tY}</p>
 */
- (void) setTransformStruct: (NSAffineTransformStruct)val
{
  _matrix = val;
}

/**
 * Transforms a single point based on the transformation matrix.
 * Returns the resulting point.
 */
- (NSPoint) transformPoint: (NSPoint)aPoint
{
  NSPoint new;

  new.x = A * aPoint.x + C * aPoint.y + TX;
  new.y = B * aPoint.x + D * aPoint.y + TY;

  return new;
}

/**
 * Transforms the NSSize represented by aSize using the reciever's 
 * transformation matrix.  Returns the resulting NSSize.
 */
- (NSSize) transformSize: (NSSize)aSize
{
  NSSize new;

  new.width = A * aSize.width + C * aSize.height;
  if (new.width < 0)
    new.width = - new.width;
  new.height = B * aSize.width + D * aSize.height;
  if (new.height < 0)
    new.height = - new.height;

  return new;
}

/**
 * <p>
 * Returns the <code>NSAffineTransformStruct</code> structure 
 * which represents the matrix of the reciever. 
 * The struct is of the form:</p>
 * <p>{m11, m12, m21, m22, tX, tY}</p>
 */
- (NSAffineTransformStruct) transformStruct
{
  return _matrix;
}

/**
 * Applies the translation specified by tranX and tranY to the receiver's matrix.
 * Points transformed by the reciever's matrix after this operation will 
 * be shifted in position based on the specified translation.
 */
- (void) translateXBy: (float)tranX  yBy: (float)tranY
{
  NSAffineTransformStruct tranm = identityTransform;
  tranm.tX = tranX;
  tranm.tY = tranY;
  _matrix = matrix_multiply(tranm, _matrix);
}

- (id) copyWithZone: (NSZone*)zone
{
  return NSCopyObject(self, 0, zone);
}

- (BOOL) isEqual: (id)anObject
{
  if ([anObject class] == isa)
    {
      NSAffineTransform	*o = anObject;

      if (A == o->A && B == o->B && C == o->C
	&& D == o->D && TX == o->TX && TY == o->TY)
	return YES;
    }
  return NO;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSAffineTransformStruct	replace;
    
  [aCoder decodeArrayOfObjCType: @encode(float)
			  count: 6
			     at: (float*)&replace];
  [self setTransformStruct: replace];

  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  NSAffineTransformStruct	replace;
    
  replace = [self transformStruct];
  [aCoder encodeArrayOfObjCType: @encode(float)
			  count: 6
			     at: (float*)&replace];
}

@end /* NSAffineTransform */

