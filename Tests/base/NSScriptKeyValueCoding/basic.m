#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptKeyValueCoding.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

@interface TestItem : NSObject
{
  NSString *_name;
  NSString *_uniqueID;
}
- (id) initWithName: (NSString *)name uniqueID: (NSString *)uniqueID;
- (NSString *) name;
- (NSString *) uniqueID;
@end

@implementation TestItem

- (id) initWithName: (NSString *)name uniqueID: (NSString *)uniqueID
{
  if ((self = [super init]))
    {
      _name = [name copy];
      _uniqueID = [uniqueID copy];
    }
  return self;
}

- (void) dealloc
{
  [_name release];
  [_uniqueID release];
  [super dealloc];
}

- (NSString *) name
{
  return _name;
}

- (NSString *) uniqueID
{
  return _uniqueID;
}

@end

@interface TestContainer : NSObject
{
  NSMutableArray *_items;
}
- (id) init;
- (NSArray *) items;
- (void) setItems: (NSArray *)items;
@end

@implementation TestContainer

- (id) init
{
  if ((self = [super init]))
    {
      _items = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [_items release];
  [super dealloc];
}

- (NSArray *) items
{
  return _items;
}

- (void) setItems: (NSArray *)items
{
  [_items setArray: items];
}

@end

int main()
{
  NSAutoreleasePool *pool;
  TestContainer *container;
  TestItem *item1;
  TestItem *item2;
  TestItem *item3;
  id result;

  pool = [NSAutoreleasePool new];

  START_SET("NSScriptKeyValueCoding value access");

  container = [[TestContainer alloc] init];
  item1 = [[TestItem alloc] initWithName: @"First" uniqueID: @"1"];
  item2 = [[TestItem alloc] initWithName: @"Second" uniqueID: @"2"];
  item3 = [[TestItem alloc] initWithName: @"Third" uniqueID: @"3"];

  [container setItems: [NSArray arrayWithObjects: item1, item2, item3, nil]];

  // Test valueAtIndex:inPropertyWithKey:
  result = [container valueAtIndex: 0 inPropertyWithKey: @"items"];
  PASS(result == item1, "valueAtIndex:inPropertyWithKey: returns correct object");

  result = [container valueAtIndex: 1 inPropertyWithKey: @"items"];
  PASS(result == item2, "valueAtIndex: with index 1 works");

  result = [container valueAtIndex: 10 inPropertyWithKey: @"items"];
  PASS(result == nil, "valueAtIndex: with out-of-bounds index returns nil");

  END_SET("NSScriptKeyValueCoding value access");

  START_SET("NSScriptKeyValueCoding valueWithName");

  // Test valueWithName:inPropertyWithKey:
  result = [container valueWithName: @"First" inPropertyWithKey: @"items"];
  PASS(result == item1, "valueWithName:inPropertyWithKey: finds object by name");

  result = [container valueWithName: @"Second" inPropertyWithKey: @"items"];
  PASS(result == item2, "valueWithName: finds second item");

  result = [container valueWithName: @"NotFound" inPropertyWithKey: @"items"];
  PASS(result == nil, "valueWithName: returns nil for non-existent name");

  END_SET("NSScriptKeyValueCoding valueWithName");

  START_SET("NSScriptKeyValueCoding valueWithUniqueID");

  // Test valueWithUniqueID:inPropertyWithKey:
  result = [container valueWithUniqueID: @"1" inPropertyWithKey: @"items"];
  PASS(result == item1, "valueWithUniqueID:inPropertyWithKey: finds object by ID");

  result = [container valueWithUniqueID: @"3" inPropertyWithKey: @"items"];
  PASS(result == item3, "valueWithUniqueID: finds third item");

  result = [container valueWithUniqueID: @"999" inPropertyWithKey: @"items"];
  PASS(result == nil, "valueWithUniqueID: returns nil for non-existent ID");

  END_SET("NSScriptKeyValueCoding valueWithUniqueID");

  START_SET("NSScriptKeyValueCoding insertion");

  TestItem *newItem;
  newItem = AUTORELEASE([[TestItem alloc] initWithName: @"Inserted" uniqueID: @"4"]);

  // Test insertValue:atIndex:inPropertyWithKey:
  [container insertValue: newItem atIndex: 1 inPropertyWithKey: @"items"];
  PASS([[container items] count] == 4, "insertValue:atIndex:inPropertyWithKey: increases count");
  PASS([container valueAtIndex: 1 inPropertyWithKey: @"items"] == newItem,
       "Inserted item is at correct index");

  // Test insertValue:inPropertyWithKey: (append)
  TestItem *appendItem;
  appendItem = AUTORELEASE([[TestItem alloc] initWithName: @"Appended" uniqueID: @"5"]);
  [container insertValue: appendItem inPropertyWithKey: @"items"];
  PASS([[container items] count] == 5, "insertValue:inPropertyWithKey: appends item");
  PASS([[container items] lastObject] == appendItem, "Appended item is at end");

  END_SET("NSScriptKeyValueCoding insertion");

  START_SET("NSScriptKeyValueCoding removal");

  NSUInteger countBefore;
  countBefore = [[container items] count];

  // Test removeValueAtIndex:fromPropertyWithKey:
  [container removeValueAtIndex: 1 fromPropertyWithKey: @"items"];
  PASS([[container items] count] == countBefore - 1,
       "removeValueAtIndex:fromPropertyWithKey: decreases count");

  END_SET("NSScriptKeyValueCoding removal");

  START_SET("NSScriptKeyValueCoding replacement");

  TestItem *replacementItem;
  replacementItem = AUTORELEASE([[TestItem alloc] initWithName: @"Replacement" uniqueID: @"6"]);

  // Test replaceValueAtIndex:inPropertyWithKey:withValue:
  [container replaceValueAtIndex: 0 
              inPropertyWithKey: @"items"
                      withValue: replacementItem];
  PASS([container valueAtIndex: 0 inPropertyWithKey: @"items"] == replacementItem,
       "replaceValueAtIndex:inPropertyWithKey:withValue: replaces object");

  END_SET("NSScriptKeyValueCoding replacement");

  START_SET("NSScriptKeyValueCoding coercion");

  // Test coerceValue:forKey:
  id coercedValue = [container coerceValue: @"test" forKey: @"items"];
  PASS([coercedValue isEqual: @"test"],
       "coerceValue:forKey: returns value unchanged by default");

  END_SET("NSScriptKeyValueCoding coercion");

  // Clean up manually allocated objects
  [container release];
  [item1 release];
  [item2 release];
  [item3 release];

  [pool release];
  return 0;
}
