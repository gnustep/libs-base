/* Dummy NXConstantString impl for so libobjc that doesn't include it */
#ifndef NeXT_RUNTIME
#include <objc/NXConstStr.h>
@implementation NXConstantString
@end
#endif

@interface Test 
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
