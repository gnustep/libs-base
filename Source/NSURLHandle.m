/* NSURLHandle.h - Class NSURLHandle
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by:	Manuel Guesdon <mguesdon@sbuilders.com>
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

//===================================================================================
@implementation NSURLHandle

//-----------------------------------------------------------------------------------
+(void)registerURLHandleClass:(Class)_urlHandleSubclass
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
+(Class)URLHandleClassForURL:(NSURL*)_url
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(id)initWithURL:(NSURL*)_url
		  cached:(BOOL)_cached
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(NSURLHandleStatus)status
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(NSString*)failureReason
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)addClient:(id <NSURLHandleClient>)_client
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)removeClient:(id <NSURLHandleClient>)_client
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)loadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)cancelLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(NSData*)resourceData
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(NSData*)availableResourceData
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)flushCachedData
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)backgroundLoadDidFailWithReason:(NSString*)reason
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)didLoadBytes:(NSData*)newData
	   loadComplete:(BOOL)_loadComplete
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
+(BOOL)canInitWithURL:(NSURL*)_url
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
+(NSURLHandle*)cachedHandleForURL:(NSURL*)_url
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(id)propertyForKey:(NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(id)propertyForKeyIfAvailable:(NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(BOOL)writeProperty:(id)propertyValue
			  forKey:(NSString*)propertyKey
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(BOOL)writeData:(NSData*)data
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(NSData*)loadInForeground
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)beginLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
};

//-----------------------------------------------------------------------------------
-(void)endLoadInBackground
{
  //FIXME
  [self notImplemented: _cmd];
};

@end
