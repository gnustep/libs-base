/* A demonstration of writing and reading with NSArchiver */

#include <base/Invocation.h>
#include <base/Array.h>
#include <base/Archiver.h>
#include <Foundation/NSValue.h>
#include <base/TextCStream.h>
#include    <Foundation/NSAutoreleasePool.h>

@interface NSNumber (printing)
- (void) print;
- printAddNumber: n;
@end

@implementation NSNumber (printing)
- (void) print
{
  printf("%d\n", [self intValue]);
}
- printAddNumber: n
{
  printf("%d\n", [self intValue] + [n intValue]);
  return self;
}
@end

int main()
{
  id obj;
  id inv;
  id array;
  int i;
  BOOL b;
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  /* Create a simple invocation, and get it's return value. */
  obj = [NSObject new];
  inv = [[MethodInvocation alloc] 
	  initWithTarget: obj selector: @selector(isInstance)];
  [inv invoke];
  [inv getReturnValue: &b];
  printf ("object is instance %d\n", (int)b);
  [inv release];

  /* Do a simple invocation on all the contents of a collection. */
  array = [Array new];
  for (i = 0; i < 5; i++)
    [array addObject: [NSNumber numberWithInt: i]];
  inv = [[MethodInvocation alloc]
	  initWithSelector: @selector(print)];
  printf ("The numbers\n");
  [array withObjectsInvoke: inv];
  [inv release];

  /* Do an invocation on all the contents of the array, but the
     array contents become the first object argument of the invocation,
     not the target for the invocation. */
  inv = [[ObjectMethodInvocation alloc]
	  initWithTarget: [NSNumber numberWithInt: 2]
	  selector: @selector(printAddNumber:), nil];
  printf ("The numbers adding 2\n");
  [array withObjectsInvoke: inv];

  /* Get an int return value in a way that is simpler than -getReturnValue: */
  printf ("The target number was %d\n", [inv intReturnValue]);
  [inv release];

  /* Use a function instead of a selector for the invocation.
     Also show the use of filtered enumerating over a collection. */
  {
    id inv2;
    id test_func (id o)
      {
	printf ("test_func got %d\n", [o intValue]);
	return [NSNumber numberWithInt: [o intValue] + 3];
      }
    inv = [[ObjectFunctionInvocation alloc]
	    initWithObjectFunction: test_func];
    inv2 = [[MethodInvocation alloc] initWithSelector: @selector(print)];
    [array withObjectsTransformedByInvoking: inv
	   invoke: inv2];
    [inv release];
    [inv2 release];
  }

  /* Archive the some invocations, read them back and invoke. */
  {
    inv = [[MethodInvocation alloc] 
	    initWithTarget: array 
	    selector: @selector(withObjectsInvoke:),
	    [[[MethodInvocation alloc] initWithSelector: @selector(print)]
	      autorelease]];
    printf ("Before archiving\n");
    [inv invoke];
    [Archiver setDefaultCStreamClass: [TextCStream class]];
    [Archiver encodeRootObject: inv withName: NULL toFile: @"invocation.txt"];
    [inv release];
    printf ("After archiving\n");
    inv = [Unarchiver decodeObjectWithName: NULL
		      fromFile: @"invocation.txt"];
    [inv invoke];
  }

  [arp release];
  exit(0);
}

