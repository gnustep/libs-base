/* Implementation of message port subclass of NSPortNameServer

   Copyright (C) 2005 Free Software Foundation, Inc.

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSMessagePortNameServer class reference</title>
   $Date$ $Revision$
   */

#include "Foundation/NSPortNameServer.h"

#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSException.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSDistributedLock.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSPort.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSThread.h"
#include "GNUstepBase/GSMime.h"

#include "GSPortPrivate.h"

#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <string.h>
#include <sys/un.h>

/* Older systems (Solaris) compatibility */
#ifndef AF_LOCAL
#define AF_LOCAL AF_UNIX
#define PF_LOCAL PF_UNIX
#endif
#ifndef SUN_LEN
#define SUN_LEN(su) \
	(sizeof(*(su)) - sizeof((su)->sun_path) + strlen((su)->sun_path))
#endif


static NSRecursiveLock *serverLock = nil;
static NSMessagePortNameServer *defaultServer = nil;

/*
Maps NSMessagePort objects to NSMutableArray:s of NSString:s. The array
is an array of names the port has been registered under by _us_.

Note that this map holds the names the port has been registered under at
some time. If the name is been unregistered by some other program, we can't
update the table, so we have to deal with the case where the array contains
names that the port isn't registered under.

Since we _have_to_ deal with this anyway, we handle it in -removePort: and
-removePort:forName:, and we don't bother removing entries in the map when
unregistering a name not for a specific port.
*/
static NSMapTable *portToNamesMap;


@interface NSMessagePortNameServer (private)
+ (NSDistributedLock*) _fileLock;
+ (NSString *) _pathForName: (NSString *)name;
@end


static void clean_up_names(void)
{
  NSMapEnumerator	mEnum;
  NSMessagePort		*port;
  NSString		*name;
  BOOL			unknownThread = GSRegisterCurrentThread();
  CREATE_AUTORELEASE_POOL(arp);

  mEnum = NSEnumerateMapTable(portToNamesMap);
  while (NSNextMapEnumeratorPair(&mEnum, (void *)&port, (void *)&name))
    {
      [defaultServer removePort: port];
    }
  NSEndMapTableEnumeration(&mEnum);
  IF_NO_GC(DESTROY(arp);)
  if (unknownThread == YES)
    {
      GSUnregisterCurrentThread();
    }
}

/**
 * Subclass of [NSPortNameServer] taking/returning instances of [NSMessagePort].
 * Port removal functionality is not supported; if you want to cancel a service,
 * you have to destroy the port (invalidate the [NSMessagePort] given to
 * [NSPortNameServer-registerPort:forName:]).
 */
@implementation NSMessagePortNameServer

+ (void) initialize
{
  if (self == [NSMessagePortNameServer class])
    {
      serverLock = [NSRecursiveLock new];
      portToNamesMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
			 NSObjectMapValueCallBacks, 0);
      atexit(clean_up_names);
    }
}

/**
 *  Obtain single instance for this host.
 */
+ (id) sharedInstance
{
  if (defaultServer == nil)
    {
      [serverLock lock];
      if (defaultServer == nil)
	{
	  defaultServer = (NSMessagePortNameServer *)NSAllocateObject(self,
	    0, NSDefaultMallocZone());
	}
      [serverLock unlock];
    }
  return defaultServer;
}

+ (NSDistributedLock*) _fileLock
{
  NSDistributedLock	*dl;

  dl = [NSDistributedLock lockWithPath: [self _pathForName: nil]];
  if ([dl tryLock] == NO)
    {
      NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 2.0];

      while (dl != nil && [dl tryLock] == NO)
	{
	  if ([limit timeIntervalSinceNow] > 0.0)
	    {
	      [NSThread sleepForTimeInterval: 0.1];
	    }
	  else
	    {
              if ([[dl lockDate] timeIntervalSinceNow] < -15.0)
                {
                  NS_DURING
                    {
                      [dl breakLock];
                    }
                  NS_HANDLER
                    {
                      NSLog(@"Failed to break lock on names for "
                        @"NSMessagePortNameServer: %@", localException);
                      dl = nil;
                    }
                  NS_ENDHANDLER
                }
              else
                {
                  NSLog(@"Failed to lock names for NSMessagePortNameServer");
                  dl = nil;
                }
	    }
	}
    }
  return dl;
}

/* Return the full path for the supplied port name or, if it's nil,
 * the path for the distributed lock protecting all names.
 */
+ (NSString *) _pathForName: (NSString *)name
{
  static NSString	*base_path = nil;
  NSString		*path;
  NSData		*data;

  if (name == nil)
    {
      name = @"lock";
    }
  else
    {
      /*
       * Make sure name is representable as a filename ... assume base64 encoded
       * strings are valid on all filesystems.
       */
      data = [name dataUsingEncoding: NSUTF8StringEncoding];
      data = [GSMimeDocument encodeBase64: data];
      name = [[NSString alloc] initWithData: data
				   encoding: NSASCIIStringEncoding];
      IF_NO_GC([name autorelease];)
    }
  [serverLock lock];
  if (!base_path)
    {
      NSNumber		*p = [NSNumber numberWithInt: 0700];
      NSDictionary	*attr;

      path = NSTemporaryDirectory();
      attr = [NSDictionary dictionaryWithObject: p
				     forKey: NSFilePosixPermissions];

      path = [path stringByAppendingPathComponent: @"NSMessagePort"];
      [[NSFileManager defaultManager] createDirectoryAtPath: path
				      attributes: attr];

      path = [path stringByAppendingPathComponent: @"names"];
      [[NSFileManager defaultManager] createDirectoryAtPath: path
				      attributes: attr];

      base_path = RETAIN(path);
    }
  else
    {
      path = base_path;
    }
  [serverLock unlock];

  path = [path stringByAppendingPathComponent: name];
  return path;
}


+ (BOOL) _livePort: (NSString *)path
{
  FILE	*f;
  char	socket_path[512];
  int	pid;
  struct stat sb;

  NSDebugLLog(@"NSMessagePort", @"_livePort: %@", path);

  f = fopen([path fileSystemRepresentation], "rt");
  if (!f)
    {
      NSDebugLLog(@"NSMessagePort", @"not live, couldn't open file (%m)");
      return NO;
    }

  fgets(socket_path, sizeof(socket_path), f);
  if (strlen(socket_path) > 0) socket_path[strlen(socket_path) - 1] = 0;

  fscanf(f, "%i", &pid);

  fclose(f);

  if (stat(socket_path, &sb) < 0)
    {
      unlink([path fileSystemRepresentation]);
      NSDebugLLog(@"NSMessagePort", @"not live, couldn't stat socket (%m)");
      return NO;
    }

  if (kill(pid, 0) < 0)
    {
      unlink([path fileSystemRepresentation]);
      unlink(socket_path);
      NSDebugLLog(@"NSMessagePort", @"not live, no such process (%m)");
      return NO;
    }
  else
    {
      struct sockaddr_un sockAddr;
      int desc;

      memset(&sockAddr, '\0', sizeof(sockAddr));
      sockAddr.sun_family = AF_LOCAL;
      strncpy(sockAddr.sun_path, socket_path, sizeof(sockAddr.sun_path));

      if ((desc = socket(PF_LOCAL, SOCK_STREAM, PF_UNSPEC)) < 0)
	{
	  unlink([path fileSystemRepresentation]);
	  unlink(socket_path);
	  NSDebugLLog(@"NSMessagePort",
	    @"couldn't create socket, assuming not live (%m)");
	  return NO;
	}
      if (connect(desc, (struct sockaddr*)&sockAddr, SUN_LEN(&sockAddr)) < 0)
	{
	  unlink([path fileSystemRepresentation]);
	  unlink(socket_path);
	  NSDebugLLog(@"NSMessagePort", @"not live, can't connect (%m)");
	  return NO;
	}
      close(desc);
      NSDebugLLog(@"NSMessagePort", @"port is live");
      return YES;
    }
}

- (NSPort*) portForName: (NSString*)name
{
  return [self portForName: name onHost: nil];
}

- (NSPort*) portForName: (NSString *)name
		 onHost: (NSString *)host
{
  NSDistributedLock	*dl;
  NSString		*path;
  FILE			*f;
  char			socket_path[512];

  NSDebugLLog(@"NSMessagePort", @"portForName: %@ host: %@", name, host);

  if ([host length] > 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to contact a named host using a "
	@"message port name server.  This name server can only be used "
	@"to contact processes owned by the same user on the local host "
	@"(host name must be an empty string).  To contact processes "
	@"owned by other users or on other hosts you must use an instance "
	@"of the NSSocketPortNameServer class."];
    }

  path = [[self class] _pathForName: name];
  if ((dl = [[self class] _fileLock]) == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Failed to lock names for NSMessagePortNameServer"];
    }
  if (![[self class] _livePort: path])
    {
      [dl unlock];
      NSDebugLLog(@"NSMessagePort", @"not a live port");
      return nil;
    }

  f = fopen([path fileSystemRepresentation], "rt");
  if (!f)
    {
      [dl unlock];
      NSDebugLLog(@"NSMessagePort", @"can't open file (%m)");
      return nil;
    }

  fgets(socket_path, sizeof(socket_path), f);
  if (strlen(socket_path) > 0) socket_path[strlen(socket_path) - 1] = 0;
  fclose(f);

  NSDebugLLog(@"NSMessagePort", @"got %s", socket_path);
  [dl unlock];

  return [NSMessagePort _portWithName: (unsigned char*)socket_path
			     listener: NO];
}

- (BOOL) registerPort: (NSPort *)port
	      forName: (NSString *)name
{
  int			fd;
  unsigned char		buf[32];
  NSDistributedLock	*dl;
  NSString		*path;
  const unsigned char	*socket_name;
  NSMutableArray	*a;

  NSDebugLLog(@"NSMessagePort", @"register %@ as %@\n", port, name);
  if ([port isKindOfClass: [NSMessagePort class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempted to register a non-NSMessagePort (%@)",
	port];
    }

  path = [[self class] _pathForName: name];
  if ((dl = [[self class] _fileLock]) == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Failed to lock names for NSMessagePortNameServer"];
    }
  if ([[self class] _livePort: path])
    {
      [dl unlock];
      NSDebugLLog(@"NSMessagePort", @"fail, is a live port (%@)", name);
      return NO;
    }

  fd = open([path fileSystemRepresentation], O_CREAT|O_EXCL|O_WRONLY, 0600);
  if (fd < 0)
    {
      [dl unlock];
      NSDebugLLog(@"NSMessagePort", @"fail, can't open file (%@) for %@",
	path, name);
      return NO;
    }

  socket_name = [(NSMessagePort *)port _name];

  write(fd, (char*)socket_name, strlen((char*)socket_name));
  write(fd, "\n", 1);
  sprintf((char*)buf, "%i\n", getpid());
  write(fd, (char*)buf, strlen((char*)buf));

  close(fd);

  [serverLock lock];
  a = NSMapGet(portToNamesMap, port);
  if (!a)
    {
      a = [[NSMutableArray alloc] init];
      NSMapInsert(portToNamesMap, port, a);
      RELEASE(a);
    }

  [a addObject: [name copy]];
  [serverLock unlock];
  [dl unlock];

  return YES;
}

- (BOOL) removePortForName: (NSString *)name
{
  NSDistributedLock	*dl;
  NSString		*path;

  NSDebugLLog(@"NSMessagePort", @"removePortForName: %@", name);
  path = [[self class] _pathForName: name];
  if ((dl = [[self class] _fileLock]) == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Failed to lock names for NSMessagePortNameServer"];
    }
  unlink([path fileSystemRepresentation]);
  [dl unlock];
  return YES;
}

- (NSArray *) namesForPort: (NSPort *)port
{
  NSMutableArray	*a;

  [serverLock lock];
  a = NSMapGet(portToNamesMap, port);
  a = [a copy];
  [serverLock unlock];
  return AUTORELEASE(a);
}

- (BOOL) removePort: (NSPort *)port
{
  NSMutableArray *a;
  int		i;

  NSDebugLLog(@"NSMessagePort", @"removePort: %@", port);

  [serverLock lock];
  a = NSMapGet(portToNamesMap, port);

  for (i = 0; i < [a count]; i++)
    {
      [self removePort: port  forName: [a objectAtIndex: i]];
    }

  NSMapRemove(portToNamesMap, port);
  [serverLock unlock];

  return YES;
}

- (BOOL) removePort: (NSPort*)port forName: (NSString*)name
{
  FILE			*f;
  char			socket_path[512];
  NSDistributedLock	*dl;
  NSString		*path;
  const unsigned char	*port_path;

  NSDebugLLog(@"NSMessagePort", @"removePort: %@  forName: %@", port, name);

  path = [[self class] _pathForName: name];
  if ((dl = [[self class] _fileLock]) == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Failed to lock names for NSMessagePortNameServer"];
    }
  f = fopen([path fileSystemRepresentation], "rt");
  if (!f)
    {
      [dl unlock];
      return YES;
    }
  fgets(socket_path, sizeof(socket_path), f);
  if (strlen(socket_path) > 0)
    {
      socket_path[strlen(socket_path) - 1] = 0;
    }
  fclose(f);
  port_path = [(NSMessagePort *)port _name];
  if (!strcmp((char*)socket_path, (char*)port_path))
    {
      unlink([path fileSystemRepresentation]);
    }
  [dl unlock];
  return YES;
}

@end

