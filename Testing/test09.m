#include <objects/objects.h>

#if (sun && __svr4__) || defined(__hpux)
long lrand48();
#define random lrand48
#else
long random();
#endif

int main()
{
  int i;
  id node;
  id s = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeCollector:[[SplayTree alloc] init]
	  nodeClass:[BinaryTreeEltNode class]];
  void foo (id o) {[o self];}

  for (i = 1; i < 20; i++)
    [s addElement:(int)random()%99];
  [[s contentsCollector] binaryTreePrintForDebugger];
  [s release];

  s = [[EltNodeCollector alloc] initWithType:@encode(int)
       nodeCollector:[[SplayTree alloc] init]
       nodeClass:[BinaryTreeEltNode class]];
  for (i = 1; i < 20; i++)
    [s addElement:(int)random()%99];
  [[s contentsCollector] binaryTreePrintForDebugger];
  [s removeElement:[s elementAtIndex:10]];
  [[s contentsCollector] binaryTreePrintForDebugger];
  [[s contentsCollector] withObjectsCall:foo];
  [s release];

  s = [[EltNodeCollector alloc] initWithType:@encode(int)
       nodeCollector:[[BinaryTree alloc] init]
       nodeClass:[BinaryTreeEltNode class]];
  [s appendElement:'i'];
  [s insertElement:'h' before:'i'];
  [s insertElement:'g' before:'h'];
  [s insertElement:'f' before:'g'];
  [s insertElement:'e' after:'f'];
  [s insertElement:'d' before:'e'];
  [s insertElement:'c' after:'d'];
  [s insertElement:'b' after:'c'];
  [s insertElement:'a' after:'b'];
  [[s contentsCollector] binaryTreePrintForDebugger];
  [[s contentsCollector] binaryTreePrintForDebugger];

  s = [[EltNodeCollector alloc] initWithType:@encode(char)
       nodeCollector:[[SplayTree alloc] init]
       nodeClass:[BinaryTreeEltNode class]];
  [s appendElement:(char)'i'];
  [s insertElement:(char)'h' before:(char)'i'];
  [s insertElement:(char)'g' before:(char)'h'];
  [s insertElement:(char)'f' before:(char)'g'];
  [s insertElement:(char)'e' after:(char)'f'];
  [s insertElement:(char)'d' before:(char)'e'];
  [s insertElement:(char)'c' after:(char)'d'];
  [s insertElement:(char)'b' after:(char)'c'];
  [s insertElement:(char)'a' after:(char)'b'];
  [[s contentsCollector] binaryTreePrintForDebugger];

  [[s contentsCollector] splayNode:[s eltNodeWithElement:(char)'a']];
  [[s contentsCollector] binaryTreePrintForDebugger];

/*
  while ([s eltNodeWithElement:(char)'a'] 
	 != [[s contentsCollector] rootNode])
    {
      [[s contentsCollector] _doSplayOperationOnNode:
       [s eltNodeWithElement:(char)'a']];
      printf("===============================\n");
      [[s contentsCollector] binaryTreePrintForDebugger];
    }
*/

  if ((node = [s eltNodeWithElement:(char)'z']) != nil)
    [s error:"eltNodeWithElement: loses."];
  exit(0);
}
