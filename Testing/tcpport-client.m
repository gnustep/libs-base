#include <stdio.h>
#include <objects/TcpPort.h>

int main ()
{
  id port;
  id packet;
  int i;

  port = [TcpOutPort newForSendingToRegisteredName: @"tcpport-test"
		     onHost: @"localhost"];
  
  for (i = 0; i < 5; i++)
    {
      packet = [[TcpPacket alloc] initForSendingWithCapacity: 100
				  replyPort: nil];
      [packet writeFormat: @"Here is message number %d\n", i];
      [port sendPacket: packet withTimeout: 20 * 1000];
      [packet release];
    }

  [port close];

  exit (0);
}
