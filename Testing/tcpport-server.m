#include <stdio.h>
#include <base/TcpPort.h>
#include <base/Invocation.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>

@interface	Dummy: NSObject
+ (id) announce_new_connection: notification;
+ (id) announce_broken_connection: notification;
@end

@implementation	Dummy

+ announce_new_connection: notification
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  NSLog (@"{%@}\n\tconnected to\n\t{%@}\n",
	  [out_port description], [in_port description]);
  NSLog (@"Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}

+ announce_broken_connection: notification
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  NSLog (@"{%@}\n\tdisconnected from\n\t{%@}\n",
	  [out_port description], [in_port description]);
  NSLog (@"Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}
@end

static id port = nil;

id handle_incoming_packet (TcpInPacket *packet)
{
  static unsigned message_count = 0;
  id reply_port;

  message_count++;
  fprintf (stdout, "received >");
  fwrite ([packet streamBuffer] + [packet streamBufferPrefix],
	  [packet streamEofPosition], 1, stdout);
  fprintf (stdout, "<\n");
  reply_port = [packet replyOutPort];
  [packet release];

  packet = [[TcpOutPacket alloc] initForSendingWithCapacity: 100
				 replyInPort: port];
  [packet writeFormat: @"Your's was my message number %d", 
	  message_count];
  [reply_port sendPacket: packet timeout:10.0];
  [packet release];
  return nil;
}

int main (int argc, char *argv[])
{
  if (argc > 1)
    port = [TcpInPort newForReceivingFromRegisteredName:
	     [NSString stringWithCString: argv[1]]];
  else
    port = [TcpInPort newForReceivingFromRegisteredName: @"tcpport-test"];

  [[NSNotificationCenter defaultCenter]
    addObserver: [Dummy class]
       selector: @selector(announce_broken_connection:)
	   name: InPortClientBecameInvalidNotification
	 object: port];
  [[NSNotificationCenter defaultCenter]
    addObserver: [Dummy class]
       selector: @selector(announce_new_connection:)
	   name: InPortAcceptedClientNotification
	 object: port];

  printf ("Waiting for connections.\n");

#if 1
  [port setReceivedPacketInvocation:
	  [[[ObjectFunctionInvocation alloc]
	     initWithObjectFunction: handle_incoming_packet]
	    autorelease]];
  [[NSRunLoop currentRunLoop] addPort: port
			     forMode: NSDefaultRunLoopMode];
  [NSRunLoop run];
#else
  {
    id packet;
    unsigned message_count = 0;
    id reply_port;

    while ((packet = [port receivePacketWithTimeout: -1]))
      {
	message_count++;
	fprintf (stdout, "received >");
	fwrite ([packet streamBuffer] + [packet streamBufferPrefix],
		[packet streamEofPosition], 1, stdout);
	fprintf (stdout, "<\n");
	reply_port = [packet replyPort];
	[packet release];

	packet = [[TcpPacket alloc] initForSendingWithCapacity: 100
				    replyPort: port];
	[packet writeFormat: @"Your's was my message number %d", 
		message_count];
	[reply_port sendPacket: packet timeout: 20.0];
	[packet release];
      }
  }
#endif
  fprintf (stdout, "Timed out.  Exiting.\n");

  exit (0);
}
