#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSOrderedSet.h>
#import "ObjectTesting.h"
#import "../../../Source/GSFastEnumeration.h"

void fast_enumeration_mutation_add(id mutableCollection)
{
  NSUInteger i = 0;
  FOR_IN(id, o, mutableCollection)
  if (i == [mutableCollection count]/2) {
    if ([mutableCollection isKindOfClass:[NSMutableDictionary class]]) {
      [mutableCollection setObject:@"boom" forKey:@"boom"];
    } else {
      [mutableCollection addObject:@"boom"];
    }
  }
  i++;
  END_FOR_IN(mutableCollection)
}

void fast_enumeration_mutation_remove(id mutableCollection)
{
  NSUInteger i = 0;
  FOR_IN(id, o, mutableCollection)
  if (i == [mutableCollection count]/2) {
    if ([mutableCollection isKindOfClass:[NSMutableDictionary class]]) {
      [mutableCollection removeObjectForKey:o];
    } else {
      [mutableCollection removeObject:o];
    }
  }
  i++;
  END_FOR_IN(mutableCollection)
}

void test_fast_enumeration(id collection, NSArray *objects)
{
  NSMutableArray *returnedObjects = [[NSMutableArray alloc] init];
  FOR_IN(id, o, collection)
  [returnedObjects addObject:o];
  END_FOR_IN(collection)
  if (!([collection isKindOfClass:[NSArray class]] ||
        [collection isKindOfClass:[NSOrderedSet class]])) {
    [returnedObjects sortUsingSelector:@selector(compare:)];
  }
  PASS_EQUAL(returnedObjects, objects, "fast enumeration returns all objects");
  
  id mutableCollection = [collection mutableCopy];
  PASS_EXCEPTION(
    fast_enumeration_mutation_add(mutableCollection),
    NSGenericException,
    "Fast enumeration mutation add properly calls @\"NSGenericException\"");
  PASS_EXCEPTION(
    fast_enumeration_mutation_remove(mutableCollection),
    NSGenericException,
    "Fast enumeration mutation remove properly calls @\"NSGenericException\"");
  [mutableCollection release];
}

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  
  NSMutableArray *objects = [NSMutableArray array];
  int i;
  for (i = 0; i < 10000; i++) {
    [objects addObject:[NSString stringWithFormat:@"%.4d", i]];
  }
  
  START_SET("NSArray")
  id array = [NSArray arrayWithArray:objects];
  test_fast_enumeration(array, objects);
  END_SET("NSArray")
  
  START_SET("NSSet")
  id set = [NSSet setWithArray:objects];
  test_fast_enumeration(set, objects);
  END_SET("NSSet")
  
  START_SET("NSOrderedSet")
  id orderedSet = [NSOrderedSet orderedSetWithArray:objects];
  test_fast_enumeration(orderedSet, objects);
  END_SET("NSOrderedSet")
  
  START_SET("NSDictionary")
  id dict = [NSDictionary dictionaryWithObjects:objects forKeys:objects];
  test_fast_enumeration(dict, objects);
  END_SET("NSDictionary")
  
  [arp release]; arp = nil;
  return 0;
}
