/** Class for serialization in GNUStep
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSSerializer class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProxy.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSObjCRuntime.h>

@class	GSDictionary;
@class	GSMutableDictionary;
@class	NSDataMalloc;
@class	GSInlineArray;
@class  GSMutableArray;
@class	GSCString;
@class	GSUnicodeString;
@class	GSMutableString;

/*
 *	Setup for inline operation of string map tables.
 */
#ifdef	GSI_NEW
#define	GSI_MAP_RETAIN_KEY(M, X)	
#define	GSI_MAP_RELEASE_KEY(M, X)	
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_HASH(M, X)	[(X).obj hash]
#define	GSI_MAP_EQUAL(M, X,Y)	[(X).obj isEqualToString: (Y).obj]
#else
#define	GSI_MAP_RETAIN_KEY(X)	
#define	GSI_MAP_RELEASE_KEY(X)	
#define	GSI_MAP_RETAIN_VAL(X)	
#define	GSI_MAP_RELEASE_VAL(X)	
#define	GSI_MAP_HASH(X)	[(X).obj hash]
#define	GSI_MAP_EQUAL(X,Y)	[(X).obj isEqualToString: (Y).obj]
#endif

#include <base/GSIMap.h>

/*
 *	Setup for inline operation of string arrays.
 */
#define	GSI_ARRAY_RETAIN(X)	
#define	GSI_ARRAY_RELEASE(X)	
#define	GSI_ARRAY_TYPES	GSUNION_OBJ

#include <base/GSIArray.h>

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
static Class	CStringClass = 0;
static Class	MStringClass = 0;
static Class	StringClass = 0;

typedef struct {
  @defs(GSString)
} *ivars;

typedef struct {
  NSMutableData	*data;
  void		(*appImp)();		// Append to data.
  void*		(*datImp)();		// Bytes pointer.
  unsigned int	(*lenImp)();		// Length of data.
  void		(*serImp)();		// Serialize integer.
  void		(*setImp)();		// Set length of data.
  unsigned	count;			// String counter.
  GSIMapTable_t	map;			// For uniquing.
  BOOL		shouldUnique;		// Do we do uniquing?
} _NSSerializerInfo;

static SEL	appSel;
static SEL	datSel;
static SEL	lenSel;
static SEL	serSel;
static SEL	setSel;

static void
initSerializerInfo(_NSSerializerInfo* info, NSMutableData *d, BOOL u)
{
  Class	c;

  c = GSObjCClass(d);
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
      GSIMapInitWithZoneAndCapacity(&info->map, NSDefaultMallocZone(), 16);
      info->count = 0;
    }
}

static void
endSerializerInfo(_NSSerializerInfo* info)
{
  if (info->shouldUnique)
    GSIMapEmptyMap(&info->map);
}

static void
serializeToInfo(id object, _NSSerializerInfo* info)
{
  Class	c;

  if (object == nil || GSObjCIsInstance(object) == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Class (%@) in property list - expected instance",
				[object description]];
    }
  c = GSObjCClass(object);
  if (GSObjCIsKindOf(c, CStringClass)
    || (c == MStringClass && ((ivars)object)->_flags.wide == 0))
    {
      GSIMapNode	node;

      if (info->shouldUnique)
	node = GSIMapNodeForKey(&info->map, (GSIMapKey)object);
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
	    GSIMapAddPair(&info->map,
		(GSIMapKey)object, (GSIMapVal)info->count++);
	}
      else
	{
	  (*info->appImp)(info->data, appSel, &st_xref, 1);
	  (*info->serImp)(info->data, serSel, node->value.uint);
	}
    }
  else if (GSObjCIsKindOf(c, StringClass))
    {
      GSIMapNode	node;

      if (info->shouldUnique)
	node = GSIMapNodeForKey(&info->map, (GSIMapKey)object);
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
#if NEED_WORD_ALIGNMENT
	  /*
	   * When packing data, an item may not be aligned on a
	   * word boundary, so we work with an aligned buffer
	   * and use memcmpy()
	   */
 	  if ((dlen % __alignof__(gsu32)) != 0)
	    {
	      unichar buffer[slen];
	      [object getCharacters: buffer];
	      memcpy((*info->datImp)(info->data, datSel) + dlen, buffer, 
		     slen*sizeof(unichar));
	    }
	  else
#endif
	  [object getCharacters: (*info->datImp)(info->data, datSel) + dlen];
	  if (info->shouldUnique)
	    GSIMapAddPair(&info->map,
		(GSIMapKey)object, (GSIMapVal)info->count++);
	}
      else
	{
	  (*info->appImp)(info->data, appSel, &st_xref, 1);
	  (*info->serImp)(info->data, serSel, node->value.uint);
	}
    }
  else if (GSObjCIsKindOf(c, ArrayClass))
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
  else if (GSObjCIsKindOf(c, DictionaryClass))
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
  else if (GSObjCIsKindOf(c, DataClass))
    {
      (*info->appImp)(info->data, appSel, &st_data, 1);
      (*info->serImp)(info->data, serSel, [object length]);
      (*info->appImp)(info->data, appSel, [object bytes], [object length]);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown class (%@) in property list",
				[c description]];
    }
}



@implementation NSSerializer

static BOOL	shouldBeCompact = NO;

+ (void) initialize
{
  if (self == [NSSerializer class])
    {
      appSel = @selector(appendBytes:length:);
      datSel = @selector(mutableBytes);
      lenSel = @selector(length);
      serSel = @selector(serializeInt:);
      setSel = @selector(setLength:);
      ArrayClass = [NSArray class];
      MutableArrayClass = [NSMutableArray class];
      DataClass = [NSData class];
      DictionaryClass = [NSDictionary class];
      MutableDictionaryClass = [NSMutableDictionary class];
      StringClass = [NSString class];
      CStringClass = [GSCString class];
      MStringClass = [GSMutableString class];
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
static BOOL	uniquing = NO;	/* Make incoming strings unique	*/
static Class	IACls = 0;	/* Immutable Array	*/
static Class	MACls = 0;	/* Mutable Array	*/
static Class	DCls = 0;	/* Data			*/
static Class	IDCls = 0;	/* Immutable Dictionary	*/
static Class	MDCls = 0;	/* Mutable Dictionary	*/
static Class	USCls = 0;	/* Unicode String	*/
static Class	CSCls = 0;	/* C String 		*/

typedef struct {
  NSData	*data;
  unsigned	*cursor;
  BOOL		mutable;
  BOOL		didUnique;
  void		(*debImp)();
  unsigned int	(*deiImp)();
  GSIArray_t	array;
} _NSDeserializerInfo;

static SEL debSel;
static SEL deiSel;
static SEL csInitSel;
static SEL usInitSel;
static SEL dInitSel;
static SEL iaInitSel;
static SEL maInitSel;
static SEL idInitSel;
static SEL mdInitSel;
static IMP csInitImp;
static IMP usInitImp;
static IMP dInitImp;
static IMP iaInitImp;
static IMP maInitImp;
static IMP idInitImp;
static IMP mdInitImp;

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
    GSIArrayInitWithZoneAndCapacity(&info->array, NSDefaultMallocZone(), 16);
}

static void
endDeserializerInfo(_NSDeserializerInfo* info)
{
  if (info->didUnique)
    GSIArrayEmpty(&info->array);
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
	  return RETAIN(GSIArrayItemAtIndex(&info->array, size).obj);
	}

      case ST_CSTRING:
	{
	  GSCString	*s;
	  char		*b;
	
	  b = NSZoneMalloc(NSDefaultMallocZone(), size);
	  (*info->debImp)(info->data, debSel, b, size, info->cursor);
	  s = (GSCString*)NSAllocateObject(CSCls, 0, NSDefaultMallocZone());
	  s = (*csInitImp)(s, csInitSel, b, size-1, YES);

	  /*
	   * If we are supposed to be doing uniquing of strings, handle it.
	   */
	  if (uniquing == YES)
	    s = GSUnique(s);

	  /*
           * If uniquing was done on serialisation, store the string for
	   * later reference.
	   */
	  if (info->didUnique)
	    GSIArrayAddItem(&info->array, (GSIArrayItem)s);
	  return s;
	}

      case ST_STRING:
	{
	  NSString	*s;
	  unichar	*b;
	  unsigned	i;
	
	  b = NSZoneMalloc(NSDefaultMallocZone(), size*sizeof(unichar));
	  (*info->debImp)(info->data, debSel, b, size*sizeof(unichar),
	    info->cursor);

	  /*
	   * Check to see if this really IS unicode ... if not, use a cString
	   */
	  for (i = 0; i < size; i++)
	    {
	      if (b[i] > 127)
		{
		  break;
		}
	    }
	  if (i == size)
	    {
	      char	*p = (char*)b;

	      for (i = 0; i < size; i++)
		{
		  p[i] = (char)b[i];
		}
	      p = NSZoneRealloc(NSDefaultMallocZone(), b, size);
	      s = (NSString*)NSAllocateObject(CSCls, 0, NSDefaultMallocZone());
	      s = (*csInitImp)(s, csInitSel, p, size, YES);
	    }
	  else
	    {
	      s = (NSString*)NSAllocateObject(USCls, 0, NSDefaultMallocZone());
	      s = (*usInitImp)(s, usInitSel, b, size, YES);
	    }

	  /*
	   * If we are supposed to be doing uniquing of strings, handle it.
	   */
	  if (uniquing == YES)
	    s = GSUnique(s);

	  /*
           * If uniquing was done on serialisation, store the string for
	   * later reference.
	   */
	  if (info->didUnique)
	    GSIArrayAddItem(&info->array, (GSIArrayItem)s);
	  return s;
	}

      case ST_ARRAY:
      case ST_MARRAY:
	{
	  id		objects[size];
	  id		a;
	  unsigned	i;

	  for (i = 0; i < size; i++)
	    {
	      objects[i] = deserializeFromInfo(info);
	      if (objects[i] == nil)
		{
#if	!GS_WITH_GC
		  while (i > 0)
		    {
		      [objects[--i] release];
		    }
#endif
		  objc_free(objects);
		  return nil;
		}
	    }
	  if (code == ST_MARRAY || info->mutable)
	    {
	      a = NSAllocateObject(MACls, 0, NSDefaultMallocZone());
	      a = (*maInitImp)(a, maInitSel, objects, size);
	    }
	  else
	    {
	      a = NSAllocateObject(IACls, sizeof(id)*size,
		NSDefaultMallocZone());
	      a = (*iaInitImp)(a, iaInitSel, objects, size);
	    }
#if	!GS_WITH_GC
	  for (i = 0; i < size; i++)
	    {
	      [objects[i] release];
	    }
#endif
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
#if	!GS_WITH_GC
		  while (i > 0)
		    {
		      [keys[--i] release];
		      [objects[i] release];
		    }
#endif
		  return nil;
		}
	      objects[i] = deserializeFromInfo(info);
	      if (objects[i] == nil)
		{
#if	!GS_WITH_GC
		  [keys[i] release];
		  while (i > 0)
		    {
		      [keys[--i] release];
		      [objects[i] release];
		    }
#endif
		  return nil;
		}
	    }
	  if (code == ST_MDICT || info->mutable)
	    {
	      d = NSAllocateObject(MDCls, 0, NSDefaultMallocZone());
	      d = (*mdInitImp)(d, mdInitSel, objects, keys, size);
	    }
	  else
	    {
	      d = NSAllocateObject(IDCls, 0, NSDefaultMallocZone());
	      d = (*idInitImp)(d, idInitSel, objects, keys, size);
	    }
#if	!GS_WITH_GC
	  for (i = 0; i < size; i++)
	    {
	      [keys[i] release];
	      [objects[i] release];
	    }
#endif
	  return d;
	}

      case ST_DATA:
	{
	  NSData	*d;

	  d = (NSData*)NSAllocateObject(DCls, 0, NSDefaultMallocZone());
	  if (size > 0)
	    {
	      void	*b = NSZoneMalloc(NSDefaultMallocZone(), size);
	
	      (*info->debImp)(info->data, debSel, b, size, info->cursor);
	      d = (*dInitImp)(d, dInitSel, b, size);
	    }
	  else
	    {
	      d = (*dInitImp)(d, dInitSel, 0, 0);
	    }
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
  initDeserializerInfo(&proxy->info, RETAIN(d), c, m);
  return AUTORELEASE(proxy);
}

- (void) dealloc
{
  RELEASE(info.data);
  endDeserializerInfo(&info);
  RELEASE(plist);
  [super dealloc];
}

- forward: (SEL)aSel :(arglist_t)frame
{
  if (plist == nil && info.data != nil)
    {
      plist = deserializeFromInfo(&info);
      RELEASE(info.data);
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
      RELEASE(info.data);
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
      debSel = @selector(deserializeBytes:length:atCursor:);
      deiSel = @selector(deserializeIntAtCursor:);
      csInitSel = @selector(initWithCStringNoCopy:length:freeWhenDone:);
      usInitSel = @selector(initWithCharactersNoCopy:length:freeWhenDone:);
      dInitSel = @selector(initWithBytesNoCopy:length:);
      iaInitSel = @selector(initWithObjects:count:);
      maInitSel = @selector(initWithObjects:count:);
      idInitSel = @selector(initWithObjects:forKeys:count:);
      mdInitSel = @selector(initWithObjects:forKeys:count:);
      IACls = [GSInlineArray class];
      MACls = [GSMutableArray class];
      DCls = [NSDataMalloc class];
      IDCls = [GSDictionary class];
      MDCls = [GSMutableDictionary class];
      USCls = [GSUnicodeString class];
      CSCls = [GSCString class];
      csInitImp = [CSCls instanceMethodForSelector: csInitSel];
      usInitImp = [USCls instanceMethodForSelector: usInitSel];
      dInitImp = [DCls instanceMethodForSelector: dInitSel];
      iaInitImp = [IACls instanceMethodForSelector: iaInitSel];
      maInitImp = [MACls instanceMethodForSelector: maInitSel];
      idInitImp = [IDCls instanceMethodForSelector: idInitSel];
      mdInitImp = [MDCls instanceMethodForSelector: mdInitSel];
    }
}

+ (id) deserializePropertyListFromData: (NSData*)data
                              atCursor: (unsigned int*)cursor
                     mutableContainers: (BOOL)flag
{
  _NSDeserializerInfo	info;
  id	o;

  if (data == nil || [data isKindOfClass: [NSData class]] == NO)
    {
      return nil;
    }
  NSAssert(cursor != 0, NSInvalidArgumentException);
  initDeserializerInfo(&info, data, cursor, flag);
  o = deserializeFromInfo(&info);
  endDeserializerInfo(&info);
  return AUTORELEASE(o);
}

+ (id) deserializePropertyListFromData: (NSData*)data
                     mutableContainers: (BOOL)flag
{
  _NSDeserializerInfo	info;
  unsigned int	cursor = 0;
  id		o;

  if (data == nil || [data isKindOfClass: [NSData class]] == NO)
    {
      return nil;
    }
  initDeserializerInfo(&info, data, &cursor, flag);
  o = deserializeFromInfo(&info);
  endDeserializerInfo(&info);
  return AUTORELEASE(o);
}

+ (id) deserializePropertyListLazilyFromData: (NSData*)data
                                    atCursor: (unsigned*)cursor
                                      length: (unsigned)length
                           mutableContainers: (BOOL)flag
{
  if (data == nil || [data isKindOfClass: [NSData class]] == NO)
    {
      return nil;
    }
  NSAssert(cursor != 0, NSInvalidArgumentException);
  if (length > [data length] - *cursor)
    {
      _NSDeserializerInfo   info;
      id    o;

      initDeserializerInfo(&info, data, cursor, flag);
      o = deserializeFromInfo(&info);
      endDeserializerInfo(&info);
      return AUTORELEASE(o);
    }
  else
    {
      return [_NSDeserializerProxy proxyWithData: data
					atCursor: cursor
					 mutable: flag];
    }
}
@end

@implementation NSDeserializer (GNUstep)
+ (void) uniquing: (BOOL)flag
{
  if (flag == YES)
    GSUniquing(YES);
  uniquing = flag;
}
@end

