/* NSGeometry.c - geometry functions
 * Copyright (C) 1993, 1994, 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: Mar 1995
 * 
 * This file is part of the GNU Objective C Class Library.
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

/**** Included Headers *******************************************************/

#include <math.h>
#include <objects/stdobjects.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>

/**** Type, Constant, and Macro Definitions **********************************/

/**** Function Implementations ***********************************************/

/** Create Basic Structures... **/

NSPoint	
NSMakePoint(float x, float y)
{
  NSPoint point;

  point.x = x;
  point.y = y;
  return point;
}

NSSize	
NSMakeSize(float w, float h)
{
  NSSize size;

  size.width = w;
  size.height = h;
  return size;
}

NSRect	
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

float 
NSMaxX(NSRect aRect)
{
  return aRect.origin.x + aRect.size.width;
}

float 
NSMaxY(NSRect aRect)
{
  return aRect.origin.y + aRect.size.height;
}

float 
NSMidX(NSRect aRect)
{
  return aRect.origin.x + (aRect.size.width / 2.0);
}

float 
NSMidY(NSRect aRect)
{
  return aRect.origin.y + (aRect.size.height / 2.0);
}

float 
NSMinX(NSRect aRect)
{
  return aRect.origin.x;
}

float 
NSMinY(NSRect aRect)
{
  return aRect.origin.y;
}

float 
NSWidth(NSRect aRect)
{
  return aRect.size.width;
}

float
NSHeight(NSRect aRect)
{
  return aRect.size.height;
}

/** Modify a Copy of a Rectangle... **/

NSRect 	
NSOffsetRect(NSRect aRect, float dx, float dy)
{
  NSRect rect = aRect;

  rect.origin.x += dx;
  rect.origin.y += dy;
  return rect;
}

NSRect 	
NSInsetRect(NSRect aRect, float dX, float dY)
{
  NSRect rect;

  rect = NSOffsetRect(aRect, dX, dY);
  rect.size.width -= (2 * dX);
  rect.size.height -= (2 * dY);
  return rect;
}

void 	
NSDivideRect(NSRect aRect,
             NSRect *slice,
             NSRect *remainder,
             float amount,
             NSRectEdge edge)
{
  static NSRect sRect, rRect;
    
  if (!slice)
    slice = &sRect;
  if (!remainder)
    remainder = &rRect;
    
  if (NSIsEmptyRect(aRect))
  {
    *slice = NSMakeRect(0,0,0,0);
    *remainder = NSMakeRect(0,0,0,0);
    return;
  }

  switch (edge)
  {
    case NSMinXEdge:
      if (amount > aRect.size.width)
      {
        *slice = aRect;
        *remainder = NSMakeRect(NSMaxX(aRect),
                                aRect.origin.y, 
                                0,
                                aRect.size.height);
      }
      else
      {
	    *slice = NSMakeRect(aRect.origin.x,
                            aRect.origin.y,
                            amount, 
                            aRect.size.height);
        *remainder = NSMakeRect(NSMaxX(*slice),
                                aRect.origin.y, 
                                NSMaxX(aRect) - NSMaxX(*slice),
                                aRect.size.height);
      }
      break;
    case NSMinYEdge:
      if (amount > aRect.size.height)
      {
        *slice = aRect;
        *remainder = NSMakeRect(aRect.origin.x,
                                NSMaxY(aRect), 
                                aRect.size.width, 0);
      }
      else
      {
        *slice = NSMakeRect(aRect.origin.x,
                            aRect.origin.y, 
                            aRect.size.width,
                            amount);
        *remainder = NSMakeRect(aRect.origin.x,
                                NSMaxY(*slice), 
                                aRect.size.width,
                                NSMaxY(aRect) - NSMaxY(*slice));
      }
      break;
    case (NSMaxXEdge):
      if (amount > aRect.size.width)
      {
	    *slice = aRect;
	    *remainder = NSMakeRect(aRect.origin.x,
                                aRect.origin.y, 
                                0,
                                aRect.size.height);
      }
      else
      {
	    *slice = NSMakeRect(NSMaxX(aRect) - amount,
                            aRect.origin.y,
                            amount,
                            aRect.size.height);
	    *remainder = NSMakeRect(aRect.origin.x,
                                aRect.origin.y, 
                                NSMinX(*slice) - aRect.origin.x,
                                aRect.size.height);
      }
      break;
    case NSMaxYEdge:
      if (amount > aRect.size.height)
      {
        *slice = aRect;
        *remainder = NSMakeRect(aRect.origin.x,
                                aRect.origin.y, 
                                aRect.size.width,
                                0);
      }
      else
      {
        *slice = NSMakeRect(aRect.origin.x,
                            NSMaxY(aRect) - amount, 
                            aRect.size.width,
                            amount);
        *remainder = NSMakeRect(aRect.origin.x,
                                aRect.origin.y, 
                                aRect.size.width,
                                NSMinY(*slice) - aRect.origin.y);
      }
      break;
    default:
      break;
  }

  return;
}

NSRect 	
NSIntegralRect(NSRect aRect)
{
  NSRect rect;

  if (NSIsEmptyRect(aRect))
    return NSMakeRect(0, 0, 0, 0);
	
  rect.origin.x = floor(aRect.origin.x);
  rect.origin.y = floor(aRect.origin.y);
  rect.size.width = ceil(aRect.size.width);
  rect.size.height = ceil(aRect.size.height);
  return rect;
}


/** Compute a Third Rectangle from Two Rectangles... **/

NSRect 	
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

/* FIXME: This function isn't listed in the OpenStep Specification. */
BOOL     
NSIntersectsRect(NSRect aRect, NSRect bRect)
{
  /* Note that intersecting at a line or a point doesn't count */
  return (NSMaxX(aRect) <= NSMinX(bRect)
          || NSMaxX(bRect) <= NSMinX(aRect)
	      || NSMaxY(aRect) <= NSMinY(bRect)
	      || NSMaxY(bRect) <= NSMinY(aRect)) ? NO : YES;
}

NSRect   
NSIntersectionRect (NSRect aRect, NSRect bRect)
{
  NSRect rect;

  if (!NSIntersectsRect(aRect, bRect))
  {
    return NSMakeRect(0, 0, 0, 0);
  }

  if (NSMinX(aRect) <= NSMinX(bRect))
  {
    rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(bRect);
    rect.origin.x = NSMinX(bRect);
  }
  else
  {
    rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(aRect);
    rect.origin.x = NSMinX(aRect);
  }

  if (NSMinY(aRect) <= NSMinY(bRect))
  {
    rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(bRect);
    rect.origin.y = NSMinY(bRect);
  }
  else
  {
    rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(aRect);
    rect.origin.y = NSMinY(aRect);
  }

  return rect;
}

/** Test geometric relationships... **/

BOOL 	
NSEqualRects(NSRect aRect, NSRect bRect)
{
  /* FIXME: Isn't it more efficient to do this by hand, rather than with
   * all of these function calls?  Maybe this doesn't matter, though. */
  return ((NSMinX(aRect) == NSMinX(bRect)) 
          && (NSMinY(aRect) == NSMinY(bRect)) 
          && (NSWidth(aRect) == NSWidth(bRect)) 
          && (NSHeight(aRect) == NSHeight(bRect))) ? YES : NO;
}

BOOL 	
NSEqualSizes(NSSize aSize, NSSize bSize)
{
  return ((aSize.width == bSize.width) 
          && (aSize.height == bSize.height)) ? YES : NO;
}

BOOL 	
NSEqualPoints(NSPoint aPoint, NSPoint bPoint)
{
  return ((aPoint.x == bPoint.x)
          && (aPoint.y == bPoint.y)) ? YES : NO;
}

BOOL 	
NSIsEmptyRect(NSRect aRect)
{
  return ((NSWidth(aRect) > 0) && (NSHeight(aRect) > 0)) ? NO : YES;
}

BOOL 	
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

BOOL 	
NSPointInRect(NSPoint aPoint, NSRect aRect)
{
  return NSMouseInRect(aPoint, aRect, YES);
}

BOOL 	
NSContainsRect(NSRect aRect, NSRect bRect)
{
  return ((NSMinX(aRect) < NSMinX(bRect))
          && (NSMinY(aRect) < NSMinY(bRect))
          && (NSMaxX(aRect) > NSMaxX(bRect))
          && (NSMaxY(aRect) > NSMaxY(bRect))) ? YES : NO;
}

/** Get a String Representation... **/

NSString *
NSStringFromPoint(NSPoint aPoint)
{
  return [NSString stringWithFormat:@"{x=%f; y=%f}", aPoint.x, aPoint.y];
}

NSString *
NSStringFromRect(NSRect aRect)
{
  return [NSString stringWithFormat:@"{x=%f; y=%f; width=%f; height=%f}",
                   aRect.origin.x, aRect.origin.y,
                   aRect.size.width, aRect.size.height];
}

NSString *
NSStringFromSize(NSSize aSize)
{
  return [NSString stringWithFormat:@"{width=%f; height=%f}",
                   aSize.width, aSize.height];
}

