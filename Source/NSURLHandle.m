/* NSURLHandle.m - Class NSURLHandle
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 	Jan 1999
   Update:	Richard Frith-Macdonald <rfm@gnu.org>
   Date:	Sep 2000
   
   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSFileManager.h>

@class	GSFileURLHandle;
@class	GSHTTPURLHandle;

@implementation NSURLHandle

static NSLock		*registryLock = nil;
static NSMutableArray	*registry = nil;
static Class		NSURLHandleClass = 0;

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)url
{
  /*
   * Each subclass is supposed to do its own caching, so we must
   * find the correct subclass and ask it for its cached handle.
   */
  if (self == NSURLHandleClass)
    {
      Class	c = [self URLHandleClassForURL: url];

      if (c == self || c == 0)
	{
	  return nil;
	}
      else
	{
	  return [c cachedHandleForURL: url];
	}
    }
  else
    {
      [self subclassResponsibility: _cmd];
      return nil;
    }
}

+ (BOOL) canInitWithURL: (NSURL*)url
{
  /*
   * The semi-abstract base class can't handle ANY scheme
   */
  return NO;
}

+ (void) initialize
{
  if (self == [NSURLHandle class])
    {
      NSURLHandleClass = self;
      registry = [NSMutableArray new];
      registryLock = [NSLock new];
      [self registerURLHandleClass: [GSFileURLHandle class]];
      [self registerURLHandleClass: [GSHTTPURLHandle class]];
    }
}

+ (void) registerURLHandleClass: (Class)urlHandleSubclass
{
  /*
   * Maintain a registry of classes that handle various schemes
   * Re-adding a class moves it to the end of the registry - so it will
   * be used in preference to any class added earlier.
   */
  [registryLock lock];
  NS_DURING
    {
      [registry removeObjectIdenticalTo: urlHandleSubclass];
      [registry addObject: urlHandleSubclass];
    }
  NS_HANDLER
    {
      [registryLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [registryLock unlock];
}

+ (Class) URLHandleClassForURL: (NSURL*)url
{
  unsigned	count;
  Class		c = 0;

  [registryLock lock];
  NS_DURING
    {
      count = [registry count];

      /*
       * Find a class to handle the URL, try most recently registered first.
       */
      while (count-- > 0)
	{
	  id	found = [registry objectAtIndex: count];

	  if ([found canInitWithURL: url] == YES)
	    {
	      c = (Class)found;
	    }
	}
    }
  NS_HANDLER
    {
      [registryLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [registryLock unlock];
  return c;
}

/*
 * Add a client object, making sure that it doesn't occur more than once.
 */
- (void) addClient: (id <NSURLHandleClient>)client
{
  RETAIN((id)client);
  [_clients removeObjectIdenticalTo: client];
  [_clients addObject: client];
  RELEASE((id)client);
}

- (NSData*) availableResourceData
{
  if (_status == NSURLHandleLoadInProgress)
    {
      return nil;
    }
  return _data;
}

- (void) backgroundLoadDidFailWithReason: (NSString*)reason
{
  NSEnumerator			*enumerator = [_clients objectEnumerator];
  id <NSURLHandleClient>	client;

  _status = NSURLHandleLoadFailed;
  DESTROY(_data);
  ASSIGNCOPY(_failure, reason);
  
  while ((client = [enumerator nextObject]) != nil)
    {
      [client URLHandle: self resourceDidFailLoadingWithReason: _failure];
    }
}

- (void) beginLoadInBackground
{
  _status = NSURLHandleLoadInProgress;
  DESTROY(_data);
  _data = [NSMutableData new];
  [_clients makeObjectsPerformSelector:
    @selector(URLHandleResourceDidBeginLoading:)
    withObject: self];
}

- (void) cancelLoadInBackground
{
  _status = NSURLHandleNotLoaded;
  DESTROY(_data);
  [_clients makeObjectsPerformSelector:
    @selector(URLHandleResourceDidCancelLoading:)
    withObject: self];
  [self endLoadInBackground];
}

- (void) dealloc
{
  RELEASE(_data);
  RELEASE(_failure);
  RELEASE(_clients);
  [super dealloc];
}

/*
 * Mathod called by subclasses during process of loading a resource.
 * The base class maintains a copy of the data being read in and
 * accumulates separate parts of the data.
 */
- (void) didLoadBytes: (NSData*)newData
	 loadComplete: (BOOL)loadComplete
{
  NSEnumerator			*enumerator;
  id <NSURLHandleClient>	client;
  
  /*
   * Let clients know we are starting loading (unless this has already been
   * done).
   */
  if (_status != NSURLHandleLoadInProgress)
    {
      _status = NSURLHandleLoadInProgress;
      DESTROY(_data);
      _data = [NSMutableData new];
      [_clients makeObjectsPerformSelector:
	@selector(URLHandleResourceDidBeginLoading:)
	withObject: self];
    }

  /*
   * If we have been given nil data, there must have been a failure!
   */
  if (newData == nil)
    {
      [self backgroundLoadDidFailWithReason: @"nil data"];
      return;
    }

  /*
   * Let clients know we have read some data.
   */
  enumerator = [_clients objectEnumerator];
  while ((client = [enumerator nextObject]) != nil)
    {
      [client URLHandle: self resourceDataDidBecomeAvailable: newData];
    }

  /*
   * Accumulate data in cache.
   */
  [_data appendData: newData];

  if (loadComplete == YES)
    {
      /*
       * Let clients know we have finished loading.
       */
      _status = NSURLHandleLoadSucceeded;
      [_clients makeObjectsPerformSelector:
	@selector(URLHandleResourceDidFinishLoading:)
	withObject: self];
    }
}

- (void) endLoadInBackground
{
  if (_status == NSURLHandleLoadInProgress)
    {
      id	tmp = _data;

      _data = [tmp copy];
      RELEASE(tmp);
    }
  _status = NSURLHandleNotLoaded;
}

- (NSString*) failureReason
{
  if (_status == NSURLHandleLoadFailed)
    return _failure;
  else
    return nil;
}

- (void) flushCachedData
{
  DESTROY(_data);
}

- (id) init
{
  return [self initWithURL: nil cached: NO];
}

- (id) initWithURL: (NSURL*)url
	    cached: (BOOL)cached
{
  _status = NSURLHandleNotLoaded;
  _clients = [NSMutableArray new];
  return self;
}

/*
 * Do a background load by using loadInForeground -
 * if this method is not overridden, loadInForeground MUST be.
 */
- (void) loadInBackground
{
  NSData	*d;

  [self beginLoadInBackground];
  d = [self loadInForeground]; 
  if (d == nil)
    {
      [self backgroundLoadDidFailWithReason: @"foreground load returned nil"];
    }
  else
    {
      [self didLoadBytes: d loadComplete: YES];
    }
  [self endLoadInBackground];
}

/*
 * Do a foreground load by using loadInBackground -
 * if this method is not overridden, loadInBackground MUST be.
 */
- (NSData*) loadInForeground
{
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];

  [self loadInBackground];
  while ([self status] == NSURLHandleLoadInProgress)
    {
      NSDate	*limit;

      limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 1.0];
      [loop runUntilDate: limit];
      RELEASE(limit);
    } 
  return _data;
}

- (id) propertyForKey: (NSString*)propertyKey
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) propertyForKeyIfAvailable: (NSString*)propertyKey
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) removeClient: (id <NSURLHandleClient>)client
{
  [_clients removeObjectIdenticalTo: client];
}

- (NSData*) resourceData
{
  if (_status == NSURLHandleLoadSucceeded)
    {
      return [self availableResourceData];
    }
  else
    {
      NSData	*d = [self loadInForeground];

      if (d != nil)
	{
	  ASSIGNCOPY(_data, d);
	}
      return _data;
    }
}

- (NSURLHandleStatus) status
{
  return _status;
}

- (BOOL) writeData: (NSData*)data
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) writeProperty: (id)propertyValue
		forKey: (NSString*)propertyKey
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end

@interface	GSFileURLHandle : NSURLHandle
{
  NSString		*_path;
  NSMutableDictionary	*_attributes;
}
@end

@implementation	GSFileURLHandle

static NSMutableDictionary	*fileCache = nil;
static NSLock			*fileLock = nil;

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)url
{
  NSURLHandle	*obj = nil;

  if ([url isFileURL] == YES)
    {
      NSString	*path = [url path];

      path = [path stringByStandardizingPath];
      [fileLock lock];
      NS_DURING
	{
	  obj = [fileCache objectForKey: path];
	  AUTORELEASE(RETAIN(obj));
	}
      NS_HANDLER
	{
	  [fileLock unlock];
	  [localException raise];
	}
      NS_ENDHANDLER
      [fileLock unlock];
    }
  return obj;
}

+ (BOOL) canInitWithURL: (NSURL*)url
{
  if ([url isFileURL] == YES)
    {
      return YES;
    }
  return NO;
}

+ (void) initialize
{
  fileCache = [NSMutableDictionary new];
  fileLock = [NSLock new];
}

- (void) dealloc
{
  RELEASE(_path);
  [super dealloc];
}

- (id) initWithURL: (NSURL*)url
	    cached: (BOOL)cached
{
  NSString	*path;

  if ([url isFileURL] == NO)
    {
      NSLog(@"Attempt to init GSFileURLHandle with bad URL");
      RELEASE(self);
      return nil;
    }
  path = [url path];
  path = [path stringByStandardizingPath];

  if (cached == YES)
    {
      id	obj;

      [fileLock lock];
      NS_DURING
	{
	  obj = [fileCache objectForKey: path];
	  if (obj != nil)
	    {
	      DESTROY(self);
	      RETAIN(obj);
	    }
	}
      NS_HANDLER
	{
	  [fileLock unlock];
	  [localException raise];
	}
      NS_ENDHANDLER
      [fileLock unlock];
      if (obj != nil)
	{
	  return obj;
	}
    }

  if ((self = [super initWithURL: url cached: cached]) != nil)
    {
      _path = [path copy];
      if (cached == YES)
	{
	  [fileLock lock];
	  NS_DURING
	    {
	      [fileCache setObject: self forKey: _path];
	    }
	  NS_HANDLER
	    {
	      [fileLock unlock];
	      [localException raise];
	    }
	  NS_ENDHANDLER
	  [fileLock unlock];
	}
    }
  return self;
}

- (NSData*) loadInForeground
{
  NSData	*d = [NSData dataWithContentsOfFile: _path];

  [self didLoadBytes: d loadComplete: YES];
  return d;
}

- (id) propertyForKey: (NSString*)propertyKey
{
  NSDictionary	*dict;

  dict = [[NSFileManager defaultManager] fileAttributesAtPath: _path
						 traverseLink: YES];
  RELEASE(_attributes);
  _attributes = [dict mutableCopy];
  return [_attributes objectForKey: propertyKey];
}

- (id) propertyForKeyIfAvailable: (NSString*)propertyKey
{
  return [_attributes objectForKey: propertyKey];
}

- (BOOL) writeData: (NSData*)data
{
  if ([data writeToFile: _path atomically: YES] == YES)
    {
      ASSIGNCOPY(_data, data);
      return YES;
    }
  return NO;
}

- (BOOL) writeProperty: (id)propertyValue
		forKey: (NSString*)propertyKey
{
  if ([self propertyForKey: propertyKey] == nil)
    {
      return NO;	/* Not a valid file property key.	*/
    }
  [_attributes setObject: propertyValue forKey: propertyKey];
  return [[NSFileManager defaultManager] changeFileAttributes: _attributes
						       atPath: _path];
}

@end

