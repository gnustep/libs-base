/* Implementation of NSUnarchiver for GNUstep
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <string.h>
#include <objc/objc-api.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSByteOrder.h>

/*
 *	Setup for inline operation of arrays.
 */
#define	GSI_ARRAY_RETAIN(X)	
#define	GSI_ARRAY_RELEASE(X)	
#define	GSI_ARRAY_TYPES	GSUNION_OBJ|GSUNION_SEL|GSUNION_STR

#include <base/GSIArray.h>

#define	_IN_NSUNARCHIVER_M
#include <Foundation/NSArchiver.h>
#undef	_IN_NSUNARCHIVER_M

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

#include <base/fast.x>

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

#define	PREFIX		"GNUstep archive"

static SEL desSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);
static SEL tagSel = @selector(deserializeTypeTag:andCrossRef:atCursor:);
static SEL dValSel = @selector(decodeValueOfObjCType:at:);

@interface	NSUnarchiverClassInfo : NSObject
{
@public
  NSString	*original;
  NSString	*name;
  Class		class;
}
+ (id) newWithName: (NSString*)n;
- (void) mapToClass: (Class)c withName: (NSString*)name;
@end

@implementation	NSUnarchiverClassInfo
+ (id) newWithName: (NSString*)n
{
  NSUnarchiverClassInfo	*info;

  info = (NSUnarchiverClassInfo*)NSAllocateObject(self,0,NSDefaultMallocZone());
  if (info)
    {
      info->original = [n copyWithZone: NSDefaultMallocZone()];
    }
  return info;
}
- (void) dealloc
{
  RELEASE(original);
  if (name)
    {
      RELEASE(name);
    }
  NSDeallocateObject(self);
}
- (void) mapToClass: (Class)c withName: (NSString*)n
{
  ASSIGN(name, n);
  class = c;
}
@end

/*
 *	Dictionary used by NSUnarchiver class to keep track of
 *	NSUnarchiverClassInfo objects used to map classes by name when
 *	unarchiving.
 */
static NSMutableDictionary	*clsDict;	/* Class information	*/

@interface	NSUnarchiverObjectInfo : NSUnarchiverClassInfo
{
@public
  unsigned	version;
  NSUnarchiverClassInfo	*overrides;
}
@end

inline Class
mapClassObject(NSUnarchiverObjectInfo *info)
{
  if (info->overrides == nil)
    {
      info->overrides = [clsDict objectForKey: info->original];
    }
  if (info->overrides)
    {
      return info->overrides->class;
    }
  else
    {
      return info->class;
    }
}

inline NSString*
mapClassName(NSUnarchiverObjectInfo *info)
{
  if (info->overrides == nil)
    {
      info->overrides = [clsDict objectForKey: info->original];
    }
  if (info->overrides)
    {
      return info->overrides->name;
    }
  else
   {
      return info->name;
   }
}

@implementation	NSUnarchiverObjectInfo
@end


@implementation NSUnarchiver

+ (void) initialize
{
  if ([self class] == [NSUnarchiver class])
    {
      clsDict = [[NSMutableDictionary alloc] initWithCapacity: 200];
    }
}

+ (id) unarchiveObjectWithData: (NSData*)anObject
{
  NSUnarchiver	*unarchiver;
  id		obj;

  unarchiver = [[self alloc] initForReadingWithData: anObject];
  NS_DURING
    {
      obj = [unarchiver decodeObject];
    }
  NS_HANDLER
    {
      RELEASE(unarchiver);
      [localException raise];
    }
  NS_ENDHANDLER
  RELEASE(unarchiver);

  return obj;
}

+ (id) unarchiveObjectWithFile: (NSString*)path
{
  NSData	*d = [_fastCls._NSDataMalloc dataWithContentsOfFile: path];

  if (d != nil)
    {
      return [self unarchiveObjectWithData: d];
    }
  return nil;
}

- (void) dealloc
{
  RELEASE(data);
  RELEASE(objDict);
  if (clsMap)
    {
      NSZone	*z = clsMap->zone;

      GSIArrayClear(clsMap);
      GSIArrayClear(objMap);
      GSIArrayClear(ptrMap);
      NSZoneFree(z, (void*)clsMap);
    }
  [super dealloc];
}

- (id) initForReadingWithData: (NSData*)anObject
{
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil data passed to initForReadingWithData:"];
    }

  self = [super init];
  if (self)
    {
      dValImp = [self methodForSelector: dValSel];
      zone = [self zone];
      /*
       *	If we are not deserializing directly from the data object
       *	then we cache our own deserialisation methods.
       */
      if ([self directDataAccess] == NO)
	{
	  src = self;		/* Default object to handle serialisation */
	  desImp = [src methodForSelector: desSel];
	  tagImp = (void (*)(id, SEL, unsigned char*, unsigned*, unsigned*))
	      [src methodForSelector: tagSel];
	}
      /*
       *	objDict is a dictionary of objects for mapping classes of
       *	one name to be those of another name!  It also handles
       *	keeping track of the version numbers that the classes were
       *	encoded with.
       */
      objDict = [[NSMutableDictionary allocWithZone: zone]
			initWithCapacity: 200];

      NS_DURING
	{
	  [self resetUnarchiverWithData: anObject atIndex: 0];
	}
      NS_HANDLER
	{
	  RELEASE(self);
	  [localException raise];
	}
      NS_ENDHANDLER
    }
  return self;
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

  (*tagImp)(src, tagSel, &info, 0, &cursor);
  (*desImp)(src, desSel, &count, @encode(unsigned), &cursor, nil);
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
	  (*dValImp)(self, dValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else
    {
      unsigned char	ainfo;

      (*tagImp)(src, tagSel, &ainfo, 0, &cursor);
      if (info != (ainfo & _GSC_MASK))
        {
          [NSException raise: NSInternalInconsistencyException
                      format: @"expected %s and got %s",
                        typeToName2(info), typeToName2(ainfo)];
        }

      for (i = 0; i < count; i++)
	{
	  (*desImp)(src, desSel, (char*)buf + offset, type, &cursor, nil);
	  offset += size;
	}
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

  (*tagImp)(src, tagSel, &info, &xref, &cursor);

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
		  if (xref >= GSIArrayCount(objMap))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"object crossref missing - %d",
					xref];
		    }
		  obj = GSIArrayItemAtIndex(objMap, xref).obj;
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

		  if (xref != GSIArrayCount(objMap))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"extra object crossref - %d",
					xref];
		    }
		  (*dValImp)(self, dValSel, @encode(Class), &c);

		  obj = [c allocWithZone: zone];
		  GSIArrayAddItem(objMap, (GSIArrayItem)obj);

		  rep = [obj initWithCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      GSIArraySetItemAtIndex(objMap, (GSIArrayItem)obj, xref);
		    }

		  rep = [obj awakeAfterUsingCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      GSIArraySetItemAtIndex(objMap, (GSIArrayItem)obj, xref);
		    }
		}
	    }
	  *(id*)address = obj;
	  return;
	}

      case _GSC_CLASS:
	{
	  Class		c;
	  NSUnarchiverObjectInfo	*classInfo;
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
	      if (xref >= GSIArrayCount(clsMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"class crossref missing - %d", xref];
		}
	      classInfo = (NSUnarchiverObjectInfo*)GSIArrayItemAtIndex(clsMap, xref).obj;
	      *(Class*)address = mapClassObject(classInfo);
	      return;
	    }
	  while ((info & _GSC_MASK) == _GSC_CLASS)
	    {
	      unsigned	cver;
	      NSString	*className;

	      if (xref != GSIArrayCount(clsMap))
		{
		  [NSException raise: NSInternalInconsistencyException
				format: @"extra class crossref - %d", xref];
		}
	      (*desImp)(src, desSel, &c, @encode(Class), &cursor, nil);
	      (*desImp)(src, desSel, &cver, @encode(unsigned), &cursor, nil);
	      if (c == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"decoded nil class"];
		}
	      className = NSStringFromClass(c);
	      classInfo = [objDict objectForKey: className];
	      if (classInfo == nil)
		{
		  classInfo = [NSUnarchiverObjectInfo newWithName: className];
		  [classInfo mapToClass: c withName: className];
		  [objDict setObject: classInfo forKey: className];
		  RELEASE(classInfo);
		}
	      classInfo->version = cver;
	      GSIArrayAddItem(clsMap, (GSIArrayItem)classInfo);
	      *(Class*)address = mapClassObject(classInfo);
	      /*
	       *	Point the address to a dummy location and read the
	       *	next tag - if it is another class, loop to get it.
	       */
	      address = &dummy;
	      (*tagImp)(src, tagSel, &info, &xref, &cursor);
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
	      if (xref >= GSIArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"sel crossref missing - %d", xref];
		}
	      sel = GSIArrayItemAtIndex(ptrMap, xref).sel;
	    }
	  else
	    {
	      if (xref != GSIArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra sel crossref - %d", xref];
		}
	      (*desImp)(src, desSel, &sel, @encode(SEL), &cursor, nil);
	      GSIArrayAddItem(ptrMap, (GSIArrayItem)sel);
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
	      (*dValImp)(self, dValSel, type, (char*)address + offset);
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
	      if (xref >= GSIArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"ptr crossref missing - %d", xref];
		}
	      *(void**)address = GSIArrayItemAtIndex(ptrMap, xref).ptr;
	    }
	  else
	    {
	      unsigned	size;

	      if (GSIArrayCount(ptrMap) != xref)
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
	      GSIArrayAddItem(ptrMap, (GSIArrayItem)*(void**)address);

	      /*
	       *	Decode value and add memory to map for crossrefs.
	       */
	      (*dValImp)(self, dValSel, type, *(void**)address);
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
	      if (xref >= GSIArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"string crossref missing - %d", xref];
		}
	      *(char**)address = GSIArrayItemAtIndex(ptrMap, xref).str;
	    }
	  else
	    {
	      if (xref != GSIArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra string crossref - %d", xref];
		}
	      (*desImp)(src, desSel, address, @encode(char*), &cursor, nil);
	      GSIArrayAddItem(ptrMap, (GSIArrayItem)*(void**)address);
	    }
	  return;
	}

      case _GSC_CHR:
      case _GSC_UCHR:
	typeCheck(*type, info & _GSC_MASK);
	(*desImp)(src, desSel, address, type, &cursor, nil);
	return;

      case _GSC_SHT:
      case _GSC_USHT:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_SHT)
	  {
	    (*desImp)(src, desSel, address, type, &cursor, nil);
	    return;
	  }
	break;

      case _GSC_INT:
      case _GSC_UINT:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_INT)
	  {
	    (*desImp)(src, desSel, address, type, &cursor, nil);
	    return;
	  }
	break;

      case _GSC_LNG:
      case _GSC_ULNG:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_LNG)
	  {
	    (*desImp)(src, desSel, address, type, &cursor, nil);
	    return;
	  }
	break;

#ifdef	_C_LNG_LNG
      case _GSC_LNG_LNG:
      case _GSC_ULNG_LNG:
	typeCheck(*type, info & _GSC_MASK);
	if ((info & _GSC_SIZE) == _GSC_S_LNG_LNG)
	  {
	    (*desImp)(src, desSel, address, type, &cursor, nil);
	    return;
	  }
	break;

#endif
      case _GSC_FLT:
	typeCheck(*type, _GSC_FLT);
	(*desImp)(src, desSel, address, type, &cursor, nil);
	return;

      case _GSC_DBL:
	typeCheck(*type, _GSC_DBL);
	(*desImp)(src, desSel, address, type, &cursor, nil);
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

	  (*desImp)(src, desSel, &val, @encode(gsu16), &cursor, nil);
	  bigval = val;
	  break;
	}

      case _GSC_I32:	/* Encoded as 32-bit	*/
	{
	  gsu32	val;

	  (*desImp)(src, desSel, &val, @encode(gsu32), &cursor, nil);
	  bigval = val;
	  break;
	}

      case _GSC_I64:	/* Encoded as 64-bit	*/
	{
	  gsu64	val;

	  (*desImp)(src, desSel, &val, @encode(gsu64), &cursor, nil);
#if	GS_HAVE_I64
	  bigval = val;
#else
	  bigval = GSSwapBigI64ToHost(val);
#endif
	  break;
	}

      default:		/* A 128-bit value	*/
	{
	  gsu128	val;

	  (*desImp)(src, desSel, &val, @encode(gsu128), &cursor, nil);
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

- (NSData*) decodeDataObject
{
  unsigned	l;

  (*dValImp)(self, dValSel, @encode(unsigned int), &l);
  if (l)
    {
      unsigned char	c;

      (*dValImp)(self, dValSel, @encode(unsigned char), &c);
      if (c == 0)
	{
	  void		*b;
	  NSData	*d;
	  NSZone	*z;

#if	GS_WITH_GC
	  z = GSAtomicMallocZone();
#else
	  z = zone;
#endif
	  b = NSZoneMalloc(z, l);
	  [self decodeArrayOfObjCType: @encode(unsigned char)
				count: l
				   at: b];
	  d = [[NSData allocWithZone: zone] initWithBytesNoCopy: b
							 length: l
						       fromZone: z];
	  IF_NO_GC(AUTORELEASE(d));
	  return d;
	}
      else
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"Decoding data object with unknown type"];
	}
    }
  return [NSData data];
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

  (*tagImp)(src, tagSel, &info, &xref, &cursor);
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
      if (xref >= GSIArrayCount(objMap))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"object crossref missing - %d",
			    xref];
	}
      obj = GSIArrayItemAtIndex(objMap, xref).obj;
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

      if (xref != GSIArrayCount(objMap))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"extra object crossref - %d",
			    xref];
	}
      (*dValImp)(self, dValSel, @encode(Class), &c);

      obj = [c allocWithZone: zone];
      GSIArrayAddItem(objMap, (GSIArrayItem)obj);

      rep = [obj initWithCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  GSIArraySetItemAtIndex(objMap, (GSIArrayItem)obj, xref);
	}

      rep = [obj awakeAfterUsingCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  GSIArraySetItemAtIndex(objMap, (GSIArrayItem)obj, xref);
	}
      /*
       *	A newly allocated object needs to be autoreleased.
       */
      return AUTORELEASE(obj);
    }
}

- (BOOL) isAtEnd
{
  return (cursor >= [data length]);
}

- (NSZone*) objectZone
{
  return zone;
}

- (void) setObjectZone: (NSZone*)aZone
{
  zone = aZone;
}

- (unsigned) systemVersion
{
  return version;
}

+ (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  NSUnarchiverClassInfo	*info = [clsDict objectForKey: nameInArchive];
  NSString		*alias = info->name;

  if (alias)
    {
      return alias;
    }
  return nameInArchive;
}

+ (void) decodeClassName: (NSString*)nameInArchive
	     asClassName: (NSString*)trueName
{
  Class	c;

  c = objc_get_class([trueName cString]);
  if (c == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"can't find class %@", trueName];
    }
  else
    {
      NSUnarchiverClassInfo	*info = [clsDict objectForKey: nameInArchive];

      if (info == nil)
	{
	  info = [NSUnarchiverClassInfo newWithName: nameInArchive];
	  [clsDict setObject: info forKey: nameInArchive];
	  RELEASE(info);
	}
      [info mapToClass: c withName: trueName];
    }
}

- (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  NSUnarchiverObjectInfo	*info = [objDict objectForKey: nameInArchive];
  NSString			*alias = mapClassName(info);

  if (alias)
    {
      return alias;
    }
  return nameInArchive;
}


- (void) decodeClassName: (NSString*)nameInArchive
	     asClassName: (NSString*)trueName
{
  Class	c;

  c = objc_get_class([trueName cString]);
  if (c == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"can't find class %@", trueName];
    }
  else
    {
      NSUnarchiverObjectInfo	*info = [objDict objectForKey: nameInArchive];

      if (info == nil)
	{
	  info = [NSUnarchiverObjectInfo newWithName: nameInArchive];
	  [objDict setObject: info forKey: nameInArchive];
	  RELEASE(info);
	}
      [info mapToClass: c withName: trueName];
    }
}

- (void) replaceObject: (id)anObject withObject: (id)replacement
{
  unsigned i;

  if (replacement == anObject)
    return;
  for (i = GSIArrayCount(objMap) - 1; i > 0; i--)
    {
      if (GSIArrayItemAtIndex(objMap, i).obj == anObject)
	{
	  GSIArraySetItemAtIndex(objMap, (GSIArrayItem)replacement, i);
	  return;
	}
    }
  [NSException raise: NSInvalidArgumentException
	      format: @"object to be replaced does not exist"];
}

- (unsigned) versionForClassName: (NSString*)className
{
  NSUnarchiverObjectInfo	*info;

  info = [objDict objectForKey: className];
  return info->version;
}

@end




@implementation	NSUnarchiver (GNUstep)

/* Re-using the unarchiver */

- (unsigned) cursor
{
  return cursor;
}

- (void) resetUnarchiverWithData: (NSData*)anObject
			 atIndex: (unsigned)pos
{
  unsigned	sizeC;
  unsigned	sizeO;
  unsigned	sizeP;

  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil passed to resetUnarchiverWithData:atIndex:"];
    }
  if (data != anObject)
    {
      Class	c;

      TEST_RELEASE(data);
      data = RETAIN(anObject);
      c = fastClass(data);
      if (src != self)
	{
	  src = data;
	  if (c != dataClass)
	    {
	      /*
	       *	Cache methods for deserialising from the data object.
	       */
	      desImp = [src methodForSelector: desSel];
	      tagImp = (void (*)(id, SEL, unsigned char*, unsigned*, unsigned*))
		  [src methodForSelector: tagSel];
	    }
	}
      dataClass = c;
    }

  /*
   *	Read header including version and crossref table sizes.
   */
  cursor = pos;
  [self deserializeHeaderAt: &cursor
		    version: &version
		    classes: &sizeC
		    objects: &sizeO
		   pointers: &sizeP];

  if (clsMap == 0)
    {
      /*
       *	Allocate and initialise arrays to build crossref maps in.
       */
      clsMap = NSZoneMalloc(zone, sizeof(GSIArray_t)*3);
      GSIArrayInitWithZoneAndCapacity(clsMap, zone, sizeC);
      GSIArrayAddItem(clsMap, (GSIArrayItem)0);

      objMap = &clsMap[1];
      GSIArrayInitWithZoneAndCapacity(objMap, zone, sizeO);
      GSIArrayAddItem(objMap, (GSIArrayItem)0);

      ptrMap = &clsMap[2];
      GSIArrayInitWithZoneAndCapacity(ptrMap, zone, sizeP);
      GSIArrayAddItem(ptrMap, (GSIArrayItem)0);
    }
  else
    {
      clsMap->count = 1;
      objMap->count = 1;
      ptrMap->count = 1;
    }

  [objDict removeAllObjects];
}

- (void) deserializeHeaderAt: (unsigned*)pos
		     version: (unsigned*)v
		     classes: (unsigned*)c
		     objects: (unsigned*)o
		    pointers: (unsigned*)p
{
  unsigned	plen = strlen(PREFIX);
  unsigned	size = plen+36;
  char		header[size+1];

  [data getBytes: header range: NSMakeRange(*pos, size)];
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

- (BOOL) directDataAccess
{
  return YES;
}

@end

