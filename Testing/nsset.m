#include <Foundation/NSSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>

void original_test ();
void intersects_set_test();
void is_subset_of_set_test ();

int
main ()
{
  original_test ();
  intersects_set_test ();
  is_subset_of_set_test ();

  printf("Test passed\n");
  exit (0);
}

void
original_test ()
{
  id a, s1, s2;
  id enumerator;

  a = [NSArray arrayWithObjects:
	       @"vache", @"poisson", @"cheval", @"poulet", nil];

  s1 = [NSSet setWithArray:a];

  assert ([s1 member:@"vache"]);
  assert ([s1 containsObject:@"cheval"]);
  assert ([s1 count] == 4);

  enumerator = [s1 objectEnumerator];
  while ([[enumerator nextObject] description]);

  s2 = [s1 mutableCopy];
  assert ([s1 isEqual:s2]);
}

void
intersects_set_test()
{
  id a1 = [NSArray arrayWithObjects: @"abstract factory", @"builder",
                  @"factory method", @"prototype", @"singleton", nil];
  id s1 = [NSSet setWithArray: a1];

  id a2 = [NSArray arrayWithObjects: @"adapter", @"bridge", @"composite",
                  @"decorator", @"facade", @"flyweight", @"Proxy", nil];
  id s2 = [NSSet setWithArray: a2];

  id s3 = [NSSet setWithObjects: @"abstract factory", @"adapter", nil];
  id s4 = [NSSet setWithObject: @"chain of responsibility"];

  id s5 = [NSSet set];
  assert (![s1 intersectsSet: s2]);
  assert (![s2 intersectsSet: s1]);

  assert ([s1 intersectsSet: s3]);
  assert ([s2 intersectsSet: s3]);
  assert ([s3 intersectsSet: s1]);
  assert ([s3 intersectsSet: s2]);

  assert (![s1 intersectsSet: s4]);
  assert (![s2 intersectsSet: s4]);
  assert (![s4 intersectsSet: s1]);
  assert (![s4 intersectsSet: s2]);

  assert (![s1 intersectsSet: s5]);
  assert (![s2 intersectsSet: s5]);
  assert (![s3 intersectsSet: s5]);
  assert (![s4 intersectsSet: s5]);
  assert (![s5 intersectsSet: s5]);

  assert (![s5 intersectsSet: s1]);
  assert (![s5 intersectsSet: s2]);
  assert (![s5 intersectsSet: s3]);
  assert (![s5 intersectsSet: s4]);
  assert (![s5 intersectsSet: s5]);
}

void
is_subset_of_set_test ()
{
  id a1 = [NSArray arrayWithObjects: @"abstract factory", @"builder",
                  @"factory method", @"prototype", @"singleton", nil];
  id s1 = [NSSet setWithArray: a1];

  id a2 = [NSArray arrayWithObjects: @"adapter", @"bridge", @"composite",
                  @"decorator", @"facade", @"flyweight", @"proxy", nil];
  id s2 = [NSSet setWithArray: a2];

  id s3 = [NSSet setWithObjects: @"abstract factory", nil];
  id s4 = [NSSet setWithObjects: @"adapter", @"proxy", nil];
  id s5 = [NSSet setWithObject: @"chain of responsibility"];

  id s6 = [NSSet set];

  assert ([s3 isSubsetOfSet: s1]);
  assert ([s4 isSubsetOfSet: s2]);
  assert ([s6 isSubsetOfSet: s1]);
  assert ([s6 isSubsetOfSet: s2]);
  assert ([s6 isSubsetOfSet: s3]);
  assert ([s6 isSubsetOfSet: s4]);
  assert ([s6 isSubsetOfSet: s5]);
  assert ([s6 isSubsetOfSet: s6]);

  assert (![s1 isSubsetOfSet: s6]);
  assert (![s1 isSubsetOfSet: s5]);
  assert (![s1 isSubsetOfSet: s4]);
  assert (![s1 isSubsetOfSet: s3]);
  assert (![s1 isSubsetOfSet: s2]);

}
