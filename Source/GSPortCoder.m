/* Implementation of NSPortCoder object for remote messaging
   Copyright (C) 1997,2000 Free Software Foundation, Inc.

   This implementation for OPENSTEP conformance written by
	Richard Frith-Macdonald <richard@brainstorm.co.u>
        Created: August 1997, rewritten June 2000

   based on original code -

        Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.

        Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
        Created: July 1994

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

#include <config.h>
#include <string.h>
#include <objc/objc-api.h>

#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSString.h>

#include <Foundation/DistributedObjects.h>
#include <base/fast.x>

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

/*
 *	Setup for inline operation of arrays.
 */
#define	GSI_ARRAY_RETAIN(X)	
#define	GSI_ARRAY_RELEASE(X)	
#define	GSI_ARRAY_TYPES	GSUNION_OBJ|GSUNION_SEL|GSUNION_STR

#include <base/GSIArray.h>



#define	_IN_PORT_CODER_M
#include <Foundation/GSPortCoder.h>
#undef	_IN_PORT_CODER_M

static BOOL debug_port_coder = NO;

typedef	unsigned char	uchar;

#define	PREFIX		"GNUstep DO archive"

static SEL eSerSel = @selector(serializeDataAt:ofObjCType:context:);
static SEL eTagSel = @selector(serializeTypeTag:);
static SEL xRefSel = @selector(serializeTypeTag:andCrossRef:);
static SEL eObjSel = @selector(encodeObject:);
static SEL eValSel = @selector(encodeValueOfObjCType:at:);
static SEL dDesSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);
static SEL dTagSel = @selector(deserializeTypeTag:andCrossRef:atCursor:);
static SEL dValSel = @selector(decodeValueOfObjCType:at:);



static const char*
typeToName1(char type)
{
  switch (type)
    {
      case _C_CLASS:	return "class";
      case _C_ID:	return "object";
      case _C_SEL:	return "selector";
      case _C_CHR:	return "char";
      case _C_UCHR:	return "unsigned char";
      case _C_SHT:	return "short";
      case _C_USHT:	return "unsigned short";
      case _C_INT:	return "int";
      case _C_UINT:	return "unsigned int";
      case _C_LNG:	return "long";
      case _C_ULNG:	return "unsigned long";
      case _C_LNG_LNG:	return "long long";
      case _C_ULNG_LNG:	return "unsigned long long";
      case _C_FLT:	return "float";
      case _C_DBL:	return "double";
      case _C_PTR:	return "pointer";
      case _C_CHARPTR:	return "cstring";
      case _C_ARY_B:	return "array";
      case _C_STRUCT_B:	return "struct";
      default:
	{
	  static char	buf1[32];
	  static char	buf2[32];
	  static char	*bufptr = buf1;

	  if (bufptr == buf1)
	    {
		bufptr = buf2;
	    }
	  else
	    {
	      bufptr = buf1;
	    }
	  sprintf(bufptr, "unknown type info - 0x%x", type);
	  return bufptr;
	}
    }
}

static const char*
typeToName2(char type)
{
  switch (type & _GSC_MASK)
    {
      case _GSC_CLASS:	return "class";
      case _GSC_ID:	return "object";
      case _GSC_SEL:	return "selector";
      case _GSC_CHR:	return "char";
      case _GSC_UCHR:	return "unsigned char";
      case _GSC_SHT:	return "short";
      case _GSC_USHT:	return "unsigned short";
      case _GSC_INT:	return "int";
      case _GSC_UINT:	return "unsigned int";
      case _GSC_LNG:	return "long";
      case _GSC_ULNG:	return "unsigned long";
      case _GSC_LNG_LNG:	return "long long";
      case _GSC_ULNG_LNG:	return "unsigned long long";
      case _GSC_FLT:	return "float";
      case _GSC_DBL:	return "double";
      case _GSC_PTR:	return "pointer";
      case _GSC_CHARPTR:	return "cstring";
      case _GSC_ARY_B:	return "array";
      case _GSC_STRUCT_B:	return "struct";
      default:
	{
	  static char	buf1[32];
	  static char	buf2[32];
	  static char	*bufptr = buf1;

	  if (bufptr == buf1)
	    {
		bufptr = buf2;
	    }
	  else
	    {
	      bufptr = buf1;
	    }
	  sprintf(bufptr, "unknown type info - 0x%x", type);
	  return bufptr;
	}
    }
}

/*
 *	There are thirtyone possible basic types.  We reserve a type of zero
 *	to mean that no information is specified.  The slots in this array
 *	MUST correspond to the definitions in NSData.h
 */
static char	type_map[32] = {
  0,
  _C_CHR,
  _C_UCHR,
  _C_SHT,
  _C_USHT,
  _C_INT,
  _C_UINT,
  _C_LNG,
  _C_ULNG,
#ifdef	_C_LNG_LNG
  _C_LNG_LNG,
  _C_ULNG_LNG,
#else
  0,
  0,
#endif
  _C_FLT,
  _C_DBL,
  0,
  0,
  0,
  _C_ID,
  _C_CLASS,
  _C_SEL,
  _C_PTR,
  _C_CHARPTR,
  _C_ARY_B,
  _C_STRUCT_B,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0
};

static inline void
typeCheck(char t1, char t2)
{
  if (type_map[(t2 & _GSC_MASK)] != t1)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected %s and got %s",
		    typeToName1(t1), typeToName2(t2)];
    }
}

@interface	GSClassInfo : NSObject
{
@public
  Class		class;
  unsigned	version;
}
+ (id) newWithClass: (Class)c andVersion: (unsigned)v;
@end

@implementation	GSClassInfo
+ (id) newWithClass: (Class)c andVersion: (unsigned)v;
{
  GSClassInfo	*info;

  info = (GSClassInfo*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  if (info != nil)
    {
      info->class = c;
      info->version = v;
    }
  return info;
}
- (void) dealloc
{
  NSDeallocateObject(self);
}
@end





@interface	GSPortCoder (Private)
- (void) _deserializeHeaderAt: (unsigned*)pos
		      version: (unsigned*)v
		      classes: (unsigned*)c
		      objects: (unsigned*)o
		     pointers: (unsigned*)p;
- (void) _serializeHeaderAt: (unsigned)pos
		    version: (unsigned)v
		    classes: (unsigned)c
		    objects: (unsigned)o
		   pointers: (unsigned)p;
- (id) _setupForDecoding;
- (id) _setupForEncoding;
@end


@implementation GSPortCoder

+ (NSPortCoder*) portCoderWithReceivePort: (NSPort*)recv
				 sendPort: (NSPort*)send
			       components: (NSArray*)comp;
{
  id	coder;

  coder = [self allocWithZone: NSDefaultMallocZone()];
  coder = [coder initWithReceivePort: recv sendPort: send components: comp];
  AUTORELEASE(coder);
  return coder;
}

- (NSConnection*) connection
{
  return _conn;
}

- (void) dealloc
{
  RELEASE(_comp);
  RELEASE(_conn);
  RELEASE(_cInfo);
  if (_clsMap != 0)
    {
      GSIMapEmptyMap(_clsMap);
      GSIMapEmptyMap(_cIdMap);
      GSIMapEmptyMap(_uIdMap);
      GSIMapEmptyMap(_ptrMap);
      NSZoneFree(_clsMap->zone, (void*)_clsMap);
    }
  if (_clsAry != 0)
    {
      GSIArrayClear(_clsAry);
      GSIArrayClear(_objAry);
      GSIArrayClear(_ptrAry);
      NSZoneFree(_clsAry->zone, (void*)_clsAry);
    }

  [super dealloc];
}

- (void) decodeArrayOfObjCType: (const char*)type
			 count: (unsigned)expected
			    at: (void*)buf
{
  int		i;
  int		offset = 0;
  int		size = objc_sizeof_type(type);
  unsigned char	info;
  unsigned	count;

  (*_dTagImp)(_src, dTagSel, &info, 0, &_cursor);
  (*_dDesImp)(_src, dDesSel, &count, @encode(unsigned), &_cursor, nil);
  if (info != _GSC_ARY_B)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected array and got %s", typeToName2(info)];
    }
  if (count != expected)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected array count %u and got %u",
			expected, count];
    }

  switch (*type)
    {
      case _C_ID:	info = _GSC_NONE; break;
      case _C_CHR:	info = _GSC_CHR; break;
      case _C_UCHR:	info = _GSC_UCHR; break;
      case _C_SHT:	info = _GSC_SHT; break;
      case _C_USHT:	info = _GSC_USHT; break;
      case _C_INT:	info = _GSC_INT; break;
      case _C_UINT:	info = _GSC_UINT; break;
      case _C_LNG:	info = _GSC_LNG; break;
      case _C_ULNG:	info = _GSC_ULNG; break;
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:	info = _GSC_LNG_LNG; break;
      case _C_ULNG_LNG:	info = _GSC_ULNG_LNG; break;
#endif
      case _C_FLT:	info = _GSC_FLT; break;
      case _C_DBL:	info = _GSC_DBL; break;
      default:		info = _GSC_NONE; break;
    }

  if (info == _GSC_NONE)
    {
      for (i = 0; i < count; i++)
	{
	  (*_dValImp)(self, dValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else
    {
      unsigned char	ainfo;

      (*_dTagImp)(_src, dTagSel, &ainfo, 0, &_cursor);
      if (info != (ainfo & _GSC_MASK))
        {
          [NSException raise: NSInternalInconsistencyException
                      format: @"expected %s and got %s",
                        typeToName2(info), typeToName2(ainfo)];
        }

      for (i = 0; i < count; i++)
	{
	  (*_dDesImp)(_src, dDesSel, (char*)buf + offset, type, &_cursor, nil);
	  offset += size;
	}
    }
}

- (NSData*) decodeDataObject
{
  int	pos;

  [self decodeValueOfObjCType: @encode(int) at: &pos];
  if (pos >= 0)
    {
      return [_comp objectAtIndex: pos];
    }
  else if (pos == -1)
    {
      return nil;
    }
  else if (pos == -2)
    {
      return [NSData data];
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Bad tag (%d) decoding data object", pos];
      return nil;
    }
}

- (NSPort*) decodePortObject
{
  unsigned	pos;

  [self decodeValueOfObjCType: @encode(unsigned) at: &pos];
  return [_comp objectAtIndex: pos];
}

/*
 *	The [-decodeObject] method is implemented purely for performance -
 *	It duplicates the code for handling objects in the
 *	[-decodeValueOfObjCType:at:] method above, but differs in that the
 *	resulting object is autoreleased when it comes from this method.
 */
- (id) decodeObject
{
  unsigned char	info;
  unsigned	xref;
  id		obj;

  (*_dTagImp)(_src, dTagSel, &info, &xref, &_cursor);
  if ((info & _GSC_MASK) != _GSC_ID)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected object and got %s", typeToName2(info)];
    }

  /*
   *	Special case - a zero crossref value is a nil pointer.
   */
  if ((info & _GSC_SIZE) == 0)
    {
      return nil;
    }

  if (info & _GSC_XREF)
    {
      if (xref >= GSIArrayCount(_objAry))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"object crossref missing - %d",
			    xref];
	}
      obj = GSIArrayItemAtIndex(_objAry, xref).obj;
      /*
       *	If it's a cross-reference, we don't need to autorelease it
       *	since we didn't create it.
       */
      return obj;
    }
  else
    {
      Class	c;
      id	rep;

      if (xref != GSIArrayCount(_objAry))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"extra object crossref - %d",
			    xref];
	}
      (*_dValImp)(self, dValSel, @encode(Class), &c);

      obj = [c allocWithZone: _zone];
      GSIArrayAddItem(_objAry, (GSIArrayItem)obj);

      rep = [obj initWithCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  GSIArraySetItemAtIndex(_objAry, (GSIArrayItem)obj, xref);
	}

      rep = [obj awakeAfterUsingCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  GSIArraySetItemAtIndex(_objAry, (GSIArrayItem)obj, xref);
	}
      /*
       *	A newly allocated object needs to be autoreleased.
       */
      return AUTORELEASE(obj);
    }
}

- (void) decodeValueOfObjCType: (const char*)type
			    at: (void*)address
{
  unsigned	xref;
  unsigned char	info;
#if	GS_HAVE_I128
    gsu128	bigval;
#else
#if	GS_HAVE_I64
    gsu64	bigval;
#else
    gsu32	bigval;
#endif
#endif

  (*_dTagImp)(_src, dTagSel, &info, &xref, &_cursor);

  switch (info & _GSC_MASK)
    {
      case _GSC_ID:
	{
	  id		obj;

	  typeCheck(*type, _GSC_ID);
	  /*
	   *	Special case - a zero crossref value size is a nil pointer.
	   */
	  if ((info & _GSC_SIZE) == 0)
	    {
	      obj = nil;
	    }
	  else
	    {
	      if (info & _GSC_XREF)
		{
		  if (xref >= GSIArrayCount(_objAry))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"object crossref missing - %d",
					xref];
		    }
		  obj = GSIArrayItemAtIndex(_objAry, xref).obj;
		  /*
		   *	If it's a cross-reference, we need to retain it in
		   *	order to give the appearance that it's actually a
		   *	new object.
		   */
		  IF_NO_GC(RETAIN(obj));
		}
	      else
		{
		  Class	c;
		  id	rep;

		  if (xref != GSIArrayCount(_objAry))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"extra object crossref - %d",
					xref];
		    }
		  (*_dValImp)(self, dValSel, @encode(Class), &c);

		  obj = [c allocWithZone: _zone];
		  GSIArrayAddItem(_objAry, (GSIArrayItem)obj);

		  rep = [obj initWithCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      GSIArraySetItemAtIndex(_objAry, (GSIArrayItem)obj, xref);
		    }

		  rep = [obj awakeAfterUsingCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      GSIArraySetItemAtIndex(_objAry, (GSIArrayItem)obj, xref);
		    }
		}
	    }
	  *(id*)address = obj;
	  return;
	}

      case _GSC_CLASS:
	{
	  Class		c;
	  GSClassInfo	*classInfo;
	  Class		dummy;

	  typeCheck(*type, _GSC_CLASS);
	  /*
	   *	Special case - a zero crossref value size is a nil pointer.
	   */
	  if ((info & _GSC_SIZE) == 0)
	    {
	      *(SEL*)address = 0;
	      return;
	    }
	  if (info & _GSC_XREF)
	    {
	      if (xref >= GSIArrayCount(_clsAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"class crossref missing - %d", xref];
		}
	      classInfo = (GSClassInfo*)GSIArrayItemAtIndex(_clsAry, xref).obj;
	      *(Class*)address = classInfo->class;
	      return;
	    }
	  while ((info & _GSC_MASK) == _GSC_CLASS)
	    {
	      unsigned	cver;
	      NSString	*className;

	      if (xref != GSIArrayCount(_clsAry))
		{
		  [NSException raise: NSInternalInconsistencyException
				format: @"extra class crossref - %d", xref];
		}
	      (*_dDesImp)(_src, dDesSel, &c, @encode(Class), &_cursor, nil);
	      (*_dDesImp)(_src, dDesSel, &cver, @encode(unsigned), &_cursor,
		nil);
	      if (c == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"decoded nil class"];
		}
	      className = NSStringFromClass(c);
	      classInfo = [_cInfo objectForKey: className];
	      if (classInfo == nil)
		{
		  classInfo = [GSClassInfo newWithClass: c andVersion: cver];
		  [_cInfo setObject: classInfo forKey: className];
		  RELEASE(classInfo);
		}
	      GSIArrayAddItem(_clsAry, (GSIArrayItem)classInfo);
	      *(Class*)address = classInfo->class;
	      /*
	       *	Point the address to a dummy location and read the
	       *	next tag - if it is another class, loop to get it.
	       */
	      address = &dummy;
	      (*_dTagImp)(_src, dTagSel, &info, &xref, &_cursor);
	    }
	  if (info != _GSC_NONE)
	    {
	      [NSException raise: NSInternalInconsistencyException
			  format: @"class list improperly terminated"];
	    }
	  return;
	}

      case _GSC_SEL:
	{
	  SEL		sel;

	  typeCheck(*type, _GSC_SEL);
	  /*
	   *	Special case - a zero crossref value size is a nil pointer.
	   */
	  if ((info & _GSC_SIZE) == 0)
	    {
	      *(SEL*)address = 0;
	      return;
	    }
	  if (info & _GSC_XREF)
	    {
	      if (xref >= GSIArrayCount(_ptrAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"sel crossref missing - %d", xref];
		}
	      sel = GSIArrayItemAtIndex(_ptrAry, xref).sel;
	    }
	  else
	    {
	      if (xref != GSIArrayCount(_ptrAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra sel crossref - %d", xref];
		}
	      (*_dDesImp)(_src, dDesSel, &sel, @encode(SEL), &_cursor, nil);
	      GSIArrayAddItem(_ptrAry, (GSIArrayItem)sel);
	    }
	  *(SEL*)address = sel;
	  return;
	}

      case _GSC_ARY_B:
	{
	  int	count;

	  typeCheck(*type, _GSC_ARY_B);
	  count = atoi(++type);
	  while (isdigit(*type))
	    {
	      type++;
	    }
	  [self decodeArrayOfObjCType: type count: count at: address];
	  return;
	}

      case _GSC_STRUCT_B:
	{
	  int offset = 0;

	  typeCheck(*type, _GSC_STRUCT_B);
	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	  for (;;)
	    {
	      (*_dValImp)(self, dValSel, type, (char*)address + offset);
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
	  return;
	}

      case _GSC_PTR:
	{
	  typeCheck(*type, _GSC_PTR);
	  /*
	   *	Special case - a zero crossref value size is a nil pointer.
	   */
	  if ((info & _GSC_SIZE) == 0)
	    {
	      *(void**)address = 0;
	      return;
	    }
	  if (info & _GSC_XREF)
	    {
	      if (xref >= GSIArrayCount(_ptrAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"ptr crossref missing - %d", xref];
		}
	      *(void**)address = GSIArrayItemAtIndex(_ptrAry, xref).ptr;
	    }
	  else
	    {
	      unsigned	size;

	      if (GSIArrayCount(_ptrAry) != xref)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra ptr crossref - %d", xref];
		}

	      /*
	       *	Allocate memory for object to be decoded into and
	       *	add it to the crossref map.
	       */
	      size = objc_sizeof_type(++type);
	      *(void**)address = _fastMallocBuffer(size);
	      GSIArrayAddItem(_ptrAry, (GSIArrayItem)*(void**)address);

	      /*
	       *	Decode value and add memory to map for crossrefs.
	       */
	      (*_dValImp)(self, dValSel, type, *(void**)address);
	    }
	  return;
	}

      case _GSC_CHARPTR:
	{
	  typeCheck(*type, _GSC_CHARPTR);
	  /*
	   *	Special case - a zero crossref value size is a nil pointer.
	   */
	  if ((info & _GSC_SIZE) == 0)
	    {
	      *(char**)address = 0;
	      return;
	    }
	  if (info & _GSC_XREF)
	    {
	      if (xref >= GSIArrayCount(_ptrAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"string crossref missing - %d", xref];
		}
	      *(char**)address = GSIArrayItemAtIndex(_ptrAry, xref).str;
	    }
	  else
	    {
	      if (xref != GSIArrayCount(_ptrAry))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra string crossref - %d", xref];
		}
	      (*_dDesImp)(_src, dDesSel, address, @encode(char*), &_cursor,
		nil);
	      GSIArrayAddItem(_ptrAry, (GSIArrayItem)*(void**)address);
	    }
	  return;
	}

      case _GSC_CHR:
      case _GSC_UCHR:
	typeCheck(*type, info & _GSC_MASK);
	(*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	return;

      case _GSC_SHT:
      case _GSC_USHT:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_SHT)
	  {
	    (*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	    return;
	  }
	break;

      case _GSC_INT:
      case _GSC_UINT:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_INT)
	  {
	    (*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	    return;
	  }
	break;

      case _GSC_LNG:
      case _GSC_ULNG:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_LNG)
	  {
	    (*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	    return;
	  }
	break;

#ifdef	_C_LNG_LNG
      case _GSC_LNG_LNG:
      case _GSC_ULNG_LNG:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_LNG_LNG)
	  {
	    (*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	    return;
	  }
	break;

#endif
      case _GSC_FLT:
	typeCheck(*type, _GSC_FLT);
	(*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	return;

      case _GSC_DBL:
	typeCheck(*type, _GSC_DBL);
	(*_dDesImp)(_src, dDesSel, address, type, &_cursor, nil);
	return;

      default:
	[NSException raise: NSInternalInconsistencyException
		    format: @"read unknown type info - %d", info];
    }

  /*
   *	We fall through to here only when we have to decode a value
   *	whose natural size on this system is not the same as on the
   *	machine on which the archive was created.
   */

  /*
   *	First, we read the data and convert it to the largest size
   *	this system can support.
   */
  switch (info & _GSC_SIZE)
    {
      case _GSC_I16:	/* Encoded as 16-bit	*/
	{
	  gsu16	val;

	  (*_dDesImp)(_src, dDesSel, &val, @encode(gsu16), &_cursor, nil);
	  bigval = val;
	  break;
	}

      case _GSC_I32:	/* Encoded as 32-bit	*/
	{
	  gsu32	val;

	  (*_dDesImp)(_src, dDesSel, &val, @encode(gsu32), &_cursor, nil);
	  bigval = val;
	  break;
	}

      case _GSC_I64:	/* Encoded as 64-bit	*/
	{
	  gsu64	val;

	  (*_dDesImp)(_src, dDesSel, &val, @encode(gsu64), &_cursor, nil);
#if	GS_HAVE_I64
	  bigval = val;
#else
	  val = GSSwapBigI64ToHost(val);
#endif
	  break;
	}

      default:		/* A 128-bit value	*/
	{
	  gsu128	val;

	  (*_dDesImp)(_src, dDesSel, &val, @encode(gsu128), &_cursor, nil);
#if	GS_HAVE_I128
	  bigval = val;
#else
	  val = GSSwapBigI128ToHost(val);
#if	GS_HAVE_I64
	  bigval = *(gsu64*)&val;
#else
	  bigval = *(gsu32*)&val;
#endif
#endif
	  break;
	}
    }

/*
 *	Now we copy from the 'bigval' to the destination location.
 */
  switch (info & _GSC_MASK)
    {
      case _GSC_SHT:
	*(short*)address = (short)bigval;
	return;
      case _GSC_USHT:
	*(unsigned short*)address = (unsigned short)bigval;
	return;
      case _GSC_INT:
	*(int*)address = (int)bigval;
	return;
      case _GSC_UINT:
	*(unsigned int*)address = (unsigned int)bigval;
	return;
      case _GSC_LNG:
	*(long*)address = (long)bigval;
	return;
      case _GSC_ULNG:
	*(unsigned long*)address = (unsigned long)bigval;
	return;
#ifdef	_C_LNG_LNG
      case _GSC_LNG_LNG:
	*(long long*)address = (long long)bigval;
	return;
      case _GSC_ULNG_LNG:
	*(unsigned long long*)address = (unsigned long long)bigval;
	return;
#endif
      default:
	[NSException raise: NSInternalInconsistencyException
		    format: @"type/size information error"];
    }
}

- (void) dispatch
{
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
	  (*_eTagImp)(_dst, eTagSel, _GSC_ARY_B);
	  (*_eSerImp)(_dst, eSerSel, &count, @encode(unsigned), nil);
	}
      for (i = 0; i < count; i++)
	{
	  (*_eValImp)(self, eValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else if (_initialPass == NO)
    {
      (*_eTagImp)(_dst, eTagSel, _GSC_ARY_B);
      (*_eSerImp)(_dst, eSerSel, &count, @encode(unsigned), nil);

      (*_eTagImp)(_dst, eTagSel, info);
      for (i = 0; i < count; i++)
	{
	  (*_eSerImp)(_dst, eSerSel, (char*)buf + offset, type, nil);
	  offset += size;
	}
    }
}

- (void) encodeBycopyObject: (id)anObj
{
  BOOL        oldBycopy = _is_by_copy;
  BOOL        oldByref = _is_by_ref;

  _is_by_copy = YES;
  _is_by_ref = NO;
  (*_eObjImp)(self, eObjSel, anObj);
  _is_by_copy = oldBycopy;
  _is_by_ref = oldByref;
}

- (void) encodeByrefObject: (id)anObj
{
  BOOL        oldBycopy = _is_by_copy;
  BOOL        oldByref = _is_by_ref;

  _is_by_copy = NO;
  _is_by_ref = YES;
  (*_eObjImp)(self, eObjSel, anObj);
  _is_by_copy = oldBycopy;
  _is_by_ref = oldByref;
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

/*
 * When asked to encode a data object, we add the object to the components
 * array, and simply record the array index, so the corresponding decode
 * method can tell which component to use.
 */
- (void) encodeDataObject: (NSData*)anObject
{
  int	pos;

  if (anObject == nil)
    {
      pos = -1;
    }
  else if ([anObject length] == 0)
    {
      pos = -2;
    }
  else
    {
      pos = (int)[_comp count];
      [_comp addObject: anObject];
    }
  [self encodeValueOfObjCType: @encode(int) at: &pos];
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
	  (*_eTagImp)(_dst, eTagSel, _GSC_ID | _GSC_XREF, _GSC_X_0);
	}
    }
  else if (fastIsInstance(anObject) == NO)
    {
      /*
       *	If the object we have been given is actually a class,
       *	we encode it as a class instead.
       */
      (*_eValImp)(self, eValSel, @encode(Class), &anObject);
    }
  else
    {
      GSIMapNode	node;

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

	  obj = [anObject replacementObjectForPortCoder: self];
	  cls = [anObject classForPortCoder];

	  (*_xRefImp)(_dst, xRefSel, _GSC_ID, node->value.uint);
	  (*_eValImp)(self, eValSel, @encode(Class), &cls);
	  [obj encodeWithCoder: self];
	}
      else if (!_initialPass)
	{
	  (*_xRefImp)(_dst, xRefSel, _GSC_ID | _GSC_XREF, node->value.uint);
	}
    }
}

/*
 * When asked to encode a port object, we add the object to the components
 * array, and simply record the array index, so the corresponding decode
 * method can tell which component to use.
 */
- (void) encodePortObject: (NSPort*)anObject
{
  unsigned	pos = [_comp count];

  [_comp addObject: anObject];
  [self encodeValueOfObjCType: @encode(unsigned) at: &pos];
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
  [self _serializeHeaderAt: _cursor
		   version: [self systemVersion]
		   classes: _clsMap->nodeCount
		   objects: _uIdMap->nodeCount
		  pointers: _ptrMap->nodeCount];

  _encodingRoot = NO;
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

	  [self encodeArrayOfObjCType: type count: count at: buf];
	}
	return;

      case _C_STRUCT_B:
	{
	  int	offset = 0;

	  if (_initialPass == NO)
	    {
	      (*_eTagImp)(_dst, eTagSel, _GSC_STRUCT_B);
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
		(*_eTagImp)(_dst, eTagSel, _GSC_PTR | _GSC_XREF | _GSC_X_0);
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
	    (*_eTagImp)(_dst, eTagSel, _GSC_CLASS | _GSC_XREF | _GSC_X_0);
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
		int		tmp = fastClassVersion(c);
		unsigned	version = tmp;
		Class		s = fastSuper(c);

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
		(*_eSerImp)(_dst, eSerSel, &c, @encode(Class), nil);
		(*_eSerImp)(_dst, eSerSel, &version, @encode(unsigned), nil);
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
	    (*_eTagImp)(_dst, eTagSel, _GSC_NONE);
	  }
	return;

      case _C_SEL:
	if (*(SEL*)buf == 0)
	  {
	    /*
	     *	Special case - a nul pointer gets an xref of zero
	     */
	    (*_eTagImp)(_dst, eTagSel, _GSC_SEL | _GSC_XREF | _GSC_X_0);
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
		(*_eSerImp)(_dst, eSerSel, buf, @encode(SEL), nil);
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
	    (*_eTagImp)(_dst, eTagSel, _GSC_CHARPTR | _GSC_XREF | _GSC_X_0);
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
		(*_eSerImp)(_dst, eSerSel, buf, type, nil);
	      }
	    else
	      {
		(*_xRefImp)(_dst, xRefSel, _GSC_CHARPTR|_GSC_XREF,
		  node->value.uint);
	      }
	  }
	return;

      case _C_CHR:
	(*_eTagImp)(_dst, eTagSel, _GSC_CHR);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(char), nil);
	return;

      case _C_UCHR:
	(*_eTagImp)(_dst, eTagSel, _GSC_UCHR);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(unsigned char), nil);
	return;

      case _C_SHT:
	(*_eTagImp)(_dst, eTagSel, _GSC_SHT | _GSC_S_SHT);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(short), nil);
	return;

      case _C_USHT:
	(*_eTagImp)(_dst, eTagSel, _GSC_USHT | _GSC_S_SHT);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(unsigned short), nil);
	return;

      case _C_INT:
	(*_eTagImp)(_dst, eTagSel, _GSC_INT | _GSC_S_INT);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(int), nil);
	return;

      case _C_UINT:
	(*_eTagImp)(_dst, eTagSel, _GSC_UINT | _GSC_S_INT);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(unsigned int), nil);
	return;

      case _C_LNG:
	(*_eTagImp)(_dst, eTagSel, _GSC_LNG | _GSC_S_LNG);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(long), nil);
	return;

      case _C_ULNG:
	(*_eTagImp)(_dst, eTagSel, _GSC_ULNG | _GSC_S_LNG);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(unsigned long), nil);
	return;

      case _C_LNG_LNG:
	(*_eTagImp)(_dst, eTagSel, _GSC_LNG_LNG | _GSC_S_LNG_LNG);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(long long), nil);
	return;

      case _C_ULNG_LNG:
	(*_eTagImp)(_dst, eTagSel, _GSC_ULNG_LNG | _GSC_S_LNG_LNG);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(unsigned long long), nil);
	return;

      case _C_FLT:
	(*_eTagImp)(_dst, eTagSel, _GSC_FLT);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(float), nil);
	return;

      case _C_DBL:
	(*_eTagImp)(_dst, eTagSel, _GSC_DBL);
	(*_eSerImp)(_dst, eSerSel, (void*)buf, @encode(double), nil);
	return;

      case _C_VOID:
	[NSException raise: NSInvalidArgumentException
		    format: @"can't encode void item"];

      default:
	[NSException raise: NSInvalidArgumentException
		    format: @"item with unknown type - %s", type];
    }
}

- (id) initWithReceivePort: (NSPort*)recv
                  sendPort: (NSPort*)send
                components: (NSArray*)comp
{
  self = [super init];
  if (self != nil)
    {
      _version = [super systemVersion];
      _zone = NSDefaultMallocZone();
      _conn = RETAIN([NSConnection connectionWithReceivePort: recv
						    sendPort: send]);

      if (comp == nil)
	{
	  _comp = [NSMutableArray new];
	  self = [self _setupForEncoding];
	}
	else
	{
	  _comp = [comp mutableCopy];
	  self = [self _setupForDecoding];
	}
    }
  return self;
}

- (BOOL) isBycopy
{
  return _is_by_copy;
}

- (BOOL) isByref
{
  return _is_by_ref;
}

- (NSZone*) objectZone
{
  return _zone;
}

- (void) setObjectZone: (NSZone*)aZone
{
  _zone = aZone;
}

- (unsigned) systemVersion
{
  return _version;
}

- (unsigned) versionForClassName: (NSString*)className
{
  GSClassInfo	*info;
  unsigned	version = NSNotFound;

  info = [_cInfo objectForKey: className];
  if (info != nil)
    {
      version = info->version;
    }
  return version;
}

@end



@implementation	GSPortCoder (Private)

- (NSMutableArray*) _components
{
  return _comp;
}

- (void) _deserializeHeaderAt: (unsigned*)pos
		      version: (unsigned*)v
		      classes: (unsigned*)c
		      objects: (unsigned*)o
		     pointers: (unsigned*)p
{
  unsigned	plen = strlen(PREFIX);
  unsigned	size = plen+36;
  char		header[size+1];

  [_src getBytes: header range: NSMakeRange(*pos, size)];
  *pos += size;
  header[size] = '\0';
  if (strncmp(header, PREFIX, plen) != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Archive has wrong prefix"];
    }
  if (sscanf(&header[plen], "%x:%x:%x:%x:", v, c, o, p) != 4)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Archive has wrong prefix"];
    }
}

- (void) _serializeHeaderAt: (unsigned)locationInData
		    version: (unsigned)v
		    classes: (unsigned)cc
		    objects: (unsigned)oc
		   pointers: (unsigned)pc
{
  unsigned	headerLength = strlen(PREFIX)+36;
  char		header[headerLength+1];
  unsigned	dataLength = [_dst length];

  sprintf(header, "%s%08x:%08x:%08x:%08x:", PREFIX, v, cc, oc, pc);

  if (locationInData + headerLength <= dataLength)
    {
      [_dst replaceBytesInRange: NSMakeRange(locationInData, headerLength)
		      withBytes: header];
    }
  else if (locationInData == dataLength)
    {
      [_dst appendBytes: header length: headerLength];
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"serializeHeader:at: bad location"];
    }
}

- (id) _setupForDecoding
{
  NS_DURING
    {
      unsigned	sizeC;
      unsigned	sizeO;
      unsigned	sizeP;

      _dValImp = [self methodForSelector: dValSel];
      _src = [_comp objectAtIndex: 0];
      _dDesImp = [_src methodForSelector: dDesSel];
      _dTagImp = (void (*)(id, SEL, unsigned char*, unsigned*, unsigned*))
	[_src methodForSelector: dTagSel];

      /*
       *	_cInfo is a dictionary of objects for keeping track of the
       *	version numbers that the classes were encoded with.
       */
      _cInfo
	= [[NSMutableDictionary allocWithZone: _zone] initWithCapacity: 200];

      /*
       *	Read header including version and crossref table sizes.
       */
      _cursor = [[_conn sendPort] reservedSpaceLength];
      [self _deserializeHeaderAt: &_cursor
			 version: &_version
			 classes: &sizeC
			 objects: &sizeO
			pointers: &sizeP];

      /*
       *	Allocate and initialise arrays to build crossref maps in.
       */
      _clsAry = NSZoneMalloc(_zone, sizeof(GSIArray_t)*3);
      GSIArrayInitWithZoneAndCapacity(_clsAry, _zone, sizeC);
      GSIArrayAddItem(_clsAry, (GSIArrayItem)0);

      _objAry = &_clsAry[1];
      GSIArrayInitWithZoneAndCapacity(_objAry, _zone, sizeO);
      GSIArrayAddItem(_objAry, (GSIArrayItem)0);

      _ptrAry = &_clsAry[2];
      GSIArrayInitWithZoneAndCapacity(_ptrAry, _zone, sizeP);
      GSIArrayAddItem(_ptrAry, (GSIArrayItem)0);
    }
  NS_HANDLER
    {
      NSLog(@"Exception setting up port coder for decoding - %@",
	localException);
      DESTROY(self);
    }
  NS_ENDHANDLER
  return self;
}

- (id) _setupForEncoding
{
  NS_DURING
    {
      /*
       * Set up mutable data object to encode into - reserve space at the
       * start for use by the port when the encoded data is sent.
       * Make the data item the first component of the array.
       */
      _cursor = [[_conn sendPort] reservedSpaceLength];
      _dst = [_fastCls._NSMutableDataMalloc allocWithZone: fastZone(self)];
      _dst = [_dst initWithLength: _cursor];
      [_comp addObject: _dst];
      RELEASE(_dst);

      /*
       * Cache method implementations for writing into data object etc
       */
      _eSerImp = [_dst methodForSelector: eSerSel];
      _eTagImp = [_dst methodForSelector: eTagSel];
      _xRefImp = [_dst methodForSelector: xRefSel];
      _eObjImp = [self methodForSelector: eObjSel];
      _eValImp = [self methodForSelector: eValSel];

      _encodingRoot = NO;
      _initialPass = NO;
      _xRefC = 0;
      _xRefO = 0;
      _xRefP = 0;

      /*
       *	Set up map tables.
       */
      _clsMap = (GSIMapTable)NSZoneMalloc(_zone, sizeof(GSIMapTable_t)*4);
      _cIdMap = &_clsMap[1];
      _uIdMap = &_clsMap[2];
      _ptrMap = &_clsMap[3];
      GSIMapInitWithZoneAndCapacity(_clsMap, _zone, 100);
      GSIMapInitWithZoneAndCapacity(_cIdMap, _zone, 10);
      GSIMapInitWithZoneAndCapacity(_uIdMap, _zone, 200);
      GSIMapInitWithZoneAndCapacity(_ptrMap, _zone, 100);

      /*
       *	Write dummy header
       */
      [self _serializeHeaderAt: _cursor
		       version: 0
		       classes: 0
		       objects: 0
		      pointers: 0];
    }
  NS_HANDLER
    {
      NSLog(@"Exception setting up port coder for encoding - %@",
	localException);
      DESTROY(self);
    }
  NS_ENDHANDLER
  return self;
}

@end

