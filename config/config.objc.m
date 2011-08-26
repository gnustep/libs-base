
#include "objc-common.g"

@interface Test 
+(int) testResult;
@end

@implementation Test
+ (void) initialize
{
  return;
}
+(int) testResult
{
  return -1;
}
@end

int main (void)
{
  return ([Test testResult] + 1);
}
