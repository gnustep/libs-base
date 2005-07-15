/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSData.h>
#include <Foundation/NSPort.h>

@class GSTcpPort;
@interface NSPortNameServer (hack)
- (Class) setPortClass: (Class)c;
@end

int
main()
{
  NSRunLoop		*loop;
  GSTcpPort		*local;
  GSTcpPort		*remote;
  NSPortNameServer	*names;
  CREATE_AUTORELEASE_POOL(pool);

  local = [GSTcpPort new];
  loop = [NSRunLoop currentRunLoop];
  [NSPortNameServer setPortClass: [GSTcpPort class]];
  names = (id)[NSPortNameServer systemDefaultPortNameServer];
  remote = [names portForName: @"GSTcpPort"];
  [loop addPort: (NSPort*)local forMode: NSDefaultRunLoopMode];
  [remote sendBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 240]
	      components: [NSMutableArray arrayWithObject:
    [NSData dataWithBytes: "hello" length: 5]]
		    from: local
		reserved: 0];
  [loop run];
  RELEASE(pool);
  exit(0);
}

