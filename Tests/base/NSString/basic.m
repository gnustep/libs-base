#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  unichar	u0 = 'a';
  unichar	u1 = 0xfe66;
  char          buf[32];
  NSString	*s;
  NSString *testObj = [NSString stringWithCString: "Hello\n"];

  test_alloc(@"NSString");
  test_NSObject(@"NSString",[NSArray arrayWithObject:testObj]);
  test_NSCoding([NSArray arrayWithObject:testObj]);
  test_keyed_NSCoding([NSArray arrayWithObject:testObj]);
  test_NSCopying(@"NSString", @"NSMutableString", 
                 [NSArray arrayWithObject:testObj], NO, NO);
  test_NSMutableCopying(@"NSString", @"NSMutableString",
  			[NSArray arrayWithObject:testObj]);

  /* Test non-ASCII strings.  */
  testObj = [@"\"\\U00C4\\U00DF\"" propertyList];
  test_NSMutableCopying(@"NSString", @"NSMutableString",
  			[NSArray arrayWithObject:testObj]);

  PASS([(s = [[NSString alloc] initWithCharacters: &u0 length: 1])
    isKindOfClass: [NSString class]]
    && ![s isKindOfClass: [NSMutableString class]],
    "initWithCharacters:length: creates mutable string for ascii");

  PASS([(s = [[NSString alloc] initWithCharacters: &u1 length: 1])
    isKindOfClass: [NSString class]]
    && ![s isKindOfClass: [NSMutableString class]],
    "initWithCharacters:length: creates mutable string for unicode");

  PASS_EXCEPTION([[NSString alloc] initWithString: nil];,
  		 NSInvalidArgumentException,
		 "NSString -initWithString: does not allow nil argument");

  PASS([@"he" getCString: buf maxLength: 2 encoding: NSASCIIStringEncoding]==NO,
    "buffer exact length fails");
  PASS([@"hell" getCString: buf maxLength: 5 encoding: NSASCIIStringEncoding],
    "buffer length+1 works");
  PASS(strcmp(buf, "hell") == 0, "getCString:maxLength:encoding");

  [arp release]; arp = nil;
  return 0;
}
