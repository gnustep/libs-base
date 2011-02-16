#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSAffineTransform.h>

#include <math.h>
static BOOL eq(double d1, double d2)
{
  if (abs(d1 - d2) < 0.000001)
    return YES;
  return NO;
}

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSAffineTransform *testObj;
  NSAffineTransformStruct flip = {1.0,0.0,0.0,-1.0,0.0,0.0};
  NSMutableArray *testObjs = [NSMutableArray new];
  NSPoint	p;
  NSSize	s;

  testObj = [NSAffineTransform new];
  [testObjs addObject:testObj];
  PASS(testObj != nil, "can create a new transfor");
   
  test_NSObject(@"NSAffineTransform", testObjs);
  test_NSCoding(testObjs);
  test_NSCopying(@"NSAffineTransform", @"NSAffineTransform", testObjs, NO, YES);
  
  testObj = [NSAffineTransform transform];
  PASS(testObj != nil, "can create an autoreleased transform");

  [testObj setTransformStruct: flip];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, 10) && eq(p.y, -10), "flip transform inverts point y");

  s = [testObj transformSize: NSMakeSize(10,10)];
  PASS(s.width == 10 && s.height == -10, "flip transform inverts size height");

  p = [testObj transformPoint: p];
  s = [testObj transformSize: s];
  PASS(eq(p.x, 10) && eq(p.y, 10) && s.width == 10 && s.height == 10,
    "flip is reversible");
  
  testObj = [NSAffineTransform transform];
  [testObj translateXBy: 5.0 yBy: 6.0];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, 15.0) && eq(p.y, 16.0), "simple translate works");

  [testObj translateXBy: 5.0 yBy: 4.0];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, 20.0) && eq(p.y, 20.0), "two simple translates work");
  
  [testObj rotateByDegrees: 90.0];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, 0.0) && eq(p.y, 20.0), "translate and rotate works");
  
  testObj = [NSAffineTransform transform];

  [testObj rotateByDegrees: 90.0];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, -10.0) && eq(p.y, 10.0), "simple rotate works");
  
  [testObj translateXBy: 5.0 yBy: 6.0];
  p = [testObj transformPoint: NSMakePoint(10,10)];
  PASS(eq(p.x, -16.0) && eq(p.y, 15.0), "rotate and translate works");

  [arp release]; arp = nil;
  return 0;
}
