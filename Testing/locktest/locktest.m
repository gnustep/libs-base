#import <Foundation/Foundation.h>

BOOL pass;

void testNSLockTryLock()
{
    // insert code here...
	NSLock *lock = [[NSLock alloc] init];
	[lock tryLock];
	[lock tryLock];
	[lock unlock];
	[lock release];
}

void testNSConditionLockTryLock()
{
    // insert code here...
	NSConditionLock *lock = [[NSConditionLock alloc] init];
	[lock tryLock];
	[lock tryLock];
	[lock unlock];
	[lock release];
}

void testNSRecursiveLockTryLock()
{
    // insert code here...
	NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
	[lock tryLock];
	[lock tryLock];
	[lock unlock];
	[lock unlock];	
	[lock release];
}

void singleThreadedTests()
{
  NS_DURING
  {
    // single threaded tests...
	testNSLockTryLock();
	testNSConditionLockTryLock();
	testNSRecursiveLockTryLock();
  }
  NS_HANDLER
  {
     NSLog(@"Test failed");
     pass = NO;
  }
  NS_ENDHANDLER
}

void multiThreadedTests()
{
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    pass = YES;
    // single threaded tests...
	singleThreadedTests();
	// multi threaded tests...
	multiThreadedTests();
	assert(pass == YES);
    [pool drain];
    return 0;
}
