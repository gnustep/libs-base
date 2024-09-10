#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#if defined(__OBJC2__)

@interface                              Foo : NSObject
@property (assign) BOOL                 a;
@property (assign) NSInteger            b;
@property (nonatomic, strong) NSString *c;
@property (nonatomic, strong) NSArray  *d;
@end

@implementation Foo
@end

@interface                   Observer : NSObject
@property (assign) Foo      *object;
@property (assign) NSString *expectedKeyPath;
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
  [target addObserver:self forKeyPath:@"a" options:0 context:&observerContext];
  [target addObserver:self forKeyPath:@"b" options:0 context:&observerContext];
  [target addObserver:self forKeyPath:@"c" options:0 context:&observerContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context
{
  PASS(context == &observerContext, "context");
  PASS(object == self.object, "object");
  PASS([keyPath isEqualToString:self.expectedKeyPath], "key path");
  self.receivedCalls++;
}

@end

int
main(int argc, char *argv[])
{
  [NSAutoreleasePool new];

  Foo      *foo = [Foo new];
  Observer *obs = [Observer new];
  [obs startObserving:foo];

  obs.expectedKeyPath = @"a";
  foo.a = YES;
  PASS(obs.receivedCalls == 1, "received calls")

  obs.expectedKeyPath = @"b";
  foo.b = 1;
  PASS(obs.receivedCalls == 2, "received calls")

  obs.expectedKeyPath = @"c";
  foo.c = @"henlo";
  PASS(obs.receivedCalls == 3, "received calls")
}

#else
int
main(int argc, const char *argv[])
{
  return 0;
}

#endif