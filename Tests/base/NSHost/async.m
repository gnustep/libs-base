
#import <Foundation/Foundation.h>
#import <Testing.h>

/*
 * Callback receiver for +lookupName:thread:target:selector:modes:.
 */
@interface HostLookupReceiver : NSObject
{
  NSHost 	*result;
  NSThread 	*callbackThread;
  BOOL 		called;
}
- (NSThread *) callbackThread;
- (BOOL) called;
- (void) hostLookupCompleted: (id)value;
- (id) result;
@end

@implementation HostLookupReceiver

- (NSThread *) callbackThread
{
  return callbackThread;
}

- (BOOL) called
{
  return called;
}

- (void) dealloc
{
  RELEASE(result);
  RELEASE(callbackThread);
  DEALLOC
}

- (void) hostLookupCompleted: (id)value
{
  ASSIGN(result, value);
  ASSIGN(callbackThread, [NSThread currentThread]);
  called = YES;
}

- (id) result
{
  return result;
}

@end

/* Run the current thread's run loop until the callback arrives or
 * the timeout expires. The supplied mode must match the mode in
 * which the callback is expected to be delivered.
 */
static BOOL
WaitForLookup(HostLookupReceiver *receiver, NSString *mode)
{
  NSDate	*deadline = [NSDate dateWithTimeIntervalSinceNow: 10.0];

  while (![receiver called] && [deadline timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: mode beforeDate: deadline];
    }

  return [receiver called];
}

int main(void)
{
  START_SET("NSHost asynchronous lookupName")
  HostLookupReceiver	*receiver;
  NSArray 		*modes;
  BOOL 			completed;

  /*
   * Test 1: A successful lookup delivers a non-nil host result.
   */
  receiver = AUTORELEASE([HostLookupReceiver new]);
  [NSHost lookupName: @"localhost"
              thread: nil
              target: receiver
            selector: @selector(hostLookupCompleted:)
               modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];

  completed = WaitForLookup(receiver, NSDefaultRunLoopMode);

  PASS(completed, "lookupName delivers its callback")
  PASS([[receiver result] isKindOfClass: [NSHost class]],
    "lookupName returns an NSHost")


  /*
   * Test 2: A nil thread means the calling thread.
   */
  receiver = AUTORELEASE([HostLookupReceiver new]);
  [NSHost lookupName: @"localhost"
              thread: nil
              target: receiver
            selector: @selector(hostLookupCompleted:)
               modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];

  completed = WaitForLookup(receiver, NSDefaultRunLoopMode);

  PASS(completed, "nil-thread lookup completes")
  PASS([receiver callbackThread] == [NSThread currentThread],
    "nil thread delivers callback on the calling thread")

  /*
   * Test 3: An empty modes array defaults to NSDefaultRunLoopMode.
   */
  receiver = AUTORELEASE([HostLookupReceiver new]);
  modes = [NSArray array];
  [NSHost lookupName: @"localhost"
              thread: nil
              target: receiver
            selector: @selector(hostLookupCompleted:)
               modes: modes];

  completed = WaitForLookup(receiver, NSDefaultRunLoopMode);

  PASS(completed, "empty modes array uses the default run-loop mode")
  PASS([receiver result] != nil,
    "empty modes array still delivers the lookup result")

  /*
   * Test 4: An explicitly supplied run-loop mode is honored.
   */
  receiver = AUTORELEASE([HostLookupReceiver new]);
  modes = [NSArray arrayWithObject: @"NSHostLookupTestMode"];
  [NSHost lookupName: @"localhost"
              thread: nil
              target: receiver
            selector: @selector(hostLookupCompleted:)
               modes: modes];

  completed = WaitForLookup(receiver, @"NSHostLookupTestMode");

  PASS(completed, "callback is delivered in the supplied run-loop mode")
  PASS([receiver result] != nil,
    "custom-mode callback receives a result")

  END_SET("NSHost asynchronous lookupName");

  return 0;
}
