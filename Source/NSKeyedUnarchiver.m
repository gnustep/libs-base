/** Implementation for NSKeyedUnarchiver for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: January 2004
   
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
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   */ 

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>

#include <GNUstepBase/GSIArray.h>
#include <GNUstepBase/GSIMap.h>

#define	_IN_NSKEYEDUNARCHIVER_M	1
#include <Foundation/NSKeyedArchiver.h>
#undef	_IN_NSKEYEDUNARCHIVER_M

static NSMapTable	globalClassMap = 0;

NSString * const NSInvalidUnarchiveOperationException
  = @"NSInvalidUnarchiveOperationException";

@implementation NSKeyedUnarchiver

+ (Class) classForClassName: (NSString*)aString
{
  return (Class)NSMapGet(globalClassMap, (void*)aString);
}

+ (void) initialize
{
  if (globalClassMap == 0)
    {
      globalClassMap = 
	NSCreateMapTable(NSObjectMapKeyCallBacks,
			  NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

+ (void) setClass: (Class)aClass forClassName: (NSString*)aString
{
  if (aClass == nil)
    {
      NSMapRemove(globalClassMap, (void*)aString);
    }
  else
    {
      NSMapInsert(globalClassMap, (void*)aString, aClass);
    }
}

/*
 * When I tried this on MacOS 10.3 it encoded the object with the key 'root',
 * so this implementation does the same.
 */
+ (id) unarchiveObjectWithData: (NSData*)data
{
  NSKeyedUnarchiver	*u = nil;
  id			o = nil;

  NS_DURING
    {
      u = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
      o = RETAIN([u decodeObjectForKey: @"root"]);
      [u finishDecoding];
      DESTROY(u);
    }
  NS_HANDLER
    {
      DESTROY(u);
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(o);
}

+ (id) unarchiveObjectWithFile: (NSString*)aPath
{
  CREATE_AUTORELEASE_POOL(pool);
  NSData	*d;
  id		o;

  d = [NSData dataWithContentsOfFile: aPath];
  o = [self unarchiveObjectWithData: d];
  RETAIN(o);
  RELEASE(pool);
  return AUTORELEASE(o);
}

- (Class) classForClassName: (NSString*)aString
{
  [self notImplemented: _cmd];
  return nil;
}

- (BOOL) containsValueForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return NO;
}

- (BOOL) decodeBoolForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return NO;
}

- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
		      returnedLength: (unsigned*)length
{
  [self notImplemented: _cmd];
  *length = 0;
  return 0;
}

- (double) decodeDoubleForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return 0.0;
}

- (float) decodeFloatForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return 0.0;
}

- (int) decodeIntForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return 0;
}

- (int32_t) decodeInt32ForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return 0;
}

- (int64_t) decodeInt64ForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return 0;
}

- (id) decodeObjectForKey: (NSString*)aKey
{
  [self notImplemented: _cmd];
  return nil;
}

- (id) delegate
{
  return _delegate;
}

- (void) finishDecoding
{
  [self notImplemented: _cmd];
}

- (id) initForReadingWithData: (NSData*)data
{
  [self notImplemented: _cmd];
  return self;
}

- (void) setClass: (Class)aClass forClassName: (NSString*)aString
{
  [self notImplemented: _cmd];
}

- (void) setDelegate: (id)delegate
{
  _delegate = delegate;		// Not retained.
}

@end

@implementation NSObject (NSKeyedUnarchiverDelegate) 
- (Class) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  cannotDecodeObjectOfClassName: (NSString*)aName
  originalClasses: (NSArray*)classNames
{
  return nil;
}
- (id) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  didDecodeObject: (id)anObject
{
  return anObject;
}
- (void) unarchiverDidFinish: (NSKeyedUnarchiver*)anUnarchiver
{
}
- (void) unarchiverWillFinish: (NSKeyedUnarchiver*)anUnarchiver
{
}
- (void) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  willReplaceObject: (id)anObject
	 withObject: (id)newObject
{
}
@end

@implementation NSObject (NSKeyedUnarchiverObjectSubstitution) 
+ (Class) classForKeyedUnarchiver
{
  return self;
}
@end

