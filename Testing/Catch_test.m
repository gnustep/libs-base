/* Catch-test.m
 *
 * Tests catch, throw and unwind-protect in Objective-C
 */

#include <objects/Catch.h>
#include <objects/UnwindProtect.h>


/* To hold a simple value, to be passed by a throw */
@interface Integer : NSObject
{
  int value;
}
+ newInt: (int) i;
- setInt: (int) i;
- (int) getInt;
@end /* Integer */

@implementation Integer
+ newInt: (int) i { return [[self new] setInt: i]; }
- setInt: (int) i { value = i; return self; }
- (int) getInt { return value; }
@end /* Integer */

void foo(void);
void bar(void);
void call( void (*fn) (void), int i);

id tag;

int main(int argc, char **argv)
{
  id result;

  tag = [Catch new];
  if (CATCH(tag,
	   {
	     printf("main ...\n");
	     call(foo,3);
	     printf("main, after foo.\n");
	     result = [Integer newInt: 7];
	   }))
    {
      printf("catching!\n");
      result = [tag value];
    }

  printf("Back in main, result is %d\n", [result getInt]);
  [result release];
  
  if (CATCH(tag,
	    {
	      printf("main ...\n");
	      call(bar,11);
	      printf("main, after bar.\n");
	      result = [Integer newInt: 18];
	    }))
    {
      printf("catching!\n");
      result = [tag value];
    }

  printf("Back in main, result is %d\n", [result getInt]);
  [result release];
  [tag release];
  return 0;
}


void call (void (*fn)(void), int i)
{
  UNWINDPROTECT({
    /* This is the body */
    printf("Calling...\n");
    fn();
  }, {
    /* This is the cleanup code */
    printf("Cleaning up. The number is %d\n", i);
  });
}



void foo()
{
  printf("foo, returning\n");
}


void bar()
{
  printf("bar, throwing...\n");
  [tag throw: [Integer newInt: 17]];
  printf("Can't happen\n");
}
