#include "Foundation/NSPortNameServer.h"

#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSException.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSPort.h"

#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <string.h>
#include <sys/un.h>


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
static NSMapTable portToNamesMap;


@interface NSMessagePortNameServer (private)
+(NSString *) _pathForName: (NSString *)name;
@end


static void clean_up_names(void)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMapEnumerator mEnum;
  NSMessagePort *port;
  NSString *name;

  mEnum = NSEnumerateMapTable(portToNamesMap);
  while (NSNextMapEnumeratorPair(&mEnum, (void *)&port, (void *)&name))
    {
      [defaultServer removePort: port];
    }
  NSEndMapTableEnumeration(&mEnum);
  DESTROY(arp);
}


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

+ (id) sharedInstance
{
  if (defaultServer == nil)
    {
      NSMessagePortNameServer *s;

      [serverLock lock];
      if (defaultServer)
	{
	  [serverLock unlock];
	  return defaultServer;
	}
      s = (NSMessagePortNameServer *)NSAllocateObject(self, 0, NSDefaultMallocZone());
      defaultServer = s;
      [serverLock unlock];
    }
  return defaultServer;
}


+(NSString *) _pathForName: (NSString *)name
{
  NSString *path;
static NSString *base_path = nil;

  [serverLock lock];
  if (!base_path)
    {
      path=NSTemporaryDirectory();

      path = [path stringByAppendingPathComponent: @"NSMessagePort"];
      mkdir([path fileSystemRepresentation], 0700);

      path = [path stringByAppendingPathComponent: @"names"];
      mkdir([path fileSystemRepresentation], 0700);

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


+(BOOL) _livePort: (NSString *)path
{
  FILE *f;
  char socket_path[512];
  int pid;
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

  if (stat(socket_path,&sb)<0)
    {
      unlink([path fileSystemRepresentation]);
      NSDebugLLog(@"NSMessagePort", @"not live, couldn't stat socket (%m)");
      return NO;
    }

  if (kill(pid,0)<0)
    {
      unlink([path fileSystemRepresentation]);
      unlink(socket_path);
      NSDebugLLog(@"NSMessagePort", @"not live, no such process (%m)");
      return NO;
    }

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
	NSDebugLLog(@"NSMessagePort", @"couldn't create socket, assuming not live (%m)");
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
  }


  NSDebugLLog(@"NSMessagePort", @"port is live");
  return YES;
}


- (NSPort *) portForName: (NSString *)name
		 onHost: (NSString *)host
{
  NSString *path;
  FILE *f;
  char socket_path[512];

  NSDebugLLog(@"NSMessagePort", @"portForName: %@ host: %@", name, host);

  if ([host length] && ![host isEqual: @"*"])
    {
      NSDebugLLog(@"NSMessagePort", @"non-local host");
      return nil;
    }

  path = [isa _pathForName: name];
  if (![isa _livePort: path])
    {
      NSDebugLLog(@"NSMessagePort", @"not a live port");
      return nil;
    }

  f = fopen([path fileSystemRepresentation], "rt");
  if (!f)
    {
      NSDebugLLog(@"NSMessagePort", @"can't open file (%m)");
      return nil;
    }

  fgets(socket_path, sizeof(socket_path), f);
  if (strlen(socket_path) > 0) socket_path[strlen(socket_path) - 1] = 0;
  fclose(f);

  NSDebugLLog(@"NSMessagePort", @"got %s", socket_path);

  return [NSMessagePort _portWithName: socket_path
			     listener: NO];
}

- (BOOL) registerPort: (NSPort *)port
	     forName: (NSString *)name
{
  int fd;
  unsigned char buf[32];
  NSString *path;
  const unsigned char *socket_name;

  NSDebugLLog(@"NSMessagePort", @"register %@ as %@\n", port, name);
  if (![port isKindOfClass: [NSMessagePort class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempted to register a non-NSMessagePort with NSMessagePortNameServer"];
      return NO;
    }

  path=[isa _pathForName: name];

  if ([isa _livePort: path])
    {
      NSDebugLLog(@"NSMessagePort", @"fail, is a live port");
      return NO;
    }

  fd = open([path fileSystemRepresentation], O_CREAT|O_EXCL|O_WRONLY, 0600);
  if (fd < 0)
    {
      NSDebugLLog(@"NSMessagePort", @"fail, can't open file (%m)");
      return NO;
    }

  socket_name = [(NSMessagePort *)port _name];

  write(fd, socket_name, strlen(socket_name));
  write(fd, "\n", 1);
  sprintf(buf, "%i\n", getpid());
  write(fd, buf, strlen(buf));

  close(fd);

  {
    NSMutableArray *a;

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
  }

  return YES;
}

- (BOOL) removePortForName: (NSString *)name
{
  NSString *path;

  NSDebugLLog(@"NSMessagePort", @"removePortForName: %@", name);
  path=[isa _pathForName: name];
  unlink([path fileSystemRepresentation]);
  return YES;
}

- (NSArray *) namesForPort: (NSPort *)port
{
  NSMutableArray *a;
  [serverLock lock];
  a = NSMapGet(portToNamesMap, port);
  a = [a copy];
  [serverLock unlock];
  return a;
}

- (BOOL) removePort: (NSPort *)port
{
  NSMutableArray *a;
  int i;

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
  FILE *f;
  char socket_path[512];
  NSString *path;
  const unsigned char *port_path;

  NSDebugLLog(@"NSMessagePort", @"removePort: %@  forName: %@", port, name);

  path = [isa _pathForName: name];

  f = fopen([path fileSystemRepresentation], "rt");
  if (!f)
    return YES;

  fgets(socket_path, sizeof(socket_path), f);
  if (strlen(socket_path) > 0) socket_path[strlen(socket_path) - 1] = 0;

  fclose(f);

  port_path = [(NSMessagePort *)port _name];

  if (!strcmp(socket_path, port_path))
    {
      unlink([path fileSystemRepresentation]);
    }

  return YES;
}

@end

