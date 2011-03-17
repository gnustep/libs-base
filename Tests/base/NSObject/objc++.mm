extern "C" {
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
}

static int A_init;
static int B_init;
static int A_destroyed;
static int B_destroyed;

class A
{
	int b;
	public:
	A() : b(12)
	{
		pass(0 == A_init, "Constructor only called once");
		pass(0 == B_init, "a constructor called before b constructor ");
		A_init = 1;
	};
	~A()
	{
		pass(0 == A_destroyed, "Destructor only called once");
		pass(1 == B_destroyed, "b destructor called before a destructor");
		A_destroyed = 1;
	};
};
class A1
{
	int b;
	public:
	A1() : b(12)
	{
		pass(1 == A_init, "a constructor called before b constructor ");
		B_init = 1;
	};
	~A1() 
	{
		pass(0 == A_destroyed, "b destructor called before a destructor");
		B_destroyed = 1;
	};
};

@interface B : NSObject
{
	A a;
}
@end
@interface C : B
{
	A1 b;
}
@end

@implementation B
- (id)init
{
	pass(1 == A_init, "a constructor called before -init");
	pass(1 == B_init, "b constructor called before -init");
	pass(0 == A_destroyed, "a destructor not called before -init");
	pass(0 == B_destroyed, "b destructor not called before -init");
	return self;
}
@end

@implementation C @end
int main(void)
{
	// Make sure constructors / destructors are called even without -init
	[[C alloc] release];
	// Reset state
	A_init = B_init = A_destroyed = B_destroyed = 0;
	// Check init is called in the middle
	[[C new] release];
}
