
#include <objc/Object.h>
#include <objects/objects.h>

#if (__svr4__) || defined(__hpux)
long lrand48();
#define random lrand48
#else
long random();
#endif

@interface Collection (TestingExtras)
- printCount;
@end
@implementation Collection (TestingExtras)
- printCount
{
  printf("%s: count=%d\n", [self name], [self count]);
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
  int i, e;

  id array = [[Array alloc] initWithType:@encode(int)];
  id bag = [[Bag alloc] initWithType:"i"];
  id stack = [[Stack alloc] initWithType:"i"];
  id queue = [[Queue alloc] initWithType:"i"];
  id gaparray = [[GapArray alloc] initWithType:"i"];
  id llist = [[EltNodeCollector alloc] initWithType:"i"
	      nodeCollector:[[LinkedList alloc] init]
	      nodeClass:[LinkedListEltNode class]];
  id bt = [[EltNodeCollector alloc] initWithType:"i"
	   nodeCollector:[[BinaryTree alloc] init]
	   nodeClass:[BinaryTreeEltNode class]];
  id rt = [[EltNodeCollector alloc] initWithType:"i"
	   nodeCollector:[[RBTree alloc] init]
	   nodeClass:[RBTreeEltNode class]];
  id st = [[EltNodeCollector alloc] initWithType:"i"
	   nodeCollector:[[SplayTree alloc] init]
	   nodeClass:[BinaryTreeEltNode class]];
  id foo = [[Array alloc] initWithType:"i"];

  id collections = [DelegatePool new];

  [collections delegatePoolAddObject:array];
  [collections delegatePoolAddObject:llist];
  [collections delegatePoolAddObject:bag];
  [collections delegatePoolAddObject:stack];
  [collections delegatePoolAddObject:queue];
  [collections delegatePoolAddObject:gaparray];
  [collections delegatePoolAddObject:bt];
  [collections delegatePoolAddObject:rt];
  [collections delegatePoolAddObject:st];
  [collections delegatePoolAddObject:foo];

  printf("delegatePool filled, count=%d\n",
	 [[collections delegatePoolCollection] count]);

  [collections addElement:99];
  [collections printCount];

  printf("Adding numbers...\n");
  for (i = 0; i < 17; i++)
    {
      e = random() % 99;
      printf("%2d ", e);
      [collections addElement:e];
    }
  printf("\ncollections filled\n\n");
  [collections printForDebugger];

  {
    BOOL testzero (elt e)
      {
	if (e.void_ptr_u == 0) return NO;
	else return YES;
      }
    if ([array trueForAllElementsByCalling:testzero])
      printf("Array contains no zero's\n");
  }

  checkSameContents([collections delegatePoolCollection]);

  printf("\nremoving 99\n\n");
  [collections removeElement:99];

  [foo removeElement:[foo minElement]];
  [foo addElement:99];
  printf("Collections 0 and 9 should mismatch\n");
  [collections printForDebugger];

  checkSameContents([collections delegatePoolCollection]);

  [collections release];

  exit(0);
}


