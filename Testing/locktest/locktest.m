#import <Foundation/Foundation.h>

// BOOL pass;

void testNSLockLock()
{
  NS_DURING
    {
      // insert code here...
      NSLock *lock = [[NSLock alloc] init];
      [lock lock];
#ifdef GNUSTEP
      [lock lock]; // On Mac OS X, this deadlocks.   Should we do the same?
      // our behavior in this case is arguably better since we raise an exception
#endif
      [lock unlock];
      [lock release];
#ifndef GNUSTEP
      NSLog(@"[NSLock lock] test passed -- Mac OS X behavior is to deadlock in this case, we throw an exception.");
#else
      NSLog(@"[NSLock lock] test failed");
#endif
    }
  NS_HANDLER
    {
      NSLog(@"[NSLock lock] test passed");
    }
  NS_ENDHANDLER;
}


void testNSConditionLockLock()
{
  NS_DURING
    {
      // insert code here...
      NSConditionLock *lock = [[NSConditionLock alloc] init];
      [lock lock];
#ifdef GNUSTEP
      [lock lock]; // On Mac OS X, this deadlocks.   Should we do the same?
      // our behavior in this case is arguably better since we raise an exception
#endif
      [lock unlock];
      [lock release];
#ifndef GNUSTEP
      NSLog(@"[NSConditionLock lock] test passed -- Mac OS X behavior is to deadlock in this case, we throw an exception.");
#else
      NSLog(@"[NSConditionLock lock] test failed");
#endif
    }
  NS_HANDLER
    {
      NSLog(@"[NSConditionLock lock] test passed");
    }
  NS_ENDHANDLER;
}

void testNSRecursiveLockLock()
{
  NS_DURING
    {
      // insert code here...
      NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
      [lock lock];
      [lock lock];
      [lock unlock];
      [lock unlock];	
      [lock release];
      NSLog(@"[NSRecursiveLock lock] test passed");
    }
  NS_HANDLER
    {
      NSLog(@"[NSRecursiveLock lock] test failed");
    }
  NS_ENDHANDLER;
}

void testNSLockTryLock()
{
  NS_DURING
    {
      // insert code here...
      NSLock *lock = [[NSLock alloc] init];
      [lock tryLock];
      [lock tryLock];
      [lock unlock];
      [lock release];
      NSLog(@"[NSLock tryLock] test passed");
    }
  NS_HANDLER
    {
      NSLog(@"[NSLock tryLock] test failed");
    }
  NS_ENDHANDLER;
}


void testNSConditionLockTryLock()
{
  NS_DURING
    {
      // insert code here...
      NSConditionLock *lock = [[NSConditionLock alloc] init];
      [lock tryLock];
      [lock tryLock];
      [lock unlock];
      [lock release];
      NSLog(@"[NSConditionLock tryLock] test passed");
    }
  NS_HANDLER
    {
      NSLog(@"[NSConditionLock tryLock] test failed");
    }
  NS_ENDHANDLER;
}

void testNSRecursiveLockTryLock()
{
  NS_DURING
    {
      // insert code here...
      NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
      [lock tryLock];
      [lock tryLock];
      [lock unlock];
      [lock unlock];	
      [lock release];
      NSLog(@"[NSRecursiveLock tryLock] test passed");
    }
  NS_HANDLER
    {
      NSLog(@"[NSRecursiveLock tryLock] test failed");
    }
  NS_ENDHANDLER;
}

void singleThreadedTests()
{
  // single threaded tests...
  NSLog(@"======== SINGLE THREADED TESTS");

  // lock
  testNSLockLock();
  testNSConditionLockLock();
  testNSRecursiveLockLock();

  // tryLock
  testNSLockTryLock();
  testNSConditionLockTryLock();
  testNSRecursiveLockTryLock();
}


void multiThreadedTests()
{
  NSLog(@"======== MULTI THREADED TESTS");
}

int main (int argc, const char * argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  
  // pass = YES;
  // single threaded tests...
  singleThreadedTests();
  // multi threaded tests...
  multiThreadedTests();
  [pool drain];
  return 0;
}
