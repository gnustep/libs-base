#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#if defined(__OBJC2__)

@class Bar;

@interface                     Foo : NSObject
@property (assign) Bar        *globalBar;
@property (assign) NSInteger   a;
@property (readonly) NSInteger b;
@end

@interface                         Bar : NSObject
@property (assign) NSInteger       x;
@property (strong, nonatomic) Foo *firstFoo;
@property (strong, nonatomic) Foo *secondFoo;
@end

@implementation Foo

+ (NSSet<NSString *> *)keyPathsForValuesAffectingB
{
  return [NSSet setWithArray:@[ @"a", @"globalBar.x" ]];
}

- (NSInteger)b
{
  return self.a + self.globalBar.x;
}

@end

@implementation Bar

- (id)init
{
  self = [super init];
  if (self)
    {
      self.firstFoo = [Foo new];
      self.firstFoo.globalBar = self;
      self.secondFoo = [Foo new];
      self.secondFoo.globalBar = self;
    }
  return self;
}
@end

@interface                   Observer : NSObject
@property (assign) Foo      *object;
@property (assign) NSInteger expectedOldValue;
@property (assign) NSInteger expectedNewValue;
@property (assign) NSInteger receivedCalls;
@end

@implementation Observer

- (id)init
{
  self = [super init];
  if (self)
    {
      self.receivedCalls = 0;
    }
  return self;
}

static char observerContext;

- (void)startObserving:(Foo *)target
{
  self.object = target;
  [target
    addObserver:self
     forKeyPath:@"b"
        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
        context:&observerContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context
{
  PASS(context == &observerContext, "context is correct");
  PASS(object == self.object, "object is correct");

  id newValue = change[NSKeyValueChangeNewKey];
  id oldValue = change[NSKeyValueChangeOldKey];

  PASS([oldValue integerValue] == self.expectedOldValue,
       "new value in change dict");
  PASS([newValue integerValue] == self.expectedNewValue,
       "old value in change dict");
  self.receivedCalls++;
}

@end

int
main(int argc, char *argv[])
{
  [NSAutoreleasePool new];

  Bar *bar = [Bar new];
  bar.x = 0;
  bar.firstFoo.a = 1;
  bar.secondFoo.a = 2;

  Observer *obs1 = [Observer new];
  Observer *obs2 = [Observer new];
  [obs1 startObserving:bar.firstFoo];
  [obs2 startObserving:bar.secondFoo];

  obs1.expectedOldValue = 1;
  obs1.expectedNewValue = 2;
  obs2.expectedOldValue = 2;
  obs2.expectedNewValue = 3;
  bar.x = 1;
  PASS(obs1.receivedCalls == 1, "num observe calls");
  PASS(obs2.receivedCalls == 1, "num observe calls");

  obs1.expectedOldValue = 2;
  obs1.expectedNewValue = 2;
  obs2.expectedOldValue = 3;
  obs2.expectedNewValue = 3;
  bar.x = 1;
  PASS(obs1.receivedCalls == 2, "num observe calls");
  PASS(obs2.receivedCalls == 2, "num observe calls");

  obs1.expectedOldValue = 2;
  obs1.expectedNewValue = 3;
  bar.firstFoo.a = 2;
  PASS(obs1.receivedCalls == 3, "num observe calls");
  PASS(obs2.receivedCalls == 2, "num observe calls");
}

#else
int
main(int argc, char *argv[])
{
  return 0;
}

#endif