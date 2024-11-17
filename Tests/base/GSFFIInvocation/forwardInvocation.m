#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

@interface GSFakeNSString : NSObject
{
  NSString* _originalItem;
}

- (id) initWithItem: (NSString*)item;
- (NSString*) originalItem;
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

- (void)forwardInvocation:(NSInvocation *)invocation
{
  SEL selector = [invocation selector];

  // Forward any invocation to the original item if it supports it...
  if ([_originalItem respondsToSelector:selector])
    [invocation invokeWithTarget:_originalItem];
  else
    [super forwardInvocation:invocation];
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
@end

int main(int argc,char **argv)
{
  START_SET("GSFFIInvocation")

  NSString *string = @"Hello, World!";

  GSFakeNSString *fakeString = [[GSFakeNSString alloc] initWithItem:string];

  NSString *upperCaseString = [string uppercaseString];
  NSString *fakeUpperCaseString = [fakeString uppercaseString];

  NSLog(@"Upper case string: %@, fake upper case string: %@", upperCaseString, fakeUpperCaseString);
  PASS_EQUAL(upperCaseString, fakeUpperCaseString, "uppercaseString selector is forwarded from the fake string to the actual NSString object");

  END_SET("GSFFIInvocation")
  return 0;
}
