/* From 
 * (Preliminary Documentation) Copyright (c) 1994 by NeXT Computer, Inc. 
 * All Rights Reserved.
 *
 * NSGeometry.h
 */
#ifndef __NSGeometry_INCLUDE__
#define __NSGeometry_INCLUDE__

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

/* Create Basic Structures */
extern NSPoint	NSMakePoint(float x, float y);
extern NSSize	NSMakeSize(float w, float h);
extern NSRect	NSMakeRect(float x, float y, float w, float h);

/* Get ractangel coordinates */
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

#endif /* _NSGeometry_include_ */
