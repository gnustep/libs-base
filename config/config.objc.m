/* Dummy NXConstantString impl for so libobjc that doesn't include it */
/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
#ifndef NeXT_RUNTIME
#include <objc/NXConstStr.h>
@implementation NXConstantString
@end
#endif

#include <objc/Object.h>

@interface NSObject : Object
@end

@implementation NSObject
@end

@interface Test : Object
+(int) testResult;
@end

@implementation Test
+(int) testResult
{
  return -1;
}
@end

int main (void)
{
  return ([Test testResult] + 1);
}
