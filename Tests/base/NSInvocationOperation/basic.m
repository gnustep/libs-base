#import <Foundation/NSInvocationOperation.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"


int main()
{
  NSInvocationOperation *op;
  NSInvocation *inv1, *inv2;
  NSValue *val;
  int length;
  NSString *hello = @"hello", *uppercaseHello;
  NSOperationQueue *queue = [NSOperationQueue new];
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];

  op = [[NSInvocationOperation alloc] initWithTarget: hello
					     selector: @selector(length)
					       object: nil];
  [queue addOperations: [NSArray arrayWithObject: op]
     waitUntilFinished: YES];
  val = [op result];
  [val getValue: &length];
  PASS((length == 5), "Can invoke a selector on a target");
  [op release];

  inv1 = [NSInvocation invocationWithMethodSignature: 
		   [hello methodSignatureForSelector: @selector(uppercaseString)]];
  [inv1 setTarget: hello];
  [inv1 setSelector: @selector(uppercaseString)];
  op = [[NSInvocationOperation alloc] initWithInvocation: inv1];
  inv2 = [op invocation];
  PASS(([inv2 isEqual: inv1]), "Can recover an operation's invocation");
  [queue addOperations: [NSArray arrayWithObject: op]
     waitUntilFinished: YES];
  uppercaseHello = [op result];
  PASS(([uppercaseHello isEqualToString: @"HELLO"]), "Can schedule an NSInvocation");
  [op release];

  op = [[NSInvocationOperation alloc] initWithTarget: hello
					     selector: @selector(release)
					       object: nil];
  [queue addOperations: [NSArray arrayWithObject: op]
     waitUntilFinished: YES];
  PASS_EXCEPTION(([op result]), NSInvocationOperationVoidResultException, 
		 "Can't get result of a void invocation");
  [op release];

  op = [[NSInvocationOperation alloc] initWithTarget: hello
					    selector: @selector(length)
					      object: nil];
  [op cancel];
  [queue addOperations: [NSArray arrayWithObject: op]
     waitUntilFinished: YES];
  PASS_EXCEPTION(([op result]), NSInvocationOperationCancelledException,
		 "Can't get the result of a cancelled invocation");
  [op release];

  op = [[NSInvocationOperation alloc] initWithTarget: hello
					    selector: @selector(length)
					      object: nil];
  PASS(([op result] == nil), "Result is nil before the invocation has completed");
  [op release];

  [queue release];
  [arp release]; arp = nil;
  return 0;
}
