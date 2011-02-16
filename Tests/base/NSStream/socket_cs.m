#if	defined(GNUSTEP_BASE_LIBRARY)
/**
 * This test tests client and server socket
 */
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSStream.h>

static GSServerStream *serverStream; 
static NSOutputStream *serverOutput = nil;
static NSOutputStream *clientOutput = nil;
static NSInputStream *serverInput = nil;
static NSInputStream *clientInput = nil;
static NSData *goldData;
static NSMutableData *testData;

@interface ClientListener : NSObject
{
  uint8_t buffer[4096];
  int writePointer;
}
@end

@implementation ClientListener

- (void)stream: (NSStream *)theStream handleEvent: (NSStreamEvent)streamEvent
{
NSLog(@"Client %p %d", theStream, streamEvent);
  switch (streamEvent) 
    {
    case NSStreamEventOpenCompleted: 
      {
        if (theStream==clientOutput)
          writePointer = 0;
        break;
      }
    case NSStreamEventHasSpaceAvailable: 
      {
        NSAssert(theStream==clientOutput, @"Wrong stream for writing");
        if (writePointer<[goldData length])
          {
            int writeReturn = [clientOutput write: [goldData bytes]+writePointer 
	      maxLength: [goldData length]-writePointer];
	    NSLog(@"Client %p wrote %d", clientOutput, writeReturn);
            if (writeReturn < 0)
              NSLog(@"Error ... %@", [clientOutput streamError]);
            writePointer += writeReturn;
          }          
        else
	  {
	    writePointer = 0;
            [clientOutput close];          
	    [clientOutput removeFromRunLoop: [NSRunLoop currentRunLoop]
				    forMode: NSDefaultRunLoopMode];
            NSLog(@"Client close %p", clientOutput);
	  }
        break;
      }
    case NSStreamEventHasBytesAvailable: 
      {
        int readSize;
        NSAssert(theStream==clientInput, @"Wrong stream for reading");
        readSize = [clientInput read: buffer maxLength: 4096];
        NSLog(@"Client %p read %d", clientInput, readSize);
        if (readSize < 0)
          {
            NSLog(@"Error ... %@", [clientInput streamError]);
            // it is possible that readSize<0 but not an Error.
	    // For example would block
          }
        else if (readSize == 0)
	  {
            [clientInput close];
	    [clientInput removeFromRunLoop: [NSRunLoop currentRunLoop]
				   forMode: NSDefaultRunLoopMode];
            NSLog(@"Client close %p", clientInput);
	  }
        else
	  {
            [testData appendBytes: buffer length: readSize];
	  }
        break;
      }
    case NSStreamEventEndEncountered: 
      {
        [theStream close];
	[theStream removeFromRunLoop: [NSRunLoop currentRunLoop]
			     forMode: NSDefaultRunLoopMode];
        NSLog(@"Client close %p", theStream);
        break;
      }
    case NSStreamEventErrorOccurred: 
      {
        NSLog(@"Error code is %d ... %@",
          [[theStream streamError] code], [theStream streamError]);
        break;
      }  
    default: 
      break;
    }
}

@end

@interface ServerListener : NSObject
{
  uint8_t buffer[4096];
  int readSize;
  int writeSize;
  BOOL readable;
  BOOL writable;
}
@end

@implementation ServerListener

- (void)stream: (NSStream *)theStream handleEvent: (NSStreamEvent)streamEvent
{
NSLog(@"Server %p %d", theStream, streamEvent);
  switch (streamEvent) 
    {
    case NSStreamEventHasBytesAvailable: 
      {
        if (theStream==serverStream)
          {
            NSAssert(serverInput==nil, @"accept twice");
            [serverStream acceptWithInputStream: &serverInput
				   outputStream: &serverOutput];
            if (serverInput)   // it is ok to accept nothing
              {
                NSRunLoop *rl = [NSRunLoop currentRunLoop];
                [serverInput scheduleInRunLoop: rl
				       forMode: NSDefaultRunLoopMode];
                [serverOutput scheduleInRunLoop: rl
					forMode: NSDefaultRunLoopMode];
		NSLog(@"Server input stream is %p", serverInput);
		NSLog(@"Server output stream is %p", serverOutput);
                [serverInput retain];
                [serverOutput retain];
                [serverInput setDelegate: self];
                [serverOutput setDelegate: self];
                [serverInput open];
                [serverOutput open];
                readSize = 0;
                writeSize = 0;
                [serverStream close];
		[serverStream removeFromRunLoop: [NSRunLoop currentRunLoop]
					forMode: NSDefaultRunLoopMode];
              }
          }
        if (theStream == serverInput)
          {
	    readable = YES;
	  }
        break;
      }
    case NSStreamEventHasSpaceAvailable: 
      {
        NSAssert(theStream==serverOutput, @"Wrong stream for writing");
	writable = YES;
        break;
      }
    case NSStreamEventEndEncountered: 
      {
        [theStream close];
	[theStream removeFromRunLoop: [NSRunLoop currentRunLoop]
			     forMode: NSDefaultRunLoopMode];
        NSLog(@"Server close %p", theStream);
	if (theStream == serverInput && writeSize == readSize)
	  {
	    [serverOutput close];
	    [serverOutput removeFromRunLoop: [NSRunLoop currentRunLoop]
				    forMode: NSDefaultRunLoopMode];
	    NSLog(@"Server output close %p", serverOutput);
	  }
        break;
      }
    case NSStreamEventErrorOccurred: 
      {
        NSLog(@"Error code is %d ... %@",
          [[theStream streamError] code], [theStream streamError]);
        break;
      }  
    default: 
      break;
    }

  while ((readable == YES && writeSize == readSize)
    || (writable == YES && writeSize < readSize))
    {
      if (readable == YES && writeSize == readSize)
	{
	  readSize = [serverInput read: buffer maxLength: 4096];
	  readable = NO;
	  NSLog(@"Server %p read %d", serverInput, readSize);
	  writeSize = 0;
	  if (readSize == 0)
	    {
	      [serverInput close];
	      [serverInput removeFromRunLoop: [NSRunLoop currentRunLoop]
				     forMode: NSDefaultRunLoopMode];
	      NSLog(@"Server input close %p", serverInput);
	      [serverOutput close];
	      [serverOutput removeFromRunLoop: [NSRunLoop currentRunLoop]
				      forMode: NSDefaultRunLoopMode];
	      NSLog(@"Server output close %p", serverOutput);
	    }
	  else if (readSize < 0)
	    {
              NSLog(@"Error ... %@", [clientInput streamError]);
	      readSize = 0;
	    }
	}
      if (writable == YES && writeSize < readSize)
	{
	  int writeReturn = [serverOutput write: buffer+writeSize 
					  maxLength: readSize-writeSize];
	  NSLog(@"Server %p wrote %d", serverOutput, writeReturn);
	  writable = NO;
	  if (writeReturn == 0)
	    {
	      [serverOutput close];
	      [serverOutput removeFromRunLoop: [NSRunLoop currentRunLoop]
				      forMode: NSDefaultRunLoopMode];
	      NSLog(@"Server close %p", serverOutput);
	      [serverInput close];
	      [serverInput removeFromRunLoop: [NSRunLoop currentRunLoop]
				     forMode: NSDefaultRunLoopMode];
	      NSLog(@"Server input close %p", serverInput);
	    }
	  else if (writeReturn > 0)
	    {
	      writeSize += writeReturn;
	    }
	  else if (writeReturn < 0)
	    {
	      NSLog(@"Error ... %@", [serverOutput streamError]);
	    }

	  /* If we have finished writing and there is no more data coming,
	   * we can close the output stream.
	   */
	  if (writeSize == readSize
	    && [serverInput streamStatus] == NSStreamStatusClosed)
	    {
	      [serverOutput close];
	      [serverOutput removeFromRunLoop: [NSRunLoop currentRunLoop]
				      forMode: NSDefaultRunLoopMode];
	      NSLog(@"Server output close %p", serverOutput);
	    }
	}
    }
} 

@end

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSRunLoop *rl = [NSRunLoop currentRunLoop];
  NSHost *host = [NSHost hostWithAddress: @"127.0.0.1"];
  ServerListener *sli;
  ClientListener *cli;
  NSString *path = @"socket_cs.m";
  NSString *socketPath = @"test-socket";

  [[NSFileManager defaultManager] removeFileAtPath: socketPath handler: nil];
  NSLog(@"sending and receiving on %@: %@", host, [host address]);
  goldData = [NSData dataWithContentsOfFile: path];
  testData = [NSMutableData dataWithCapacity: 4096];

  sli = [ServerListener new];
  cli = [ClientListener new];
  serverStream
    = [GSServerStream serverStreamToAddr: [host address] port: 54321];
  [serverStream setDelegate: sli];
  [serverStream scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [serverStream open];
  [NSStream getStreamsToHost: host
			port: 54321
		 inputStream: &clientInput
		outputStream: &clientOutput];
  NSLog(@"Client input stream is %p", clientInput);
  NSLog(@"Client output stream is %p", clientOutput);
  [clientInput setDelegate: cli];
  [clientOutput setDelegate: cli];
  [clientInput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientOutput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientInput open];
  [clientOutput open];

  [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30]];
  PASS([goldData isEqualToData: testData], "Local tcp");

  DESTROY(serverInput);
  DESTROY(serverOutput);
  clientInput = nil;
  clientOutput = nil;
  DESTROY(sli);
  DESTROY(cli);
  [testData setLength: 0];

  sli = [ServerListener new];
  cli = [ClientListener new];
  serverStream
    = [GSServerStream serverStreamToAddr: [host address] port: 54321];
  [serverStream setDelegate: sli];
  [serverStream open];
  [serverStream scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [NSStream getStreamsToHost: host
			port: 54321
		 inputStream: &clientInput
		outputStream: &clientOutput];
  NSLog(@"Client input stream is %p", clientInput);
  NSLog(@"Client output stream is %p", clientOutput);
  [clientInput setDelegate: cli];
  [clientOutput setDelegate: cli];
  [clientInput open];
  [clientOutput open];
  [clientInput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientOutput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];

  [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30]];
  PASS([goldData isEqualToData: testData], "Local tcp (blocking open)");

  DESTROY(serverInput);
  DESTROY(serverOutput);
  clientInput = nil;
  clientOutput = nil;
  DESTROY(sli);
  DESTROY(cli);
  [testData setLength: 0];

  sli = [ServerListener new];
  cli = [ClientListener new];
  serverStream = [GSServerStream serverStreamToAddr: socketPath];
  [serverStream setDelegate: sli];
  [serverStream scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [serverStream open];
  [NSStream getLocalStreamsToPath: socketPath
		      inputStream: &clientInput
		     outputStream: &clientOutput];
  NSLog(@"Client input stream is %p", clientInput);
  NSLog(@"Client output stream is %p", clientOutput);
  [clientInput setDelegate: cli];
  [clientOutput setDelegate: cli];
  [clientInput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientOutput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientInput open];
  [clientOutput open];

  [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30]];

  PASS([goldData isEqualToData: testData], "Local socket");

  DESTROY(serverInput);
  DESTROY(serverOutput);
  clientInput = nil;
  clientOutput = nil;
  DESTROY(sli);
  DESTROY(cli);
  [testData setLength: 0];
  [[NSFileManager defaultManager] removeFileAtPath: socketPath handler: nil];

  sli = [ServerListener new];
  cli = [ClientListener new];
  serverStream = [GSServerStream serverStreamToAddr: socketPath];
  [serverStream setDelegate: sli];
  [serverStream open];
  [serverStream scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [NSStream getLocalStreamsToPath: socketPath
		      inputStream: &clientInput
		     outputStream: &clientOutput];
  NSLog(@"Client input stream is %p", clientInput);
  NSLog(@"Client output stream is %p", clientOutput);
  [clientInput setDelegate: cli];
  [clientOutput setDelegate: cli];
  [clientInput open];
  [clientOutput open];
  [clientInput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [clientOutput scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];

  [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30]];

  PASS([goldData isEqualToData: testData], "Local socket (blocking open)");

  DESTROY(serverInput);
  DESTROY(serverOutput);
  clientInput = nil;
  clientOutput = nil;
  DESTROY(sli);
  DESTROY(cli);
  [testData setLength: 0];
  [[NSFileManager defaultManager] removeFileAtPath: socketPath handler: nil];

  [arp release];
  return 0;
}
#else
int main()
{
  return 0;
}
#endif
