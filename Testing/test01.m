#include <gnustep/base/objects.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/Invocation.h>

@interface ConstantCollection (TestingExtras)
- printCount;
@end
@implementation ConstantCollection (TestingExtras)
- printCount
{
  printf("%s: count=%d\n", object_get_class_name (self), [self count]);
  return self;
}
@end

void checkSameContents(id objectslist)
{
  unsigned i, c = [objectslist count];
  
  for (i = 1; i < c; i++)
    if (![[objectslist objectAtIndex:0] 
	  contentsEqual:[objectslist objectAtIndex:i]])
      printf("collection 0 does not have same contents as collection %d\n", i);
}


int main()
{
  int i;

  id array = [Array new];
  // id bag = [Bag new];
  // id set = [Set new];
  id stack = [Stack new];
  id queue = [Queue new];
  id gaparray = [GapArray new];
  id foo = [Array new];

  id collections = [DelegatePool new];

  [collections delegatePoolAddObject:array];
  //  [collections delegatePoolAddObject:bag];
  //  [collections delegatePoolAddObject:set];
  [collections delegatePoolAddObject:stack];
  [collections delegatePoolAddObject:queue];
  [collections delegatePoolAddObject:gaparray];
  [collections delegatePoolAddObject:foo];

  printf("delegatePool filled, count=%d\n",
	 [[collections delegatePoolCollection] count]);

  [collections addObject: [NSNumber numberWithInt: 99]];
  [collections printCount];

  printf("Adding numbers...\n");
  for (i = 1; i < 17; i++)
    {
      printf("%2d ", i);
      [collections addObject: [NSNumber numberWithInt: i]];
    }
  printf("\ncollections filled\n\n");
  [collections printForDebugger];

  {
    id inv = [[MethodInvocation alloc] 
	       initWithTarget: nil
	       selector: @selector(isEqual:), 
	       [NSNumber numberWithInt:0]];
    if ([array trueForAllObjectsByInvoking: inv])
      printf("Array contains no zero's\n");
  }

  checkSameContents([collections delegatePoolCollection]);

  printf("\nremoving 99\n\n");
  [collections removeObject: [NSNumber numberWithInt: 99]];

  [foo removeObject:[foo minObject]];
  [foo addObject: [NSNumber numberWithInt: 99]];
  printf("Collections 0 and 9 should mismatch\n");
  [collections printForDebugger];

  checkSameContents([collections delegatePoolCollection]);

  [collections release];

  exit(0);
}


