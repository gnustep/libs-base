#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSMethodSignature *sig;
  NSInvocation      *inv;
  NSTimer	    *tim;
  NSRunLoop	    *run;
  NSDate	    *date;

  sig = [NSTimer instanceMethodSignatureForSelector:@selector(isValid)];
  inv = [NSInvocation invocationWithMethodSignature: sig];
  
  run = [NSRunLoop currentRunLoop];
  PASS(run != nil, "NSRunLoop understands [+currentRunLoop]");
  PASS([run currentMode] == nil, "-currentMode returns nil");
  
  TEST_EXCEPTION(date = [NSDate dateWithTimeIntervalSinceNow:3];
  		 [run runUntilDate:date];,
		 nil,NO,"-runUntilDate: works");
  TEST_EXCEPTION(date = [NSDate dateWithTimeIntervalSinceNow:5];
  		 tim = [NSTimer scheduledTimerWithTimeInterval: 2.0
						    invocation:inv
				 		       repeats:YES];,
	         nil,NO,"-runUntilDate: works with a timer");
  
  
  
  [arp release]; arp = nil;
  return 0;
}
