
/* call - Program to test NSFileHandle TCP/IP connection.

   Copyright (C) 2002 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: Jun 2002
	 
   This file is part of the GNUstep Base Library.
*/

#include <Foundation/Foundation.h>

@class	GSTelnetHandle;
extern NSString * const GSTelnetNotification;
extern NSString * const GSTelnetErrorKey;
extern NSString * const GSTelnetTextKey;

@interface Call : NSObject
{
  NSFileHandle		*ichan;
  NSFileHandle		*ochan;
  GSTelnetHandle	*remote;
  NSMutableData		*buf;
}
- (void) didRead: (NSNotification*)notification;
- (void) didWrite: (NSNotification*)notification;
- (void) gotTelnet: (NSNotification*)notification;
@end


@implementation Call

- (void) dealloc
{
  RELEASE(ichan);
  RELEASE(ochan);
  RELEASE(remote);
  RELEASE(buf);
  [super dealloc];
}

- (void) didRead: (NSNotification*)notification
{
  NSDictionary	*userInfo = [notification userInfo];
  NSData	*d;

  d = [userInfo objectForKey: NSFileHandleNotificationDataItem];
  if (d == nil || [d length] == 0)
    {
      NSLog(@"Read EOF");
      exit(0);
    }
  else
    {
      char	*ptr;
      unsigned	len;
      int	i;

      [buf appendData: d];
      ptr = [buf mutableBytes];
      len = [buf length];
      for (i = 0; i < len; i++)
	{
	  if (ptr[i] == '\n')
	    {
	      NSString	*s;

	      if (i > 0 && ptr[i-1] == '\r')
		{
		  s = [NSString stringWithCString: ptr length: i-1];
		}
	      else
		{
		  s = [NSString stringWithCString: ptr length: i];
		}
	      len -= (i + 1);
	      if (len > 0)
		{
		  memcpy(ptr, &ptr[i+1], len);
		}
	      [buf setLength: len];
	      ptr = [buf mutableBytes];
	      i = -1;
	      [remote putTelnetLine: s];
	    }
	}
      [ichan readInBackgroundAndNotify];
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

- (void) gotTelnet: (NSNotification*)notification
{
  NSDictionary	*info = [notification userInfo];
  NSArray	*text;

  text = [info objectForKey: GSTelnetTextKey];
  if (text == nil)
    {
      NSLog(@"Lost telnet - %@", [info objectForKey: GSTelnetErrorKey]);
      exit(0);
    }
  else
    {
      unsigned	i;

      for (i = 0; i < [text count]; i++)
	{
	  [ochan writeInBackgroundAndNotify:
	    [[text objectAtIndex: i] dataUsingEncoding: NSUTF8StringEncoding]];
	}
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
  buf = [NSMutableData new];
  ichan = RETAIN([NSFileHandle fileHandleWithStandardInput]);
  ochan = RETAIN([NSFileHandle fileHandleWithStandardOutput]);
  remote = [[GSTelnetHandle alloc] initWithHandle:
    [NSFileHandle fileHandleAsClientAtAddress:
      host service: service protocol: protocol] isConnected: YES];
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
	       object: ichan];
      [nc addObserver: self
	     selector: @selector(didWrite:)
		 name: GSFileHandleWriteCompletionNotification
	       object: ochan];
      [nc addObserver: self
	     selector: @selector(gotTelnet:)
		 name: GSTelnetNotification
	       object: remote];
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

