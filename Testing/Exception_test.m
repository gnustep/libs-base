/* Exception_test.c
 *
 * Test Objective-C exception facilities
 */

#include <objects/Exception.h>
#include <objects/Catch.h>
#include <objects/UnwindProtect.h>


#include <stdio.h>


@protocol IntMath
+ new: (int) n;
- init: (int) n;
- (int) value;
- plus: (id <IntMath>) number;
- times: (id <IntMath>) number;
- divide: (id <IntMath>) number;
@end /* IntMath */

@protocol MathError <AnyError>
@end /* MathError */

@interface DivideByZero : Error <MathError>
@end /* DivideByZero */

@implementation DivideByZero
- (const char *) message { return "Divide by zero attempted"; }
@end /* DivideByZero */


@interface Integer : NSObject <IntMath>
{
  int value;
}
@end /* Integer */

@implementation Integer
+ new: (int) n { return [[super new] init: n]; }
- init: (int) n { value = n; return self; }
- init { value = 43; return self; }
- (int) value { return value; }
- plus: (id <IntMath>) number { value += [number value]; return self; }
- times: (id <IntMath>) number { value *= [number value]; return self; }
- divide: (id <IntMath>) number
{
  if ([number value] == 0)
    [[DivideByZero new] raise];
  value /= [number value];
  return self;
}
@end /* Integer */


void foo(id <IntMath> object, int number);


int main(int argc, char **argv)
{
  id <IntMath> n;
  id error;
  volatile int i;

  /* With extra argument, dump core */
  BOOL dump = (argc > 2);
  
  n = [Integer new: 17];
  for (i=-7; i<3; i++)
  {
    TRY(
	{
	  printf("foo(%d, %d)...\n", [n value], i);
	  foo(n, i);
	},
	@protocol(AnyError), error,
	{
	  printf("An error was catched. Class: %s, message: %s.\n",
		 [error name], [error message]);
	  [error finished];
	});
  }

  if (dump)
    { /* Raise an exception without handler, and dump core */
      printf("Now, try division by zero and dump core...\n");
      [[DivideByZero new] raise];
    }
  return 0;
}

void foo(id <IntMath> object, int number)
{
  id protect = [UnwindProtect new];
  id tmp = [Integer new];
  id test = [Catch new];

  [protect cleanupBySending: @selector(init) to: object];
  [protect cleanupBySending: @selector(release) to: tmp];

  /* Automagically release test */
  [protect cleanupBySending: @selector(release) to: test];
  
  switch(number)
    {
    case 0:
      [object divide: [tmp init: number]];
      break;
    case -1:
      [object plus: [tmp init: 5]];
      break;
    case 1:
      [test throw: object];
      break;
    default:
      [object times: [tmp init: number]];
    }
  printf("Computed: %d\n", [object value]);
  [protect cleanup];
}
