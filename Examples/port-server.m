#include <stdio.h>
#include <gnustep/base/SocketPort.h>

#define MSG "Hello back to you, from a server SocketPort"

int main()
{
  id packet;
  id p = [TcpPort newLocalWithNumber:3];
  id rp;
  int len;
  char *buf;

  for (;;)
    {
      packet = [p receivePacketWithTimeout: -1];
      len = [p streamBufferLength];
      buf = [p streamBuffer];
      if (len >= 0 && len < 32)
	buf[l] = '\0';
      printf("(length %d): %s\n", len, buf);

      [p sendPacket:MSG length:strlen(MSG)
	 toPort:rp
	 timeout:15000];
    }
  exit(0);
}
