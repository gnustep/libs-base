#import "Testing.h"
#import <Foundation/Foundation.h>

#define	GSI_MAP_KTYPES	GSUNION_OBJ
#define	GSI_MAP_VTYPES	GSUNION_OBJ
#import "GNUstepBase/GSIMap.h"

static NSString *
keyAt(unsigned i)
{
  return [NSString stringWithFormat: @"key%u", i];
}

static BOOL
containsKeys(GSIMapTable map, unsigned count)
{
  unsigned	i;

  for (i = 0; i < count; i++)
    {
      GSIMapNode	node = GSIMapNodeForKey(map, (GSIMapKey)(id)keyAt(i));

      if (0 == node || NO == [node->value.obj isEqual: keyAt(i)])
	{
	  return NO;
	}
    }
  return YES;
}

int
main(void)
{
  ENTER_POOL
  GSIMapTable_t	map;
  GSIMapBucket	buckets;
  uintptr_t	bucketCount;
  unsigned	i;

  START_SET("GSIMap small maps")

  GSIMapInitWithZoneAndCapacity(&map, NSDefaultMallocZone(), 0);
  PASS(map.bucketCount == 1, "empty map uses a single bucket")

  buckets = map.buckets;
  GSIMapAddPair(&map, (GSIMapKey)(id)keyAt(0), (GSIMapVal)(id)keyAt(0));
  GSIMapAddPair(&map, (GSIMapKey)(id)keyAt(1), (GSIMapVal)(id)keyAt(1));
  PASS(map.buckets == buckets && map.bucketCount == 1,
    "adding to a small map does not reallocate its bucket")

  for (i = 2; i < 100; i++)
    {
      GSIMapAddPair(&map, (GSIMapKey)(id)keyAt(i), (GSIMapVal)(id)keyAt(i));
    }
  PASS(map.bucketCount > 1, "map grows beyond a single bucket")
  PASS(containsKeys(&map, 100), "all keys found after growing")
  GSIMapEmptyMap(&map);

  END_SET("GSIMap small maps")

  START_SET("GSIMap capacity")

  GSIMapInitWithZoneAndCapacity(&map, NSDefaultMallocZone(), 1000);
  buckets = map.buckets;
  bucketCount = map.bucketCount;
  PASS(bucketCount > 1, "map with large capacity has many buckets")

  for (i = 0; i < 100; i++)
    {
      GSIMapAddPair(&map, (GSIMapKey)(id)keyAt(i), (GSIMapVal)(id)keyAt(i));
    }
  PASS(map.buckets == buckets && map.bucketCount == bucketCount,
    "adding to a map within its capacity keeps its buckets")
  PASS(containsKeys(&map, 100), "all keys found in map with capacity")

  GSIMapCleanMap(&map);
  GSIMapAddPair(&map, (GSIMapKey)(id)keyAt(0), (GSIMapVal)(id)keyAt(0));
  PASS(map.bucketCount == bucketCount,
    "adding to a cleaned map keeps its buckets")
  PASS(containsKeys(&map, 1), "key found in cleaned map")
  GSIMapEmptyMap(&map);

  END_SET("GSIMap capacity")

  LEAVE_POOL
  return 0;
}
