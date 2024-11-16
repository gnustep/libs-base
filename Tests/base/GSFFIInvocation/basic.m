#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

@protocol NSMenuItem <NSObject>
- (NSString*) keyEquivalent;
- (void) setKeyEquivalent: (NSString*)aKeyEquivalent;
@end

@interface NSMenuItem : NSObject <NSMenuItem>
{
  NSString *_keyEquivalent;
}
@end

@implementation NSMenuItem
- (void) setKeyEquivalent: (NSString*)aKeyEquivalent
{
  ASSIGNCOPY(_keyEquivalent,  aKeyEquivalent);
}

- (NSString*) keyEquivalent
{
  return _keyEquivalent;
}
@end

@interface GSFakeNSMenuItem : NSObject
{
  NSMenuItem* _originalItem;
}

- (id) initWithItem: (NSMenuItem*)item;
- (NSMenuItem*) originalItem;
- (id) target;
- (SEL)action;
- (void) action: (id)sender;
@end

@implementation GSFakeNSMenuItem
- (id) initWithItem: (NSMenuItem*)item
{
  self = [super init];
  if (self)
  {
    _originalItem = item;
  }
  return self;
}

- (NSMenuItem*) originalItem
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

  NSMenuItem *item = [NSMenuItem alloc];
  [item setKeyEquivalent:@"Hello, World!"];

  GSFakeNSMenuItem *fakeItem = [[GSFakeNSMenuItem alloc] initWithItem:item];

  NSString *itemKeyEquivalent = [item keyEquivalent];
  NSString *fakeItemKeyEquivalent = [fakeItem keyEquivalent];

  NSLog(@"Item key equivalent: %@, fake item key equivalent: %@", itemKeyEquivalent, fakeItemKeyEquivalent);

  END_SET("GSFFIInvocation")
  return 0;
}
