#include <stdio.h>
#include <gnustep/base/SocketPort.h>

#define MSG "Hello back to you, from a server SocketPort"
#define BUFFER_SIZE 80

int main()
{
  char b[BUFFER_SIZE];
  int l;
  id p = [SocketPort newLocalWithNumber:3];
  id rp;

  for (;;)
    {
      l = [p receivePacket:b length:BUFFER_SIZE
	     fromPort:&rp
	     timeout:-1];
      if (l >= 0 && l < 32)
	b[l] = '\0';
      printf("(length %d): %s\n", l, b);

      [p sendPacket:MSG length:strlen(MSG)
	 toPort:rp
	 timeout:15000];
    }
  exit(0);
}
