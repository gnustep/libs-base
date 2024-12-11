#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface Foo : NSObject
@end

@implementation Foo
@end

@interface Observer : NSObject
@end

@implementation Observer
@end

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  RELEASE(pool);
  NSLog(@".... legacy tests ...");
  return 0;
}

