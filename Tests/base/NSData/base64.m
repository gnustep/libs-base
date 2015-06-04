#import <Foundation/Foundation.h>

#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSData        *data;
  NSData        *ref;

/*
  data = [[NSData alloc] initWithBase64EncodedString: @"" options: 0];
  ref = [NSData data];
  PASS_EQUAL(data, ref, "base64 decoding vector 1")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zg" options: 0];
  ref = [NSData dataWithBytes: "f" length: 1];
  PASS_EQUAL(data, ref, "base64 decoding vector 2")
  [data release];

  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zg=="],
    @"f", "base64 decoding vector 2")
  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zm8="],
    @"fo", "base64 decoding vector 3")
  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zm9v"],
    @"foo", "base64 decoding vector 4")
  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zm9vYg=="],
    @"foob", "base64 decoding vector 5")
  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zm9vYmE="],
    @"fooba", "base64 decoding vector 6")
  PASS_EQUAL([GSMimeDocument decodeBase64String: @"Zm9vYmFy"],
    @"foobar", "base64 decoding vector 7")
*/

  [arp release]; arp = nil;
  return 0;
}
