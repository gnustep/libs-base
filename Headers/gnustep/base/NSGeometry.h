/* Interface for NSGeometry routines for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995
   
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

#ifndef __NSGeometry_h_OBJECTS_INCLUDE
#define __NSGeometry_h_OBJECTS_INCLUDE

#include <objc/objc.h>

/* Geometry */

typedef struct _NSPoint {	/* Point definition. */
    float x;
    float y;
} NSPoint;
	
typedef struct _NSSize {	/* Rectangle sizes. */
    float width;
    float height;
} NSSize;

typedef struct _NSRect {	/* Rectangle. */
    NSPoint origin;
    NSSize size;
} NSRect;

typedef enum {
    NSMinXEdge,
    NSMinYEdge,
    NSMaxXEdge,
    NSMaxYEdge
} NSRectEdge;

/* Standard zero structures */
const NSPoint NSZeroPoint;
const NSRect NSZeroRect;
const NSSize NSZeroSize;

/* Create Basic Structures */
extern NSPoint	NSMakePoint(float x, float y);
extern NSSize	NSMakeSize(float w, float h);
extern NSRect	NSMakeRect(float x, float y, float w, float h);

/* Get rectangle coordinates */
extern float NSMaxX(NSRect aRect);
extern float NSMaxY(NSRect aRect);
extern float NSMidX(NSRect aRect);
extern float NSMidY(NSRect aRect);
extern float NSMinX(NSRect aRect);
extern float NSMinY(NSRect aRect);
extern float NSWidth(NSRect aRect);
extern float NSHeight(NSRect aRect);

/* Modify a copy of a rectangle */
extern NSRect 	NSOffsetRect(NSRect aRect, float dx, float dy);
extern NSRect 	NSInsetRect(NSRect aRect, float dX, float dY);
extern NSRect 	NSIntegralRect(NSRect aRect);
extern void 	NSDivideRect(NSRect aRect, NSRect *slice, NSRect *remainder,
			float amount, NSRectEdge edge);

/* Compute a third rectangle from two rectangles */
extern NSRect 	NSUnionRect(NSRect aRect, NSRect bRect);
extern NSRect   NSIntersectionRect (NSRect aRect, NSRect bRect);


/* Test geometrical relationships */
extern BOOL 	NSEqualRects(NSRect aRect, NSRect bRect);
extern BOOL 	NSEqualSizes(NSSize aSize, NSSize bSize);
extern BOOL 	NSEqualPoints(NSPoint aPoint, NSPoint bPoint);
extern BOOL 	NSIsEmptyRect(NSRect aRect);
extern BOOL 	NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped);
extern BOOL 	NSPointInRect(NSPoint aPoint, NSRect aRect);
extern BOOL 	NSContainsRect(NSRect aRect, NSRect bRect);

extern BOOL	NSIntersectsRect (NSRect aRect, NSRect bRect);

#endif /* __NSGeometry_h_OBJECTS_INCLUDE */
