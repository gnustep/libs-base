/* Class for serialization in GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdoanld <richard@brainstorm.co.uk>
   Date: August 1997

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/fast.x>
#include <gnustep/base/mframe.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProxy.h>

@class	NSGCString;
@class	NSGString;
@class	NSGArray;
@class	NSGMutableArray;
@class	NSGDictionary;
@class	NSGMutableDictionary;
@class	NSDataMalloc;

/*
 *	Setup for inline operation of string map tables.
 */
#define	FAST_MAP_RETAIN_KEY(X)	X
#define	FAST_MAP_RELEASE_KEY(X)	
#define	FAST_MAP_RETAIN_VAL(X)	X
#define	FAST_MAP_RELEASE_VAL(X)	
#define	FAST_MAP_HASH(X)	[(X).o hash]
#define	FAST_MAP_EQUAL(X,Y)	[(X).o isEqualToString: (Y).o]

#include "FastMap.x"

/*
 *	Setup for inline operation of string arrays.
 */
#define	FAST_ARRAY_RETAIN(X)	X
#define	FAST_ARRAY_RELEASE(X)	

#include "FastArray.x"

/*
 *	Define constants for data types and variables to hold them.
 */
#define ST_XREF		0
#define ST_CSTRING	1
#define ST_STRING	2
#define ST_ARRAY	3
#define ST_MARRAY	4
#define ST_DICT		5
#define ST_MDICT	6
#define ST_DATA		7

static char	st_xref = (char)ST_XREF;
static char	st_cstring = (char)ST_CSTRING;
static char	st_string = (char)ST_STRING;
static char	st_array = (char)ST_ARRAY;
static char	st_marray = (char)ST_MARRAY;
static char	st_dict = (char)ST_DICT;
static char	st_mdict = (char)ST_MDICT;
static char	st_data = (char)ST_DATA;



/*
 *	Variables to cache class information.
 */
static Class	ArrayClass = 0;
static Class	MutableArrayClass = 0;
static Class	DataClass = 0;
static Class	DictionaryClass = 0;
static Class	MutableDictionaryClass = 0;

typedef struct {
  NSMutableData	*data;
  void		(*appImp)();		// Append to data.
  void*		(*datImp)();		// Bytes pointer.
  unsigned int	(*lenImp)();		// Length of data.
  void		(*serImp)();		// Serialize integer.
  void		(*setImp)();		// Set length of data.
  unsigned	count;			// String counter.
  FastMapTable_t	map;		// For uniquing.
  BOOL		shouldUnique;		// Do we do uniquing?
} _NSSerializerInfo;

static SEL	appSel = @selector(appendBytes:length:);
static SEL	datSel = @selector(mutableBytes);
static SEL	lenSel = @selector(length);
static SEL	serSel = @selector(serializeInt:);
static SEL	setSel = @selector(setLength:);

static void
initSerializerInfo(_NSSerializerInfo* info, NSMutableData *d, BOOL u)
{
  Class	c = fastClass(d);

  info->data = d; 
  info->appImp = (void (*)())get_imp(c, appSel);
  info->datImp = (void* (*)())get_imp(c, datSel);
  info->lenImp = (unsigned int (*)())get_imp(c, lenSel);
  info->serImp = (void (*)())get_imp(c, serSel);
  info->setImp = (void (*)())get_imp(c, setSel);
  info->shouldUnique = u;
  (*info->appImp)(d, appSel, &info->shouldUnique, 1);
  if (u)
    {
      FastMapInitWithZoneAndCapacity(&info->map, NSDefaultMallocZone(), 16);
      info->count = 0;
    }
}

static void
endSerializerInfo(_NSSerializerInfo* info)
{
  if (info->shouldUnique)
    FastMapEmptyMap(&info->map);
}

static id
serializeToInfo(id object, _NSSerializerInfo* info)
{
  Class	c = fastClass(object);

  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString ||
	c == _fastCls._NXConstantString)
    {
      FastMapNode	node;

      if (info->shouldUnique)
	node = FastMapNodeForKey(&info->map, (FastMapItem)object);
      else
	node = 0;
      if (node == 0)
	{
	  unsigned	slen;
	  unsigned	dlen;

	  slen = [object cStringLength] + 1;
	  (*info->appImp)(info->data, appSel, &st_cstring, 1);
	  (*info->serImp)(info->data, serSel, slen);
	  dlen = (*info->lenImp)(info->data, lenSel);
	  (*info->setImp)(info->data, setSel, dlen + slen);
	  [object getCString: (*info->datImp)(info->data, datSel) + dlen];
	  if (info->shouldUnique)
	    FastMapAddPair(&info->map,
		(FastMapItem)object, (FastMapItem)info->count++);
	}
      else
	{
	  (*info->appImp)(info->data, appSel, &st_xref, 1);
	  (*info->serImp)(info->data, serSel, node->value.I);
	}
    }
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    {
      FastMapNode	node;

      if (info->shouldUnique)
	node = FastMapNodeForKey(&info->map, (FastMapItem)object);
      else
	node = 0;
      if (node == 0)
	{
	  unsigned	slen;
	  unsigned	dlen;

	  slen = [object length];
	  (*info->appImp)(info->data, appSel, &st_string, 1);
	  (*info->serImp)(info->data, serSel, slen);
	  dlen = (*info->lenImp)(info->data, lenSel);
	  (*info->setImp)(info->data, setSel, dlen + slen*sizeof(unichar));
	  [object getCharacters: (*info->datImp)(info->data, datSel) + dlen];
	  if (info->shouldUnique)
	    FastMapAddPair(&info->map,
		(FastMapItem)object, (FastMapItem)info->count++);
	}
      else
	{
	  (*info->appImp)(info->data, appSel, &st_xref, 1);
	  (*info->serImp)(info->data, serSel, node->value.I);
	}
    }
  else if (fastClassIsKindOfClass(c, ArrayClass))
    {
      unsigned int count;

      if ([object isKindOfClass: MutableArrayClass])
        (*info->appImp)(info->data, appSel, &st_marray, 1);
      else
        (*info->appImp)(info->data, appSel, &st_array, 1);

      count = [object count];
      (*info->serImp)(info->data, serSel, count);

      if (count)
	{
	  id		objects[count];
	  unsigned int	i;

	  [object getObjects: objects];
	  for (i = 0; i < count; i++)
	    {
	      serializeToInfo(objects[i], info);
	    }
	}
    }
  else if (fastClassIsKindOfClass(c, DictionaryClass))
    {
      NSEnumerator	*e = [object keyEnumerator];
      id		k;
      IMP		nxtImp;
      IMP		objImp;

      nxtImp = [e methodForSelector: @selector(nextObject)];
      objImp = [object methodForSelector: @selector(objectForKey:)];

      if ([object isKindOfClass: MutableDictionaryClass])
        (*info->appImp)(info->data, appSel, &st_mdict, 1);
      else
        (*info->appImp)(info->data, appSel, &st_dict, 1);

      (*info->serImp)(info->data, serSel, [object count]);
      while ((k = (*nxtImp)(e, @selector(nextObject))) != nil)
	{
	  id o = (*objImp)(object, @selector(objectForKey:), k);

	  serializeToInfo(k, info);
	  serializeToInfo(o, info);
	}
    }
  else if (fastClassIsKindOfClass(c, DataClass))
    {
      (*info->appImp)(info->data, appSel, &st_data, 1);
      (*info->serImp)(info->data, serSel, [object length]);
      (*info->appImp)(info->data, appSel, [object bytes], [object length]);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown class in property list"];
    }
}



@implementation NSSerializer

static BOOL	shouldBeCompact = YES;

+ (void) initialize
{
  if (self == [NSSerializer class])
    {
      ArrayClass = [NSArray class];
      MutableArrayClass = [NSMutableArray class];
      DataClass = [NSData class];
      DictionaryClass = [NSDictionary class];
      MutableDictionaryClass = [NSMutableDictionary class];
    }
}

+ (NSData*) serializePropertyList: (id)propertyList
{
  _NSSerializerInfo	info;
  NSMutableData		*d;

  NSAssert(propertyList != nil, NSInvalidArgumentException);
  d = [NSMutableData dataWithCapacity: 1024];
  initSerializerInfo(&info, d, shouldBeCompact);
  serializeToInfo(propertyList, &info);
  endSerializerInfo(&info);
  return info.data;
}

+ (void) serializePropertyList: (id)propertyList
		      intoData: (NSMutableData*)d
{
  _NSSerializerInfo	info;

  NSAssert(propertyList != nil, NSInvalidArgumentException);
  NSAssert(d != nil, NSInvalidArgumentException);
  initSerializerInfo(&info, d, shouldBeCompact);
  serializeToInfo(propertyList, &info);
  endSerializerInfo(&info);
}

@end

@implementation	NSSerializer (GNUstep)
+ (void) serializePropertyList: (id)propertyList
		      intoData: (NSMutableData*)d
		       compact: (BOOL)flag
{
  _NSSerializerInfo	info;

  NSAssert(propertyList != nil, NSInvalidArgumentException);
  NSAssert(d != nil, NSInvalidArgumentException);
  initSerializerInfo(&info, d, flag);
  serializeToInfo(propertyList, &info);
  endSerializerInfo(&info);
}
+ (void) shouldBeCompact: (BOOL)flag
{
  shouldBeCompact = flag;
}
@end



/*
 *	Variables to cache class information.
 */
static Class	GArrayClass = 0;
static Class	GMutableArrayClass = 0;
static Class	GDataClass = 0;
static Class	GDictionaryClass = 0;
static Class	GMutableDictionaryClass = 0;

typedef struct {
  NSData	*data;
  unsigned	*cursor;
  BOOL		mutable;
  BOOL		didUnique;
  void		(*debImp)();
  unsigned int	(*deiImp)();
  FastArray_t	array;
} _NSDeserializerInfo;

static SEL	debSel = @selector(deserializeBytes:length:atCursor:);
static SEL	deiSel = @selector(deserializeIntAtCursor:);

static void
initDeserializerInfo(_NSDeserializerInfo* info, NSData *d, unsigned *c, BOOL m)
{
  info->data = d;
  info->cursor = c;
  info->mutable = m;
  info->debImp = (void (*)())[d methodForSelector: debSel];
  info->deiImp = (unsigned int (*)())[d methodForSelector: deiSel];
  (*info->debImp)(d, debSel, &info->didUnique, 1, c);
  if (info->didUnique)
    FastArrayInitWithZoneAndCapacity(&info->array, NSDefaultMallocZone(), 16);
}

static void
endDeserializerInfo(_NSDeserializerInfo* info)
{
  if (info->didUnique)
    FastArrayEmpty(&info->array);
}

static id
deserializeFromInfo(_NSDeserializerInfo* info)
{
  char		code;
  unsigned int	size;

  (*info->debImp)(info->data, debSel, &code, 1, info->cursor);
  size = (*info->deiImp)(info->data, deiSel, info->cursor);

  switch (code)
    {
      case ST_XREF:
	{
	  return [FastArrayItemAtIndex(&info->array, size).o retain];
	}

      case ST_CSTRING:
	{
	  NSGCString	*s;
	  char		*b = objc_malloc(size);
	
	  (*info->debImp)(info->data, debSel, b, size, info->cursor);
	  s = [_fastCls._NSGCString allocWithZone: NSDefaultMallocZone()];
	  s = [s initWithCStringNoCopy: b
				length: size-1
			      fromZone: NSDefaultMallocZone()];
	  if (info->didUnique)
	    FastArrayAddItem(&info->array, (FastArrayItem)s);
	  return s;
	}

      case ST_STRING:
	{
	  NSGString	*s;
	  unichar	*b = objc_malloc(size*2);
	
	  (*info->debImp)(info->data, debSel, b, size*2, info->cursor);
	  s = [_fastCls._NSGString allocWithZone: NSDefaultMallocZone()];
	  s = [s initWithCharactersNoCopy: b
				   length: size
			         fromZone: NSDefaultMallocZone()];
	  if (info->didUnique)
	    FastArrayAddItem(&info->array, (FastArrayItem)s);
	  return s;
	}

      case ST_ARRAY:
      case ST_MARRAY:
	{
	  id	objects[size];
	  id	a;
	  int	i;

	  for (i = 0; i < size; i++)
	    {
	      objects[i] = deserializeFromInfo(info);
	      if (objects[i] == nil)
		{
		  while (i > 0)
		    {
		      [objects[--i] release];
		    }
		  return nil;
		}
	    }
	  if (code == ST_MARRAY || info->mutable)
	    {
	      a = [GMutableArrayClass allocWithZone: NSDefaultMallocZone()];
	      a = [a initWithObjects: objects
			       count: size];
	    }
	  else
	    {
	      a = [GArrayClass allocWithZone: NSDefaultMallocZone()];
	      a = [a initWithObjects: objects
			       count: size];
	    }
	  while (i > 0)
	    {
	      [objects[--i] release];
	    }
	  return a;
	}

      case ST_DICT:
      case ST_MDICT:
	{
	  id	keys[size];
	  id	objects[size];
	  id	d;
	  int	i;

	  for (i = 0; i < size; i++)
	    {
	      keys[i] = deserializeFromInfo(info);
	      if (keys[i] == nil)
		{
		  while (i > 0)
		    {
		      [keys[--i] release];
		      [objects[i] release];
		    }
		  return nil;
		}
	      objects[i] = deserializeFromInfo(info);
	      if (objects[i] == nil)
		{
		  [keys[i] release];
		  while (i > 0)
		    {
		      [keys[--i] release];
		      [objects[i] release];
		    }
		  return nil;
		}
	    }
	  if (code == ST_MDICT || info->mutable)
	    {
	      d=[GMutableDictionaryClass allocWithZone: NSDefaultMallocZone()];
	      d = [d initWithObjects: objects
			     forKeys: keys
			       count: size];
	    }
	  else
	    {
	      d = [GDictionaryClass allocWithZone: NSDefaultMallocZone()];
	      d = [d initWithObjects: objects
			     forKeys: keys
			       count: size];
	    }
	  while (i > 0)
	    {
	      [keys[--i] release];
	      [objects[i] release];
	    }
	  return d;
	}

      case ST_DATA:
	{
	  NSData	*d;
	  void		*b = objc_malloc(size);
	
	  (*info->debImp)(info->data, debSel, b, size, info->cursor);
	  d = [GDataClass allocWithZone: NSDefaultMallocZone()];
	  d = [d initWithBytesNoCopy: b
			      length: size
			    fromZone: NSDefaultMallocZone()];
	  return d;
	}

      default:
	return nil;
    }
}



@interface	_NSDeserializerProxy : NSProxy
{
  _NSDeserializerInfo	info;
  id			plist;
}
+ (_NSDeserializerProxy*) proxyWithData: (NSData*)d
			       atCursor: (unsigned int*)c
				mutable: (BOOL)m;
@end

@implementation	_NSDeserializerProxy
+ (_NSDeserializerProxy*) proxyWithData: (NSData*)d
			       atCursor: (unsigned int*)c
				mutable: (BOOL)m
{
  _NSDeserializerProxy	*proxy;

  proxy = (_NSDeserializerProxy*)NSAllocateObject(self,0,NSDefaultMallocZone());
  initDeserializerInfo(&proxy->info, [d retain], c, m);
  return [proxy autorelease];
}

- (void) dealloc
{
  [info.data release];
  endDeserializerInfo(&info);
  [plist release];
  [super dealloc];
}

- forward: (SEL)aSel :(arglist_t)frame
{
  IMP	imp;

  if (plist == nil && info.data != nil)
    {
      plist = deserializeFromInfo(&info);
      [info.data release];
      info.data = nil;
    }
  return [plist performv: aSel :frame];
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    return YES;
  else
    return [[self self] isEqual: other];
}

- (id) self
{
  if (plist == nil && info.data != nil)
    {
      plist = deserializeFromInfo(&info);
      [info.data release];
      info.data = nil;
    }
  return plist;
}
@end



@implementation NSDeserializer

+ (void) initialize
{
  if (self == [NSDeserializer class])
    {
      GArrayClass = [NSGArray class];
      GMutableArrayClass = [NSGMutableArray class];
      GDataClass = [NSDataMalloc class];
      GDictionaryClass = [NSGDictionary class];
      GMutableDictionaryClass = [NSGMutableDictionary class];
    }
}

+ (id) deserializePropertyListFromData: (NSData*)data
                              atCursor: (unsigned int*)cursor
                     mutableContainers: (BOOL)flag
{
  _NSDeserializerInfo	info;
  id	o;

  NSAssert(data != nil, NSInvalidArgumentException);
  NSAssert(cursor != 0, NSInvalidArgumentException);
  initDeserializerInfo(&info, data, cursor, flag);
  o = deserializeFromInfo(&info);
  endDeserializerInfo(&info);
  [o autorelease];
  return o;
}

+ (id) deserializePropertyListFromData: (NSData*)data
                     mutableContainers: (BOOL)flag
{
  _NSDeserializerInfo	info;
  unsigned int	cursor = 0;
  id		o;

  NSAssert(data != nil, NSInvalidArgumentException);
  initDeserializerInfo(&info, data, &cursor, flag);
  o = deserializeFromInfo(&info);
  endDeserializerInfo(&info);
  [o autorelease];
  return o;
}

+ (id) deserializePropertyListLazilyFromData: (NSData*)data
                                    atCursor: (unsigned*)cursor
                                      length: (unsigned)length
                           mutableContainers: (BOOL)flag
{
  NSAssert(data != nil, NSInvalidArgumentException);
  NSAssert(cursor != 0, NSInvalidArgumentException);
  if (length > [data length] - *cursor)
    {
      _NSDeserializerInfo   info;
      id    o;

      initDeserializerInfo(&info, data, cursor, flag);
      o = deserializeFromInfo(&info);
      endDeserializerInfo(&info);
      [o autorelease];
      return o;
    }
  else
    {
      return [_NSDeserializerProxy proxyWithData: data
					atCursor: cursor
					 mutable: flag];
    }
}
@end

