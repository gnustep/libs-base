/** Implementation of NSArchiver for GNUstep
   Copyright (C) 1998,1999 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSArchiver class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_RETAIN_KEY(X)	
#define	GSI_MAP_RELEASE_KEY(X)	
#define	GSI_MAP_RETAIN_VAL(X)	
#define	GSI_MAP_RELEASE_VAL(X)	
#define	GSI_MAP_HASH(X)	((X).uint)
#define	GSI_MAP_EQUAL(X,Y)	((X).uint == (Y).uint)

#include <base/GSIMap.h>

#define	_IN_NSARCHIVER_M
#include <Foundation/NSArchiver.h>
#undef	_IN_NSARCHIVER_M

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

typedef	unsigned char	uchar;


#define	PREFIX		"GNUstep archive"

@implementation NSArchiver

static SEL serSel;
static SEL tagSel;
static SEL xRefSel;
static SEL eObjSel;
static SEL eValSel;

@class NSMutableDataMalloc;
static Class	NSMutableDataMallocClass;

+ (void) initialize
{
  if (self == [NSArchiver class])
    {
      serSel = @selector(serializeDataAt:ofObjCType:context:);
      tagSel = @selector(serializeTypeTag:);
      xRefSel = @selector(serializeTypeTag:andCrossRef:);
      eObjSel = @selector(encodeObject:);
      eValSel = @selector(encodeValueOfObjCType:at:);
      NSMutableDataMallocClass = [NSMutableDataMalloc class];
    }
}

- (id) init
{
  NSMutableData	*d;

  d = [[NSMutableDataMallocClass allocWithZone: GSObjCZone(self)] init];
  self = [self initForWritingWithMutableData: d];
  RELEASE(d);
  return self;
}

- (id) initForWritingWithMutableData: (NSMutableData*)anObject
{
  self = [super init];
  if (self)
    {
      NSZone		*zone = [self zone];

      _data = RETAIN(anObject);
      if ([self directDataAccess] == YES)
        {
	  _dst = _data;
	}
      else
	{
	  _dst = self;
	}
      _serImp = [_dst methodForSelector: serSel];
      _tagImp = [_dst methodForSelector: tagSel];
      _xRefImp = [_dst methodForSelector: xRefSel];
      _eObjImp = [self methodForSelector: eObjSel];
      _eValImp = [self methodForSelector: eValSel];

      [self resetArchiver];

      /*
       *	Set up map tables.
       */
      _clsMap = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t)*6);
      _cIdMap = &_clsMap[1];
      _uIdMap = &_clsMap[2];
      _ptrMap = &_clsMap[3];
      _namMap = &_clsMap[4];
      _repMap = &_clsMap[5];
      GSIMapInitWithZoneAndCapacity(_clsMap, zone, 100);
      GSIMapInitWithZoneAndCapacity(_cIdMap, zone, 10);
      GSIMapInitWithZoneAndCapacity(_uIdMap, zone, 200);
      GSIMapInitWithZoneAndCapacity(_ptrMap, zone, 100);
      GSIMapInitWithZoneAndCapacity(_namMap, zone, 1);
      GSIMapInitWithZoneAndCapacity(_repMap, zone, 1);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_data);
  if (_clsMap)
    {
      GSIMapEmptyMap(_clsMap);
      if (_cIdMap)
	{
	  GSIMapEmptyMap(_cIdMap);
	}
      if (_uIdMap)
	{
	  GSIMapEmptyMap(_uIdMap);
	}
      if (_ptrMap)
	{
	  GSIMapEmptyMap(_ptrMap);
	}
      if (_namMap)
	{
	  GSIMapEmptyMap(_namMap);
	}
      if (_repMap)
	{
	  GSIMapEmptyMap(_repMap);
	}
      NSZoneFree(_clsMap->zone, (void*)_clsMap);
    }
  return [super dealloc];
}

+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
  NSArchiver	*archiver;
  id		d;
  NSZone	*z = NSDefaultMallocZone();

  d = [[NSMutableDataMallocClass allocWithZone: z] initWithCapacity: 0];
  if (d == nil)
    {
      return nil;
    }
  archiver = [[self allocWithZone: z] initForWritingWithMutableData: d];
  RELEASE(d);
  d = nil;
  if (archiver)
    {
      NS_DURING
	{
	  [archiver encodeRootObject: rootObject];
	  d = AUTORELEASE([archiver->_data copy]);
	}
      NS_HANDLER
	{
	  RELEASE(archiver);
	  [localException raise];
	}
      NS_ENDHANDLER
      RELEASE(archiver);
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
      case _C_ID:	info = _GSC_NONE;		break;
      case _C_CHR:	info = _GSC_CHR;		break;
      case _C_UCHR:	info = _GSC_UCHR; 		break;
      case _C_SHT:	info = _GSC_SHT | _GSC_S_SHT;	break;
      case _C_USHT:	info = _GSC_USHT | _GSC_S_SHT;	break;
      case _C_INT:	info = _GSC_INT | _GSC_S_INT;	break;
      case _C_UINT:	info = _GSC_UINT | _GSC_S_INT;	break;
      case _C_LNG:	info = _GSC_LNG | _GSC_S_LNG;	break;
      case _C_ULNG:	info = _GSC_ULNG | _GSC_S_LNG; break;
      case _C_LNG_LNG:	info = _GSC_LNG_LNG | _GSC_S_LNG_LNG;	break;
      case _C_ULNG_LNG:	info = _GSC_ULNG_LNG | _GSC_S_LNG_LNG;	break;
      case _C_FLT:	info = _GSC_FLT;	break;
      case _C_DBL:	info = _GSC_DBL;	break;
      default:		info = _GSC_NONE;	break;
    }

  /*
   *	Simple types can be serialized immediately, more complex ones
   *	are dealt with by our [encodeValueOfObjCType:at:] method.
   */
  if (info == _GSC_NONE)
    {
      if (_initialPass == NO)
	{
	  (*_tagImp)(_dst, tagSel, _GSC_ARY_B);
	  (*_serImp)(_dst, serSel, &count, @encode(unsigned), nil);
	}
      for (i = 0; i < count; i++)
	{
	  (*_eValImp)(self, eValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else if (_initialPass == NO)
    {
      (*_tagImp)(_dst, tagSel, _GSC_ARY_B);
      (*_serImp)(_dst, serSel, &count, @encode(unsigned), nil);

      (*_tagImp)(_dst, tagSel, info);
      for (i = 0; i < count; i++)
	{
	  (*_serImp)(_dst, serSel, (char*)buf + offset, type, nil);
	  offset += size;
	}
    }
}

- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)buf
{
  switch (*type)
    {
      case _C_ID:
	(*_eObjImp)(self, eObjSel, *(void**)buf);
	return;

      case _C_ARY_B:
	{
	  int		count = atoi(++type);

	  while (isdigit(*type))
	    {
	      type++;
	    }

	  if (_initialPass == NO)
	    {
	      (*_tagImp)(_dst, tagSel, _GSC_ARY_B);
	    }

	  [self encodeArrayOfObjCType: type count: count at: buf];
	}
	return;

      case _C_STRUCT_B:
	{
	  int	offset = 0;

	  if (_initialPass == NO)
	    {
	      (*_tagImp)(_dst, tagSel, _GSC_STRUCT_B);
	    }

	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */

	  for (;;)
	    {
	      (*_eValImp)(self, eValSel, type, (char*)buf + offset);
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
	    if (_initialPass == NO)
	      {
		/*
		 *	Special case - a nul pointer gets an xref of zero
		 */
		(*_tagImp)(_dst, tagSel, _GSC_PTR | _GSC_XREF | _GSC_X_0);
	      }
	  }
	else
	  {
	    GSIMapNode	node;

	    node = GSIMapNodeForKey(_ptrMap, (GSIMapKey)*(void**)buf);
	    if (_initialPass == YES)
	      {
		/*
		 *	First pass - add pointer to map and encode item pointed
		 *	to in case it is a conditionally encoded object.
		 */
		if (node == 0)
		  {
		    GSIMapAddPair(_ptrMap,
			(GSIMapKey)*(void**)buf, (GSIMapVal)0);
		    type++;
		    buf = *(char**)buf;
		    (*_eValImp)(self, eValSel, type, buf);
		  }
	      }
	    else if (node == 0 || node->value.uint == 0)
	      {
		/*
		 *	Second pass, unwritten pointer - write it.
		 */
		if (node == 0)
		  {
		    node = GSIMapAddPair(_ptrMap,
			(GSIMapKey)*(void**)buf, (GSIMapVal)++_xRefP);
		  }
		else
		  {
		    node->value.uint = ++_xRefP;
		  }
		(*_xRefImp)(_dst, xRefSel, _GSC_PTR, node->value.uint);
		type++;
		buf = *(char**)buf;
		(*_eValImp)(self, eValSel, type, buf);
	      }
	    else
	      {
		/*
		 *	Second pass, write a cross-reference number.
		 */
		(*_xRefImp)(_dst, xRefSel, _GSC_PTR|_GSC_XREF,
		  node->value.uint);
	      }
	  }
	return;

      default:	/* Types that can be ignored in first pass.	*/
	if (_initialPass)
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
	    (*_tagImp)(_dst, tagSel, _GSC_CLASS | _GSC_XREF | _GSC_X_0);
	  }
	else
	  {
	    Class	c = *(Class*)buf;
	    GSIMapNode	node;
	    BOOL	done = NO;

	    node = GSIMapNodeForKey(_clsMap, (GSIMapKey)(void*)c);
	    
	    if (node != 0)
	      {
		(*_xRefImp)(_dst, xRefSel, _GSC_CLASS | _GSC_XREF,
		  node->value.uint);
		return;
	      }
	    while (done == NO)
	      {
		int		tmp = GSObjCVersion(c);
		unsigned	version = tmp;
		Class		s = GSObjCSuper(c);

		if (tmp < 0)
		  {
		    [NSException raise: NSInternalInconsistencyException
				format: @"negative class version"];
		  }
		node = GSIMapAddPair(_clsMap,
			(GSIMapKey)(void*)c, (GSIMapVal)++_xRefC);
		/*
		 *	Encode tag and crossref number.
		 */
		(*_xRefImp)(_dst, xRefSel, _GSC_CLASS, node->value.uint);
		/*
		 *	Encode class, and version.
		 */
		(*_serImp)(_dst, serSel, &c, @encode(Class), nil);
		(*_serImp)(_dst, serSel, &version, @encode(unsigned), nil);
		/*
		 *	If we have a super class that has not been encoded,
		 *	we must loop round to encode it here so that its
		 *	version information will be available when objects
		 *	of its subclasses are decoded and call
		 *	[super initWithCoder:ccc]
		 */
		if (s == c || s == 0
		  || GSIMapNodeForKey(_clsMap, (GSIMapKey)(void*)s) != 0)
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
	    (*_tagImp)(_dst, tagSel, _GSC_NONE);
	  }
	return;

      case _C_SEL:
	if (*(SEL*)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*_tagImp)(_dst, tagSel, _GSC_SEL | _GSC_XREF | _GSC_X_0);
	  }
	else
	  {
	    SEL		s = *(SEL*)buf;
	    GSIMapNode	node = GSIMapNodeForKey(_ptrMap, (GSIMapKey)(void*)s);

	    if (node == 0)
	      {
		node = GSIMapAddPair(_ptrMap,
		  (GSIMapKey)(void*)s, (GSIMapVal)++_xRefP);
		(*_xRefImp)(_dst, xRefSel, _GSC_SEL, node->value.uint);
		/*
		 *	Encode selector.
		 */
		(*_serImp)(_dst, serSel, buf, @encode(SEL), nil);
	      }
	    else
	      {
		(*_xRefImp)(_dst, xRefSel, _GSC_SEL|_GSC_XREF,
		  node->value.uint);
	      }
	  }
	return;

      case _C_CHARPTR:
	if (*(char**)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*_tagImp)(_dst, tagSel, _GSC_CHARPTR | _GSC_XREF | _GSC_X_0);
	  }
	else
	  {
	    GSIMapNode	node;

	    node = GSIMapNodeForKey(_ptrMap, (GSIMapKey)*(char**)buf);
	    if (node == 0)
	      {
		node = GSIMapAddPair(_ptrMap,
			(GSIMapKey)*(char**)buf, (GSIMapVal)++_xRefP);
		(*_xRefImp)(_dst, xRefSel, _GSC_CHARPTR, node->value.uint);
		(*_serImp)(_dst, serSel, buf, type, nil);
	      }
	    else
	      {
		(*_xRefImp)(_dst, xRefSel, _GSC_CHARPTR|_GSC_XREF,
		  node->value.uint);
	      }
	  }
	return;

      case _C_CHR:
	(*_tagImp)(_dst, tagSel, _GSC_CHR);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(signed char), nil);
	return;

      case _C_UCHR:
	(*_tagImp)(_dst, tagSel, _GSC_UCHR);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(unsigned char), nil);
	return;

      case _C_SHT:
	(*_tagImp)(_dst, tagSel, _GSC_SHT | _GSC_S_SHT);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(short), nil);
	return;

      case _C_USHT:
	(*_tagImp)(_dst, tagSel, _GSC_USHT | _GSC_S_SHT);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(unsigned short), nil);
	return;

      case _C_INT:
	(*_tagImp)(_dst, tagSel, _GSC_INT | _GSC_S_INT);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(int), nil);
	return;

      case _C_UINT:
	(*_tagImp)(_dst, tagSel, _GSC_UINT | _GSC_S_INT);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(unsigned int), nil);
	return;

      case _C_LNG:
	(*_tagImp)(_dst, tagSel, _GSC_LNG | _GSC_S_LNG);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(long), nil);
	return;

      case _C_ULNG:
	(*_tagImp)(_dst, tagSel, _GSC_ULNG | _GSC_S_LNG);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(unsigned long), nil);
	return;

      case _C_LNG_LNG:
	(*_tagImp)(_dst, tagSel, _GSC_LNG_LNG | _GSC_S_LNG_LNG);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(long long), nil);
	return;

      case _C_ULNG_LNG:
	(*_tagImp)(_dst, tagSel, _GSC_ULNG_LNG | _GSC_S_LNG_LNG);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(unsigned long long), nil);
	return;

      case _C_FLT:
	(*_tagImp)(_dst, tagSel, _GSC_FLT);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(float), nil);
	return;

      case _C_DBL:
	(*_tagImp)(_dst, tagSel, _GSC_DBL);
	(*_serImp)(_dst, serSel, (void*)buf, @encode(double), nil);
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
  if (_encodingRoot)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"encoding root object more than once"];
    }

  _encodingRoot = YES;

  /*
   *	First pass - find conditional objects.
   */
  _initialPass = YES;
  (*_eObjImp)(self, eObjSel, rootObject);

  /*
   *	Second pass - write archive.
   */
  _initialPass = NO;
  (*_eObjImp)(self, eObjSel, rootObject);

  /*
   *	Write sizes of crossref arrays to head of archive.
   */
  [self serializeHeaderAt: _startPos
		  version: [self systemVersion]
		  classes: _clsMap->nodeCount
		  objects: _uIdMap->nodeCount
		 pointers: _ptrMap->nodeCount];

  _encodingRoot = NO;
}

- (void) encodeConditionalObject: (id)anObject
{
  if (_encodingRoot == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"conditionally encoding without root object"];
      return;
    }

  if (_initialPass)
    {
      GSIMapNode	node;

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
      node = GSIMapNodeForKey(_cIdMap, (GSIMapKey)anObject);
      if (node != 0)
	{
	  return;
	}

      /*
       *	If we have unconditionally encoded this object, we can ignore
       *	it now.
       */
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)anObject);
      if (node != 0)
	{
	  return;
	}

      GSIMapAddPair(_cIdMap, (GSIMapKey)anObject, (GSIMapVal)0);
    }
  else if (anObject == nil)
    {
      (*_eObjImp)(self, eObjSel, nil);
    }
  else
    {
      GSIMapNode	node;

      if (_repMap->nodeCount)
	{
	  node = GSIMapNodeForKey(_repMap, (GSIMapKey)anObject);
	  if (node)
	    {
	      anObject = (id)node->value.ptr;
	    }
	}

      node = GSIMapNodeForKey(_cIdMap, (GSIMapKey)anObject);
      if (node != 0)
	{
	  (*_eObjImp)(self, eObjSel, nil);
	}
      else
	{
	  (*_eObjImp)(self, eObjSel, anObject);
	}
    }
}

- (void) encodeDataObject: (NSData*)anObject
{
  unsigned	l = [anObject length];

  (*_eValImp)(self, eValSel, @encode(unsigned int), &l);
  if (l)
    {
      const void	*b = [anObject bytes];
      unsigned char	c = 0;			/* Type tag	*/

      /*
       * The type tag 'c' is used to specify an encoding scheme for the
       * actual data - at present we have '0' meaning raw data.  In the
       * future we might want zipped data for instance.
       */
      (*_eValImp)(self, eValSel, @encode(unsigned char), &c);
      [self encodeArrayOfObjCType: @encode(unsigned char)
			    count: l
			       at: b];
    }
}

- (void) encodeObject: (id)anObject
{
  if (anObject == nil)
    {
      if (_initialPass == NO)
	{
	  /*
	   *	Special case - encode a nil pointer as a crossref of zero.
	   */
	  (*_tagImp)(_dst, tagSel, _GSC_ID | _GSC_XREF, _GSC_X_0);
	}
    }
  else
    {
      GSIMapNode	node;

      /*
       *	Substitute replacement object if required.
       */
      node = GSIMapNodeForKey(_repMap, (GSIMapKey)anObject);
      if (node)
	{
	  anObject = (id)node->value.ptr;
	}

      /*
       *	See if the object has already been encoded.
       */
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)anObject);

      if (_initialPass)
	{
	  if (node == 0)
	    {
	      /*
	       *	Remove object from map of conditionally encoded objects
	       *	and add it to the map of unconditionay encoded ones.
	       */
	      GSIMapRemoveKey(_cIdMap, (GSIMapKey)anObject);
	      GSIMapAddPair(_uIdMap, (GSIMapKey)anObject, (GSIMapVal)0);
	      [anObject encodeWithCoder: self];
	    }
	  return;
	}

      if (node == 0 || node->value.uint == 0)
	{
	  Class	cls;
	  id	obj;

	  if (node == 0)
	    {
	      node = GSIMapAddPair(_uIdMap,
			(GSIMapKey)anObject, (GSIMapVal)++_xRefO);
	    }
	  else
	    {
	      node->value.uint = ++_xRefO;
	    }

	  obj = [anObject replacementObjectForArchiver: self];
	  if (GSObjCIsInstance(obj) == NO)
	    {
	      /*
	       * If the object we have been given is actually a class,
	       * we encode it as a special case.
	       */
	      (*_xRefImp)(_dst, xRefSel, _GSC_CID, node->value.uint);
	      (*_eValImp)(self, eValSel, @encode(Class), &obj);
	    }
	  else
	    {
	      cls = [obj classForArchiver];
	      if (_namMap->nodeCount)
		{
		  GSIMapNode	n;

		  n = GSIMapNodeForKey(_namMap, (GSIMapKey)cls);

		  if (n)
		    {
		      cls = (Class)n->value.ptr;
		    }
		}
	      (*_xRefImp)(_dst, xRefSel, _GSC_ID, node->value.uint);
	      (*_eValImp)(self, eValSel, @encode(Class), &cls);
	      [obj encodeWithCoder: self];
	    }
	}
      else
	{
	  (*_xRefImp)(_dst, xRefSel, _GSC_ID | _GSC_XREF, node->value.uint);
	}
    }
}

- (NSMutableData*) archiverData
{
  return _data;
}

- (NSString*) classNameEncodedForTrueClassName: (NSString*)trueName
{
  if (_namMap->nodeCount)
    {
      GSIMapNode	node;
      Class		c;

      c = objc_get_class([trueName cString]);
      node = GSIMapNodeForKey(_namMap, (GSIMapKey)c);
      if (node)
	{
	  c = (Class)node->value.ptr;
	  return [NSString stringWithCString: GSObjCName(c)];
	}
    }
  return trueName;
}

- (void) encodeClassName: (NSString*)trueName
	   intoClassName: (NSString*)inArchiveName
{
  GSIMapNode	node;
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
  node = GSIMapNodeForKey(_namMap, (GSIMapKey)tc);
  if (node == 0)
    {
      GSIMapAddPair(_namMap, (GSIMapKey)(void*)tc, (GSIMapVal)(void*)ic);
    }
  else
    {
      node->value.ptr = (void*)ic;
    }
}

- (void) replaceObject: (id)object
	    withObject: (id)newObject
{
  GSIMapNode	node;

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
  node = GSIMapNodeForKey(_repMap, (GSIMapKey)object);
  if (node == 0)
    {
      GSIMapAddPair(_repMap, (GSIMapKey)object, (GSIMapVal)newObject);
    }
  else
    {
      node->value.ptr = (void*)newObject;
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
  if (_clsMap)
    {
      GSIMapCleanMap(_clsMap);
      if (_cIdMap)
	{
	  GSIMapCleanMap(_cIdMap);
	}
      if (_uIdMap)
	{
	  GSIMapCleanMap(_uIdMap);
	}
      if (_ptrMap)
	{
	  GSIMapCleanMap(_ptrMap);
	}
      if (_namMap)
	{
	  GSIMapCleanMap(_namMap);
	}
      if (_repMap)
	{
	  GSIMapCleanMap(_repMap);
	}
    }
  _encodingRoot = NO;
  _initialPass = NO;
  _xRefC = 0;
  _xRefO = 0;
  _xRefP = 0;

  /*
   *	Write dummy header
   */
  _startPos = [_data length];
  [self serializeHeaderAt: _startPos
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
  unsigned	dataLength = [_data length];

  sprintf(header, "%s%08x:%08x:%08x:%08x:", PREFIX, v, cc, oc, pc);

  if (locationInData + headerLength <= dataLength)
    {
      [_data replaceBytesInRange: NSMakeRange(locationInData, headerLength)
		      withBytes: header];
    }
  else if (locationInData == dataLength)
    {
      [_data appendBytes: header length: headerLength];
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"serializeHeader:at: bad location"];
    }
}

@end

