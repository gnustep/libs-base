#import "Testing.h"
#import <Foundation/Foundation.h>

int main(void)
{
#if BASE_NATIVE_OBJC_EXCEPTIONS == 1
	id caught = nil;
	id thrown = @"thrown";
	@try
	{
		@throw thrown;
	}
	@catch (id str)
	{
		caught = str;
	}
	[NSAutoreleasePool new];
	PASS((caught == thrown), "Throwing an NSConstantString instance before the class is initialised");
#else
	[NSAutoreleasePool new];
	unsupported("Native exceptions");
#endif
	return 0;
}
