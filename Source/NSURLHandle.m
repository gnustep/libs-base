/* NSURLHandle.m - Class NSURLHandle
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 		Jan 1999
   
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

/*
Note from Manuel Guesdon: 
* functions are not implemented. If someone has documentation or ideas on 
how it should work...
*/

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSMapTable.h>

//=============================================================================
@implementation NSURLHandle

static NSMapTable	*cache = 0;
static NSMutableArray	*registry = nil;

+ (void) initialize
{
  if (self == [NSURLHandle class])
    {
      cache = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSObjectMapValueCallBacks, 0);
      registry = [NSMutableArray new];
    }
}

+ (void) registerURLHandleClass: (Class)_urlHandleSubclass
{
  if ([registry indexOfObjectIdenticalTo: _urlHandleSubclass] == NSNotFound)
    {
      [registry addObject: _urlHandleSubclass];
    }
}

+ (Class) URLHandleClassForURL: (NSURL*)_url
{
  unsigned	count = [registry count];

  while (count-- > 0)
    {
      id	found = [registry objectAtIndex: count];

      if ([found canInitWithURL: _url] == YES)
	{
	  return (Class)found;
	}
    }
  return 0;
}

- (id) initWithURL: (NSURL*)_url
	    cached: (BOOL)_cached
{
  Class		concreteSubclass;
  NSURLHandle	*instance;

  if (_cached == YES)
    {
      instance = (id)NSMapGet(cache, (void*)_url);
      if (instance != nil)
	{
	  RELEASE(self);
	  return instance;
	}
    }
  concreteSubclass = [NSURLHandle URLHandleClassForURL: _url];
  if (concreteSubclass == 0)
    {
      NSLog(@"Attempt to init NSURLHandle with unsupported URL schema");
      RELEASE(self);
    }
  RELEASE(self);
  instance = [concreteSubclass alloc];
  instance = [instance initWithURL: _url cached: _cached];
  if (instance != nil)
    {
      NSMapInsert(cache, (void*)_url, (void*)instance);
    }
  return instance;
}

//-----------------------------------------------------------------------------
- (NSURLHandleStatus) status
{
  //FIXME
  [self notImplemented: _cmd];
  return (NSURLHandleStatus)0;
}

//-----------------------------------------------------------------------------
- (NSString*) failureReason
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (void) addClient: (id <NSURLHandleClient>)_client
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (void) removeClient: (id <NSURLHandleClient>)_client
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (void) loadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (void) cancelLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (NSData*) resourceData
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (NSData*) availableResourceData
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (void) flushCachedData
{
  NSResetMapTable(cache);
}

//-----------------------------------------------------------------------------
- (void) backgroundLoadDidFailWithReason: (NSString*)reason
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (void) didLoadBytes: (NSData*)newData
	   loadComplete: (BOOL)_loadComplete
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
+ (BOOL) canInitWithURL: (NSURL*)_url
{
  //FIXME
  [self notImplemented: _cmd];
  return NO;
}

//-----------------------------------------------------------------------------
+ (NSURLHandle*) cachedHandleForURL: (NSURL*)_url
{
  return (NSURLHandle*) NSMapGet(cache, (void*)_url);
}

//-----------------------------------------------------------------------------
- (id) propertyForKey: (NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (id) propertyForKeyIfAvailable: (NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (BOOL) writeProperty: (id)propertyValue
			  forKey: (NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
  return NO;
}

//-----------------------------------------------------------------------------
- (BOOL) writeData: (NSData*)data
{
  //FIXME
  [self notImplemented: _cmd];
  return NO;
}

//-----------------------------------------------------------------------------
- (NSData*) loadInForeground
{
  //FIXME
  [self notImplemented: _cmd];
  return nil;
}

//-----------------------------------------------------------------------------
- (void) beginLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
}

//-----------------------------------------------------------------------------
- (void) endLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
}

@end
