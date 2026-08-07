#import <Foundation/Foundation.h>
#import <Foundation/NSScriptCoercionHandler.h>

@interface TestCoercer : NSObject
@end

@implementation TestCoercer

- (NSString *) numberToString: (NSNumber *)number
{
  NSLog(@"numberToString called with: %@", number);
  return [number stringValue];
}

@end

int main()
{
  NSAutoreleasePool *pool;
  NSScriptCoercionHandler *handler;
  TestCoercer *coercer;
  NSNumber *num;
  id result;

  pool = [[NSAutoreleasePool alloc] init];

  handler = [NSScriptCoercionHandler sharedCoercionHandler];
  NSLog(@"Handler: %@", handler);

  coercer = [[TestCoercer alloc] init];
  NSLog(@"Coercer: %@", coercer);

  num = [NSNumber numberWithInt: 42];
  NSLog(@"Number: %@, class: %@", num, [num class]);

  NSLog(@"Registering coercer...");
  [handler registerCoercer: coercer
                  selector: @selector(numberToString:)
        toConvertFromClass: [NSNumber class]
                   toClass: [NSString class]];

  NSLog(@"Attempting coercion...");
  result = [handler coerceValue: num toClass: [NSString class]];
  NSLog(@"Result: %@, class: %@", result, [result class]);

  [coercer release];
  [pool release];
  return 0;
}
