#import <Foundation/NSString.h>
#import "ObjectTesting.h"

int main(void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *regex = @"abcd*";
  NSString *source = @"abcdddddd e f g";
  NSRange r = [source rangeOfString: regex options: NSRegularExpressionSearch];
  PASS(r.length == 9, "Correct length for regex, expected 9 got %d", (int)r.length);
  regex = @"aBcD*";
  r = [source rangeOfString: regex options: (NSRegularExpressionSearch | NSCaseInsensitiveSearch)];
  PASS(r.length == 9, "Correct length for regex, expected 9 got %d", (int)r.length);

  [pool release];
  return 0;
}
