#include "second-client.h"
#include <gnustep/base/String.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/Invocation.h>
#include <gnustep/base/RunLoop.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>

id announce_new_connection (id notification)
{
#if 0
  id connection = [notification object];
  printf ("Created Connection 0x%x to %@\n",
	  (unsigned)connection, [[connection outPort] description]);
#endif
  return nil;
}

int main(int argc, char *argv[])
{
  static id server;
  id a1;
  id remote_array;
  char namebuf[16];

  printf("Looking up server object on localhost with name `secondserver'\n");
  if (argc > 1)
    server = [Connection rootProxyAtName: [String stringWithCString: argv[1]]];
  else
    server = [Connection rootProxyAtName: @"secondserver"];
  printf("Found server.\n");

  [NotificationDispatcher
    addInvocation: [[ObjectFunctionInvocation alloc]
		     initWithObjectFunction: announce_new_connection]
    name: ConnectionWasCreatedNotification
    object: nil];

  /* Create an AppellationObject */
  a1 = [[AppellationObject alloc] init];
  sprintf(namebuf, "%d", (int)getpid());
  [a1 setAppellation: namebuf];
  printf("This client has appellation %s\n", [a1 appellation]);

  /* Let the server know about object a1. */
  [server addRemoteObject: a1];

  /* Get the server's array of all other AppellationObject's */
  remote_array = [server array];

  /* Print all the appellations; this will involve making connections
     to the other clients of the server. */
  {
    int i, count;
    const char *s;
    id a2;			/* appellation object from server's list */
    
    count = [remote_array count];
    for (i = 0; i < count; i++)
      {
	a2 = [remote_array objectAtIndex: i];
	s = [a2 appellation];
	printf(">>>Server knows about client with appellation %s<<<\n", s);
	if ([a2 isProxy])
	  (*objc_free)((void*)s);
      }
  }

  /* Cause an exception, and watch it return to us. */
  NS_DURING
    {
      [remote_array objectAtIndex: 99];
    }
  NS_HANDLER
    {
      printf("Caught our exception\n"
	     "NAME: %@\n"
	     "REASON: %@\n",
	     [exception name],
	     [exception reason]);
      [exception release];
    }
  NS_ENDHANDLER

  /* Run, exiting as soon as there are 30 minutes with no requests */
  [RunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30 * 60]];
  
  /* Clean up, to let the server know we're going away; (although
     this isn't strictly necessary because the remote port will
     detect that the connection has been severed). */
  [[server connectionForProxy] invalidate];

  exit(0);
}
