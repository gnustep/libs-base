/* catch-test.c
 *
 * Tests catch,throw and unwind-protect in C
 */

/* The output should be
main ...
Calling...
foo, returning
Cleaning up. The number is 3
main, after foo.
Back in main, result is 7
main ...
Calling...
bar, throwing...
Cleaning up. The number is 11
catching!
Back in main, result is 17
*/

#include <ccatch.h>
#include <stdio.h>

catch_tag tag;

void foo(void);
void bar(void);
void call(void (*fn) (void), int i);

int main(int argc, char **argv)
{
  volatile int res;
  int caught;

  init_ccatch();

  if ((caught = CCATCH(tag,
		       {
			 printf("main ...\n");
			 call(foo,3);
			 printf("main, after foo.\n");
			 res = 7;
		       }))!=0)
    {
      printf("catching!\n");
      res = caught;
    }
  ccatch_cleanup(tag);

  printf("Back in main, result is %d\n", res);

  if ((caught = CCATCH(tag,
		       {
			 printf("main ...\n");
			 call(bar,11);
			 printf("main, after bar.\n");
			 res = 18;
		       }))!=0)
    {
      printf("catching!\n");
      res = caught;
    }
  ccatch_cleanup(tag);
    
  printf("Back in main, result is %d\n",res);
  return 0;
}

void call (void (*fn)(void), int i)
{
  CPROTECT({
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
  CTHROW(tag, 17);
  printf("Can't happen!\n");
}
