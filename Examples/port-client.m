#include <stdio.h>
#include <gnustep/base/SocketPort.h>
#include <gnustep/base/String.h>

#define MSG "Hello from a client SocketPort."
#define BUFFER_SIZE 80

int main(int argc, char *argv[])
{
  char b[BUFFER_SIZE];
  int len;
  id remotePort;
  id localPort = [SocketPort newLocal];
  id rp;

  if (argc > 1)
    remotePort = [SocketPort newRemoteWithNumber:3 
			     onHost:[String stringWithCString:argv[1]]];
  else
    remotePort = [SocketPort newRemoteWithNumber:3 onHost:@""];

  strcpy(b, MSG);
  [localPort sendPacket:b length:strlen(b)
	     toPort:remotePort
	     timeout: 15000];
  len = [localPort receivePacket:b length:BUFFER_SIZE
		   fromPort:&rp
		   timeout:15000];

  if (len == -1)
    {
      fprintf(stderr, "receive from SocketPort timed out\n");
    }
  else
    {
      b[len] = '\0';
      printf("(length %d): %s\n", len, b);
    }

  exit(0);
}
