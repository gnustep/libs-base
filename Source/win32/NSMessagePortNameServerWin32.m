/* Implementation of message port subclass of NSPortNameServer

   Copyright (C) 2005 Free Software Foundation, Inc.

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the
   Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   <title>NSMessagePortNameServer class reference</title>
   $Date$ $Revision$
   */

#include "Foundation/NSPortNameServer.h"

#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSException.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSPort.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSThread.h"

#include "GSPortPrivate.h"

#define	UNISTR(X) \
((const unichar*)[(X) cStringUsingEncoding: NSUnicodeStringEncoding])

extern int	errno;

static NSRecursiveLock *serverLock = nil;
static NSMessagePortNameServer *defaultServer = nil;
static NSMapTable portToNamesMap;
static NSString	*registry;
static HKEY	key;

@interface NSMessagePortNameServer (private)
+ (NSString *) _query: (NSString *)name;
+ (NSString *) _translate: (NSString *)name;
@end


static void clean_up_names(void)
{
  NSMapEnumerator mEnum;
  NSMessagePort	*port;
  NSString	*name;
  BOOL	unknownThread = GSRegisterCurrentThread();
  CREATE_AUTORELEASE_POOL(arp);

  mEnum = NSEnumerateMapTable(portToNamesMap);
  while (NSNextMapEnumeratorPair(&mEnum, (void *)&port, (void *)&name))
    {
      [defaultServer removePort: port];
    }
  NSEndMapTableEnumeration(&mEnum);
  DESTROY(arp);
  RegCloseKey(key);
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
      int	rc;

      serverLock = [NSRecursiveLock new];
      portToNamesMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
	NSObjectMapValueCallBacks, 0);
      atexit(clean_up_names);

      registry = @"Software\\GNUstepNSMessagePort";
      rc = RegCreateKeyExW(
	HKEY_CURRENT_USER,
	UNISTR(registry),
	0,
	L"",
	REG_OPTION_VOLATILE,
	STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ|KEY_SET_VALUE
	|KEY_QUERY_VALUE,
	NULL,
	&key,
	NULL);
      if (rc == ERROR_SUCCESS)
	{
	  rc = RegFlushKey(key);
	  if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to flush registry HKEY_CURRENT_USER\\%@ (%x)",
		registry, rc);
	    }
	}
      else
	{
	  NSLog(@"Failed to create registry HKEY_CURRENT_USER\\%@ (%x)",
	    registry, rc);
	}
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


+ (NSString *) _query: (NSString *)name
{
  NSString	*n;
  NSString	*p;
  unsigned char	buf[25];
  DWORD		len = 25;
  DWORD		type;
  HANDLE	h;
  int		rc;

  n = [[self class] _translate: name];

  rc = RegQueryValueExW(
    key,
    UNISTR(n),
    (LPDWORD)0,
    &type,
    (LPBYTE)buf,
    &len);
  if (rc != ERROR_SUCCESS)
    {
      return nil;
    }

  n = [NSString stringWithUTF8String: buf];

  /*
   * See if we can open the mailslot ... if not, the query returned
   * an old name, and we can remove it.
   */
  p = [NSString stringWithFormat:
    @"\\\\.\\mailslot\\GNUstep\\NSMessagePort\\%@", n];
  h = CreateFileW(
    UNISTR(p),
    GENERIC_WRITE,
    FILE_SHARE_READ|FILE_SHARE_WRITE,
    (LPSECURITY_ATTRIBUTES)0,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    (HANDLE)0);
  if (h == INVALID_HANDLE_VALUE)
    {
      RegDeleteValueW(key, UNISTR(n));
      return nil;
    }
  else
    {
      CloseHandle(h);	// OK
      return n;
    }
}

+ (NSString *) _translate: (NSString *)name
{
  return name;
}

- (NSPort*) portForName: (NSString *)name
		 onHost: (NSString *)host
{
  NSString	*n;

  NSDebugLLog(@"NSMessagePortNameServer",
    @"portForName: %@ host: %@", name, host);

  if ([host length] && ![host isEqual: @"*"])
    {
      NSDebugLLog(@"NSMessagePortNameServer", @"non-local host");
      return nil;
    }

  n = [[self class] _query: name];
  if (n == nil)
    {
      NSDebugLLog(@"NSMessagePortNameServer", @"got no port for %@", name);
      return nil;
    }
  else
    {
      NSDebugLLog(@"NSMessagePortNameServer", @"got %@ for %@", n, name);
      return AUTORELEASE([NSMessagePort newWithName: n]);
    }
}

- (BOOL) registerPort: (NSPort *)port
	      forName: (NSString *)name
{
  NSMutableArray	*a;
  NSString		*n;
  int			rc;

  NSDebugLLog(@"NSMessagePortNameServer", @"register %@ as %@\n", port, name);
  if ([port isKindOfClass: [NSMessagePort class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempted to register a non-NSMessagePort (%@)",
	port];
      return NO;
    }

  if ([[self class] _query: name] != nil)
    {
      NSDebugLLog(@"NSMessagePortNameServer", @"fail, is a live port");
      return NO;
    }

  n = [[self class] _translate: name];

  rc = RegSetValueExW(
    key,
    UNISTR(n),
    0,
    REG_BINARY,
    [[(NSMessagePort*)port name] UTF8String],
    25);
  if (rc == ERROR_SUCCESS)
    {
      rc = RegFlushKey(key);
      if (rc != ERROR_SUCCESS)
	{
	  NSLog(@"Failed to flush registry HKEY_CURRENT_USER\\%@\\%@ (%x)",
	    registry, n, rc);
	}
    }
  else
    {
      NSLog(@"Failed to insert HKEY_CURRENT_USER\\%@\\%@ (%x) %s",
	registry, n, rc, GSLastErrorStr(rc));
      return NO;
    }

  [serverLock lock];
  a = NSMapGet(portToNamesMap, port);
  if (a != nil)
    {
      a = [[NSMutableArray alloc] init];
      NSMapInsert(portToNamesMap, port, a);
      RELEASE(a);
    }
  [a addObject: [name copy]];
  [serverLock unlock];

  return YES;
}

- (BOOL) removePortForName: (NSString *)name
{
  NSString	*n;
  int		rc;

  NSDebugLLog(@"NSMessagePortNameServer", @"removePortForName: %@", name);
  n = [[self class] _translate: name];
  rc = RegDeleteValueW(key, UNISTR(n));

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

  NSDebugLLog(@"NSMessagePortNameServer", @"removePort: %@", port);

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
  NSDebugLLog(@"NSMessagePortNameServer",
    @"removePort: %@  forName: %@", port, name);

  if ([self portForName: name onHost: @""] == port)
    {
      return [self removePortForName: name];
    }
  return NO;
}

@end

