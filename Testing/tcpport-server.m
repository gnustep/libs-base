#include <stdio.h>
#include <objects/TcpPort.h>
#include <objects/Notification.h>
#include <objects/Invocation.h>
#include <objects/RunLoop.h>

id announce_new_connection (id notification)
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  printf ("{%@}\n\tconnected to\n\t{%@}\n",
	  [out_port description], [in_port description]);
  printf ("Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}

id announce_broken_connection (id notification)
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  printf ("{%@}\n\tdisconnected from\n\t{%@}\n",
	  [out_port description], [in_port description]);
  printf ("Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}

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
  [reply_port sendPacket: packet];
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

  [NotificationDispatcher
    addInvocation: [[ObjectFunctionInvocation alloc] 
		     initWithObjectFunction: announce_broken_connection]
    name: InPortClientBecameInvalidNotification
    object: port];
  [NotificationDispatcher
    addInvocation: [[ObjectFunctionInvocation alloc] 
		     initWithObjectFunction: announce_new_connection]
    name: InPortAcceptedClientNotification
    object: port];

  printf ("Waiting for connections.\n");

#if 1
  [port setReceivedPacketInvocation:
	  [[[ObjectFunctionInvocation alloc]
	     initWithObjectFunction: handle_incoming_packet]
	    autorelease]];
  [port addToRunLoop: [RunLoop currentInstance] forMode: nil];
  [[RunLoop currentInstance] run];
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
	[reply_port sendPacket: packet withTimeout: 20 * 1000];
	[packet release];
      }
  }
#endif
  fprintf (stdout, "Timed out.  Exiting.\n");

  exit (0);
}
