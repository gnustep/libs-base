#import <Foundation/Foundation.h>

#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSData        *data;
  NSData        *ref;

  PASS_EXCEPTION([[NSData alloc] initWithBase64EncodedString: nil options: 0],
    NSInvalidArgumentException, "nil argument causes exception");

  data = [[NSData alloc] initWithBase64EncodedString: @"" options: 0];
  ref = [NSData data];
  PASS_EQUAL(data, ref, "base64 decoding vector 1")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zg==" options: 0];
  ref = [NSData dataWithBytes: "f" length: 1];
  PASS_EQUAL(data, ref, "base64 decoding vector 2")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zm8=" options: 0];
  ref = [NSData dataWithBytes: "fo" length: 2];
  PASS_EQUAL(data, ref, "base64 decoding vector 3")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zm9v" options: 0];
  ref = [NSData dataWithBytes: "foo" length: 3];
  PASS_EQUAL(data, ref, "base64 decoding vector 4")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zm9vYg==" options: 0];
  ref = [NSData dataWithBytes: "foob" length: 4];
  PASS_EQUAL(data, ref, "base64 decoding vector 5")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zm9vYmE=" options: 0];
  ref = [NSData dataWithBytes: "fooba" length: 5];
  PASS_EQUAL(data, ref, "base64 decoding vector 6")
  [data release];

  data = [[NSData alloc] initWithBase64EncodedString: @"Zm9vYmFy" options: 0];
  ref = [NSData dataWithBytes: "foobar" length: 6];
  PASS_EQUAL(data, ref, "base64 decoding vector 7")
  [data release];

  [arp release]; arp = nil;
  return 0;
}
