#include <gnustep/base/all.h>

int main()
{
  id a = [[Array alloc] initWithType:@encode(int)];
  int i;
  unsigned ret42 (arglist_t f) { return 42; }

  [a addElementsCount:5, 
     ((elt)0),((elt)1),((elt)2),((elt)3),((elt)4)];
  [a printForDebugger];
  i = [a indexOfElement:99 
	 ifAbsentCall:ret42];
  
  printf("This should be 42---> %d\n", i);
  exit(0);
}
