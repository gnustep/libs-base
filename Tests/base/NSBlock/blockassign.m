#import "Testing.h"
#import <Foundation/Foundation.h>

int main (int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#if __has_feature(blocks)
	BOOL (^hello)(void) = ^() { return YES; };
	PASS(hello(), "Calling a block");
	BOOL (^helloCopy)(void) = Block_copy(hello);
	Block_release(hello);
	PASS(helloCopy(), "Calling a copy of a block");
	NSArray *blockArr = [NSArray arrayWithObject:helloCopy];
	PASS([blockArr count] == 1, "Block used as object in an array");
	void (^helloArr)(void) = [blockArr objectAtIndex:0];
	PASS(helloCopy(), "Block successfully retrived from array");
	Block_release(helloCopy);
#elif defined(__clang__)
	unsupported("Your compiler supports blocks, but this support was disabled for some reason.");
#else
	unsupported("Your compiler does not support blocks.");
#endif
	[pool drain];

	return 0;
}

