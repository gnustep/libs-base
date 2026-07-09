/**
   kvoToMany.m

   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: June 2024

   Based on WinObjC KVO tests by Microsoft Corporation.

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/
/**
  Copyright (c) Microsoft. All rights reserved.

  This code is licensed under the MIT License (MIT).

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

#import <Foundation/Foundation.h>
#import "Testing.h"

#define BOXF(V) [NSNumber numberWithFloat: (V)]
#define BOXI(V) [NSNumber numberWithInteger: (V)]

@interface Observee : NSObject
{
  NSMutableArray *_bareArray;
  NSMutableArray *_manualNotificationArray;
  NSMutableArray *_kvcMediatedArray;
  NSMutableArray *_arrayWithHelpers;
  NSMutableSet   *_setWithHelpers;
  NSMutableSet   *_kvcMediatedSet;
  NSMutableSet   *_manualNotificationSet;
  NSSet          *_roSet;
}

- (NSArray *)manualNotificationArray;
- (NSSet *)setWithHelpers;

@end

typedef void (*ChangeCallback)(NSString *, id, NSDictionary *, void *);
typedef void (*PerformBlock)(Observee *);

@implementation Observee
- (instancetype)init
{
  self = [super init];
  if (self)
    {
      _bareArray = [NSMutableArray new];
      _manualNotificationArray = [NSMutableArray new];
      _kvcMediatedArray = [NSMutableArray new];
      _arrayWithHelpers = [NSMutableArray new];
      _setWithHelpers = [NSMutableSet new];
      _kvcMediatedSet = [NSMutableSet new];
      _manualNotificationSet = [NSMutableSet new];
    }
  return self;
}

- (void)dealloc
{
  [_bareArray release];
  [_manualNotificationArray release];
  [_kvcMediatedArray release];
  [_arrayWithHelpers release];
  [_setWithHelpers release];
  [_kvcMediatedSet release];
  [_manualNotificationSet release];
  [_roSet release];
  [super dealloc];
}

/* Used for testing NSKeyValueFastMutableSet which is used in
 * +[NSKeyValueMutableSet setForKey:ofObject:] */

- (NSSet *)proxySet
{
  return _kvcMediatedSet;
}

- (void)addProxySetObject:(id)obj
{
  [_kvcMediatedSet addObject:obj];
}

- (void)removeProxySetObject:(id)obj
{
  [_kvcMediatedSet removeObject:obj];
}

- (void)addProxySet:(NSSet *)set
{
  [_kvcMediatedSet unionSet:set];
}

- (void)removeProxySet:(NSSet *)set
{
  [_kvcMediatedSet minusSet:set];
}

/* Used for testing NSKeyValueSlowMutableSet which is used
 * when no add or remove method is available. */
- (NSSet *)proxyRoSet
{
  return _roSet;
}

- (void)setProxyRoSet:(NSSet *)set
{
  ASSIGN(_roSet, set);
}

- (void)addObjectToBareArray:(NSObject *)object
{
  [_bareArray addObject:object];
}

- (void)addObjectToManualArray:(NSObject *)object
{
  NSIndexSet *indexes =
    [NSIndexSet indexSetWithIndex:[_manualNotificationArray count]];
  [self willChange:NSKeyValueChangeInsertion
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
  [_manualNotificationArray addObject:object];
  [self didChange:NSKeyValueChangeInsertion
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
}

- (void)removeObjectFromManualArrayIndex:(NSUInteger)index
{
  NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
  [self willChange:NSKeyValueChangeRemoval
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
  [_manualNotificationArray removeObjectAtIndex:index];
  [self didChange:NSKeyValueChangeRemoval
    valuesAtIndexes:indexes
             forKey:@"manualNotificationArray"];
}

- (NSArray *)manualNotificationArray
{
  return _manualNotificationArray;
}

- (void)insertObject:(NSObject *)object
  inArrayWithHelpersAtIndex:(NSUInteger)index
{
  [_arrayWithHelpers insertObject:object atIndex:index];
}

- (void)removeObjectFromArrayWithHelpersAtIndex:(NSUInteger)index
{
  [_arrayWithHelpers removeObjectAtIndex:index];
}

- (NSSet *)setWithHelpers
{
  return _setWithHelpers;
}

- (void)addSetWithHelpersObject:(id)obj
{
  [_setWithHelpers addObject:obj];
}

- (void)removeSetWithHelpersObject:(id)obj
{
  [_setWithHelpers removeObject:obj];
}

- (void)addSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers unionSet:set];
}

- (void)removeSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers minusSet:set];
}

- (void)intersectSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers intersectSet:set];
}

- (void)setSetWithHelpers:(NSSet *)set
{
  [_setWithHelpers setSet:set];
}

- (void)manualSetAddObject:(id)obj
{
  NSSet *set = [NSSet setWithObject:obj];
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueUnionSetMutation
                 usingObjects:set];
  [_manualNotificationSet addObject:obj];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueUnionSetMutation
                usingObjects:set];
}

- (void)manualSetRemoveObject:(id)obj
{
  NSSet *set = [NSSet setWithObject:obj];
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueMinusSetMutation
                 usingObjects:set];
  [_manualNotificationSet removeObject:obj];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueMinusSetMutation
                usingObjects:set];
}

- (void)manualUnionSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueUnionSetMutation
                 usingObjects:set];
  [_manualNotificationSet unionSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueUnionSetMutation
                usingObjects:set];
}

- (void)manualMinusSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueMinusSetMutation
                 usingObjects:set];
  [_manualNotificationSet minusSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueMinusSetMutation
                usingObjects:set];
}

- (void)manualIntersectSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueIntersectSetMutation
                 usingObjects:set];
  [_manualNotificationSet intersectSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueIntersectSetMutation
                usingObjects:set];
}

- (void)manualSetSet:(NSSet *)set
{
  [self willChangeValueForKey:@"manualNotificationSet"
              withSetMutation:NSKeyValueSetSetMutation
                 usingObjects:set];
  [_manualNotificationSet setSet:set];
  [self didChangeValueForKey:@"manualNotificationSet"
             withSetMutation:NSKeyValueSetSetMutation
                usingObjects:set];
}

@end

@interface TestObserver : NSObject
{
  ChangeCallback *_callbacks;
  NSUInteger      _callbackCount;
  NSUInteger      _callbackIndex;
  NSUInteger      _hits;
}
- (void)setCallbacks:(ChangeCallback *)callbacks count:(NSUInteger)count;
- (NSUInteger)hits;
@end

@implementation TestObserver
- (instancetype)init
{
  self = [super init];
  if (self)
    {
      _callbacks = NULL;
      _callbackCount = 0;
      _hits = 0;
      _callbackIndex = 0;
    }
  return self;
}

- (NSUInteger)hits
{
  return _hits;
}

- (void)setCallbacks:(ChangeCallback *)callbacks count:(NSUInteger)count
{
  _callbacks = callbacks;
  _callbackCount = count;
  _callbackIndex = 0;
  _hits = 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (_callbackCount > 0)
    {
      _callbacks[_callbackIndex](keyPath, object, change, context);
      _callbackIndex = (_callbackIndex + 1) % _callbackCount;
    }
  _hits++;
}
@end

@interface                                  TestFacade : NSObject
{
  Observee     *_observee;
  TestObserver *_observer;
}
@property (nonatomic, retain) Observee     *observee;
@property (nonatomic, retain) TestObserver *observer;
@end

@implementation TestFacade
@synthesize observee = _observee;
@synthesize observer = _observer;
+ (instancetype)newWithObservee:(Observee *)observee
{
  return [[TestFacade alloc] initWithObservee:observee];
}

- (instancetype)initWithObservee:(Observee *)observee
{
  self = [super init];
  if (self)
    {
      ASSIGN(_observee, observee);
      _observer = [TestObserver new];
    }
  return self;
}

- (void)dealloc
{
  [_observee release];
  [_observer release];
  [super dealloc];
}

- (void)observeKeyPath:(NSString *)keyPath
           withOptions:(NSKeyValueObservingOptions)options
          performingFn:(PerformBlock)fn
  andExpectChangeCallbacks:(ChangeCallback *)callbacks
                     count:(NSUInteger)count
{
  [_observer setCallbacks:callbacks count:count];
  NS_DURING
    {
      [_observee addObserver:_observer
                  forKeyPath:keyPath
                     options:options
                     context:nil];
      fn(_observee);
      [_observee removeObserver:_observer forKeyPath:keyPath];
    }
  NS_HANDLER
    {
      NSLog(@"Test failed with exception: %@", localException);
    }
  NS_ENDHANDLER
}

- (NSUInteger)hits
{
  return [_observer hits];
}
@end

@interface                                 DummyObject : NSObject
{
  NSString    *_name;
  DummyObject *_sub;
}
@property (nonatomic, copy) NSString      *name;
@property (nonatomic, retain) DummyObject *sub;
@end

@implementation DummyObject
@synthesize name = _name;
@synthesize sub = _sub;
+ (instancetype)makeDummy
{
  DummyObject *ret = [[DummyObject new] autorelease];
  ret.name = @"Value";
  return ret;
}

- (void)dealloc
{
  [_name release];
  [_sub release];
  [super dealloc];
}

@end

static void
bareArray_illegalNotification(NSString *keyPath, id object,
                              NSDictionary *change, void *context)
{
  // Any notification here is illegal.
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "Any notification here is illegal.");
}

static void
bareArray_addObject(Observee *observee)
{
  [observee addObjectToBareArray:@"hello"];
}

static void
ToMany_NoNotificationOnBareArray()
{
  START_SET("ToMany_NoNotificationOnBareArray");

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"bareArray"
             withOptions:0
            performingFn:bareArray_addObject
    andExpectChangeCallbacks:(ChangeCallback[]){bareArray_illegalNotification}
                       count:1];
  PASS([facade hits] == 0, "No notifications were sent");

  [facade release];
  [observee release];

  END_SET("ToMany_NoNotificationOnBareArray");
}

static void
notifyingArray_firstInsertCallback(NSString *keyPath, id object,
                                   NSDictionary *change, void *context)
{
  NSIndexSet *indexes;

  (void)keyPath;
  (void)object;
  (void)context;

  PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), [change objectForKey: NSKeyValueChangeKindKey],
             "firstInsertCallback: Change is an insertion");

  indexes = [change objectForKey: NSKeyValueChangeIndexesKey];

  PASS(indexes != nil, "firstInsertCallback: Indexes are not nil");
  PASS([indexes firstIndex] == 0, "firstInsertCallback: Index is 0");

  if (![[change objectForKey: NSKeyValueChangeNotificationIsPriorKey] boolValue])
    {
      PASS_EQUAL(@"object1", [[change objectForKey: NSKeyValueChangeNewKey] objectAtIndex:0],
                 "firstInsertCallback: New object is 'object1'");
    }
}

static void
notifyingArray_secondInsertCallback(NSString *keyPath, id object,
                                    NSDictionary *change, void *context)
{
  NSIndexSet *indexes;

  (void)keyPath;
  (void)object;
  (void)context;

  // We should get an add on index 1 of "object2"
  PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), [change objectForKey: NSKeyValueChangeKindKey],
             "secondInsertCallback: Change is an insertion");

  indexes = [change objectForKey: NSKeyValueChangeIndexesKey];

  PASS(indexes != nil, "secondInsertCallback: Indexes are not nil");
  PASS([indexes firstIndex] == 1, "secondInsertCallback: Index is 1");

  if (![[change objectForKey: NSKeyValueChangeNotificationIsPriorKey] boolValue])
    {
      PASS_EQUAL(@"object2", [[change objectForKey: NSKeyValueChangeNewKey] objectAtIndex:0],
                 "secondInsertCallback: New object is 'object2'");
    }
}

static void
notifyingArray_removalCallback(NSString *keyPath, id object,
                               NSDictionary *change, void *context)
{
  NSIndexSet *indexes;

  (void)keyPath;
  (void)object;
  (void)context;

  PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), [change objectForKey: NSKeyValueChangeKindKey],
             "removalCallback: Change is a removal");

  indexes = [change objectForKey: NSKeyValueChangeIndexesKey];

  PASS(indexes != nil, "removalCallback: Indexes are not nil");
  PASS([indexes firstIndex] == 0, "removalCallback: Index is 0");
  if ([[change objectForKey: NSKeyValueChangeNotificationIsPriorKey] boolValue])
    {
      PASS_EQUAL(@"object1", [[change objectForKey: NSKeyValueChangeOldKey] objectAtIndex:0],
                 "removalCallback: Old object is 'object1'");
    }
}

static void
notifyingArray_illegalChangeNotification(NSString *keyPath, id object,
                                         NSDictionary *change, void *context)
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "illegalChangeNotification: was called");
}

static void
notifyingArray_initialNotificationCallback(NSString *keyPath, id object,
                                           NSDictionary *change, void *context)
{
  NSArray *expectedArray = [NSArray arrayWithObjects: @"object2", nil];

  (void)keyPath;
  (void)object;
  (void)context;

  PASS_EQUAL(expectedArray, [change objectForKey: NSKeyValueChangeNewKey],
    "Initial notification: New array is 'object2'");
  NSLog(@"Initial notification: New array is %@",
        [change objectForKey: NSKeyValueChangeNewKey]);
}

static void
notifyingArray_manualMutation1(Observee *observee)
{
  [observee addObjectToManualArray:@"object1"];
  [observee addObjectToManualArray:@"object2"];
  [observee removeObjectFromManualArrayIndex:0];
}

static void
notifyingArray_manualMutation2(Observee *observee)
{
  [observee addObjectToManualArray:@"object1"];
  [observee addObjectToManualArray:@"object2"];
  [observee removeObjectFromManualArrayIndex:0];
}

static void
notifyingArray_emptyMutation(Observee *observee)
{
  (void)observee;
}

static void
notifyingArray_kvcMediatedMutation(Observee *observee)
{
  // This array is not assisted with setter functions and should go
  // through the get/mutate/set codepath.
  NSMutableArray *mediatedVersionOfArray =
    [observee mutableArrayValueForKey:@"kvcMediatedArray"];
  [mediatedVersionOfArray addObject:@"object1"];
  [mediatedVersionOfArray addObject:@"object2"];
  [mediatedVersionOfArray removeObjectAtIndex:0];
}

static void
notifyingArray_helpersMediatedMutation(Observee *observee)
{
  // This array is assisted by setter functions, and should also
  // dispatch one notification per change.
  NSMutableArray *mediatedVersionOfArray =
    [observee mutableArrayValueForKey:@"arrayWithHelpers"];
  [mediatedVersionOfArray addObject:@"object1"];
  [mediatedVersionOfArray addObject:@"object2"];
  [mediatedVersionOfArray removeObjectAtIndex:0];
}

static void
notifyingArray_helpersManualMutation(Observee *observee)
{
  // This array is assisted by setter functions, and should also
  // dispatch one notification per change.
  [observee insertObject:@"object1" inArrayWithHelpersAtIndex:0];
  [observee insertObject:@"object2" inArrayWithHelpersAtIndex:1];
  [observee removeObjectFromArrayWithHelpersAtIndex:0];
}

static void
ToMany_NotifyingArray()
{
  START_SET("ToMany_NotifyingArray");

  /* Testing manually notifiying array (utilizes add and remove meths in
   * Observee) */

  Observee   *observee;
  TestFacade *facade;

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  // This test expects one change for each key; any more than that is a failure.
  [facade observeKeyPath:@"manualNotificationArray"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_manualMutation1
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_firstInsertCallback, notifyingArray_secondInsertCallback,
      notifyingArray_removalCallback,
      notifyingArray_illegalChangeNotification}
                       count:4];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // This test expects two change notifications for each key; any more than that
  // is a failure.
  [facade observeKeyPath:@"manualNotificationArray"
             withOptions:NSKeyValueObservingOptionPrior
                         | NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_manualMutation2
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_firstInsertCallback, notifyingArray_firstInsertCallback,
      notifyingArray_secondInsertCallback, notifyingArray_secondInsertCallback,
      notifyingArray_removalCallback, notifyingArray_removalCallback,
      notifyingArray_illegalChangeNotification}
                       count:7];

  PASS([facade hits] == 6, "Six notifications were sent");
  PASS_EQUAL(([NSArray arrayWithObjects: @"object2", nil]),
    [observee manualNotificationArray],
    "Final array is 'object2'");

  // This test expects one change notification: the initial one. Any more than
  // that is a failure.
  [facade observeKeyPath:@"manualNotificationArray"
             withOptions:NSKeyValueObservingOptionInitial
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_emptyMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_initialNotificationCallback,
      notifyingArray_illegalChangeNotification}
                       count:2];
  PASS([facade hits] == 1, "One notification was sent");

  /* Testing mediated array */
  [facade observeKeyPath:@"kvcMediatedArray"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_kvcMediatedMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_firstInsertCallback, notifyingArray_secondInsertCallback,
      notifyingArray_removalCallback,
      notifyingArray_illegalChangeNotification}
                       count:4];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  /* Testing array with helpers */
  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_helpersMediatedMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_firstInsertCallback, notifyingArray_secondInsertCallback,
      notifyingArray_removalCallback,
      notifyingArray_illegalChangeNotification}
                       count:4];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // In this test, we use the same arrayWithHelpers as above, but interact with
  // it manually.
  [facade observeKeyPath:@"arrayWithHelpers"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:notifyingArray_helpersManualMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      notifyingArray_firstInsertCallback, notifyingArray_secondInsertCallback,
      notifyingArray_removalCallback,
      notifyingArray_illegalChangeNotification}
                       count:4];
  PASS([facade hits] == 3, "Three notifications were sent");

  [facade release];
  [observee release];

  END_SET("ToMany_NotifyingArray");
}

static void
kvcAgg_insertCallbackPost(NSString *keyPath, id object, NSDictionary *change,
                          void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;

  PASS([change objectForKey: NSKeyValueChangeNotificationIsPriorKey] == nil, "Post change");
  PASS_EQUAL(BOXI(NSKeyValueChangeSetting), [change objectForKey: NSKeyValueChangeKindKey],
             "Change is a setting");
  PASS_EQUAL(BOXI(0), [change objectForKey: NSKeyValueChangeOldKey], "Old value is 0");
  PASS_EQUAL(BOXI(1), [change objectForKey: NSKeyValueChangeNewKey], "New value is 1");

  NSIndexSet *indexes = [change objectForKey: NSKeyValueChangeIndexesKey];
  PASS(indexes == nil, "Indexes are nil");
}

static void
kvcAgg_illegalChangeNotification(NSString *keyPath, id object,
                                 NSDictionary *change, void *context)
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "illegalChangeNotification");
}

static void
kvcAgg_mediatedMutation(Observee *observee)
{
  // This array is assisted by setter functions, and should also
  // dispatch one notification per change.
  NSMutableArray *mediatedVersionOfArray =
    [observee mutableArrayValueForKey:@"arrayWithHelpers"];
  [mediatedVersionOfArray addObject:@"object1"];
}

static void
kvcAgg_manualMutation(Observee *observee)
{
  // This array is assisted by setter functions, and should also
  // dispatch one notification per change.
  [observee insertObject:@"object1" inArrayWithHelpersAtIndex:0];
}

static void
ToMany_KVCMediatedArrayWithHelpers_AggregateFunction()
{
  START_SET("ToMany_KVCMediatedArrayWithHelpers_AggregateFunction");

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers.@count"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:kvcAgg_mediatedMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      kvcAgg_insertCallbackPost, kvcAgg_illegalChangeNotification}
                       count:2];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];
  // In this test, we use the same arrayWithHelpers as above, but interact with
  // it manually.
  [facade observeKeyPath:@"arrayWithHelpers.@count"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:kvcAgg_manualMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      kvcAgg_insertCallbackPost, kvcAgg_illegalChangeNotification}
                       count:2];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  END_SET("ToMany_KVCMediatedArrayWithHelpers_AggregateFunction");
}

static void
toOne_insertCallbackPost(NSString *keyPath, id object, NSDictionary *change,
                         void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;

  PASS([change objectForKey: NSKeyValueChangeNotificationIsPriorKey] == nil, "Post change");
  PASS_EQUAL(BOXI(NSKeyValueChangeSetting), [change objectForKey: NSKeyValueChangeKindKey],
             "Change is a setting");
  NSArray *expectedOld = [NSArray arrayWithObjects: @"Value", nil];
  PASS_EQUAL(expectedOld, [change objectForKey: NSKeyValueChangeOldKey],
             "Old value is correct");
  NSArray *expectedNew = [NSArray arrayWithObjects: @"Value", @"Value", nil];
  PASS_EQUAL(expectedNew, [change objectForKey: NSKeyValueChangeNewKey],
             "New value is correct");
  NSIndexSet *indexes = [change objectForKey: NSKeyValueChangeIndexesKey];
  PASS(indexes == nil, "Indexes are nil");
}

static void
toOne_illegalChangeNotification(NSString *keyPath, id object,
                                NSDictionary *change, void *context)
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "illegalChangeNotification");
}

static void
toOne_insertMutation(Observee *observee)
{
  // This array is assisted by setter functions, and should also
  // dispatch one notification per change.
  [observee insertObject:[DummyObject makeDummy]
    inArrayWithHelpersAtIndex:0];
}

static void
ToMany_ToOne_ShouldDowngradeForOrderedObservation()
{
  START_SET("ToMany_ToOne_ShouldDowngradeForOrderedObservation");

  Observee *observee = [Observee new];
  [observee insertObject:[DummyObject makeDummy] inArrayWithHelpersAtIndex:0];

  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"arrayWithHelpers.name"
             withOptions:NSKeyValueObservingOptionOld
                         | NSKeyValueObservingOptionNew
            performingFn:toOne_insertMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      toOne_insertCallbackPost, toOne_illegalChangeNotification}
                       count:2];
  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [observee release];

  END_SET("ToMany_ToOne_ShouldDowngradeForOrderedObservation");
}

static void
leak_onlyNewCallback(NSString *keyPath, id object, NSDictionary *change,
                     void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS([change objectForKey: NSKeyValueChangeNewKey] != nil, "New key is not nil");
  PASS([change objectForKey: NSKeyValueChangeOldKey] == nil, "Old key is nil");
}

static void
leak_illegalChangeNotification(NSString *keyPath, id object,
                               NSDictionary *change, void *context)
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "illegalChangeNotification");
}

static void
leak_addMutation(Observee *observee)
{
  [observee addObjectToManualArray:@"object1"];
}

static void
ObserverInformationShouldNotLeak()
{
  START_SET("ObserverInformationShouldNotLeak");

  Observee   *observee = [Observee new];
  TestFacade *firstFacade = [TestFacade newWithObservee:observee];
  [observee
    addObserver:firstFacade.observer
     forKeyPath:@"manualNotificationArray"
        options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
        context:nil];

  TestFacade *facade = [TestFacade newWithObservee:observee];
  [facade observeKeyPath:@"manualNotificationArray"
             withOptions:NSKeyValueObservingOptionNew
            performingFn:leak_addMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      leak_onlyNewCallback, leak_illegalChangeNotification}
                       count:2];

  [observee removeObserver:firstFacade.observer
                forKeyPath:@"manualNotificationArray"];

  PASS([facade hits] == 1, "One notification was sent");

  [facade release];
  [firstFacade release];
  [observee release];

  END_SET("ObserverInformationShouldNotLeak");
}

static void __attribute__((unused))
NSArrayShouldNotBeObservable()
{
  START_SET("NSArrayShouldNotBeObservable");

  NSArray      *test = [NSArray arrayWithObjects: BOXI(1), BOXI(2), BOXI(3), nil];
  TestObserver *observer = [TestObserver new];
  PASS_EXCEPTION([test addObserver:observer
                        forKeyPath:@"count"
                           options:0
                           context:nil],
    (NSString*)nil,
    "NSArray is not observable");

  // These would throw anyways because there should be no observer for the key
  // path, but test anyways
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count"],
    (NSString*)nil,
    "Check removing non-existent observer");
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count" context:nil],
    (NSString*)nil,
                 "Check removing non-existent observer");

  [observer release];

  END_SET("NSArrayShouldNotBeObservable");
}

static void
NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange()
{
  START_SET("NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange");

  NSArray      *o1 = AUTORELEASE([Observee new]);
  NSArray      *o2 = AUTORELEASE([Observee new]);
  NSArray      *test = [NSArray arrayWithObjects: o1, o2, nil];
  TestObserver *observer = [TestObserver new];

  PASS_EXCEPTION([test addObserver:observer
                   toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:4]
                           forKeyPath:@"bareArray"
                              options:0
                              context:nil],
    (NSString*)nil,
    "Observe index out of range");

  [observer release];

  END_SET("NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange");
}

static void
NSArrayObserveElements()
{
  START_SET("NSArrayObserveElements");

  Observee *observee1 = [Observee new];
  Observee *observee2 = [Observee new];
  Observee *observee3 = [Observee new];

  NSArray      *observeeArray = [NSArray arrayWithObjects: observee1, observee2, observee3, nil];
  TestObserver *observer = [TestObserver new];
  PASS_RUNS([observeeArray
                     addObserver:observer
              toObjectsAtIndexes:[NSIndexSet
                                   indexSetWithIndexesInRange:NSMakeRange(0, 2)]
                      forKeyPath:@"manualNotificationArray"
                         options:(NSKeyValueObservingOptionOld
                                  | NSKeyValueObservingOptionNew)
                         context:nil],
            "Observe first two elements");

  // First two elements in range for observation so observer will receive
  // changes
  [[observeeArray objectAtIndex: 0] addObjectToManualArray:@"object1"];
  [[observeeArray objectAtIndex: 0] addObjectToManualArray:@"object2"];
  PASS([observer hits] == 2, "First two elements in range for observation");

  [[observeeArray objectAtIndex: 1] addObjectToManualArray:@"object1"];
  PASS([observer hits] == 3, "Second element in range for observation");

  // But the third element is not so observer will not receive changes
  [[observeeArray objectAtIndex: 2] addObjectToManualArray:@"object1"];
  PASS([observer hits] == 3, "Third element not in range for observation");

  PASS_RUNS([observeeArray
                    removeObserver:observer
              fromObjectsAtIndexes:[NSIndexSet
                                     indexSetWithIndexesInRange:NSMakeRange(0,
                                                                            1)]
                        forKeyPath:@"manualNotificationArray"],
            "remove observer from first element");

  // Removed observer from first element, so modifying it will not report a
  // change
  [[observeeArray objectAtIndex: 0] addObjectToManualArray:@"object3"];
  PASS([observer hits] == 3, "First element observer removed");

  // But the second element is still being observed
  [[observeeArray objectAtIndex: 1] addObjectToManualArray:@"object2"];
  PASS([observer hits] == 4, "Second element still being observed");

  PASS_RUNS([observeeArray
                    removeObserver:observer
              fromObjectsAtIndexes:[NSIndexSet
                                     indexSetWithIndexesInRange:NSMakeRange(1,
                                                                            1)]
                        forKeyPath:@"manualNotificationArray"],
            "remove observer from second element");

  [[observeeArray objectAtIndex: 1] addObjectToManualArray:@"object3"];
  PASS([observer hits] == 4, "Second element observer removed");

  [observer release];
  [observee1 release];
  [observee2 release];
  [observee3 release];

  END_SET("NSArrayObserveElements");
}

static void
NSSetShouldNotBeObservable()
{
  START_SET("NSSetShouldNotBeObservable");

  NSSet        *test = [NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil];
  TestObserver *observer = [TestObserver new];
  PASS_EXCEPTION([test addObserver:observer
                        forKeyPath:@"count"
                           options:0
                           context:nil],
    (NSString*)nil,
    "NSSet is not observable");

  // These would throw anyways because there should be no observer for the key
  // path, but test anyways
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count"],
    (NSString*)nil,
    "Check removing non-existent observer");
  PASS_EXCEPTION([test removeObserver:observer forKeyPath:@"count" context:nil],
    (NSString*)nil,
    "Check removing non-existent observer");

  [observer release];

  END_SET("NSSetShouldNotBeObservable");
}

static BOOL setSetChanged = NO;

static void
setMut_unionCallback(NSString *keyPath, id object, NSDictionary *change,
                     void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), [change objectForKey: NSKeyValueChangeKindKey],
             "Union change is an insertion");
  NSSet *expected = [NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil];
  PASS_EQUAL([change objectForKey: NSKeyValueChangeNewKey], expected,
             "Union new key is correct");
  PASS([change objectForKey: NSKeyValueChangeOldKey] == nil, "Union old key is nil");
}

static void
setMut_minusCallback(NSString *keyPath, id object, NSDictionary *change,
                     void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS_EQUAL([change objectForKey: NSKeyValueChangeKindKey], BOXI(NSKeyValueChangeRemoval),
             "Minus change is a removal");
  PASS_EQUAL([change objectForKey: NSKeyValueChangeOldKey], [NSSet setWithObject:BOXI(1)],
             "Minus old key is correct");
  PASS([change objectForKey: NSKeyValueChangeNewKey] == nil, "Minus new key is nil");
}

static void
setMut_addCallback(NSString *keyPath, id object, NSDictionary *change,
                   void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS_EQUAL(BOXI(NSKeyValueChangeInsertion), [change objectForKey: NSKeyValueChangeKindKey],
             "Add change is an insertion");
  NSLog(@"Change %@", change);
  PASS_EQUAL([NSSet setWithObject:BOXI(1)], [change objectForKey: NSKeyValueChangeNewKey],
             "Add new key is correct");
  PASS([change objectForKey: NSKeyValueChangeOldKey] == nil, "Add old key is nil");
}

static void
setMut_removeCallback(NSString *keyPath, id object, NSDictionary *change,
                      void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), [change objectForKey: NSKeyValueChangeKindKey],
             "Remove change is a removal");
  PASS_EQUAL([NSSet setWithObject:BOXI(1)], [change objectForKey: NSKeyValueChangeOldKey],
             "Remove old key is correct");
  PASS([change objectForKey: NSKeyValueChangeNewKey] == nil, "Remove new key is nil");
}

static void
setMut_intersectCallback(NSString *keyPath, id object, NSDictionary *change,
                         void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  PASS_EQUAL(BOXI(NSKeyValueChangeRemoval), [change objectForKey: NSKeyValueChangeKindKey],
             "Intersect change is a removal");
  NSSet *expected = [NSSet setWithObject:BOXI(3)];
  PASS_EQUAL(expected, [change objectForKey: NSKeyValueChangeOldKey],
             "Intersect old key is correct");
  PASS([change objectForKey: NSKeyValueChangeNewKey] == nil, "Intersect new key is nil");
}

static void
setMut_setCallback(NSString *keyPath, id object, NSDictionary *change,
                   void *context)
{
  (void)keyPath;
  (void)object;
  (void)context;
  if (setSetChanged)
    {
      PASS_EQUAL(BOXI(NSKeyValueChangeReplacement),
                 [change objectForKey: NSKeyValueChangeKindKey],
                 "Set change is a replacement");
      PASS_EQUAL([NSSet setWithObject:BOXI(2)], [change objectForKey: NSKeyValueChangeOldKey],
                 "Set old key is correct");
      PASS_EQUAL([NSSet setWithObject:BOXI(3)], [change objectForKey: NSKeyValueChangeNewKey],
                 "Set new key is correct");
    }
  // setXxx method is not automatically swizzled for observation
  else
    {
      PASS_EQUAL(BOXI(NSKeyValueChangeSetting), [change objectForKey: NSKeyValueChangeKindKey],
                 "Set change is a setting");
      PASS_EQUAL([NSSet setWithObject:BOXI(3)], [change objectForKey: NSKeyValueChangeOldKey],
                 "Set old key is correct");
      PASS_EQUAL([NSSet setWithObject:BOXI(3)], [change objectForKey: NSKeyValueChangeNewKey],
                 "Set new key is correct");
    }
}

static void
setMut_illegalChangeNotification(NSString *keyPath, id object,
                                 NSDictionary *change, void *context)
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  PASS(NO, "illegalChangeNotification");
}

static void
setMut_helpersMutation(Observee *observee)
{
  // This set is assisted by setter functions, and should also
  // dispatch one notification per change.
  [observee
    addSetWithHelpers:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
  [observee removeSetWithHelpers:[NSSet setWithObject:BOXI(1)]];
  [observee addSetWithHelpersObject:BOXI(1)];
  [observee removeSetWithHelpersObject:BOXI(1)];
  [observee intersectSetWithHelpers:[NSSet setWithObject:BOXI(2)]];
  [observee setSetWithHelpers:[NSSet setWithObject:BOXI(3)]];
}

static void
setMut_kvcMediatedMutation(Observee *observee)
{
  // Proxy mutable set should dispatch one notification per change
  // The proxy set is a NSKeyValueIvarMutableSet
  NSMutableSet *proxySet =
    [observee mutableSetValueForKey:@"kvcMediatedSet"];
  [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
  [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
  [proxySet addObject:BOXI(1)];
  [proxySet removeObject:BOXI(1)];
  [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
  [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
}

static void
setMut_manualMutation(Observee *observee)
{
  // Manually should dispatch one notification per change
  [observee manualUnionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
  [observee manualMinusSet:[NSSet setWithObject:BOXI(1)]];
  [observee manualSetAddObject:BOXI(1)];
  [observee manualSetRemoveObject:BOXI(1)];
  [observee manualIntersectSet:[NSSet setWithObject:BOXI(2)]];
  [observee manualSetSet:[NSSet setWithObject:BOXI(3)]];
}

static void
setMut_proxyMutation(Observee *observee)
{
  // Proxy mutable set should dispatch one notification per change
  // The proxy set is a NSKeyValueIvarMutableSet
  NSMutableSet *proxySet =
    [observee mutableSetValueForKey:@"proxySet"];
  [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
  [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
  [proxySet addObject:BOXI(1)];
  [proxySet removeObject:BOXI(1)];
  [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
  [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
}

static void
setMut_proxyRoMutation(Observee *observee)
{
  NSMutableSet *proxySet =
    [observee mutableSetValueForKey:@"proxyRoSet"];
  [proxySet unionSet:[NSSet setWithObjects:BOXI(1), BOXI(2), BOXI(3), nil]];
  [proxySet minusSet:[NSSet setWithObject:BOXI(1)]];
  [proxySet addObject:BOXI(1)];
  [proxySet removeObject:BOXI(1)];
  [proxySet intersectSet:[NSSet setWithObject:BOXI(2)]];
  [proxySet setSet:[NSSet setWithObject:BOXI(3)]];
}

static void
NSSetMutationMethods()
{
  START_SET("NSSetMutationMethods");

  setSetChanged = NO;

  Observee   *observee = [Observee new];
  TestFacade *facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"setWithHelpers"
             withOptions:NSKeyValueObservingOptionNew
                         | NSKeyValueObservingOptionOld
            performingFn:setMut_helpersMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      setMut_unionCallback, setMut_minusCallback, setMut_addCallback,
      setMut_removeCallback, setMut_intersectCallback, setMut_setCallback,
      setMut_illegalChangeNotification}
                       count:7];
  PASS([facade hits] == 6, "All six notifications were sent (setWithHelpers)");

  setSetChanged = YES;

  [observee release];
  [facade release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"kvcMediatedSet"
             withOptions:NSKeyValueObservingOptionNew
                         | NSKeyValueObservingOptionOld
            performingFn:setMut_kvcMediatedMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      setMut_unionCallback, setMut_minusCallback, setMut_addCallback,
      setMut_removeCallback, setMut_intersectCallback, setMut_setCallback,
      setMut_illegalChangeNotification}
                       count:7];
  PASS([facade hits] == 6, "All six notifications were sent (kvcMediatedSet)");

  [observee release];
  [facade release];

  observee = [Observee new];
  facade = [TestFacade newWithObservee:observee];

  [facade observeKeyPath:@"manualNotificationSet"
             withOptions:NSKeyValueObservingOptionNew
                         | NSKeyValueObservingOptionOld
            performingFn:setMut_manualMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      setMut_unionCallback, setMut_minusCallback, setMut_addCallback,
      setMut_removeCallback, setMut_intersectCallback, setMut_setCallback,
      setMut_illegalChangeNotification}
                       count:7];
  PASS([facade hits] == 6,
       "All six notifications were sent (manualNotificationSet)");

  /* Indirect proxy (add<key>Object, etc.) to test
   * NSKeyValueFastMutableSet */
  [facade observeKeyPath:@"proxySet"
             withOptions:NSKeyValueObservingOptionNew
                         | NSKeyValueObservingOptionOld
            performingFn:setMut_proxyMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      setMut_unionCallback, setMut_minusCallback, setMut_addCallback,
      setMut_removeCallback, setMut_intersectCallback, setMut_setCallback,
      setMut_illegalChangeNotification}
                       count:7];
  PASS([facade hits] == 6, "All six notifications were sent (proxySet)");

  /* Indirect slow proxy via NSInvocation to test NSKeyValueSlowMutableSet */
  /* Indirect proxy (add<key>Object, etc.) to test
   * NSKeyValueFastMutableSet */
  [facade observeKeyPath:@"proxyRoSet"
             withOptions:NSKeyValueObservingOptionNew
                         | NSKeyValueObservingOptionOld
            performingFn:setMut_proxyRoMutation
    andExpectChangeCallbacks:(ChangeCallback[]){
      setMut_unionCallback, setMut_minusCallback, setMut_addCallback,
      setMut_removeCallback, setMut_intersectCallback, setMut_setCallback,
      setMut_illegalChangeNotification}
                       count:7];
  PASS([facade hits] == 6, "All six notifications were sent (proxySet)");

  [observee release];
  [facade release];

  END_SET("NSSetMutationMethods");
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  ToMany_NoNotificationOnBareArray();
  ToMany_NotifyingArray();
  ToMany_KVCMediatedArrayWithHelpers_AggregateFunction();

  ToMany_ToOne_ShouldDowngradeForOrderedObservation();
  ObserverInformationShouldNotLeak();

  // NSArrayShouldNotBeObservable();
  NSArrayShouldThrowWhenTryingToObserveIndexesOutOfRange();
  NSArrayObserveElements();

  NSSetShouldNotBeObservable();
  NSSetMutationMethods();

  DESTROY(pool);

  return 0;
}
