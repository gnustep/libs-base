#import <Foundation/Foundation.h>
#import "Testing.h"

/* Tests for the NSGeometry rectangle functions not exercised by NSGeometry1.m:
 * the coordinate accessors, NSIsEmptyRect, NSOffsetRect / NSInsetRect,
 * NSIntegralRect, NSUnionRect, NSIntersectionRect, NSContainsRect,
 * NSPointInRect / NSMouseInRect and NSDivideRect.  All values are chosen so
 * the floating-point results are exact.
 */

static NSRect R(CGFloat x, CGFloat y, CGFloat w, CGFloat h)
{ return NSMakeRect(x, y, w, h); }
static NSPoint P(CGFloat x, CGFloat y)
{ return NSMakePoint(x, y); }

int main(void)
{
  START_SET("rectangle accessors")
    NSRect	r = R(2, 4, 10, 20);

    PASS(NSMinX(r) == 2, "NSMinX is the origin x");
    PASS(NSMinY(r) == 4, "NSMinY is the origin y");
    PASS(NSMaxX(r) == 12, "NSMaxX is origin x + width");
    PASS(NSMaxY(r) == 24, "NSMaxY is origin y + height");
    PASS(NSMidX(r) == 7, "NSMidX is the horizontal midpoint");
    PASS(NSMidY(r) == 14, "NSMidY is the vertical midpoint");
    PASS(NSWidth(r) == 10, "NSWidth is the width");
    PASS(NSHeight(r) == 20, "NSHeight is the height");
  END_SET("rectangle accessors")

  START_SET("NSIsEmptyRect")
    PASS(NSIsEmptyRect(R(0, 0, 0, 0)) == YES, "a zero rect is empty");
    PASS(NSIsEmptyRect(R(1, 1, 0, 5)) == YES, "a zero-width rect is empty");
    PASS(NSIsEmptyRect(R(1, 1, 5, 0)) == YES, "a zero-height rect is empty");
    PASS(NSIsEmptyRect(R(1, 1, -5, 5)) == YES, "a negative-width rect is empty");
    PASS(NSIsEmptyRect(R(1, 1, 5, 5)) == NO, "a positive-area rect is not empty");
  END_SET("NSIsEmptyRect")

  START_SET("NSOffsetRect and NSInsetRect")
    PASS(NSEqualRects(NSOffsetRect(R(2, 4, 10, 20), 3, -1), R(5, 3, 10, 20)),
      "NSOffsetRect translates the origin and keeps the size");
    PASS(NSEqualRects(NSInsetRect(R(0, 0, 10, 10), 2, 3), R(2, 3, 6, 4)),
      "NSInsetRect moves each side inward");
    PASS(NSEqualRects(NSInsetRect(R(0, 0, 4, 4), 3, 3), R(3, 3, -2, -2)),
      "NSInsetRect may produce a negative size (MacOS compatibility)");
  END_SET("NSOffsetRect and NSInsetRect")

  START_SET("NSIntegralRect")
    PASS(NSEqualRects(NSIntegralRect(R(1.2, 2.7, 3.1, 1.1)), R(1, 2, 4, 2)),
      "NSIntegralRect expands to the enclosing integer rect");
    PASS(NSEqualRects(NSIntegralRect(R(1.5, 1.5, 0, 0)), R(0, 0, 0, 0)),
      "NSIntegralRect of an empty rect is the zero rect");
  END_SET("NSIntegralRect")

  START_SET("NSUnionRect")
    PASS(NSEqualRects(NSUnionRect(R(0, 0, 4, 4), R(2, 2, 4, 4)), R(0, 0, 6, 6)),
      "NSUnionRect is the bounding box of two overlapping rects");
    PASS(NSEqualRects(NSUnionRect(R(0, 0, 2, 2), R(5, 5, 1, 1)), R(0, 0, 6, 6)),
      "NSUnionRect spans two disjoint rects");
    PASS(NSEqualRects(NSUnionRect(R(1, 1, 3, 3), R(0, 0, 0, 0)), R(1, 1, 3, 3)),
      "NSUnionRect with an empty rect returns the other rect");
    PASS(NSEqualRects(NSUnionRect(R(0, 0, 0, 0), R(0, 0, 0, 0)), R(0, 0, 0, 0)),
      "NSUnionRect of two empty rects is the zero rect");
  END_SET("NSUnionRect")

  START_SET("NSIntersectionRect")
    PASS(NSEqualRects(NSIntersectionRect(R(0, 0, 4, 4), R(2, 2, 4, 4)),
      R(2, 2, 2, 2)),
      "NSIntersectionRect is the overlapping region");
    PASS(NSEqualRects(NSIntersectionRect(R(0, 0, 2, 2), R(5, 5, 2, 2)),
      R(0, 0, 0, 0)),
      "NSIntersectionRect of disjoint rects is the zero rect");
    PASS(NSEqualRects(NSIntersectionRect(R(0, 0, 2, 2), R(2, 0, 2, 2)),
      R(0, 0, 0, 0)),
      "rects that only touch along an edge have an empty intersection");
  END_SET("NSIntersectionRect")

  START_SET("NSContainsRect, NSPointInRect and NSMouseInRect")
    NSRect	big = R(0, 0, 10, 10);

    PASS(NSContainsRect(big, R(2, 2, 3, 3)) == YES,
      "NSContainsRect is YES for a fully enclosed rect");
    PASS(NSContainsRect(big, R(8, 8, 5, 5)) == NO,
      "NSContainsRect is NO when a rect extends past a side");
    PASS(NSContainsRect(big, R(0, 0, 10, 10)) == YES,
      "NSContainsRect allows the inner rect to touch the sides");

    PASS(NSPointInRect(P(5, 5), big) == YES, "a point inside the rect is in it");
    PASS(NSPointInRect(P(0, 0), big) == YES,
      "the origin corner is in the rect (flipped convention)");
    PASS(NSPointInRect(P(10, 10), big) == NO,
      "the far corner is not in the rect");
    PASS(NSPointInRect(P(-1, 5), big) == NO, "a point left of the rect is outside");

    /* NSMouseInRect (unflipped) includes the upper edge and excludes the lower. */
    PASS(NSMouseInRect(P(5, 10), big, NO) == YES,
      "unflipped NSMouseInRect includes the maxY edge");
    PASS(NSMouseInRect(P(5, 0), big, NO) == NO,
      "unflipped NSMouseInRect excludes the minY edge");
  END_SET("NSContainsRect, NSPointInRect and NSMouseInRect")

  START_SET("NSDivideRect")
    NSRect	slice, remainder;

    NSDivideRect(R(0, 0, 10, 10), &slice, &remainder, 3, NSMinXEdge);
    PASS(NSEqualRects(slice, R(0, 0, 3, 10))
      && NSEqualRects(remainder, R(3, 0, 7, 10)),
      "NSDivideRect from the min-x edge");

    NSDivideRect(R(0, 0, 10, 10), &slice, &remainder, 3, NSMaxXEdge);
    PASS(NSEqualRects(slice, R(7, 0, 3, 10))
      && NSEqualRects(remainder, R(0, 0, 7, 10)),
      "NSDivideRect from the max-x edge");

    NSDivideRect(R(0, 0, 10, 10), &slice, &remainder, 4, NSMinYEdge);
    PASS(NSEqualRects(slice, R(0, 0, 10, 4))
      && NSEqualRects(remainder, R(0, 4, 10, 6)),
      "NSDivideRect from the min-y edge");

    NSDivideRect(R(0, 0, 10, 10), &slice, &remainder, 4, NSMaxYEdge);
    PASS(NSEqualRects(slice, R(0, 6, 10, 4))
      && NSEqualRects(remainder, R(0, 0, 10, 6)),
      "NSDivideRect from the max-y edge");
  END_SET("NSDivideRect")

  return 0;
}
