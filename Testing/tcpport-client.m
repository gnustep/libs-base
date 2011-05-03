/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <stdio.h>
#include <GNUstepBase/TcpPort.h>
#include <Foundation/NSRunLoop.h>
#include <GNUstepBase/Invocation.h>
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
			     [NSString stringWithUTF8String: argv[1]]
			   onHost: @"localhost"];
  else
    out_port = [TcpOutPort newForSendingToRegisteredName: @"tcpport-test"
			   onHost: nil];

  in_port = [TcpInPort newForReceiving];

  [in_port setReceivedPacketInvocation:
	     [[[ObjectFunctionInvocation alloc]
		initWithObjectFunction: handle_incoming_packet]
	       autorelease]];

  [[NSRunLoop currentRunLoop] addPort: in_port
			      forMode: NSDefaultRunLoopMode];

  for (i = 0; i < 10; i++)
    {
      packet = [[TcpOutPacket alloc] initForSendingWithCapacity: 100
				     replyInPort: in_port];
      [packet writeFormat: @"Here is message number %d", i];
      [out_port sendPacket: packet timeout: 10.0];
      [packet release];

      [[NSRunLoop currentRunLoop] runUntilDate:
	[NSDate dateWithTimeIntervalSinceNow: 1.0]];
    }

  [out_port close];

  exit (0);
}
