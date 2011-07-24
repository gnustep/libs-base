#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>

int main()
{
	[NSAutoreleasePool new];
	NSHashTable *ht = [NSHashTable hashTableWithWeakObjects];
	id obj = [NSObject new];
	[ht addObject: obj];
	PASS([ht containsObject: obj], "Added object to weak hash table");
	PASS(1 == [ht count], "Weak hash table contains one object");
	PASS([ht containsObject: obj], "Added object to weak hash table");
	[obj release];
	PASS(0 == [ht count], "Weak hash table contains no objects");
	PASS(0 == [[ht allObjects] count], "Weak hash table contains no objects");
	return 0;
}
