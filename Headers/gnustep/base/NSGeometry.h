/* Interface for NSGeometry routines for GNUStep
 * Copyright (C) 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: 1995
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

#ifndef __NSGeometry_h_GNUSTEP_BASE_INCLUDE
#define __NSGeometry_h_GNUSTEP_BASE_INCLUDE

/**** Included Headers *******************************************************/

#include <objc/objc.h>
#include <Foundation/NSString.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Point definition. */
typedef struct _NSPoint NSPoint;
struct _NSPoint
{
  float x;
  float y;
};

/* Rectangle sizes. */
typedef struct _NSSize NSSize;
struct _NSSize
{
  float width;
  float height;
};

/* Rectangle. */
typedef struct _NSRect NSRect;
struct _NSRect
{
  NSPoint origin;
  NSSize size;
};

/* Sides of a rectangle. */
typedef enum _NSRectEdge NSRectEdge;
enum _NSRectEdge
{
  NSMinXEdge,
  NSMinYEdge,
  NSMaxXEdge,
  NSMaxYEdge
};

const NSPoint NSZeroPoint;  /* A zero point. */
const NSRect NSZeroRect;    /* A zero origin rectangle. */
const NSSize NSZeroSize;    /* A zero size rectangle. */

/**** Function Prototypes ****************************************************/

/** Create Basic Structures... **/

/* Returns an NSPoint having x-coordinate X and y-coordinate Y. */
extern NSPoint
NSMakePoint(float x, float y);

/* Returns an NSSize having width WIDTH and height HEIGHT. */
extern NSSize
NSMakeSize(float w, float h);

/* Returns an NSRect having point of origin (X, Y) and size {W, H}. */
extern NSRect
NSMakeRect(float x, float y, float w, float h);

/** Get a Rectangle's Coordinates... **/

/* Returns the greatest x-coordinate value still inside ARECT. */
extern float
NSMaxX(NSRect aRect);

/* Returns the greatest y-coordinate value still inside ARECT. */
extern float
NSMaxY(NSRect aRect);

/* Returns the x-coordinate of ARECT's middle point. */
extern float
NSMidX(NSRect aRect);

/* Returns the y-coordinate of ARECT's middle point. */
extern float
NSMidY(NSRect aRect);

/* Returns the least x-coordinate value still inside ARECT. */
extern float
NSMinX(NSRect aRect);

/* Returns the least y-coordinate value still inside ARECT. */
extern float
NSMinY(NSRect aRect);

/* Returns ARECT's width. */
extern float
NSWidth(NSRect aRect);

/* Returns ARECT's height. */
extern float
NSHeight(NSRect aRect);

/** Modify a Copy of a Rectangle... **/

/* Returns the rectangle obtained by moving each of ARECT's
 * horizontal sides inward by DY and each of ARECT's vertical
 * sides inward by DX. */
extern NSRect
NSInsetRect(NSRect aRect, float dX, float dY);

/* Returns the rectangle obtained by translating ARECT
 * horizontally by DX and vertically by DY. */
extern NSRect
NSOffsetRect(NSRect aRect, float dx, float dy);

/* Divides ARECT into two rectangles (namely SLICE and REMAINDER) by
 * "cutting" ARECT---parallel to, and a distance AMOUNT from the edge
 * of ARECT determined by EDGE.  You may pass 0 in as either of SLICE or
 * REMAINDER to avoid obtaining either of the created rectangles. */
extern void
NSDivideRect(NSRect aRect,
             NSRect *slice,
             NSRect *remainder,
             float amount,
             NSRectEdge edge);

/* Returns a rectangle obtained by expanding ARECT minimally
 * so that all four of its defining components are integers. */
extern NSRect
NSIntegralRect(NSRect aRect);

/** Compute a Third Rectangle from Two Rectangles... **/

/* Returns the smallest rectangle which contains both ARECT
 * and BRECT (modulo a set of measure zero).  If either of ARECT
 * or BRECT is an empty rectangle, then the other rectangle is
 * returned.  If both are empty, then the empty rectangle is returned. */
extern NSRect
NSUnionRect(NSRect aRect, NSRect bRect);

/* Returns the largest rectange which lies in both ARECT and
 * BRECT.  If ARECT and BRECT have empty intersection (or, rather,
 * intersection of measure zero, since this includes having their
 * intersection be only a point or a line), then the empty
 * rectangle is returned. */
extern NSRect
NSIntersectionRect(NSRect aRect, NSRect bRect);

/** Test geometric relationships... **/

/* Returns 'YES' iff ARECT's and BRECT's origin and size are the same. */
extern BOOL
NSEqualRects(NSRect aRect, NSRect bRect);

/* Returns 'YES' iff ASIZE's and BSIZE's width and height are the same. */
extern BOOL
NSEqualSizes(NSSize aSize, NSSize bSize);

/* Returns 'YES' iff APOINT's and BPOINT's x- and y-coordinates
 * are the same. */
extern BOOL
NSEqualPoints(NSPoint aPoint, NSPoint bPoint);

/* Returns 'YES' iff the area of ARECT is zero (i.e., iff either
 * of ARECT's width or height is negative or zero). */
extern BOOL
NSIsEmptyRect(NSRect aRect);

/* Returns 'YES' iff APOINT is inside ARECT. */ 
extern BOOL
NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped);

/* Just like 'NSMouseInRect(aPoint, aRect, YES)'. */
extern BOOL
NSPointInRect(NSPoint aPoint, NSRect aRect);

/* Returns 'YES' iff ARECT totally encloses BRECT.  NOTE: For
 * this to be the case, ARECT cannot be empty, nor can any side
 * of BRECT coincide with any side of ARECT. */
extern BOOL
NSContainsRect(NSRect aRect, NSRect bRect);

/* FIXME: This function isn't listed in the OpenStep Specification. */
extern BOOL
NSIntersectsRect(NSRect aRect, NSRect bRect);

/** Get a String Representation... **/

/* Returns an NSString of the form "{x=X; y=Y}", where
 * X and Y are the x- and y-coordinates of APOINT, respectively. */
extern NSString *
NSStringFromPoint(NSPoint aPoint);

/* Returns an NSString of the form "{x=X; y=Y; width=W; height=H}",
 * where X, Y, W, and H are the x-coordinate, y-coordinate,
 * width, and height of ARECT, respectively. */
extern NSString *
NSStringFromRect(NSRect aRect);

/* Returns an NSString of the form "{width=W; height=H}", where
 * W and H are the width and height of ASIZE, respectively. */
extern NSString *
NSStringFromSize(NSSize aSize);

#endif /* __NSGeometry_h_GNUSTEP_BASE_INCLUDE */
