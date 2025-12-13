#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptCoercionHandler.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@interface TestCoercer : NSObject
@end

@implementation TestCoercer

- (NSString *) numberToString: (NSNumber *)number
{
  return [number stringValue];
}

- (NSNumber *) stringToNumber: (NSString *)string
{
  return [NSNumber numberWithInteger: [string integerValue]];
}

@end

int main()
{
  NSAutoreleasePool *pool;
  NSScriptCoercionHandler *handler;
  TestCoercer *coercer;
  NSNumber *num;
  NSString *str;
  id result;

  pool = [[NSAutoreleasePool alloc] init];

  START_SET("NSScriptCoercionHandler singleton");

  // Test shared instance
  handler = [NSScriptCoercionHandler sharedCoercionHandler];
  PASS(handler != nil, "sharedCoercionHandler returns instance");

  // Test singleton property
  PASS([NSScriptCoercionHandler sharedCoercionHandler] == handler,
       "sharedCoercionHandler returns same instance");

  END_SET("NSScriptCoercionHandler singleton");

  START_SET("NSScriptCoercionHandler coercion");

  coercer = [[TestCoercer alloc] init];

  // Test without registered coercer
  num = [NSNumber numberWithInt: 42];
  result = [handler coerceValue: num toClass: [NSString class]];
  PASS([result isKindOfClass: [NSNumber class]],
       "coerceValue without registered coercer returns original value");

  // Register coercer
  [handler registerCoercer: coercer
                  selector: @selector(numberToString:)
        toConvertFromClass: [NSNumber class]
                   toClass: [NSString class]];

  // Test with registered coercer
  result = [handler coerceValue: num toClass: [NSString class]];
  PASS([result isKindOfClass: [NSString class]],
       "coerceValue with registered coercer returns converted value");
  PASS([result isEqual: @"42"],
       "Coerced value is correct");

  END_SET("NSScriptCoercionHandler coercion");

  START_SET("NSScriptCoercionHandler bidirectional");

  // Register reverse coercer
  [handler registerCoercer: coercer
                  selector: @selector(stringToNumber:)
        toConvertFromClass: [NSString class]
                   toClass: [NSNumber class]];

  str = @"123";
  result = [handler coerceValue: str toClass: [NSNumber class]];
  PASS([result isKindOfClass: [NSNumber class]],
       "Reverse coercion works");
  PASS([result integerValue] == 123,
       "Reverse coerced value is correct");

  END_SET("NSScriptCoercionHandler bidirectional");

  START_SET("NSScriptCoercionHandler edge cases");

  // Test nil value
  result = [handler coerceValue: nil toClass: [NSString class]];
  PASS(result == nil, "coerceValue with nil returns nil");

  // Test already correct type
  str = @"test";
  result = [handler coerceValue: str toClass: [NSString class]];
  PASS(result == str, "coerceValue with matching type returns original");

  // Test invalid registration
  [handler registerCoercer: nil
                  selector: @selector(someMethod:)
        toConvertFromClass: [NSNumber class]
                   toClass: [NSString class]];
  PASS(YES, "registerCoercer with nil coercer doesn't crash");

  [handler registerCoercer: coercer
                  selector: NULL
        toConvertFromClass: [NSNumber class]
                   toClass: [NSString class]];
  PASS(YES, "registerCoercer with NULL selector doesn't crash");

  [handler registerCoercer: coercer
                  selector: @selector(someMethod:)
        toConvertFromClass: Nil
                   toClass: [NSString class]];
  PASS(YES, "registerCoercer with Nil fromClass doesn't crash");

  [handler registerCoercer: coercer
                  selector: @selector(someMethod:)
        toConvertFromClass: [NSNumber class]
                   toClass: Nil];
  PASS(YES, "registerCoercer with Nil toClass doesn't crash");

  END_SET("NSScriptCoercionHandler edge cases");

  START_SET("NSScriptCoercionHandler multiple coercers");

  // Register another coercer for different type pair
  [handler registerCoercer: coercer
                  selector: @selector(numberToString:)
        toConvertFromClass: [NSValue class]
                   toClass: [NSString class]];

  // Test that original coercion still works
  num = [NSNumber numberWithInt: 99];
  result = [handler coerceValue: num toClass: [NSString class]];
  PASS([result isEqual: @"99"],
       "Original coercion still works after registering another");

  END_SET("NSScriptCoercionHandler multiple coercers");

  [coercer release];
  [pool release];
  return 0;
}
