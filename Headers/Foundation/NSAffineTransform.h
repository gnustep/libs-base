/*
   NSAffineTransform.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: August 1997
   Rewrite for MacOS-X compatibility: Richard Frith-Macdonald, 1999
   
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

#ifndef __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE
#define __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

typedef	struct {
  float	m11;
  float	m12;
  float	m21;
  float	m22;
  float	tX;
  float	tY;
} NSAffineTransformStruct;

@interface NSAffineTransform : NSObject <NSCopying, NSCoding>
{
@private
  NSAffineTransformStruct	_matrix;
  BOOL _isIdentity;	// special case: A=D=1 and B=C=0
  BOOL _isFlipY;	// special case: A=1 D=-1 and B=C=0
  BOOL _pad1 GS_UNUSED_IVAR;
  BOOL _pad2 GS_UNUSED_IVAR;
}

+ (NSAffineTransform*) transform;
- (void) appendTransform: (NSAffineTransform*)aTransform;
- (id) initWithTransform: (NSAffineTransform*)aTransform;
- (void) invert;
- (void) prependTransform: (NSAffineTransform*)aTransform;
- (void) rotateByDegrees: (float)angle;
- (void) rotateByRadians: (float)angleRad;
- (void) scaleBy: (float)scale;
- (void) scaleXBy: (float)scaleX yBy: (float)scaleY;
- (void) setTransformStruct: (NSAffineTransformStruct)val;
- (NSPoint) transformPoint: (NSPoint)aPoint;
- (NSSize) transformSize: (NSSize)aSize;
- (NSAffineTransformStruct) transformStruct;
- (void) translateXBy: (float)tranX yBy: (float)tranY;
@end

#endif /* __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE */
