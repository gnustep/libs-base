#if	GNUSTEP
#include	<Foundation/Foundation.h>

@interface	TestClass : NSObject
{
  NSOutputStream *op;
  NSInputStream *ip;
  NSMutableData	*capture;
  unsigned	written;
  BOOL		readable;
  BOOL		writable;
}
- (int) runTest;
@end

@implementation	TestClass

- (void) dealloc
{
  RELEASE(capture);
  RELEASE(op);
  RELEASE(ip);
  [super dealloc];
}

- (id) init
{
  capture = [NSMutableData new];

  return self;
}

- (int) runTest
{
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  NSRunLoop		*rl = [NSRunLoop currentRunLoop];
  NSHost		*host = [NSHost hostWithName: @"localhost"];
  NSStream		*serverStream;
  NSString		*file;
  int			port = [[defs stringForKey: @"Port"] intValue];

  if (port == 0) port = 54321;

  file = [defs stringForKey: @"FileName"];
  if (file == nil) file = @"Capture.dat";

  serverStream = [GSServerStream serverStreamToAddr: [host address] port: port];
  if (serverStream == nil)
    {
      NSLog(@"Failed to create server stream");
      return 1;
    }
  [serverStream setDelegate: self];
  [serverStream scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
  [serverStream open];

  [rl runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30]];

  if ([capture writeToFile: file atomically: YES] == NO)
    {
      NSLog(@"Unable to write captured data to '%@'", file);
      return 1;
    }

  return 0;
}

- (void) stream: (NSStream *)theStream handleEvent: (NSStreamEvent)streamEvent
{
  NSRunLoop	*rl = [NSRunLoop currentRunLoop];
  NSString	*resp = @"HTTP/1.0 204 Empty success response\r\n\r\n";

// NSLog(@"Event %p %d", theStream, streamEvent);

  switch (streamEvent) 
    {
      case NSStreamEventHasBytesAvailable: 
	{
	  if (ip == nil)
	    {
	      [(GSServerStream*)theStream acceptWithInputStream: &ip
						   outputStream: &op];
	      if (ip)   // it is ok to accept nothing
		{
		  RETAIN(ip);
		  RETAIN(op);
		  [ip scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
		  [op scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
		  [ip setDelegate: self];
		  [op setDelegate: self];
		  [ip open];
		  [op open];
		  [theStream close];
		  [theStream removeFromRunLoop: rl
				       forMode: NSDefaultRunLoopMode];
		}
	    }
	  if (theStream == ip)
	    {
	      readable = YES;
	      while (readable == YES)
		{
		  unsigned char	buffer[BUFSIZ];
		  int		readSize;

		  readSize = [ip read: buffer maxLength: sizeof(buffer)];
		  if (readSize <= 0)
		    {
		      readable = NO;
		    }
		  else
		    {
		      [capture appendBytes: buffer length: readSize];
		    }
		}
	    }
	  break;
	}
      case NSStreamEventHasSpaceAvailable: 
	{
	  NSData	*data;

	  NSAssert(theStream == op, @"Wrong stream for writing");
	  writable = YES;
	  data = [resp dataUsingEncoding: NSASCIIStringEncoding];
	  while (writable == YES && written < [data length])
	    {
	      int	result = [op write: [data bytes] + written
			   maxLength: [data length] - written];

	      if (result <= 0)
		{
		  writable = NO;
		}
	      else
		{
		  written += result;
		}
	    }
	  if (written == [data length])
	    {
	      [op close];
	      [op removeFromRunLoop: rl forMode: NSDefaultRunLoopMode];
	    }
	  break;
	}
      case NSStreamEventEndEncountered: 
	{
	  [theStream close];
	  [theStream removeFromRunLoop: rl forMode: NSDefaultRunLoopMode];
	  NSLog(@"Server close %p", theStream);
	  break;
	}

      case NSStreamEventErrorOccurred: 
	{
	  int	code = [[theStream streamError] code];

	  [theStream close];
	  [theStream removeFromRunLoop: rl forMode: NSDefaultRunLoopMode];
	  NSAssert1(1, @"Error! code is %d", code);
	  break;
	}  

      default: 
	break;
    }
} 

@end

int
main(int argc, char **argv)
{
  int	result;
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  result = [[[[TestClass alloc] init] autorelease] runTest];

  RELEASE(arp);
  return result;
}

#else

int main()
{
  return 0;
}

#endif
