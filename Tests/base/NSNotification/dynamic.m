#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#import "ObjectTesting.h"

@interface Toggle : NSObject @end
@implementation Toggle
- (void)foo: (NSNotification*)n
{
	assert(0);
}
- (void)bar: (NSNotification*)n {}
@end

int main(void)
{
	[NSAutoreleasePool new];
	NSNotificationCenter *nc = [NSNotificationCenter new];
	id t = [Toggle new];
	[nc addObserver: t selector: @selector(foo:) name: nil object: nil];
	class_replaceMethod([Toggle class],
	                    @selector(foo:),
	                    class_getMethodImplementation([Toggle class],
	                                                  @selector(bar:)),
	                    "v@:@");
	[nc postNotificationName: @"foo" object: t];
	return 0;
}
