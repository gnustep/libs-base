
#include <objects/objects.h>


int main()
{
  id array = [[Array alloc] initWithType:@encode(int)];
  id bag;
  id llist;
  id btree;

  [array addElementsCount:6, ((elt)0),((elt)1),((elt)5),((elt)3),
	 ((elt)4),((elt)2)];
  bag = [array shallowCopyAs:[Bag class]];
  llist = [[EltNodeCollector alloc] initWithType:@encode(int)
	   nodeCollector:[[LinkedList alloc] init]
	   nodeClass:[LinkedListEltNode class]];
  [llist addContentsOf:array];

  btree = [[EltNodeCollector alloc] initWithType:@encode(int)
	   nodeCollector:[[BinaryTree alloc] init]
	   nodeClass:[BinaryTreeEltNode class]];
  [btree addContentsOf:array];
  printf("btree count = %d\n", [btree count]);

  /* tmp test */
/*
  if (typeof((id)0) != typeof(id))
    printf("typeof error\n");
*/

  [array printForDebugger];
  [bag printForDebugger];
  [llist printForDebugger];
  [btree printForDebugger];

  /*  foo = [array shallowCopyAs:[Object class]]; 
   Shouldn't the compiler complain about this?
   Object does not conform to <Collecting> */

  exit(0);
}


