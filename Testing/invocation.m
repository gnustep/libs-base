/* A demonstration of writing and reading with NSArchiver */

#include <objects/Invocation.h>
#include <objects/Array.h>
#include <Foundation/NSValue.h>

@interface NSNumber (printing)
- (void) print;
@end

@implementation NSNumber (printing)
- (void) print
{
  printf("%d\n", [self intValue]);
}
@end

int main()
{
  id obj;
  id inv;
  id array;
  char *n;
  int i;

  obj = [NSObject new];
  inv = [[MethodInvocation alloc] 
	  initWithTarget: obj selector: @selector(name)];
  [inv invoke];
  [inv getReturnValue: &n];
  printf ("name is %s\n", n);
  [inv release];

  array = [Array new];
  for (i = 0; i < 5; i++)
    [array addObject: [NSNumber numberWithInt: i]];

  inv = [[MethodInvocation alloc]
	  initWithSelector: @selector(print)];
  [array withObjectsInvoke: inv];

  exit(0);
}

