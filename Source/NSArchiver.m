/* of NSArchiver for GNUstep
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <richard@brainstorm.co.Ik>
   Created: October 1998
   
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
#include <objc/objc-api.h>
/*
 *	Setup for inline operation of pointer map tables.
 */
#define	FAST_MAP_RETAIN_KEY(X)	X
#define	FAST_MAP_RELEASE_KEY(X)	
#define	FAST_MAP_RETAIN_VAL(X)	X
#define	FAST_MAP_RELEASE_VAL(X)	
#define	FAST_MAP_HASH(X)	((X).I)
#define	FAST_MAP_EQUAL(X,Y)	((X).I == (Y).I)

#include "FastMap.x"

#define	_IN_NSARCHIVER_M
#include <Foundation/NSArchiver.h>
#undef	_IN_NSARCHIVER_M

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

#include <gnustep/base/fast.x>

typedef	unsigned char	uchar;


#define	PREFIX		"GNUstep archive"

static SEL serSel = @selector(serializeDataAt:ofObjCType:context:);
static SEL tagSel = @selector(serializeTypeTag:);
static SEL xRefSel = @selector(serializeCrossRef:);
static SEL eObjSel = @selector(encodeObject:);
static SEL eValSel = @selector(encodeValueOfObjCType:at:);

@implementation NSArchiver

- (id) init
{
  return [self initForWritingWithMutableData:
	[[_fastCls._NSMutableDataMalloc allocWithZone: [self zone]] init]];
}

- (id) initForWritingWithMutableData: (NSMutableData*)anObject
{
  self = [super init];
  if (self)
    {
      NSZone		*zone = [self zone];

      data = [anObject retain];
      if ([self directDataAccess] == YES)
        {
	  dst = data;
	}
      else
	{
	  dst = self;
	}
      serImp = [dst methodForSelector: serSel];
      tagImp = [dst methodForSelector: tagSel];
      xRefImp = [dst methodForSelector: xRefSel];
      eObjImp = [self methodForSelector: eObjSel];
      eValImp = [self methodForSelector: eValSel];

      [self resetArchiver];

      /*
       *	Set up map tables.
       */
      clsMap = (FastMapTable)NSZoneMalloc(zone, sizeof(FastMapTable_t)*6);
      cIdMap = &clsMap[1];
      uIdMap = &clsMap[2];
      ptrMap = &clsMap[3];
      namMap = &clsMap[4];
      repMap = &clsMap[5];
      FastMapInitWithZoneAndCapacity(clsMap, zone, 100);
      FastMapInitWithZoneAndCapacity(cIdMap, zone, 10);
      FastMapInitWithZoneAndCapacity(uIdMap, zone, 200);
      FastMapInitWithZoneAndCapacity(ptrMap, zone, 100);
      FastMapInitWithZoneAndCapacity(namMap, zone, 1);
      FastMapInitWithZoneAndCapacity(repMap, zone, 1);
    }
  return self;
}

- (void) dealloc
{
  [data release];
  if (clsMap)
    {
      FastMapEmptyMap(clsMap);
      if (cIdMap)
	{
	  FastMapEmptyMap(cIdMap);
	}
      if (uIdMap)
	{
	  FastMapEmptyMap(uIdMap);
	}
      if (ptrMap)
	{
	  FastMapEmptyMap(ptrMap);
	}
      if (namMap)
	{
	  FastMapEmptyMap(namMap);
	}
      if (repMap)
	{
	  FastMapEmptyMap(repMap);
	}
      NSZoneFree(clsMap->zone, (void*)clsMap);
    }
  return [super dealloc];
}

+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
  NSArchiver	*archiver;
  id		d;
  NSZone	*z = NSDefaultMallocZone();

  d = [[_fastCls._NSMutableDataMalloc allocWithZone: z] initWithCapacity: 0];
  if (d == nil)
    {
      return nil;
    }
    archiver = [[self allocWithZone: z] initForWritingWithMutableData: d];
    if (archiver)
      {
	NS_DURING
	  {
	    [archiver encodeRootObject: rootObject];
	    d = [[archiver->data copy] autorelease];
	  }
	NS_HANDLER
	  {
	    d = nil;
	  }
	NS_ENDHANDLER
	[archiver release];
      }
    else
      {
	d = nil;
      }

    return d;
}

+ (BOOL) archiveRootObject: (id)rootObject
		    toFile: (NSString*)path
{
  id	d = [self archivedDataWithRootObject: rootObject];

  return [d writeToFile: path atomically: YES];
}

- (void) encodeArrayOfObjCType: (const char*)type
			 count: (unsigned)count
			    at: (const void*)buf
{
  unsigned	i;
  unsigned	offset = 0;
  unsigned	size = objc_sizeof_type(type);
  uchar		info;

  switch (*type)
    {
      case _C_ID:	info = _C_NONE;	break;
      case _C_CHR:	info = _C_CHR;	break;
      case _C_UCHR:	info = _C_UCHR; break;
      case _C_SHT:	info = _C_SHT;	break;
      case _C_USHT:	info = _C_USHT; break;
      case _C_INT:	info = _C_INT;	break;
      case _C_UINT:	info = _C_UINT;	break;
      case _C_LNG:	info = _C_LNG;	break;
      case _C_ULNG:	info = _C_ULNG; break;
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:	info = _C_LNG_LNG;	break;
      case _C_ULNG_LNG:	info = _C_ULNG_LNG;	break;
#endif
      case _C_FLT:	info = _C_FLT;	break;
      case _C_DBL:	info = _C_DBL;	break;
      default:		info = _C_NONE; break;
    }

  /*
   *	Simple types can be serialized immediately, more complex ones
   *	are dealt with by our [encodeValueOfObjCType:at:] method.
   */
  if (info == _C_NONE)
    {
      if (isInPreparatoryPass == NO)
	{
	  (*tagImp)(dst, tagSel, _C_ARY_B);
	  (*serImp)(dst, serSel, &count, @encode(unsigned), nil);
	}
      for (i = 0; i < count; i++)
	{
	  (*eValImp)(self, eValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else if (isInPreparatoryPass == NO)
    {
      (*tagImp)(dst, tagSel, _C_ARY_B);
      (*serImp)(dst, serSel, &count, @encode(unsigned), nil);

      (*tagImp)(dst, tagSel, info);
      for (i = 0; i < count; i++)
	{
	  (*serImp)(dst, serSel, (char*)buf + offset, type, nil);
	  offset += size;
	}
    }
}

- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)buf
{
  uchar	info;

  switch (*type)
    {
      case _C_ID:
	(*eObjImp)(self, eObjSel, *(void**)buf);
	return;

      case _C_ARY_B:
	{
	  int		count = atoi(++type);

	  while (isdigit(*type))
	    {
	      type++;
	    }

	  if (isInPreparatoryPass == NO)
	    {
	      (*tagImp)(dst, tagSel, _C_ARY_B);
	    }
	  [self encodeArrayOfObjCType: type count: count at: buf];
	}
	return;

      case _C_STRUCT_B:
	{
	  int	offset = 0;

	  if (isInPreparatoryPass == NO)
	    {
	      (*tagImp)(dst, tagSel, _C_STRUCT_B);
	    }

	  while (*type != _C_STRUCT_E && *type != '=')
	    {
	      type++;
	    }

	  for (;;)
	    {
	      (*eValImp)(self, eValSel, type, (char*)buf + offset);
	      offset += objc_sizeof_type(type);
	      type = objc_skip_typespec(type);
	      if (*type == _C_STRUCT_E)
		{
		  break;
		}
	      else
		{
		  int	align = objc_alignof_type(type);
		  int	rem = offset % align;

		  if (rem != 0)
		    {
		      offset += align - rem;
		    }
		}
	    }
	}
	return;

      case _C_PTR:
	if (*(void**)buf == 0)
	  {
	    if (isInPreparatoryPass == NO)
	      {
		/*
		 *	Special case - a nul pointer gets an xref of zero
		 */
		(*tagImp)(dst, tagSel, _C_PTR | _C_XREF);
		(*xRefImp)(dst, xRefSel, 0);
	      }
	  }
	else
	  {
	    FastMapNode	node;

	    node = FastMapNodeForKey(ptrMap, (FastMapItem)*(void**)buf);
	    if (isInPreparatoryPass == YES)
	      {
		/*
		 *	First pass - add pointer to map and encode item pointed
		 *	to in case it is a conditionally encoded object.
		 */
		if (node == 0)
		  {
		    FastMapAddPair(ptrMap,
			(FastMapItem)*(void**)buf, (FastMapItem)0);
		    type++;
		    buf = *(char**)buf;
		    (*eValImp)(self, eValSel, type, buf);
		  }
	      }
	    else if (node == 0 || node->value.I == 0)
	      {
		/*
		 *	Second pass, unwritten pointer - write it.
		 */
		if (node == 0)
		  {
		    node = FastMapAddPair(ptrMap,
			(FastMapItem)*(void**)buf, (FastMapItem)++xRefP);
		  }
		else
		  {
		    node->value.I = ++xRefP;
		  }
		(*tagImp)(dst, tagSel, _C_PTR);
		type++;
		buf = *(char**)buf;
		(*eValImp)(self, eValSel, type, buf);
	      }
	    else
	      {
		/*
		 *	Second pass, write a cross-reference number.
		 */
		(*tagImp)(dst, tagSel, _C_PTR | _C_XREF);
		(*xRefImp)(dst, xRefSel, node->value.I);
	      }
	  }
	return;

      default:	/* Types that can be ignored in first pass.	*/
	if (isInPreparatoryPass)
	  {
	    return;	
	  }
	break;
    }

  switch (*type)
    {
      case _C_CLASS:
	if (*(Class*)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*tagImp)(dst, tagSel, _C_CLASS | _C_XREF);
	    (*xRefImp)(dst, xRefSel, 0);
	  }
	else
	  {
	    Class	c = *(Class*)buf;
	    FastMapNode	node;
	    BOOL	done = NO;

	    node = FastMapNodeForKey(clsMap, (FastMapItem)(void*)c);
	    
	    if (node != 0)
	      {
		(*tagImp)(dst, tagSel, _C_CLASS | _C_XREF);
		(*xRefImp)(dst, xRefSel, node->value.I);
		return;
	      }
	    while (done == NO)
	      {
		int		tmp = fastClassVersion(c);
		unsigned	version = tmp;
		Class		s = fastSuper(c);

		if (tmp < 0)
		  {
		    [NSException raise: NSInternalInconsistencyException
				format: @"negative class version"];
		  }
		node = FastMapAddPair(clsMap,
			(FastMapItem)(void*)c, (FastMapItem)++xRefC);
		/*
		 *	Encode tag and crossref number.
		 */
		(*tagImp)(dst, tagSel, _C_CLASS);
		(*xRefImp)(dst, xRefSel, node->value.I);
		/*
		 *	Encode class, and version.
		 */
		(*serImp)(dst, serSel, &c, @encode(Class), nil);
		(*serImp)(dst, serSel, &version, @encode(unsigned), nil);
		/*
		 *	If we have a super class that has not been encoded,
		 *	we must loop round to encode it here so that its
		 *	version information will be available when objects
		 *	of its subclasses are decoded and call
		 *	[super initWithCoder:ccc]
		 */
		if (s == c || s == 0 ||
			FastMapNodeForKey(clsMap, (FastMapItem)(void*)s) != 0)
		  {
		    done = YES;
		  }
		else
		  {
		    c = s;
		  }
	      }
	    /*
	     *	Encode an empty tag to terminate the list of classes.
	     */
	    (*tagImp)(dst, tagSel, _C_NONE);
	  }
	return;

      case _C_SEL:
	if (*(SEL*)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*tagImp)(dst, tagSel, _C_SEL | _C_XREF);
	    (*xRefImp)(dst, xRefSel, 0);
	  }
	else
	  {
	    SEL		s = *(SEL*)buf;
	    FastMapNode	node = FastMapNodeForKey(ptrMap, (FastMapItem)(void*)s);

	    if (node == 0)
	      {
		node = FastMapAddPair(ptrMap,
			(FastMapItem)(void*)s, (FastMapItem)++xRefP);
		(*tagImp)(dst, tagSel, _C_SEL);
		(*xRefImp)(dst, xRefSel, node->value.I);
		/*
		 *	Encode selector.
		 */
		(*serImp)(dst, serSel, buf, @encode(SEL), nil);
	      }
	    else
	      {
		(*tagImp)(dst, tagSel, _C_SEL | _C_XREF);
		(*xRefImp)(dst, xRefSel, node->value.I);
	      }
	  }
	return;

      case _C_CHARPTR:
	if (*(char**)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*tagImp)(dst, tagSel, _C_CHARPTR | _C_XREF);
	    (*xRefImp)(dst, xRefSel, 0);
	  }
	else
	  {
	    FastMapNode	node;

	    node = FastMapNodeForKey(ptrMap, (FastMapItem)*(char**)buf);
	    if (node == 0)
	      {
		node = FastMapAddPair(ptrMap,
			(FastMapItem)*(char**)buf, (FastMapItem)++xRefP);
		(*tagImp)(dst, tagSel, _C_CHARPTR);
		(*xRefImp)(dst, xRefSel, node->value.I);
		(*serImp)(dst, serSel, buf, type, nil);
	      }
	    else
	      {
		(*tagImp)(dst, tagSel, _C_CHARPTR | _C_XREF);
		(*xRefImp)(dst, xRefSel, node->value.I);
	      }
	  }
	return;

      case _C_CHR:
	(*tagImp)(dst, tagSel, _C_CHR);
	(*serImp)(dst, serSel, (void*)buf, @encode(char), nil);
	return;

      case _C_UCHR:
	(*tagImp)(dst, tagSel, _C_UCHR);
	(*serImp)(dst, serSel, (void*)buf, @encode(unsigned char), nil);
	return;

      case _C_SHT:
	(*tagImp)(dst, tagSel, _C_SHT);
	(*serImp)(dst, serSel, (void*)buf, @encode(short), nil);
	return;

      case _C_USHT:
	(*tagImp)(dst, tagSel, _C_USHT);
	(*serImp)(dst, serSel, (void*)buf, @encode(unsigned short), nil);
	return;

      case _C_INT:
	(*tagImp)(dst, tagSel, _C_INT);
	(*serImp)(dst, serSel, (void*)buf, @encode(int), nil);
	return;

      case _C_UINT:
	(*tagImp)(dst, tagSel, _C_UINT);
	(*serImp)(dst, serSel, (void*)buf, @encode(unsigned int), nil);
	return;

      case _C_LNG:
	(*tagImp)(dst, tagSel, _C_LNG);
	(*serImp)(dst, serSel, (void*)buf, @encode(long), nil);
	return;

      case _C_ULNG:
	(*tagImp)(dst, tagSel, _C_ULNG);
	(*serImp)(dst, serSel, (void*)buf, @encode(unsigned long), nil);
	return;

#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:
	(*tagImp)(dst, tagSel, _C_LNG_LNG);
	(*serImp)(dst, serSel, (void*)buf, @encode(long long), nil);
	return;

      case _C_ULNG_LNG:
	(*tagImp)(dst, tagSel, _C_ULNG_LNG);
	(*serImp)(dst, serSel, (void*)buf, @encode(unsigned long long), nil);
	return;

#endif
      case _C_FLT:
	(*tagImp)(dst, tagSel, _C_FLT);
	(*serImp)(dst, serSel, (void*)buf, @encode(float), nil);
	return;

      case _C_DBL:
	(*tagImp)(dst, tagSel, _C_DBL);
	(*serImp)(dst, serSel, (void*)buf, @encode(double), nil);
	return;

      case _C_VOID:
	[NSException raise: NSInvalidArgumentException
		    format: @"can't encode void item"];

      default:
	[NSException raise: NSInvalidArgumentException
		    format: @"item with unknown type - %s", type];
    }
}

- (void) encodeRootObject: (id)rootObject
{
  if (isEncodingRootObject)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"encoding root object more than once"];
    }

  isEncodingRootObject = YES;

  /*
   *	First pass - find conditional objects.
   */
  isInPreparatoryPass = YES;
  (*eObjImp)(self, eObjSel, rootObject);

  /*
   *	Second pass - write archive.
   */
  isInPreparatoryPass = NO;
  (*eObjImp)(self, eObjSel, rootObject);

  /*
   *	Write sizes of crossref arrays to head of archive.
   */
  [self serializeHeaderAt: startPos
		  version: [self systemVersion]
		  classes: clsMap->nodeCount
		  objects: uIdMap->nodeCount
		 pointers: ptrMap->nodeCount];

  isEncodingRootObject = NO;
}

- (void) encodeConditionalObject: (id)anObject
{
  if (isEncodingRootObject == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"conditionally encoding without root object"];
      return;
    }

  if (isInPreparatoryPass)
    {
      FastMapNode	node;

      /*
       *	Conditionally encoding 'nil' is a no-op.
       */
      if (anObject == nil)
	{
	  return;
	}

      /*
       *	If we have already conditionally encoded this object, we can
       *	ignore it this time.
       */
      node = FastMapNodeForKey(cIdMap, (FastMapItem)anObject);
      if (node != 0)
	{
	  return;
	}

      /*
       *	If we have unconditionally encoded this object, we can ignore
       *	it now.
       */
      node = FastMapNodeForKey(uIdMap, (FastMapItem)anObject);
      if (node != 0)
	{
	  return;
	}

      FastMapAddPair(cIdMap, (FastMapItem)anObject, (FastMapItem)0);
    }
  else if (anObject == nil)
    {
      (*eObjImp)(self, eObjSel, nil);
    }
  else
    {
      FastMapNode	node;

      if (repMap->nodeCount)
	{
	  node = FastMapNodeForKey(repMap, (FastMapItem)anObject);
	  if (node)
	    {
	      anObject = (id)node->value.p;
	    }
	}

      node = FastMapNodeForKey(cIdMap, (FastMapItem)anObject);
      if (node != 0)
	{
	  (*eObjImp)(self, eObjSel, nil);
	}
      else
	{
	  (*eObjImp)(self, eObjSel, anObject);
	}
    }
}

- (void) encodeObject: (id)anObject
{
  if (anObject == nil)
    {
      if (isInPreparatoryPass == NO)
	{
	  /*
	   *	Special case - encode a nil pointer as a crossref of zero.
	   */
	  (*tagImp)(dst, tagSel, _C_ID | _C_XREF);
	  (*xRefImp)(dst, xRefSel, 0);
	}
    }
  else if (fastIsInstance(anObject) == NO)
    {
      /*
       *	If the object we have been given is actually a class,
       *	we encode it as a class instead.
       */
      (*eValImp)(self, eValSel, @encode(Class), &anObject);
    }
  else
    {
      FastMapNode	node;

      /*
       *	Substitute replacement object if required.
       */
      node = FastMapNodeForKey(repMap, (FastMapItem)anObject);
      if (node)
	{
	  anObject = (id)node->value.p;
	}

      /*
       *	See if the object has already been encoded.
       */
      node = FastMapNodeForKey(uIdMap, (FastMapItem)anObject);

      if (isInPreparatoryPass)
	{
	  if (node == 0)
	    {
	      /*
	       *	Remove object from map of conditionally encoded objects
	       *	and add it to the map of unconditionay encoded ones.
	       */
	      FastMapRemoveKey(cIdMap, (FastMapItem)anObject);
	      FastMapAddPair(uIdMap, (FastMapItem)anObject, (FastMapItem)0);
	      [anObject encodeWithCoder: self];
	    }
	  return;
	}

      if (node == 0 || node->value.I == 0)
	{
	  Class	cls;
	  id	obj;
	  uchar	info = _C_ID;

	  if (node == 0)
	    {
	      node = FastMapAddPair(uIdMap,
			(FastMapItem)anObject, (FastMapItem)++xRefO);
	    }
	  else
	    {
	      node->value.I = ++xRefO;
	    }

	  obj = [anObject replacementObjectForArchiver: self];
	  cls = [anObject classForArchiver];

	  (*tagImp)(dst, tagSel, _C_ID);
	  (*xRefImp)(dst, xRefSel, node->value.I);
	  if (namMap->nodeCount)
	    {
	      FastMapNode	node;

	      node = FastMapNodeForKey(namMap, (FastMapItem)cls);

	      if (node)
		{
		  cls = (Class)node->value.p;
		}
	    }
	  (*eValImp)(self, eValSel, @encode(Class), &cls);
	  [obj encodeWithCoder: self];
	}
      else if(!isInPreparatoryPass)
	{
	  (*tagImp)(dst, tagSel, _C_ID | _C_XREF);
	  (*xRefImp)(dst, xRefSel, node->value.I);
	}
    }
}

- (NSMutableData*) archiverData
{
  return data;
}

- (NSString*) classNameEncodedForTrueClassName:(NSString*)trueName
{
  if (namMap->nodeCount)
    {
      FastMapNode	node;
      Class		c;

      c = objc_get_class([trueName cString]);
      node = FastMapNodeForKey(namMap, (FastMapItem)c);
      if (node)
	{
	  c = (Class)node->value.p;
	  return [NSString stringWithCString: fastClassName(c)];
	}
    }
  return trueName;
}

- (void) encodeClassName: (NSString*)trueName
	   intoClassName: (NSString*)inArchiveName
{
  FastMapNode	node;
  Class		tc;
  Class		ic;

  tc = objc_get_class([trueName cString]);
  if (tc == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Can't find class '%@'.", trueName];
    }
  ic = objc_get_class([inArchiveName cString]);
  if (ic == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Can't find class '%@'.", inArchiveName];
    }
  node = FastMapNodeForKey(namMap, (FastMapItem)tc);
  if (node == 0)
    {
      FastMapAddPair(namMap, (FastMapItem)(void*)tc, (FastMapItem)(void*)ic);
    }
  else
    {
      node->value.p = (void*)ic;
    }
}

- (void) replaceObject: (id)object
	    withObject: (id)newObject
{
  FastMapNode	node;

  if (object == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"attempt to remap nil"];
    }
  if (newObject == 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"attempt to remap object to nil"];
    }
  node = FastMapNodeForKey(namMap, (FastMapItem)object);
  if (node == 0)
    {
      FastMapAddPair(namMap, (FastMapItem)object, (FastMapItem)newObject);
    }
  else
    {
      node->value.p = (void*)newObject;
    }
}
@end



/*
 *	Catagories for compatibility with old GNUstep encoding.
 */

@implementation	NSArchiver (GNUstep)

/* Re-using an archiver */

- (void) resetArchiver
{
  char        buf[strlen(PREFIX)+33];

  if (clsMap)
    {
      FastMapCleanMap(clsMap);
      if (cIdMap)
	{
	  FastMapCleanMap(cIdMap);
	}
      if (uIdMap)
	{
	  FastMapCleanMap(uIdMap);
	}
      if (ptrMap)
	{
	  FastMapCleanMap(ptrMap);
	}
      if (namMap)
	{
	  FastMapCleanMap(namMap);
	}
      if (repMap)
	{
	  FastMapCleanMap(repMap);
	}
    }
  isEncodingRootObject = NO;
  isInPreparatoryPass = NO;
  xRefC = 0;
  xRefO = 0;
  xRefP = 0;

  /*
   *	Write dummy header
   */
  startPos = [data length];
  [self serializeHeaderAt: startPos
		  version: 0
		  classes: 0
		  objects: 0
		 pointers: 0];
}

- (BOOL) directDataAccess
{
  return YES;
}

- (void) serializeHeaderAt: (unsigned)locationInData
		   version: (unsigned)v
		   classes: (unsigned)cc
		   objects: (unsigned)oc
		  pointers: (unsigned)pc
{
  unsigned	headerLength = strlen(PREFIX)+36;
  char		header[headerLength+1];
  unsigned	dataLength = [data length];

  sprintf(header, "%s%08x:%08x:%08x:%08x:", PREFIX, v, cc, oc, pc);

  if (locationInData + headerLength <= dataLength)
    {
      [data replaceBytesInRange: NSMakeRange(locationInData, headerLength)
		      withBytes: header];
    }
  else if (locationInData == dataLength)
    {
      [data appendBytes: header length: headerLength];
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"serializeHeader:at: bad location"];
    }
}

/* libObjects compatibility */
 
- (void) encodeArrayOfObjCType: (const char*) type
		         count: (unsigned)count
			    at: (const void*)buf
		      withName: (id)name
{
  (*eObjImp)(self, eObjSel, name);
  [self encodeArrayOfObjCType: type count: count at: buf];
}

- (void) encodeIndent
{
}

- (void) encodeValueOfCType: (const char*) type
			 at: (const void*)buf
		   withName: (id)name
{
  (*eObjImp)(self, eObjSel, name);
  (*eValImp)(self, eValSel, type, buf);
}

- (void) encodeValueOfObjCType: (const char*) type
			    at: (const void*)buf
		      withName: (id)name
{
  (*eObjImp)(self, eObjSel, name);
  (*eValImp)(self, eValSel, type, buf);
}

- (void) encodeObject: (id)anObject
	     withName: (id)name
{
  (*eObjImp)(self, eObjSel, name);
  (*eObjImp)(self, eObjSel, anObject);
}
@end

