#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

@interface GSFakeNSString : NSObject
{
  NSString* _originalItem;
}

- (id) initWithItem: (NSString*)item;
- (NSString*) originalItem;
- (id) target;
- (SEL)action;
- (void) action: (id)sender;
@end

@implementation GSFakeNSString
- (id) initWithItem: (NSString*)item
{
  self = [super init];
  if (self)
  {
    _originalItem = item;
  }
  return self;
}

- (NSString*) originalItem
{
  return _originalItem;
}

- (id)target
{
  return self;
}

- (SEL)action
{
  return @selector(action:);
}

- (id)forwardingTargetForSelector:(SEL)selector
{
  if ([_originalItem respondsToSelector:selector])
    return _originalItem;
  return nil;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
  SEL selector = [invocation selector];

  // Forward any invocation to the original item if it supports it...
  if ([_originalItem respondsToSelector:selector])
    [invocation invokeWithTarget:_originalItem];
}

-(NSMethodSignature*)methodSignatureForSelector:(SEL)selector
{
	NSMethodSignature *signature = [[_originalItem class] instanceMethodSignatureForSelector:selector];
	if(signature == nil)
	{
		signature = [NSMethodSignature signatureWithObjCTypes:"@^v^c"];
	}
	return(signature);
}

- (void)doesNotRecognizeSelector:(SEL)selector
{
  NSLog(@"%s:selector not recognized: %@", __PRETTY_FUNCTION__, NSStringFromSelector(selector));
}
@end

int main(int argc,char **argv)
{
  START_SET("GSFFIInvocation")

  NSString *string = @"Hello, World!";

  GSFakeNSString *fakeString = [[GSFakeNSString alloc] initWithItem:string];

  NSString *upperCaseString = [string uppercaseString];
  NSString *fakeUpperCaseString = [fakeString uppercaseString];

  PASS_EQUAL(upperCaseString, fakeUpperCaseString, "uppercaseString selector is forwarded from the fake string to the actual NSString object");
  NSLog(@"Upper case string: %@, fake upper case string: %@", upperCaseString, fakeUpperCaseString);

  END_SET("GSFFIInvocation")
  return 0;
}
