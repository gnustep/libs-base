
/* call - Program to test NSFileHandle TCP/IP connection.

   Copyright (C) 2002 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: Jun 2002
	 
   This file is part of the GNUstep Base Library.
*/

#include <Foundation/Foundation.h>

@interface Call : NSObject
{
  NSFileHandle		*ichan;
  NSFileHandle		*ochan;
  NSFileHandle		*remote;
}
- (void) didRead: (NSNotification*)notification;
- (void) didWrite: (NSNotification*)notification;
@end


@implementation Call

- (void) dealloc
{
  RELEASE(ichan);
  RELEASE(ochan);
  RELEASE(remote);
  [super dealloc];
}

- (void) didRead: (NSNotification*)notification
{
  NSDictionary	*userInfo = [notification userInfo];
  NSFileHandle	*object = [notification object];
  NSData	*d;

  d = [userInfo objectForKey: NSFileHandleNotificationDataItem];
  if (d == nil || [d length] == 0)
    {
      NSLog(@"Read EOF");
      exit(0);
    }
  else
    {
      if (object == ichan)
	{
	  [remote writeInBackgroundAndNotify: d];
	  [ichan readInBackgroundAndNotify];
	}
      else
	{
	  [ochan writeInBackgroundAndNotify: d];
	  [remote readInBackgroundAndNotify];
	}
    }
}

- (void) didWrite: (NSNotification*)notification
{
  NSDictionary	*userInfo = [notification userInfo];
  NSString	*e;

  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e)
    {
      NSLog(@"%@", e);
      exit(0);
    }
}

- (id) init
{
  NSArray	*args = [[NSProcessInfo processInfo] arguments];
  NSString	*host = @"localhost";
  NSString	*service = @"telnet";
  NSString	*protocol = @"tcp";

  if ([args count] > 1)
    {
      host = [args objectAtIndex: 1];
      if ([args count] > 2)
	{
	  service = [args objectAtIndex: 2];
	  if ([args count] > 3)
	    {
	      protocol = [args objectAtIndex: 3];
	    }
	}
    }
  ichan = RETAIN([NSFileHandle fileHandleWithStandardInput]);
  ochan = RETAIN([NSFileHandle fileHandleWithStandardOutput]);
  remote = RETAIN([NSFileHandle fileHandleAsClientAtAddress:
    host service: service protocol: protocol]);
  if (remote == nil)
    {
      NSLog(@"Failed to create connection");
      DESTROY(self);
    }
  else
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

      [nc addObserver: self
	     selector: @selector(didRead:)
		 name: NSFileHandleReadCompletionNotification
	       object: (id)ichan];
      [nc addObserver: self
	     selector: @selector(didWrite:)
		 name: GSFileHandleWriteCompletionNotification
	       object: (id)ochan];
      [nc addObserver: self
	     selector: @selector(didRead:)
		 name: NSFileHandleReadCompletionNotification
	       object: (id)remote];
      [nc addObserver: self
	     selector: @selector(didWrite:)
		 name: GSFileHandleWriteCompletionNotification
	       object: (id)remote];
      [remote readInBackgroundAndNotify];
      [ichan readInBackgroundAndNotify];
    }
  return self;
}

@end



int
main()
{
  Call	*console;
  CREATE_AUTORELEASE_POOL(arp);

  console = [Call new];
  RELEASE(arp);
  [[NSRunLoop currentRunLoop] run];
  RELEASE(console);
  return 0;
}

