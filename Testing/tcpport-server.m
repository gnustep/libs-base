#include <stdio.h>
#include <objects/TcpPort.h>

int main ()
{
  id port;
  id packet;

  port = [TcpInPort newForReceivingFromRegisteredName: @"tcpport-test"];
  
  while ((packet = [port receivePacketWithTimeout: 20 * 1000]))
    {
      fprintf (stdout, "received >");
      fwrite ([packet streamBuffer], [packet streamEofPosition], 1, stdout);
      fprintf (stdout, "<\n");
      [packet release];
    }
  fprintf (stdout, "Timed out.  Exiting.\n");

  exit (0);
}
