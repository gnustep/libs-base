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

@interface Test : Object
+(void) load;
+(int) test_result;
@end

@implementation Test
static int test_result = 1;
+(void) load {test_result = 0;}
+(int) test_result {return test_result;}
@end

int main (void) {return [Test test_result];}
