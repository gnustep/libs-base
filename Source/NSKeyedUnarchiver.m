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
#include <Foundation/NSNull.h>
#include <Foundation/NSValue.h>

/*
 *      Setup for inline operation of arrays.
 */
#define GSI_ARRAY_RETAIN(A, X)
#define GSI_ARRAY_RELEASE(A, X)
#define GSI_ARRAY_TYPES GSUNION_OBJ|GSUNION_SEL|GSUNION_PTR


#include <GNUstepBase/GSIArray.h>

#define	_IN_NSKEYEDUNARCHIVER_M	1
#include <Foundation/NSKeyedArchiver.h>
#undef	_IN_NSKEYEDUNARCHIVER_M

NSString * const NSInvalidUnarchiveOperationException
  = @"NSInvalidUnarchiveOperationException";

static NSMapTable	globalClassMap = 0;

#define	GETVAL \
  NSString	*oldKey = aKey; \
  id		o; \
  \
  if ([aKey isKindOfClass: [NSString class]] == NO) \
    { \
      [NSException raise: NSInvalidArgumentException \
		  format: @"%@, bad key '%@' in %@", \
	NSStringFromClass([self class]), aKey, NSStringFromSelector(_cmd)]; \
    } \
  if ([aKey hasPrefix: @"$"] == YES) \
    { \
      aKey = [@"$" stringByAppendingString: aKey]; \
    } \
  if ([_keyMap objectForKey: aKey] != nil) \
    { \
      [NSException raise: NSInvalidArgumentException \
		  format: @"%@, duplicate key '%@' in %@", \
	NSStringFromClass([self class]), aKey, NSStringFromSelector(_cmd)]; \
    } \
  o = [_keyMap objectForKey: aKey];



@interface NSKeyedUnarchiver (Private)
- (id) _decodeObject: (unsigned)index;
@end

@implementation NSKeyedUnarchiver (Private)
- (id) _decodeObject: (unsigned)index
{
  id	o;
  id	obj;

  /*
   * If the referenced object is already in _objMap
   * we simply return it (the object at index 0 maps to nil)
   */
  obj = GSIArrayItemAtIndex(_objMap, index).obj;
  if (obj != nil)
    {
      if (obj == GSIArrayItemAtIndex(_objMap, 0).obj)
	{
	  return nil;
	}
      return obj;
    }

  /*
   * No mapped object, so we decode from the property list
   * in _objects
   */
  obj = [_objects objectAtIndex: index];
  if ([obj isKindOfClass: [NSDictionary class]] == YES)
    {
      NSString		*classname;
      NSArray		*classes;
      Class		c;
      id		r;
      NSDictionary	*savedKeyMap;
      unsigned		savedCursor;

      /*
       * Fetch the class information from the table.
       */
      o = [obj objectForKey: @"$class"];
      o = [o objectForKey: @"CF$UID"];
      o = [_objects objectAtIndex: [o intValue]];
      classname = [o objectForKey: @"$classname"];
      classes = [o objectForKey: @"$classes"];
      c = [self classForClassName: classname];
      if (c == nil)
	{
	  c = [[self class] classForClassName: classname];
	  if (c == nil)
	    {
	      c = NSClassFromString(classname);
	      if (c == nil)
		{
		  c = [_delegate unarchiver: self
		    cannotDecodeObjectOfClassName: classname
		    originalClasses: classes];
		  if (c == nil)
		    {
		      [NSException raise:
			NSInvalidUnarchiveOperationException
			format: @"[%@ +%@]: no class for name '%@'",
			NSStringFromClass([self class]),
			NSStringFromSelector(_cmd), 
			classname];
		    }
		}
	    }
	}


      savedCursor = _cursor;
      savedKeyMap = _keyMap;

      _cursor = 0;			// Starting object decode
      _keyMap = obj;			// Dictionary describing object

      o = [c allocWithZone: _zone];	// Create instance.
      r = [o initWithCoder: self];
      if (r != o)
	{
	  [_delegate unarchiver: self
	      willReplaceObject: o
		     withObject: r];
	  o = r;
	}
      r = [o awakeAfterUsingCoder: self];
      if (r != o)
	{
	  [_delegate unarchiver: self
	      willReplaceObject: o
		     withObject: r];
	  o = r;
	}

      if (_delegate != nil)
	{
	  r = [_delegate unarchiver: self didDecodeObject: o];
	  if (r != o)
	    {
	      [_delegate unarchiver: self
		  willReplaceObject: o
			 withObject: r];
	      o = r;
	    }
	}

      if (o == nil)
	{
	  obj = RETAIN(GSIArrayItemAtIndex(_objMap, 0).obj);
	}
      else
	{
	  obj = o;
	}

      _keyMap = savedKeyMap;
      _cursor = savedCursor;
    }
  else
    {
      RETAIN(obj);	// Use the decoded object directly
    }

  GSIArraySetItemAtIndex(_objMap, (GSIArrayItem)obj, index);
  return obj;
}
@end


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
  return (Class)NSMapGet(_clsMap, (void*)aString);
}

- (BOOL) containsValueForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      return YES;
    }
  return NO;
}

- (void) dealloc
{
  DESTROY(_archive);
  if (_clsMap != 0)
    {
      NSFreeMapTable(_clsMap);
      _clsMap = 0;
    }
  if (_objMap != 0)
    {
      NSZone    *z = _objMap->zone;

      GSIArrayClear(_objMap);
      NSZoneFree(z, (void*)_objMap);
    }
  [super dealloc];
}

- (BOOL) decodeBoolForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  return [o boolValue];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return NO;
}

- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
		      returnedLength: (unsigned*)length
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSData class]] == YES)
	{
	  *length = [o length];
	  return [o bytes];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  *length = 0;
  return 0;
}

- (double) decodeDoubleForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  return [o doubleValue];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return 0.0;
}

- (float) decodeFloatForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  return [o floatValue];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return 0.0;
}

- (int) decodeIntForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  long long	l = [o longLongValue];

	  return l;
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return 0;
}

- (int32_t) decodeInt32ForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  long long	l = [o longLongValue];

	  return l;
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return 0;
}

- (int64_t) decodeInt64ForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      if ([o isKindOfClass: [NSNumber class]] == YES)
	{
	  long long	l = [o longLongValue];

	  return l;
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return 0;
}

- (id) decodeObject
{
  NSString	*key = [NSString stringWithFormat: @"$%d", _cursor++];
  NSNumber	*pos;
  id		o = [_keyMap objectForKey: key];

  if (o != nil)
    {
      if ([o isKindOfClass: [NSDictionary class]] == YES
	&& (pos = [o objectForKey: @"CF$UID"]) != nil)
	{
	  int	index = [pos intValue];

	  return [self _decodeObject: index];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    key, o];
	}
    }
  return nil;
}

- (id) decodeObjectForKey: (NSString*)aKey
{
  GETVAL
  if (o != nil)
    {
      NSNumber	*pos;

      if ([o isKindOfClass: [NSDictionary class]] == YES
	&& (pos = [o objectForKey: @"CF$UID"]) != nil)
	{
	  int	index = [pos intValue];

	  return [self _decodeObject: index];
	}
      else
	{
	  [NSException raise: NSInvalidUnarchiveOperationException
		      format: @"[%@ +%@]: value for key(%@) is '%@'",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
	    oldKey, o];
	}
    }
  return nil;
}

- (id) delegate
{
  return _delegate;
}

- (void) finishDecoding
{
  [_delegate unarchiverWillFinish: self];
  DESTROY(_archive);
  [_delegate unarchiverDidFinish: self];
}

- (id) initForReadingWithData: (NSData*)data
{
  self = [super init];
  if (self)
    {
      NSPropertyListFormat	format;
      NSString			*error;

      _zone = [self zone];
      _archive = [NSPropertyListSerialization propertyListFromData: data
	mutabilityOption: NSPropertyListImmutable
	format: &format
	errorDescription: &error];
      if (_archive == nil)
	{
	  DESTROY(self);
	}
      else
	{
	  unsigned	count;
	  unsigned	i;

	  RETAIN(_archive);
	  _archiverClass = [_archive objectForKey: @"$archiver"];
	  _version = [_archive objectForKey: @"$version"];

	  _objects = [_archive objectForKey: @"$objects"];
	  _keyMap = [_archive objectForKey: @"$top"];

	  _clsMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
	    NSNonOwnedPointerMapValueCallBacks, 0);
	  _objMap = NSZoneMalloc(_zone, sizeof(GSIArray_t));
	  count = [_objects count];
	  GSIArrayInitWithZoneAndCapacity(_objMap, _zone, count);
	  // Add marker for nil object
	  GSIArrayAddItem(_objMap, (GSIArrayItem)(void*)[NSNull null]);
	  // Add markers for unencoded objects.
	  for (i = 1; i < count; i++)
	    {
	      GSIArrayAddItem(_objMap, (GSIArrayItem)(void*)0);
	    }
	}
    }
  return self;
}

- (void) setClass: (Class)aClass forClassName: (NSString*)aString
{
  if (aString == nil)
    {
      NSMapRemove(_clsMap, (void*)aString);
    }
  else
    {
      NSMapInsert(_clsMap, (void*)aString, (void*)aClass);
    }
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

