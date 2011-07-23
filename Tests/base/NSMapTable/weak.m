#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMapTable.h>

int main()
{
	[NSAutoreleasePool new];
	NSMapTable *map = [NSMapTable mapTableWithStrongToWeakObjects];
	NSMapTable *map2 = [NSMapTable mapTableWithWeakToStrongObjects];
	id obj = [NSObject new];
	
	[map setObject: obj forKey: @"1"];
	[map2 setObject: @"1" forKey: obj];
	PASS(obj == [map objectForKey: @"1"], "Value stored in weak-value map");
	PASS(nil != [map2 objectForKey: obj], "Value stored in weak-key map");
	[obj release];
	PASS(nil == [map objectForKey: @"1"], "Value removed from weak-value map");
	NSEnumerator *enumerator = [map2 keyEnumerator];
	NSUInteger count = 0;
	while ([enumerator nextObject] != nil) { count++; }
	PASS(count == 0, "Value removed from weak-key map");
	PASS(0 == [map count], "Weak-value map reports correct count");
	PASS(0 == [map2 count], "Weak-key map reports correct count");
	return 0;
}
