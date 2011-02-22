#include "Testing.h"
#include <Foundation/NSAutoreleasePool.h>
#include <AppKit/NSAffineTransform.h>

static BOOL
is_equal_struct(NSAffineTransformStruct as, NSAffineTransformStruct bs)
{
  if (EQ(as.m11, bs.m11) && EQ(as.m12, bs.m12) && EQ(as.m21, bs.m21)
      && EQ(as.m22, bs.m22) && EQ(as.tX, bs.tX) && EQ(as.tY, bs.tY))
    return YES;
  return NO;
}

#if 0
static void
print_matrix (const char *str, NSAffineTransformStruct MM)
{
  printf("%s = %f %f %f %f  %f %f\n", str, MM.m11, MM.m12,
  	MM.m21, MM.m22, MM.tX, MM.tY);
}
#endif

int main(int argc, char *argv[])
{
  NSAffineTransform *aa, *bb, *cc;
  NSAffineTransformStruct as = {2, 3, 4, 5, 10, 20};
  NSAffineTransformStruct bs = {6, 7, 8, 9, 14, 15};
  NSAffineTransformStruct cs;

  NSAffineTransformStruct answer1 = 
    {36.000000, 41.000000, 64.000000, 73.000000,  234.000000, 265.000000};
  NSAffineTransformStruct answer2 = 
    {40.000000, 53.000000, 52.000000, 69.000000,  98.000000, 137.000000};
  NSAffineTransformStruct answer3 = 
    {6.000000, 9.000000, 8.000000, 10.000000,  10.000000, 20.000000};
  NSAffineTransformStruct answer4 = 
    {6.000000, 9.000000, 8.000000, 10.000000,  194.000000, 268.000000};
  NSAffineTransformStruct answer5 = 
    {2.172574, 3.215242, 3.908954, 4.864383,  10.000000, 20.000000};
  NSAffineTransformStruct answer6 = 
    {2.172574, 3.215242, 3.908954, 4.864383,  90.796249, 126.684265};
  NSAffineTransformStruct answer7 = 
    {1.651156, 2.443584, 1.329044, 1.653890,  90.796249, 126.684265};

  NSAutoreleasePool *pool = [NSAutoreleasePool new];


  aa = [NSAffineTransform transform];
  bb = [NSAffineTransform transform];
  [aa setTransformStruct: as];
  [bb setTransformStruct: bs];

  /* Append matrix */
  cc = [aa copy];
  [cc appendTransform: bb];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer1),
       "appendTransform:");

  /* Prepend matrix */
  cc = [aa copy];
  [cc prependTransform: bb];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer2),
       "prependTransform:");

  /* scaling */
  cc = [aa copy];
  [cc scaleXBy: 3 yBy: 2];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer3),
       "scaleXBy:yBy:");
  //print_matrix ("Scale X A", cs);
  [cc translateXBy: 12 yBy: 14];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer4),
       "translateXBy:yBy:");
  //print_matrix ("Trans X Scale X A", cs);

  /* rotation */
  cc = [aa copy];
  [cc rotateByDegrees: 2.5];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer5),
       "rotateByDegrees");
  //print_matrix ("Rotate X A", cs);
  [cc translateXBy: 12 yBy: 14];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer6),
       "Translate X Rotate X A");
  //print_matrix ("Trans X Rotate X A", cs);

  /* multiple */
  [cc scaleXBy: .76 yBy: .34];
  cs = [cc transformStruct];
  pass(is_equal_struct(cs, answer7),
       "Scale X Translate X Rotate X A");
  //print_matrix ("Scale X Trans X Rotate X A", cs);

  [pool release];
  return 0;
}
