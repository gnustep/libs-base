
#include <gnustep/base/Connection.h>
#include "first-server.h"
#include <Foundation/NSString.h>
#include <gnustep/base/RunLoop.h>
#include <sys/file.h>


@interface	MyIo: NSObject <FdListening,FdSpeaking>
{
   id	runLoop;
   id	mode;
   char	c;
}
- initForRunLoop: r andMode: m;
- (void) readyForReadingOnFileDescriptor: (int)fd;
- (void) readyForWritingOnFileDescriptor: (int)fd;
@end

@implementation	MyIo
- initForRunLoop: r andMode: m
{
    runLoop = r;
    mode = m;
    return self;
}
- (void) readyForReadingOnFileDescriptor: (int)fd
{
    if (read(fd, &c, 1) == 1) {
        [runLoop addWriteDescriptor: 1 object: self forMode: mode];
        [runLoop removeReadDescriptor: fd forMode: mode];
    }
}
- (void) readyForWritingOnFileDescriptor: (int)fd
{
    if (write(fd, &c, 1) == 1) {
        [runLoop addReadDescriptor: 0 object: self forMode: mode];
	[runLoop removeWriteDescriptor: fd forMode: mode];
    }
}
@end

@implementation FirstServer
- sayHiTo: (char *)name
{
  printf("Hello, %s.\n", name);
  return self;
}
@end

int main()
{
  id s, c;
  MyIo*		myIo;
  NSString*	m;
  id r;

  r = [RunLoop currentInstance];
  m = [RunLoop currentMode];
  myIo = [[MyIo alloc] initForRunLoop: r andMode: m];

  [r addReadDescriptor: 0 object: myIo forMode: m];

  /* Create our server object */
  s = [[FirstServer alloc] init];

  /* Register a connection that provides the server object to the network */
  printf("Registering a connection for the server using name `firstserver'\n");
  c = [Connection newRegisteringAtName:@"firstserver"
		  withRootObject:s];
  
  /* Run the connection */
  printf("Running the connection... (until you interrupt with control-C)\n");
  [c runConnection];			/* This runs until interrupt. */

  exit(0);
}
