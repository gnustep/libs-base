#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSStream.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSInputStream *t1;
  NSOutputStream *t2;
  NSHost *host = [NSHost hostWithName:@"localhost"];

  [NSStream getStreamsToHost:host port:80 inputStream:&t1 outputStream:&t2];

  test_NSObject(@"NSStream", [NSArray arrayWithObjects:t1, t2, nil]); 

  [arp release]; arp = nil;
  return 0;
}
