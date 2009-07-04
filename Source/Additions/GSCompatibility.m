/* GSCompatibility - Extra definitions for compiling on MacOSX

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Written by:  Stephane Corthesy on Sat Nov 16 2002.

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

*/
#include "config.h"
#include <objc/objc-class.h>
#include "GNUstepBase/GSCategories.h"
#include "GNUstepBase/GCObject.h"

/* Avoid compiler warnings about internal method
*/
@interface	NSError (GNUstep)
+ (NSError*) _last;
@end

NSThread *GSCurrentThread()
{
  return [NSThread currentThread];
}

NSMutableDictionary *GSCurrentThreadDictionary()
{
  return [[NSThread currentThread] threadDictionary];
}

NSArray *NSStandardLibraryPaths()
{
  return NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
					       NSAllDomainsMask, YES);
}

// Defined in NSDecimal.m
void NSDecimalFromComponents(NSDecimal *result,
			     unsigned long long mantissa,
			     short exponent, BOOL negative)
{
  *result = [[NSDecimalNumber decimalNumberWithMantissa:mantissa
			      exponent:exponent
			      isNegative:negative] decimalValue];
}

// Defined in NSDebug.m
NSString*
GSDebugMethodMsg(id obj, SEL sel, const char *file, int line, NSString *fmt)
{
  NSString	*message;
  Class		cls = (Class)obj;
  char		c = '+';

  if ([obj isInstance] == YES)
    {
      c = '-';
      cls = [obj class];
    }
  message = [NSString stringWithFormat: @"File %s: %d. In [%@ %c%@] %@",
    file, line, NSStringFromClass(cls), c, NSStringFromSelector(sel), fmt];
  return message;
}

NSString*
GSDebugFunctionMsg(const char *func, const char *file, int line, NSString *fmt)
{
  NSString *message;

  message = [NSString stringWithFormat: @"File %s: %d. In %s %@",
    file, line, func, fmt];
  return message;
}

@implementation NSArray (GSCompatibility)

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
  unsigned	c = [array count];
  id		objects[c];

  if ([array isProxy])
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [array objectAtIndex: i];
	}
    }
  else
    {
      [array getObjects: objects];
    }
  if (shouldCopy == YES)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [objects[i] copy];
	}
      self = [self initWithObjects: objects count: c];
#if GS_WITH_GC == 0
      while (i > 0)
	{
	  [objects[--i] release];
	}
#endif
    }
  else
    {
      self = [self initWithObjects: objects count: c];
    }
  return self;
}

@end

@interface NSDistantObject (GSCategoriesRevealed)
// This method is implemented in MacOS X 10.2.4, but is not public
+ (void) _enableLogging:(BOOL)flag;
@end

@implementation NSDistantObject (GSCompatibility)

+ (void) setDebug: (int)val
{
  if ([self respondsToSelector:@selector(_enableLogging:)])
    [self _enableLogging:!!val];
}
@end

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>

@implementation NSFileHandle(GSCompatibility)
// From GSFileHandle.m

static BOOL
getAddr(NSString* name, NSString* svc, NSString* pcl, struct  sockaddr_in *sin)
{
  const char        *proto = "tcp";
  struct servent    *sp;

  if (pcl)
    {
      proto = [pcl lossyCString];
    }
  memset(sin, '\0', sizeof(*sin));
  sin->sin_family = AF_INET;

  /*
   *    If we were given a hostname, we use any address for that host.
   *    Otherwise we expect the given name to be an address unless it  is
   *    a null (any address).
   */
  if (name)
    {
      NSHost*        host = [NSHost hostWithName: name];

      if (host != nil)
        {
	  name = [host address];
        }
#ifndef    HAVE_INET_ATON
      sin->sin_addr.s_addr = inet_addr([name lossyCString]);
      if (sin->sin_addr.s_addr == INADDR_NONE)
#else
	if (inet_aton([name lossyCString], &sin->sin_addr) == 0)
#endif
	  {
	    return NO;
	  }
    }
  else
    {
      sin->sin_addr.s_addr = NSSwapHostIntToBig(INADDR_ANY);
    }
  if (svc == nil)
    {
      sin->sin_port = 0;
      return YES;
    }
  else if ((sp = getservbyname([svc lossyCString], proto)) == 0)
    {
      const char*     ptr = [svc lossyCString];
      int             val = atoi(ptr);

      while (isdigit(*ptr))
	{
	  ptr++;
	}
      if (*ptr == '\0' && val <= 0xffff)
	{
	  unsigned short       v = val;

	  sin->sin_port = NSSwapHostShortToBig(v);
	  return YES;
	}
      else if (strcmp(ptr, "gdomap") == 0)
	{
	  unsigned short       v;
#ifdef    GDOMAP_PORT_OVERRIDE
	  v = GDOMAP_PORT_OVERRIDE;
#else
	  v = 538;    // IANA allocated port
#endif
	  sin->sin_port = NSSwapHostShortToBig(v);
	  return YES;
	}
      else
	{
	  return NO;
	}
    }
  else
    {
      sin->sin_port = sp->s_port;
      return YES;
    }
}

- (id) initAsServerAtAddress: (NSString*)a
                           service: (NSString*)s
                          protocol: (NSString*)p
{
#ifndef    BROKEN_SO_REUSEADDR
  int    status = 1;
#endif
  int    net;
  struct sockaddr_in    sin;
  int    size = sizeof(sin);

  if (getAddr(a, s, p, &sin) == NO)
    {
      RELEASE(self);
      NSLog(@"bad address-service-protocol combination");
      return  nil;
    }

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
    {
      NSLog(@"unable to create socket - %@", [NSError _last]);
      RELEASE(self);
      return nil;
    }

#ifndef    BROKEN_SO_REUSEADDR
  /*
   * Under decent systems, SO_REUSEADDR means that the port can be  reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  setsockopt(net, SOL_SOCKET, SO_REUSEADDR, (char *)&status,  sizeof(status));
#endif

  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) < 0)
    {
      NSLog(@"unable to bind to port %s:%d - %@",  inet_ntoa(sin.sin_addr),
	    NSSwapBigShortToHost(sin.sin_port),  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (listen(net, 5) < 0)
    {
      NSLog(@"unable to listen on port - %@",  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (getsockname(net, (struct sockaddr*)&sin, &size) < 0)
    {
      NSLog(@"unable to get socket name - %@",  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  self = [self initWithFileDescriptor: net closeOnDealloc: YES];

  return self;
}

+ (id) fileHandleAsServerAtAddress: (NSString*)address
                           service: (NSString*)service
                          protocol: (NSString*)protocol
{
  id    o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsServerAtAddress: address
                                      service: service
                                     protocol: protocol]);
}

- (NSString*) socketAddress
{
  struct sockaddr_in    sin;
  int    size = sizeof(sin);

  if (getsockname([self fileDescriptor], (struct sockaddr*)&sin,  &size) < 0)
    {
      NSLog(@"unable to get socket name - %@",  [NSError _last]);
      return nil;
    }

  return [[[NSString alloc] initWithCString:  (char*)inet_ntoa(sin.sin_addr)]
	   autorelease];
}

@end


@implementation NSProcessInfo(GSCompatibility)

static NSMutableSet	*_debug_set = nil;

BOOL GSDebugSet(NSString *level)
// From GNUStep's
{
  static IMP debugImp = 0;
  static SEL debugSel;

  if (debugImp == 0)
    {
      debugSel = @selector(member:);
      if (_debug_set == nil)
	{
	  [[NSProcessInfo processInfo] debugSet];
	}
      debugImp = [_debug_set methodForSelector: debugSel];
    }
  if ((*debugImp)(_debug_set, debugSel, level) == nil)
    {
      return NO;
    }
  return YES;
}

- (NSMutableSet *) debugSet
// Derived from GNUStep's
{
  if (_debug_set == nil)
    {
      int		argc = [[self arguments] count];
      NSMutableSet	*mySet;
      int		i;

      mySet = [NSMutableSet new];
      for (i = 0; i < argc; i++)
	{
	  NSString	*str = [[self arguments] objectAtIndex:i];

	  if ([str hasPrefix: @"--GNU-Debug="])
	    [mySet addObject: [str substringFromIndex: 12]];
	}
      _debug_set = mySet;
    }
  return _debug_set;
}

@end

@implementation NSString(GSCompatibility)

// From GNUStep
/**
 * If the string consists of the words 'true' or 'yes' (case insensitive)
 * or begins with a non-zero numeric value, return YES, otherwise return
 * NO.
 */
- (BOOL) boolValue
{
  if ([self caseInsensitiveCompare: @"YES"] == NSOrderedSame)
    {
        return YES;
    }
  if ([self caseInsensitiveCompare: @"true"] == NSOrderedSame)
    {
        return YES;
    }
  return [self intValue] != 0 ? YES : NO;
}

- (NSString*) substringFromRange:(NSRange)range
{
  return [self substringWithRange:range];
}

@end

@implementation NSInvocation(GSCompatibility)
- (retval_t) returnFrame:(arglist_t)args
{
#warning (stephane@sente.ch) Not implemented
  return (retval_t)[self notImplemented:_cmd];
}

- (id) initWithArgframe:(arglist_t)args selector:(SEL)selector
{
#warning (stephane@sente.ch) Not implemented
  return [self notImplemented:_cmd];
}

@end

@implementation NSObject(GSCompatibility)

+ (id) notImplemented:(SEL)selector
{
  [NSException raise: NSGenericException
	       format: @"method %s not implemented in %s(class)",
	       selector ? GSNameFromSelector(selector) : "(null)",
	       GSClassNameFromObject(self)];
  return nil;
}

// In NSObject.m, category GNU
- (BOOL) isInstance
{
  return GSObjCIsInstance(self);
}

@end

@implementation NSBundle(GSCompatibility)

// In NSBundle.m
+ (NSString *) pathForLibraryResource: (NSString *)name
			       ofType: (NSString *)ext
			  inDirectory: (NSString *)bundlePath
{
  NSString	*path = nil;
  NSString	*bundle_path = nil;
  NSArray	*paths;
  NSBundle	*bundle;
  NSEnumerator	*enumerator;

  /* Gather up the paths */
  paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                              NSAllDomainsMask, YES);

  enumerator = [paths objectEnumerator];
  while ((path == nil) && (bundle_path = [enumerator nextObject]))
    {
      bundle = [self bundleWithPath: bundle_path];
      path = [bundle pathForResource: name
                              ofType: ext
                         inDirectory: bundlePath];
    }

  return path;
}

@end

