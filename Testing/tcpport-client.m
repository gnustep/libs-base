#include <stdio.h>
#include <objects/TcpPort.h>

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
  
  for (i = 0; i < 10; i++)
    {
      packet = [[TcpPacket alloc] initForSendingWithCapacity: 100
				  replyPort: in_port];
      [packet writeFormat: @"Here is message number %d", i];
      [out_port sendPacket: packet withTimeout: 20 * 1000];
      [packet release];

      packet = [in_port receivePacketWithTimeout: 1000];
      if (packet)
	{
	  fprintf (stdout, "received >");
	  fwrite ([packet streamBuffer] + [packet streamBufferPrefix],
		  [packet streamEofPosition], 1, stdout);
	  fprintf (stdout, "<\n");
	  [packet release];
	}

      sleep (2);
    }

  [out_port close];

  exit (0);
}
