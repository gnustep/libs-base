#include "second-server.h"
#include "second-client.h"
#include <gnustep/base/Connection.h>
#include <gnustep/base/TcpPort.h>
#include <gnustep/base/String.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/Invocation.h>

/* This function will be called by an Invocation object that will be 
   registered to fire every time an InPort accepts a new client. */
id announce_new_port (id notification)
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  printf ("{%@}\n\tconnected to\n\t{%@}\n",
	  [out_port description], [in_port description]);
  printf ("Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}

/* This function will be called by an Invocation object that will be 
   registered to fire every time an InPort client disconnects. */
id announce_broken_port (id notification)
{
  id in_port = [notification object];
  id out_port = [notification userInfo];
  printf ("{%@}\n\tdisconnected from\n\t{%@}\n",
	  [out_port description], [in_port description]);
  printf ("Now servicing %d connection(s).\n",
	  [in_port numberOfConnectedOutPorts]);
  return nil;
}

/* The implementation of the object that will be registered with  D.O. 
   as the server. */
@implementation SecondServer

- init
{
  [super init];
  array = [[Array alloc] init];
  return self;
}

- addRemoteObject: o
{
  const char *s;
  [array addObject:o];

  /* This next line is a callback */
  s = [o appellation];
  printf("Added remote object with appellation %s\n", s);

  return self;
}

- array
{
  return array;
}

- (Connection*) connection: ancestor didConnect: newConn
{
  printf(">>>>New connection 0x%x created\n", (unsigned)newConn);
  [NotificationDispatcher
    addObserver: self
    selector: @selector(connectionBecameInvalid:)
    name: ConnectionBecameInvalidNotification
    object: newConn];
  [newConn setDelegate: self];
  return newConn;
}

- connectionBecameInvalid: notification
{
  id connection = [notification object];
  if ([connection isKindOf: [Connection class]])
    {
      int arrayCount = [array count];
      int i;

      printf(">>> Connection 0x%x invalidated\n", (unsigned)connection);

      /* Remember to avoid calling -isEqual: on the proxies of the
	 invalidated Connection. */
      for (i = arrayCount-1; i >= 0; i--)
	{
	  id o = [array objectAtIndex: i];
	  if ([o isProxy]
	      && [o connectionForProxy] == connection)
	    {
	      printf(">>> Removing proxy 0x%x\n", (unsigned)o);
	      [array removeObjectAtIndex: i];
	    }
	}
    }
  else
    {
      [self error:"non-Connection sent invalidation"];
    }
  return self;
}

@end

int main(int argc, char *argv[])
{
  id s;
  id c;

  [NSObject enableDoubleReleaseCheck: YES];

  s = [[SecondServer alloc] init];

  [NotificationDispatcher
    addInvocation: [[ObjectFunctionInvocation alloc] 
		     initWithObjectFunction: announce_broken_port]
    name: InPortClientBecameInvalidNotification
    object: nil];
  [NotificationDispatcher
    addInvocation: [[ObjectFunctionInvocation alloc] 
		     initWithObjectFunction: announce_new_port]
    name: InPortAcceptedClientNotification
    object: nil];

  if (argc > 1)
    c = [Connection newRegisteringAtName: [String stringWithCString: argv[1]]
		      withRootObject:s];
  else
    c = [Connection newRegisteringAtName: @"secondserver" withRootObject: s];
  printf("Regsitered server object on localhost with name `secondserver'\n");

  [c setDelegate:s];
  [NotificationDispatcher
    addObserver: s
    selector: @selector(connectionBecameInvalid:)
    name: ConnectionBecameInvalidNotification
    object: c];

  [c runConnection];

  exit(0);
}
