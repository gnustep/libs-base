/*
 * GSOperation.m 
 *
 * Tests for the GNUstep NSOperation/GSOperation extensions.
 */

#import <Foundation/Foundation.h>
#import <GNUstepBase/GNUstep.h>
#import <GNUstepBase/GSOperation.h>
#import <ObjectTesting.h>


/*
 * --------------------------------------------------------------------------
 * Test target
 * --------------------------------------------------------------------------
 */

@interface GSOperationTestTarget : NSObject
{
  NSMutableArray *_calls;
  NSMutableArray *_arguments;
  id _returnValue;
}
- (NSArray *) calls;
- (NSArray *) arguments;

- (id) noArgument;
- (id) oneArgument: (id)object;
- (id) anotherArgument: (id)object;
- (id) nilResult;
- (id) raiseException;
- (id) returnValue;
@end


@implementation GSOperationTestTarget

- (id) init
{
  if ((self = [super init]))
    {
      _calls = [NSMutableArray new];
      _arguments = [NSMutableArray new];
      _returnValue = [@"return" retain];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_calls);
  RELEASE(_arguments);
  RELEASE(_returnValue);
  DEALLOC
}

- (NSArray *) calls
{
  return _calls;
}

- (NSArray *) arguments
{
  return _arguments;
}

- (id) noArgument
{
  [_calls addObject: @"noArgument"];
  [_arguments addObject: [NSNull null]];
  return _returnValue;
}

- (id) oneArgument: (id)object
{
  [_calls addObject: @"oneArgument"];
  [_arguments addObject: object ? object : [NSNull null]];
  return object;
}

- (id) anotherArgument: (id)object
{
  [_calls addObject: @"anotherArgument"];
  [_arguments addObject: object ? object : [NSNull null]];
  return object;
}

- (id) nilResult
{
  [_calls addObject: @"nilResult"];
  [_arguments addObject: [NSNull null]];
  return nil;
}

- (id) returnValue
{
  [_calls addObject: @"returnValue"];
  [_arguments addObject: [NSNull null]];
  return _returnValue;
}

- (id) raiseException
{
  [_calls addObject: @"raiseException"];
  [_arguments addObject: [NSNull null]];

  [NSException raise: @"GSOperationTestException"
              format: @"expected test exception"];

  return nil;
}

@end


/*
 * --------------------------------------------------------------------------
 * Test delegate
 * --------------------------------------------------------------------------
 */

@interface GSOperationTestDelegate : NSObject <GSOperationCompletion>
{
  NSMutableArray *_indexes;
  NSMutableArray *_results;
  NSUInteger _completedCount;
  BOOL _stop;
}
- (void) setStop: (BOOL)flag;

- (NSUInteger) completedCount;
- (NSArray *) indexes;
- (NSArray *) results;
@end


@implementation GSOperationTestDelegate

- (id) init
{
  if ((self = [super init]))
    {
      _indexes = [NSMutableArray new];
      _results = [NSMutableArray new];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_indexes);
  RELEASE(_results);
  DEALLOC
}

- (void) setStop: (BOOL)flag
{
  _stop = flag;
}

- (NSUInteger) completedCount
{
  return _completedCount;
}

- (NSArray *) indexes
{
  return _indexes;
}

- (NSArray *) results
{
  return _results;
}

- (void) operationCompleted
{
  _completedCount++;
}

- (BOOL) shouldStopOperation: (GSOperation *)operation
                 afterItemAt: (NSUInteger)index
               completedWith: (id)result
{
  [_indexes addObject:
    [NSNumber numberWithUnsignedInteger: index]];

  [_results addObject: result ? result : [NSNull null]];

  return _stop;
}

@end


/*
 * --------------------------------------------------------------------------
 * Delegate used to verify weak/non-retaining delegate semantics.
 * --------------------------------------------------------------------------
 */

@interface GSOperationWeakDelegate : NSObject <GSOperationCompletion>
{
  BOOL *_destroyed;
}
- (id) initWithFlag: (BOOL *)flag;
@end


@implementation GSOperationWeakDelegate

- (id) initWithFlag: (BOOL *)flag
{
  if ((self = [super init]))
    _destroyed = flag;
  return self;
}

- (void) dealloc
{
  if (_destroyed != NULL)
    *_destroyed = YES;

  DEALLOC
}

- (void) operationCompleted
{
}

- (BOOL) shouldStopOperation: (GSOperation *)operation
                 afterItemAt: (NSUInteger)index
               completedWith: (id)result
{
  return NO;
}

@end


/*
 * Delegate implementing only operationCompleted.
 */
@interface GSOperationCompletionOnlyDelegate : NSObject
{
  NSUInteger _completed;
}
- (NSUInteger) completed;
@end


@implementation GSOperationCompletionOnlyDelegate

- (NSUInteger) completed
{
  return _completed;
}

- (void) operationCompleted
{
  _completed++;
}

@end


/*
 * --------------------------------------------------------------------------
 * Construction and item inspection
 * --------------------------------------------------------------------------
 */

static void
testInitialState(void)
{
  GSOperation *op;

  op = [GSOperation new];

  PASS([op itemCount] == 0,
       "new GSOperation initially has no items");

  PASS([op delegate] == nil,
       "new GSOperation initially has no delegate");

  [op release];
}


static void
testAddOperationWithoutObject(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  id storedTarget;
  id storedObject;
  SEL storedSelector;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  PASS([op itemCount] == 1,
       "adding a no-argument operation creates one item");

  storedTarget = nil;
  storedObject = (id)0x1234;
  storedSelector = NULL;

  [op getTarget: &storedTarget
       selector: &storedSelector
         object: &storedObject
         ofItem: 0];

  PASS(storedTarget == target,
       "getTarget returns the target");

  PASS(storedSelector == @selector(noArgument),
       "getTarget returns the selector");

  PASS(storedObject == nil,
       "no-argument operation stores a nil object");

  [op release];
  [target release];
}


static void
testAddOperationWithObject(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  id storedTarget;
  id storedObject;
  SEL storedSelector;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"hello"];

  PASS([op itemCount] == 1,
       "adding an operation with an object creates one item");

  storedTarget = nil;
  storedObject = nil;
  storedSelector = NULL;

  [op getTarget: &storedTarget
       selector: &storedSelector
         object: &storedObject
         ofItem: 0];

  PASS(storedTarget == target,
       "operation stores the supplied target");

  PASS(storedSelector == @selector(oneArgument:),
       "operation stores the supplied selector");

  PASS([storedObject isEqual: @"hello"],
       "operation stores the supplied object");

  [op release];
  [target release];
}


static void
testMultipleItemsAndOrder(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  id t;
  id o;
  SEL s;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"one"];

  [op addOperationTarget: target
        performSelector: @selector(anotherArgument:)
             withObject: @"two"];

  PASS([op itemCount] == 3,
       "multiple operation items are counted correctly");

  [op getTarget: &t selector: &s object: &o ofItem: 1];

  PASS(t == target,
       "second item has the correct target");

  PASS(s == @selector(oneArgument:),
       "second item has the correct selector");

  PASS([o isEqual: @"one"],
       "second item has the correct object");

  [op getTarget: &t selector: &s object: &o ofItem: 2];

  PASS(t == target,
       "third item has the correct target");

  PASS(s == @selector(anotherArgument:),
       "third item has the correct selector");

  PASS([o isEqual: @"two"],
       "third item has the correct object");

  [op start];

  PASS([[target calls] count] == 3,
       "all items execute");

  PASS([[[target calls] objectAtIndex: 0] isEqual: @"noArgument"],
       "first item executes first");

  PASS([[[target arguments] objectAtIndex: 1] isEqual: @"one"],
       "second item executes second");

  PASS([[[target arguments] objectAtIndex: 2] isEqual: @"two"],
       "third item executes third");

  [op release];
  [target release];
}


static void
testGetTargetAllowsNullOutputs(void)
{
  GSOperation *op;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op getTarget: NULL
       selector: NULL
         object: NULL
         ofItem: 0];

  PASS([op itemCount] == 1,
       "getTarget accepts NULL output parameters");

  [op release];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * Item mutation and ownership
 * --------------------------------------------------------------------------
 */

static void
testItemMutation(void)
{
  GSOperationTestTarget *target1;
  GSOperationTestTarget *target2;
  GSOperation *op;
  id target;
  id object;
  SEL selector;

  target1 = [GSOperationTestTarget new];
  target2 = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target1
        performSelector: @selector(oneArgument:)
             withObject: @"old"];

  [op setTarget: target2 atIndex: 0];
  [op setSelector: @selector(anotherArgument:) atIndex: 0];
  [op setObject: @"new" atIndex: 0];

  target = nil;
  object = nil;
  selector = NULL;

  [op getTarget: &target
       selector: &selector
         object: &object
         ofItem: 0];

  PASS(target == target2,
       "setTarget changes the target");

  PASS(selector == @selector(anotherArgument:),
       "setSelector changes the selector");

  PASS([object isEqual: @"new"],
       "setObject changes the object");

  [op start];

  PASS([[target2 calls] count] == 1,
       "mutated item executes");

  PASS([[[target2 arguments] objectAtIndex: 0] isEqual: @"new"],
       "mutated object is supplied to target");

  PASS([[target1 calls] count] == 0,
       "old target is no longer used");

  [op release];
  [target1 release];
  [target2 release];
}


static void
testTargetAndObjectAreRetained(void)
{
  GSOperation *op;
  GSOperationTestTarget *target;
  NSString *object;

  op = [GSOperation new];
  target = [GSOperationTestTarget new];
  object = [[NSString alloc] initWithString: @"retained"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: object];

  RELEASE(target);
  RELEASE(object);

  [op start];

  /*
   * If either the target or object had not been retained by the
   * operation, execution here would use a dangling reference.
   */
  PASS([op itemCount] == 0,
       "operation executes after caller releases target and object");

  [op release];
}


/*
 * --------------------------------------------------------------------------
 * Execution, return values, nil, exceptions
 * --------------------------------------------------------------------------
 */

static void
testExecutionAndReturnValue(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  GSOperationTestDelegate *delegate;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"result"];

  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 1,
       "starting operation invokes its target");

  PASS([[[target arguments] objectAtIndex: 0] isEqual: @"result"],
       "operation passes the supplied argument");

  PASS([[delegate results] count] == 1,
       "delegate receives one item result");

  PASS([[[delegate results] objectAtIndex: 0] isEqual: @"result"],
       "delegate receives the target return value unchanged");

  [op release];
  [delegate release];
  [target release];
}


static void
testNilObjectArgument(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: nil];

  [op start];

  PASS([[target calls] count] == 1,
       "an explicitly nil object argument is executed");

  PASS([[[target arguments] objectAtIndex: 0]
        isEqual: [NSNull null]],
       "nil object argument is passed as nil");

  [op release];
  [target release];
}


static void
testNilReturnValue(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(nilResult)];

  [op setDelegate: delegate];
  [op start];

  PASS([[delegate results] count] == 1,
       "nil-returning item still produces a completion callback");

  PASS([[[delegate results] objectAtIndex: 0]
        isEqual: [NSNull null]],
       "delegate receives nil result");

  [op release];
  [delegate release];
  [target release];
}


static void
testExceptionIsReported(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;
  id result;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(raiseException)];

  [op setDelegate: delegate];
  [op start];

  PASS([[delegate results] count] == 1,
       "exception-producing item completes");

  result = [[delegate results] objectAtIndex: 0];

  PASS([result isKindOfClass: [NSException class]],
       "exception is reported as an NSException");

  PASS([[result name] isEqual: @"GSOperationTestException"],
       "original exception name is preserved");

  [op release];
  [delegate release];
  [target release];
}


static void
testInvalidTargetProducesNilResult(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;

  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: nil
        performSelector: @selector(oneArgument:)
             withObject: @"value"];

  [op setDelegate: delegate];
  [op start];

  PASS([[delegate results] count] == 1,
       "nil target produces an item completion callback");

  PASS([[[delegate results] objectAtIndex: 0]
        isEqual: [NSNull null]],
       "nil target produces a nil result");

  [op release];
  [delegate release];
}


static void
testNullSelectorProducesNilResult(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: NULL
             withObject: @"value"];

  [op setDelegate: delegate];
  [op start];

  PASS([[delegate results] count] == 1,
       "NULL selector produces an item completion callback");

  PASS([[[delegate results] objectAtIndex: 0]
        isEqual: [NSNull null]],
       "NULL selector produces a nil result");

  PASS([[target calls] count] == 0,
       "NULL selector does not message target");

  [op release];
  [delegate release];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * Delegate behavior
 * --------------------------------------------------------------------------
 */

static void
testDelegateContinues(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"one"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"two"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"three"];

  [delegate setStop: NO];
  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 3,
       "delegate returning NO permits all items");

  PASS([[delegate indexes] count] == 3,
       "delegate receives every item callback");

  PASS([[[delegate indexes] objectAtIndex: 0]
        unsignedIntegerValue] == 0,
       "first callback has index zero");

  PASS([[[delegate indexes] objectAtIndex: 1]
        unsignedIntegerValue] == 1,
       "second callback has index one");

  PASS([[[delegate indexes] objectAtIndex: 2]
        unsignedIntegerValue] == 2,
       "third callback has index two");

  PASS([delegate completedCount] == 1,
       "operationCompleted is called once");

  [op release];
  [delegate release];
  [target release];
}


static void
testDelegateStops(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [delegate setStop: YES];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"one"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"two"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"three"];

  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 1,
       "delegate returning YES stops later items");

  PASS([[[target arguments] objectAtIndex: 0] isEqual: @"one"],
       "stopping does not undo the current item");

  PASS([[delegate indexes] count] == 1,
       "delegate receives the stopping item's callback");

  PASS([delegate completedCount] == 1,
       "operationCompleted is called after early stopping");

  [op release];
  [delegate release];
  [target release];
}


static void
testDelegateCanAppendItem(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"initial"];

  /*
   * Use the delegate's callback to append an item while main is
   * iterating over the operation's item list.
   */
  [delegate setStop: NO];
  [op setDelegate: delegate];

  /*
   * The standard delegate does not append, so use a small subclass
   * implemented below.
   */

  [op release];
  [delegate release];
  [target release];
}


/*
 * Delegate which appends an operation after the first item.
 */
@interface GSOperationAppendingDelegate : GSOperationTestDelegate
{
  id _target;
  BOOL _added;
}
- (id) initWithTarget: (id)target;
@end


@implementation GSOperationAppendingDelegate

- (id) initWithTarget: (id)target
{
  if ((self = [super init]))
    _target = [target retain];

  return self;
}

- (void) dealloc
{
  RELEASE(_target);
  DEALLOC
}

- (BOOL) shouldStopOperation: (GSOperation *)operation
                 afterItemAt: (NSUInteger)index
               completedWith: (id)result
{
  BOOL stop;

  stop = [super shouldStopOperation: operation
                       afterItemAt: index
                     completedWith: result];

  if (!_added && index == 0)
    {
      [operation addOperationTarget: _target
                    performSelector: @selector(oneArgument:)
                         withObject: @"added"];
      _added = YES;
    }

  return stop;
}

@end


static void
testDelegateCanAppendItemActuallyExecutes(void)
{
  GSOperation *op;
  GSOperationAppendingDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [[GSOperationAppendingDelegate alloc] initWithTarget: target];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"initial"];

  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 2,
       "item appended by delegate is executed");

  PASS([[[target arguments] objectAtIndex: 0]
        isEqual: @"initial"],
       "original item executes first");

  PASS([[[target arguments] objectAtIndex: 1]
        isEqual: @"added"],
       "delegate-added item executes afterwards");

  [op release];
  [delegate release];
  [target release];
}


/*
 * Delegate which changes a later item before it executes.
 */
@interface GSOperationMutatingDelegate : GSOperationTestDelegate
@end


@implementation GSOperationMutatingDelegate

- (BOOL) shouldStopOperation: (GSOperation *)operation
                 afterItemAt: (NSUInteger)index
               completedWith: (id)result
{
  BOOL stop;

  stop = [super shouldStopOperation: operation
                       afterItemAt: index
                     completedWith: result];

  if (index == 0)
    [operation setObject: @"modified" atIndex: 1];

  return stop;
}

@end


static void
testDelegateCanMutateLaterItem(void)
{
  GSOperation *op;
  GSOperationMutatingDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationMutatingDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"first"];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"original"];

  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 2,
       "both items execute after delegate mutation");

  PASS([[[target arguments] objectAtIndex: 1]
        isEqual: @"modified"],
       "delegate can modify a later item before it executes");

  [op release];
  [delegate release];
  [target release];
}


static void
testDelegateWithoutStopMethod(void)
{
  GSOperation *op;
  GSOperationCompletionOnlyDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationCompletionOnlyDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op setDelegate: (id)delegate];
  [op start];

  PASS([[target calls] count] == 1,
       "delegate without shouldStopOperation does not prevent execution");

  PASS([delegate completed] == 1,
       "delegate without shouldStopOperation receives operationCompleted");

  [op release];
  [delegate release];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * Delegate lifecycle
 * --------------------------------------------------------------------------
 */

static void
testDelegateReplacementAndClearing(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate1;
  GSOperationTestDelegate *delegate2;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate1 = [GSOperationTestDelegate new];
  delegate2 = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op setDelegate: delegate1];

  PASS([op delegate] == delegate1,
       "setDelegate installs the delegate");

  [op setDelegate: delegate2];

  PASS([op delegate] == delegate2,
       "setDelegate replaces the delegate");

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op start];

  PASS([delegate1 completedCount] == 0,
       "replaced delegate receives no callback");

  PASS([delegate2 completedCount] == 1,
       "current delegate receives the callback");

  [op setDelegate: nil];

  PASS([op delegate] == nil,
       "setDelegate:nil clears the delegate");

  [op release];
  [delegate1 release];
  [delegate2 release];
  [target release];
}


static void
testDelegateIsWeak(void)
{
  GSOperation *op;
  GSOperationWeakDelegate *delegate;
  BOOL destroyed;

  destroyed = NO;
  op = [GSOperation new];

  delegate = [[GSOperationWeakDelegate alloc]
               initWithFlag: &destroyed];

  /* We need to create/destroy an autorelease pool becuse the delegate
   * will be retained and autoreleased by the -delegate method.
   */
  ENTER_POOL
  [op setDelegate: delegate];

  PASS([op delegate] == delegate,
       "live delegate is returned by delegate");
  LEAVE_POOL

  RELEASE(delegate);

  PASS(destroyed,
       "GSOperation does not retain its delegate");

  PASS([op delegate] == nil,
       "deallocated weak delegate is returned as nil");

  [op release];
}


/*
 * --------------------------------------------------------------------------
 * Item-list lifetime and completion
 * --------------------------------------------------------------------------
 */

static void
testItemsAreClearedAfterExecution(void)
{
  GSOperation *op;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  PASS([op itemCount] == 1,
       "operation initially contains one item");

  [op start];

  PASS([op itemCount] == 0,
       "items are cleared after execution");

  [op release];
  [target release];
}


static void
testItemsAreClearedAfterStop(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [delegate setStop: YES];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op setDelegate: delegate];
  [op start];

  PASS([op itemCount] == 0,
       "items are cleared when delegate stops operation");

  [op release];
  [delegate release];
  [target release];
}


static void
testItemsAreClearedAfterExceptionAndStop(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [delegate setStop: YES];

  [op addOperationTarget: target
        performSelector: @selector(raiseException)];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"must-not-run"];

  [op setDelegate: delegate];
  [op start];

  PASS([[target calls] count] == 1,
       "exception is the only executed item when delegate stops");

  PASS([op itemCount] == 0,
       "items are cleared after exception and delegate stop");

  [op release];
  [delegate release];
  [target release];
}


static void
testOperationCompletedIsCalled(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op setDelegate: delegate];
  [op start];

  PASS([delegate completedCount] == 1,
       "operationCompleted is called once when operation completes");

  [op release];
  [delegate release];
  [target release];
}


static void
testOperationCompletedAfterStop(void)
{
  GSOperation *op;
  GSOperationTestDelegate *delegate;
  GSOperationTestTarget *target;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  op = [GSOperation new];

  [delegate setStop: YES];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op addOperationTarget: target
        performSelector: @selector(noArgument)];

  [op setDelegate: delegate];
  [op start];

  PASS([delegate completedCount] == 1,
       "operationCompleted is called when delegate stops operation");

  [op release];
  [delegate release];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * Factory methods
 * --------------------------------------------------------------------------
 */

static void
testFactoryWithoutObject(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  id storedTarget;
  id storedObject;
  SEL storedSelector;

  target = [GSOperationTestTarget new];

  op = [NSOperation operationTarget: target
                   performSelector: @selector(noArgument)];

  PASS([op isKindOfClass: [GSOperation class]],
       "factory without object returns GSOperation");

  PASS([op itemCount] == 1,
       "factory without object creates one item");

  storedTarget = nil;
  storedObject = (id)0x1234;
  storedSelector = NULL;

  [op getTarget: &storedTarget
       selector: &storedSelector
         object: &storedObject
         ofItem: 0];

  PASS(storedTarget == target,
       "factory stores target");

  PASS(storedSelector == @selector(noArgument),
       "factory stores selector");

  PASS(storedObject == nil,
       "factory stores nil object");

  [target release];
}


static void
testFactoryWithObject(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;
  id storedTarget;
  id storedObject;
  SEL storedSelector;

  target = [GSOperationTestTarget new];

  op = [NSOperation operationTarget: target
                   performSelector: @selector(oneArgument:)
                        withObject: @"factory"];

  PASS([op isKindOfClass: [GSOperation class]],
       "factory with object returns GSOperation");

  PASS([op itemCount] == 1,
       "factory with object creates one item");

  storedTarget = nil;
  storedObject = nil;
  storedSelector = NULL;

  [op getTarget: &storedTarget
       selector: &storedSelector
         object: &storedObject
         ofItem: 0];

  PASS(storedTarget == target,
       "factory stores target");

  PASS(storedSelector == @selector(oneArgument:),
       "factory stores selector");

  PASS([storedObject isEqual: @"factory"],
       "factory stores object");

  [target release];
}


static void
testFactoryOperationCanExecute(void)
{
  GSOperationTestTarget *target;
  NSAutoreleasePool *pool;
  GSOperation *op;

  target = [GSOperationTestTarget new];
  pool = [NSAutoreleasePool new];

  op = [NSOperation operationTarget: target
                   performSelector: @selector(noArgument)];

  PASS(op != nil,
       "factory returns an autoreleased operation");

  [op start];

  PASS([[target calls] count] == 1,
       "autoreleased factory operation executes correctly");

  [pool drain];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * NSOperationQueue integration
 * --------------------------------------------------------------------------
 */

static void
testQueueExecution(void)
{
  GSOperationTestTarget *target;
  NSOperationQueue *queue;
  GSOperation *op1;
  GSOperation *op2;

  target = [GSOperationTestTarget new];
  queue = [NSOperationQueue new];

  op1 = [NSOperation operationTarget: target
                    performSelector: @selector(oneArgument:)
                         withObject: @"one"];

  op2 = [NSOperation operationTarget: target
                    performSelector: @selector(oneArgument:)
                         withObject: @"two"];

  [queue addOperation: op1];
  [queue addOperation: op2];

  [queue waitUntilAllOperationsAreFinished];

  PASS([[target calls] count] == 2,
       "GSOperation instances execute in NSOperationQueue");

  PASS([[target arguments] containsObject: @"one"],
       "first queued operation executes");

  PASS([[target arguments] containsObject: @"two"],
       "second queued operation executes");

  [queue release];
  [target release];
}


static void
testQueuedOperationWithDelegate(void)
{
  GSOperationTestTarget *target;
  GSOperationTestDelegate *delegate;
  NSOperationQueue *queue;
  GSOperation *op;

  target = [GSOperationTestTarget new];
  delegate = [GSOperationTestDelegate new];
  queue = [NSOperationQueue new];
  op = [GSOperation new];

  [op addOperationTarget: target
        performSelector: @selector(oneArgument:)
             withObject: @"queued"];

  [op setDelegate: delegate];

  [queue addOperation: op];
  [queue waitUntilAllOperationsAreFinished];

  PASS([[target calls] count] == 1,
       "queued GSOperation executes its target");

  PASS([[delegate indexes] count] == 1,
       "queued GSOperation invokes item delegate");

  PASS([delegate completedCount] == 1,
       "queued GSOperation invokes operationCompleted");

  [queue release];
  [delegate release];
  [target release];
}


/*
 * --------------------------------------------------------------------------
 * NSOperation lifecycle
 * --------------------------------------------------------------------------
 */

static void
testOperationIsFinishedAfterStart(void)
{
  GSOperationTestTarget *target;
  GSOperation *op;

  target = [GSOperationTestTarget new];

  op = [NSOperation operationTarget: target
                   performSelector: @selector(noArgument)];

  [op start];

  PASS([op isFinished],
       "GSOperation is finished after synchronous start");

  [target release];
}


/*
 * --------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------
 */

int
main(void)
{
  START_SET("GSOperation")

  /*
   * Construction and inspection.
   */
  testInitialState();
  testAddOperationWithoutObject();
  testAddOperationWithObject();
  testMultipleItemsAndOrder();
  testGetTargetAllowsNullOutputs();

  /*
   * Mutation and ownership.
   */
  testItemMutation();
  testTargetAndObjectAreRetained();

  /*
   * Execution and results.
   */
  testExecutionAndReturnValue();
  testNilObjectArgument();
  testNilReturnValue();
  testExceptionIsReported();
  testInvalidTargetProducesNilResult();
  testNullSelectorProducesNilResult();

  /*
   * Delegate behavior.
   */
  testDelegateContinues();
  testDelegateStops();
  testDelegateCanAppendItemActuallyExecutes();
  testDelegateCanMutateLaterItem();
  testDelegateWithoutStopMethod();

  /*
   * Delegate lifecycle.
   */
  testDelegateReplacementAndClearing();
  testDelegateIsWeak();

  /*
   * Item lifetime and whole-operation completion.
   */
  testItemsAreClearedAfterExecution();
  testItemsAreClearedAfterStop();
  testItemsAreClearedAfterExceptionAndStop();
  testOperationCompletedIsCalled();
  testOperationCompletedAfterStop();

  /*
   * Factory methods.
   */
  testFactoryWithoutObject();
  testFactoryWithObject();
  testFactoryOperationCanExecute();

  /*
   * NSOperationQueue integration.
   */
  testQueueExecution();
  testQueuedOperationWithDelegate();

  /*
   * NSOperation lifecycle.
   */
  testOperationIsFinishedAfterStart();

  END_SET("GSOperation")

  return 0;
}

