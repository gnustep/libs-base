#import "ObjectTesting.h"
#import <Foundation/NSPointerArray.h>

int main(void)
{
	[NSAutoreleasePool new];
	NSPointerArray *pa = [NSPointerArray pointerArrayWithWeakObjects];
	id obj = [NSObject new];
	[pa addPointer: obj];
	PASS([pa count] == 1, "Added object to weak array");
	[obj release];
	[pa compact];
	PASS([pa count] == 0, "Removed object to weak array");
	return 0;
}
