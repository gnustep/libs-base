/* Interface for NSGeometry routines for GNUStep
 * Copyright (C) 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: 1995,199
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

#ifndef __NSGeometry_h_GNUSTEP_BASE_INCLUDE
#define __NSGeometry_h_GNUSTEP_BASE_INCLUDE

/**** Included Headers *******************************************************/

#include <objc/objc.h>
#ifdef __OBJC__
#include <Foundation/NSString.h>
#endif

/**** Type, Constant, and Macro Definitions **********************************/

#ifndef MAX
#define MAX(a,b) \
       ({typeof(a) _MAX_a = (a); typeof(b) _MAX_b = (b);  \
         _MAX_a > _MAX_b ? _MAX_a : _MAX_b; })
#define	GS_DEFINED_MAX
#endif

#ifndef MIN
#define MIN(a,b) \
       ({typeof(a) _MIN_a = (a); typeof(b) _MIN_b = (b);  \
         _MIN_a < _MIN_b ? _MIN_a : _MIN_b; })
#define	GS_DEFINED_MIN
#endif

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

/*
 *	All but the most complex functions are declared static inline in this
 *	header file so that they are maximally efficient.  In order to provide
 *	true functions (for code modules that don't have this header) this
 *	header is included in NSGeometry.m where the functions are no longer
 *	declared inline.
 */
#ifdef	IN_NSGEOMETRY_M
#define	GS_GEOM_SCOPE	extern
#define GS_GEOM_ATTR	
#else
#define	GS_GEOM_SCOPE	static inline
#define GS_GEOM_ATTR	__attribute__((unused))
#endif

/** Create Basic Structures... **/

/* Returns an NSPoint having x-coordinate X and y-coordinate Y. */
GS_GEOM_SCOPE NSPoint
NSMakePoint(float x, float y) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSPoint
NSMakePoint(float x, float y)
{
  NSPoint point;

  point.x = x;
  point.y = y;
  return point;
}

/* Returns an NSSize having width WIDTH and height HEIGHT. */
GS_GEOM_SCOPE NSSize
NSMakeSize(float w, float h) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSSize
NSMakeSize(float w, float h)
{
  NSSize size;

  size.width = w;
  size.height = h;
  return size;
}

/* Returns an NSRect having point of origin (X, Y) and size {W, H}. */
GS_GEOM_SCOPE NSRect
NSMakeRect(float x, float y, float w, float h) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSRect
NSMakeRect(float x, float y, float w, float h)
{
  NSRect rect;

  rect.origin.x = x;
  rect.origin.y = y;
  rect.size.width = w;
  rect.size.height = h;
  return rect;
}

/** Get a Rectangle's Coordinates... **/

/* Returns the greatest x-coordinate value still inside ARECT. */
GS_GEOM_SCOPE float
NSMaxX(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMaxX(NSRect aRect)
{
  return aRect.origin.x + aRect.size.width;
}

/* Returns the greatest y-coordinate value still inside ARECT. */
GS_GEOM_SCOPE float
NSMaxY(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMaxY(NSRect aRect)
{
  return aRect.origin.y + aRect.size.height;
}

/* Returns the x-coordinate of ARECT's middle point. */
GS_GEOM_SCOPE float
NSMidX(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMidX(NSRect aRect)
{
  return aRect.origin.x + (aRect.size.width / 2.0);
}

/* Returns the y-coordinate of ARECT's middle point. */
GS_GEOM_SCOPE float
NSMidY(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMidY(NSRect aRect)
{
  return aRect.origin.y + (aRect.size.height / 2.0);
}

/* Returns the least x-coordinate value still inside ARECT. */
GS_GEOM_SCOPE float
NSMinX(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMinX(NSRect aRect)
{
  return aRect.origin.x;
}

/* Returns the least y-coordinate value still inside ARECT. */
GS_GEOM_SCOPE float
NSMinY(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSMinY(NSRect aRect)
{
  return aRect.origin.y;
}

/* Returns ARECT's width. */
GS_GEOM_SCOPE float
NSWidth(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSWidth(NSRect aRect)
{
  return aRect.size.width;
}

/* Returns ARECT's height. */
GS_GEOM_SCOPE float
NSHeight(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE float
NSHeight(NSRect aRect)
{
  return aRect.size.height;
}

/* Returns 'YES' iff the area of ARECT is zero (i.e., iff either
 * of ARECT's width or height is negative or zero). */
GS_GEOM_SCOPE BOOL
NSIsEmptyRect(NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSIsEmptyRect(NSRect aRect)
{
  return ((NSWidth(aRect) > 0) && (NSHeight(aRect) > 0)) ? NO : YES;
}

/** Modify a Copy of a Rectangle... **/

/* Returns the rectangle obtained by translating ARECT
 * horizontally by DX and vertically by DY. */
GS_GEOM_SCOPE NSRect
NSOffsetRect(NSRect aRect, float dx, float dy) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSRect
NSOffsetRect(NSRect aRect, float dx, float dy)
{
  NSRect rect = aRect;

  rect.origin.x += dx;
  rect.origin.y += dy;
  return rect;
}

/* Returns the rectangle obtained by moving each of ARECT's
 * horizontal sides inward by DY and each of ARECT's vertical
 * sides inward by DX. */
GS_GEOM_SCOPE NSRect
NSInsetRect(NSRect aRect, float dX, float dY) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSRect
NSInsetRect(NSRect aRect, float dX, float dY)
{
  NSRect rect;

  rect = NSOffsetRect(aRect, dX, dY);
  rect.size.width -= (2 * dX);
  rect.size.height -= (2 * dY);
  return rect;
}

/* Divides ARECT into two rectangles (namely SLICE and REMAINDER) by
 * "cutting" ARECT---parallel to, and a distance AMOUNT from the edge
v * of ARECT determined by EDGE.  You may pass 0 in as either of SLICE or
 * REMAINDER to avoid obtaining either of the created rectangles. */
GS_EXPORT void
NSDivideRect(NSRect aRect,
             NSRect *slice,
             NSRect *remainder,
             float amount,
             NSRectEdge edge);

/* Returns a rectangle obtained by expanding ARECT minimally
 * so that all four of its defining components are integers. */
GS_EXPORT NSRect
NSIntegralRect(NSRect aRect);

/** Compute a Third Rectangle from Two Rectangles... **/

/* Returns the smallest rectangle which contains both ARECT
 * and BRECT (modulo a set of measure zero).  If either of ARECT
 * or BRECT is an empty rectangle, then the other rectangle is
 * returned.  If both are empty, then the empty rectangle is returned. */
GS_GEOM_SCOPE NSRect
NSUnionRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSRect
NSUnionRect(NSRect aRect, NSRect bRect)
{
  NSRect rect;

  if (NSIsEmptyRect(aRect) && NSIsEmptyRect(bRect))
    return NSMakeRect(0,0,0,0);
  else if (NSIsEmptyRect(aRect))
    return bRect;
  else if (NSIsEmptyRect(bRect))
    return aRect;

  rect = NSMakeRect(MIN(NSMinX(aRect), NSMinX(bRect)),
                    MIN(NSMinY(aRect), NSMinY(bRect)), 0, 0);

  rect = NSMakeRect(NSMinX(rect),
                    NSMinY(rect),
                    MAX(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(rect),
                    MAX(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(rect));

  return rect;
}

/* Returns the largest rectange which lies in both ARECT and
 * BRECT.  If ARECT and BRECT have empty intersection (or, rather,
 * intersection of measure zero, since this includes having their
 * intersection be only a point or a line), then the empty
 * rectangle is returned. */
GS_GEOM_SCOPE NSRect
NSIntersectionRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE NSRect
NSIntersectionRect (NSRect aRect, NSRect bRect)
{
  if (NSMaxX(aRect) <= NSMinX(bRect) || NSMaxX(bRect) <= NSMinX(aRect)
    || NSMaxY(aRect) <= NSMinY(bRect) || NSMaxY(bRect) <= NSMinY(aRect)) 
    {
      return NSMakeRect(0, 0, 0, 0);
    }
  else
    {
      NSRect    rect;

      if (NSMinX(aRect) <= NSMinX(bRect))
        rect.origin.x = bRect.origin.x;
      else
        rect.origin.x = aRect.origin.x;

      if (NSMinY(aRect) <= NSMinY(bRect))
        rect.origin.y = bRect.origin.y;
      else
        rect.origin.y = aRect.origin.y;

      if (NSMaxX(aRect) >= NSMaxX(bRect))
        rect.size.width = NSMaxX(bRect) - rect.origin.x;
      else
        rect.size.width = NSMaxX(aRect) - rect.origin.x;

      if (NSMaxY(aRect) >= NSMaxY(bRect))
        rect.size.height = NSMaxY(bRect) - rect.origin.y;
      else
        rect.size.height = NSMaxY(aRect) - rect.origin.y;

      return rect;
    }
}

/** Test geometric relationships... **/

/* Returns 'YES' iff ARECT's and BRECT's origin and size are the same. */
GS_GEOM_SCOPE BOOL
NSEqualRects(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSEqualRects(NSRect aRect, NSRect bRect)
{
  return ((NSMinX(aRect) == NSMinX(bRect))
          && (NSMinY(aRect) == NSMinY(bRect))
          && (NSWidth(aRect) == NSWidth(bRect))
          && (NSHeight(aRect) == NSHeight(bRect))) ? YES : NO;
}

/* Returns 'YES' iff ASIZE's and BSIZE's width and height are the same. */
GS_GEOM_SCOPE BOOL
NSEqualSizes(NSSize aSize, NSSize bSize) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSEqualSizes(NSSize aSize, NSSize bSize)
{
  return ((aSize.width == bSize.width)
          && (aSize.height == bSize.height)) ? YES : NO;
}

/* Returns 'YES' iff APOINT's and BPOINT's x- and y-coordinates
 * are the same. */
GS_GEOM_SCOPE BOOL
NSEqualPoints(NSPoint aPoint, NSPoint bPoint) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSEqualPoints(NSPoint aPoint, NSPoint bPoint)
{
  return ((aPoint.x == bPoint.x)
          && (aPoint.y == bPoint.y)) ? YES : NO;
}

/* Returns 'YES' iff APOINT is inside ARECT. */ 
GS_GEOM_SCOPE BOOL
NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped)
{
  if (flipped)
    return ((aPoint.x >= NSMinX(aRect))
            && (aPoint.y >= NSMinY(aRect))
            && (aPoint.x < NSMaxX(aRect))
            && (aPoint.y < NSMaxY(aRect))) ? YES : NO;
  else
    return ((aPoint.x >= NSMinX(aRect))
            && (aPoint.y > NSMinY(aRect))
            && (aPoint.x < NSMaxX(aRect))
            && (aPoint.y <= NSMaxY(aRect))) ? YES : NO;
}

/* Just like 'NSMouseInRect(aPoint, aRect, YES)'. */
GS_GEOM_SCOPE BOOL
NSPointInRect(NSPoint aPoint, NSRect aRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSPointInRect(NSPoint aPoint, NSRect aRect)
{
  return NSMouseInRect(aPoint, aRect, YES);
}

/* Returns 'YES' iff ARECT totally encloses BRECT.  NOTE: For
 * this to be the case, ARECT cannot be empty, nor can any side
 * of BRECT coincide with any side of ARECT. */
GS_GEOM_SCOPE BOOL
NSContainsRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSContainsRect(NSRect aRect, NSRect bRect)
{
  return ((NSMinX(aRect) < NSMinX(bRect))
          && (NSMinY(aRect) < NSMinY(bRect))
          && (NSMaxX(aRect) > NSMaxX(bRect))
          && (NSMaxY(aRect) > NSMaxY(bRect))) ? YES : NO;
}

#ifndef	STRICT_OPENSTEP
GS_GEOM_SCOPE BOOL
NSIntersectsRect(NSRect aRect, NSRect bRect) GS_GEOM_ATTR;

GS_GEOM_SCOPE BOOL
NSIntersectsRect(NSRect aRect, NSRect bRect)
{
  /* Note that intersecting at a line or a point doesn't count */
  return (NSMaxX(aRect) <= NSMinX(bRect)
          || NSMaxX(bRect) <= NSMinX(aRect)
              || NSMaxY(aRect) <= NSMinY(bRect)
              || NSMaxY(bRect) <= NSMinY(aRect)) ? NO : YES;
}
#endif

/** Get a String Representation... **/

#ifdef __OBJC__
/* Returns an NSString of the form "{x=X; y=Y}", where
 * X and Y are the x- and y-coordinates of APOINT, respectively. */
GS_EXPORT NSString *
NSStringFromPoint(NSPoint aPoint);

/* Returns an NSString of the form "{x=X; y=Y; width=W; height=H}",
 * where X, Y, W, and H are the x-coordinate, y-coordinate,
 * width, and height of ARECT, respectively. */
GS_EXPORT NSString *
NSStringFromRect(NSRect aRect);

/* Returns an NSString of the form "{width=W; height=H}", where
 * W and H are the width and height of ASIZE, respectively. */
GS_EXPORT NSString *
NSStringFromSize(NSSize aSize);

GS_EXPORT NSPoint	NSPointFromString(NSString* string);
GS_EXPORT NSSize	NSSizeFromString(NSString* string);
GS_EXPORT NSRect	NSRectFromString(NSString* string);

#endif /* __OBJC__ */

#ifdef	GS_DEFINED_MAX
#undef	GS_DEFINED_MAX
#undef	MAX
#endif

#ifdef	GS_DEFINED_MIN
#undef	GS_DEFINED_MIN
#undef	MIN
#endif
#endif /* __NSGeometry_h_GNUSTEP_BASE_INCLUDE */
