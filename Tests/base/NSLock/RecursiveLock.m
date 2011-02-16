#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  BOOL ret;
  NSLock *lock = [NSRecursiveLock new];
  ret = [lock tryLock];
  if (ret)
    [lock unlock];
  PASS(ret, "NSRecursiveLock with tryLock, then unlocking");
  
  ASSIGN(lock,[NSRecursiveLock new]);
  ret = [lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  if (ret)
    [lock unlock];
  PASS(ret, "NSRecursiveLock lockBeforeDate: works");
  
  ASSIGN(lock,[NSRecursiveLock new]);
  [lock tryLock];
  ret = [lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  if (ret)
    [lock unlock];
  PASS(ret, "NSRecursiveLock lockBeforeDate: with NSRecursiveLock returns YES");

  [arp release]; arp = nil;
  return 0;
}

