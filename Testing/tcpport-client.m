#include <stdio.h>
#include <objects/TcpPort.h>
#include <objects/RunLoop.h>
#include <objects/Invocation.h>
#include <Foundation/NSDate.h>

id handle_incoming_packet (id packet)
{
  fprintf (stdout, "received >");
  fwrite ([packet streamBuffer] + [packet streamBufferPrefix],
	  [packet streamEofPosition], 1, stdout);
  fprintf (stdout, "<\n");
  [packet release];
  return nil;
}

int main (int argc, char *argv[])
{
  id out_port;
  id in_port;
  id packet;
  int i;

  if (argc > 1)
    out_port = [TcpOutPort newForSendingToRegisteredName: 
			     [NSString stringWithCString: argv[1]]
			   onHost: @"localhost"];
  else
    out_port = [TcpOutPort newForSendingToRegisteredName: @"tcpport-test"
			   onHost: @"localhost"];

  in_port = [TcpInPort newForReceiving];

  [in_port setPacketInvocation:
	     [[[ObjectFunctionInvocation alloc]
		initWithObjectFunction: handle_incoming_packet]
	       autorelease]];

  [in_port addToRunLoop: [RunLoop currentInstance] forMode: nil];
  
  for (i = 0; i < 10; i++)
    {
      packet = [[TcpPacket alloc] initForSendingWithCapacity: 100
				  replyPort: in_port];
      [packet writeFormat: @"Here is message number %d", i];
      [out_port sendPacket: packet withTimeout: 20 * 1000];
      [packet release];

      [RunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    }

  [out_port close];

  exit (0);
}
