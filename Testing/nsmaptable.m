#include <stdio.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSValue.h>

int main ()
{
  NSMapTable *mt;
  NSMapEnumerator me;
  int i;
  void *k;
  void *v;
  id o;

  /* Test with ints */

  mt = NSCreateMapTable (NSIntMapKeyCallBacks,
			 NSIntMapValueCallBacks,
			 0);

  for (i = 0; i < 16; i++)
    NSMapInsert (mt, (void*)i, (void*)(i*2));

  printf ("value for key %d is %d\n",
	  3, (int)NSMapGet (mt, (void*)3));
  NSMapRemove (mt, (void*)3);
  printf ("after removing: value for key %d is %d\n",
	  3, (int)NSMapGet (mt, (void*)3));

  me = NSEnumerateMapTable (mt);
  while (NSNextMapEnumeratorPair (&me, &k, &v))
    printf ("(%d,%d) ", (int)k, (int)v);
  printf ("\n");

  NSFreeMapTable (mt);


  /* Test with NSNumber objects */

  mt = NSCreateMapTable (NSObjectMapKeyCallBacks,
			 NSObjectMapValueCallBacks,
			 0);

  for (i = 0; i < 16; i++)
    NSMapInsert (mt, 
		 [NSNumber numberWithInt: i], 
		 [NSNumber numberWithInt: i*i]);

  o = [NSNumber numberWithInt: 3];
  printf ("value for key %s is %s\n",
	  [[o description] cString],
	  [[(id)NSMapGet (mt, o) description] cString]);
  NSMapRemove (mt, o);
  if (NSMapGet (mt, o))
    printf ("after removing: value for key %s is %s\n",
	    [[o description] cString],
	    [[(id)NSMapGet (mt, o) description] cString]);
  else
    printf ("after removing: no value for key %s\n",
	    [[o description] cString]);

  me = NSEnumerateMapTable (mt);
  while (NSNextMapEnumeratorPair (&me, &k, &v))
    printf ("(%d,%d) ", [(id)k intValue], [(id)v intValue]);
  printf ("\n");

  NSFreeMapTable (mt);

  exit (0);
}
