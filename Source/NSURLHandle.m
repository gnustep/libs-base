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
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSMapTable.h>

@class	GSFileURLHandle;

@implementation NSURLHandle

static NSMutableArray	*registry = nil;

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)url
{
  /*
   * Each subclass is supposed to do its own caching, so we must
   * find the correct subclass and ask it for its cached handle.
   */
  if (self == [NSURLHandle class])
    {
      Class	c = [self URLHandleClassForURL: url];

      return [c cachedHandleForURL: url];
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
      registry = [NSMutableArray new];
      [self registerURLHandleClass: [GSFileURLHandle class]];
    }
}

+ (void) registerURLHandleClass: (Class)urlHandleSubclass
{
  /*
   * Maintain a registry of classes that handle various schemes
   * Re-adding a class moves it to the end of the registry - so it will
   * be used in preference to any class added earlier.
   */
  [registry removeObjectIdenticalTo: urlHandleSubclass];
  [registry addObject: urlHandleSubclass];
}

+ (Class) URLHandleClassForURL: (NSURL*)url
{
  unsigned	count = [registry count];

  /*
   * Find a class to handle the URL, try most recently registered first.
   */
  while (count-- > 0)
    {
      id	found = [registry objectAtIndex: count];

      if ([found canInitWithURL: url] == YES)
	{
	  return (Class)found;
	}
    }
  return 0;
}

- (void) addClient: (id <NSURLHandleClient>)client
{
  [_clients addObject: client];
}

- (NSData*) availableResourceData
{
  return AUTORELEASE([_data copy]);
}

- (void) backgroundLoadDidFailWithReason: (NSString*)reason
{
  NSEnumerator			*enumerator = [_clients objectEnumerator];
  id <NSURLHandleClient>	client;

  _status = NSURLHandleLoadFailed;
  [_data setLength: 0];
  ASSIGNCOPY(_failure, reason);
  
  while ((client = [enumerator nextObject]) != nil)
    {
      [client URLHandle: self resourceDidFailLoadingWithReason: _failure];
    }
}

- (void) beginLoadInBackground
{
  _status = NSURLHandleLoadInProgress;
  [_data setLength: 0];
  [_clients makeObjectsPerformSelector:
    @selector(URLHandleResourceDidBeginLoading:)
    withObject: self];
}

- (void) cancelLoadInBackground
{
  _status = NSURLHandleNotLoaded;
  [_data setLength: 0];
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
      [_data setLength: 0];
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
  _status = NSURLHandleNotLoaded;
  [_data setLength: 0];
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
  [_data setLength: 0];
}

- (id) init
{
  _status = NSURLHandleNotLoaded;
  _clients = [NSMutableArray new];
  _data = [NSMutableData new];
  return self;
}

- (id) initWithURL: (NSURL*)url
	    cached: (BOOL)cached
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) loadInBackground
{
  [self subclassResponsibility: _cmd];
}

- (NSData*) loadInForeground
{
  [self subclassResponsibility: _cmd];
  return nil;
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
	  [_data setData: d];
	}
      return d;
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
  NSString	*_path;
}
@end

@implementation	GSFileURLHandle

static NSMutableDictionary	*fileCache = nil;

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)url
{
  NSURLHandle	*obj = nil;

  if ([url isFileURL] == YES)
    {
      NSString	*path = [url path];

      path = [path stringByStandardizingPath];
      obj = [fileCache objectForKey: path];
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

      obj = [fileCache objectForKey: path];
      if (obj != nil)
	{
	  RELEASE(self);
	  self = RETAIN(obj);
	  return self;
	}
    }
  self = [super init];
  if (self != nil)
    {
      _path = [path copy];
      if (cached == YES)
	{
	  [fileCache setObject: self forKey: _path];
	  RELEASE(self);
	}
    }
  return self;
}

- (void) loadInBackground
{
  [self loadInForeground];
}

- (NSData*) loadInForeground
{
  NSData	*d = [NSData dataWithContentsOfFile: _path];

  [self didLoadBytes: d loadComplete: YES];
  return d;
}

- (id) propertyForKey: (NSString*)propertyKey
{
  return nil;
}

- (id) propertyForKeyIfAvailable: (NSString*)propertyKey
{
  return nil;
}

- (BOOL) writeData: (NSData*)data
{
  /* FIXME */
  [self notImplemented: _cmd];
  return NO;
}

- (BOOL) writeProperty: (id)propertyValue
		forKey: (NSString*)propertyKey
{
  return NO;
}

@end

