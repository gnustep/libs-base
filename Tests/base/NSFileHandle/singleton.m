#import <Foundation/Foundation.h>

id a,b,c;

int main(void)
{
	NSAutoreleasePool *p = [NSAutoreleasePool new];
	NSZombieEnabled = YES;
	a = [NSFileHandle fileHandleWithStandardInput];
	b = [NSFileHandle fileHandleWithStandardOutput];
	c = [NSFileHandle fileHandleWithStandardError];
	[p drain];
	assert(0 != [a description]);
	assert(0 != [b description]);
	assert(0 != [c description]);
}
