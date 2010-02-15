
#include "objc-common.g"

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
