#include <stdio.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSValue.h>

int main ()
{
  NSHashTable *ht;
  NSHashEnumerator he;
  int i;
  void *v;

  /* Test with ints */

  ht = NSCreateHashTable (NSIntHashCallBacks, 0);

  for (i = 1; i < 16; i++)
    NSHashInsert (ht, (void*)i);

  NSHashRemove (ht, (void*)3);

  he = NSEnumerateHashTable (ht);
  while ((v = NSNextHashEnumeratorItem (&he)))
    printf ("(%d) ", (int)v);
  printf ("\n");

  NSFreeHashTable (ht);


#if 0
  /* Test with NSNumber objects */

  mt = NSCreateHashTable (NSObjectHashKeyCallBacks,
			 NSObjectHashValueCallBacks,
			 0);

  for (i = 0; i < 16; i++)
    NSHashInsert (mt, 
		 [NSNumber numberWithInt: i], 
		 [NSNumber numberWithInt: i*i]);

  o = [NSNumber numberWithInt: 3];
  printf ("value for key %s is %s\n",
	  [[o description] cString],
	  [[(id)NSHashGet (mt, o) description] cString]);
  NSHashRemove (mt, o);
  printf ("after removing: value for key %s is %s\n",
	  [[o description] cString],
	  [[(id)NSHashGet (mt, o) description] cString]);

  me = NSEnumerateHashTable (mt);
  while (NSNextHashEnumeratorPair (&me, &k, &v))
    printf ("(%d,%d) ", [(id)k intValue], [(id)v intValue]);
  printf ("\n");

  NSFreeHashTable (mt);
#endif

  exit (0);
}
