#if	defined(GNUSTEP_BASE_LIBRARY)
/**
 * This test tests IPv6 using NSStream
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  NSInputStream *inputStream;
  NSOutputStream *outputStream;
  
  NSString *ipv6ServerAddress = @"::1"; // Replace with your actual IPv6 server address
  uint16_t port = 12345; // Replace with the actual port number
  
  // Resolve the IPv6 address using NSHost
  NSHost *host = [NSHost hostWithName: ipv6ServerAddress];
  NSArray *addresses = [host addresses];

  PASS([addresses count] > 0, "Resolve IPv6 address");
  
  NSString *ipv6Address = [addresses objectAtIndex: 0];
  
  [NSStream getStreamsToHost: [NSHost hostWithName: ipv6Address]
			port: port
		 inputStream: &inputStream
		outputStream: &outputStream];
  
  [inputStream open];
  [outputStream open];
  
  // Perform your tests here to validate the IPv6 stream
  // You can write and read data from the stream and assert the expected results
  // For example:
  
  NSString *testData = @"Test Data";
  NSData *dataToWrite = [testData dataUsingEncoding:NSUTF8StringEncoding];
  NSInteger bytesWritten = [outputStream write: [dataToWrite bytes] maxLength: [dataToWrite length]];
  
  PASS(bytesWritten > 0, "Write data to the stream");
  
  uint8_t buffer[1024];
  NSInteger bytesRead = [inputStream read:buffer maxLength:1024];
  NSString *receivedString = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
  
  PASS(bytesRead > 0, "Read data from the stream");
  PASS([receivedString isEqualToString: testData], "Received data matches the expected data");
  
  [inputStream close];
  [outputStream close];
  
  [arp release];
  arp = nil;

  return 0;
}
#else
int main()
{
  return 0;
}
#endif
