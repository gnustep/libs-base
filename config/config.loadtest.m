/* Dummy NXConstantString impl for so libobjc that doesn't include it */
#include <objc/NXConstStr.h>
@implementation NXConstantString
@end

@interface Test 
static int test_result;
+(void) load;
+(int) test_result;
@end

@implementation Test
static int test_result = 1;
+(void) load {test_result = 0;}
+(int) test_result {return test_result;}
@end

int main (void) {return [Test test_result];}
