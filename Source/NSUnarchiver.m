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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <config.h>
#include <objc/objc-api.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>

/*
 *	Setup for inline operation of arrays.
 */
#define	FAST_ARRAY_RETAIN(X)	X
#define	FAST_ARRAY_RELEASE(X)	

#include "FastArray.x"

#define	_IN_NSUNARCHIVER_M
#include <Foundation/NSArchiver.h>
#undef	_IN_NSUNARCHIVER_M

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

#include <gnustep/base/fast.x>

typedef	unsigned char uchar;

static const char*
typeToName(char type)
{
  switch (type & _C_MASK)
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
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:	return "long long";
      case _C_ULNG_LNG:	return "unsigned long long";
#endif
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

static inline void
typeCheck(char t1, char t2)
{
  if (t1 != t2)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected %s and got %s",
		    typeToName(t1), typeToName(t2)];
    }
}

#define	PREFIX		"GNUstep archive"

static SEL desSel = @selector(deserializeDataAt:ofObjCType:atCursor:context:);
static SEL tagSel = @selector(deserializeTypeTagAtCursor:);
static SEL xRefSel = @selector(deserializeCrossRefAtCursor:);
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
  [original release];
  if (name)
    {
      [name release];
    }
  NSDeallocateObject(self);
}
- (void) mapToClass: (Class)c withName: (NSString*)n
{
  if (n != name)
    {
      [n retain];
      [name release];
      name = n;
    }
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
      [unarchiver release];
      [localException raise];
    }
  NS_ENDHANDLER
  [unarchiver release];

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
  [data release];
  [objDict release];
  if (clsMap)
    {
      NSZone	*z = clsMap->zone;

      FastArrayClear(clsMap);
      FastArrayClear(objMap);
      FastArrayClear(ptrMap);
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
	  tagImp = (unsigned char (*)(id, SEL, unsigned*))
	      [src methodForSelector: tagSel];
	  xRefImp = (unsigned (*)(id, SEL, unsigned*))
	      [src methodForSelector: xRefSel];
	}
      /*
       *	objDict is a dictionary of objects for mapping classes of
       *	one name to be those of another name!  It also handles
       *	keeping track of the version numbers that the classes were
       *	encoded with.
       */
      objDict = [[NSMutableDictionary allocWithZone: zone]
			initWithCapacity: 200];

      [self resetUnarchiverWithData: anObject atIndex: 0];
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
  uchar		info;
  unsigned	count;

  info = (*tagImp)(src, tagSel, &cursor);
  (*desImp)(src, desSel, &count, @encode(unsigned), &cursor, nil);
  if (info != _C_ARY_B)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected array and got %s", typeToName(info)];
    }
  if (count != expected)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected array count %u and got %u",
			expected, count];
    }

  switch (*type)
    {
      case _C_ID:	info = _C_NONE; break;
      case _C_CHR:	info = _C_CHR; break;
      case _C_UCHR:	info = _C_UCHR; break;
      case _C_SHT:	info = _C_SHT; break;
      case _C_USHT:	info = _C_USHT; break;
      case _C_INT:	info = _C_INT; break;
      case _C_UINT:	info = _C_UINT; break;
      case _C_LNG:	info = _C_LNG; break;
      case _C_ULNG:	info = _C_ULNG; break;
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:	info = _C_LNG_LNG; break;
      case _C_ULNG_LNG:	info = _C_ULNG_LNG; break;
#endif
      case _C_FLT:	info = _C_FLT; break;
      case _C_DBL:	info = _C_DBL; break;
      default:		info = _C_NONE; break;
    }

  if (info == _C_NONE)
    {
      for (i = 0; i < count; i++)
	{
	  (*dValImp)(self, dValSel, type, (char*)buf + offset);
	  offset += size;
	}
    }
  else
    {
      uchar	ainfo;

      ainfo = (*tagImp)(src, tagSel, &cursor);
      if (info != ainfo)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"expected %s and got %s",
			typeToName(info), typeToName(ainfo)];
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
  uchar info = (*tagImp)(src, tagSel, &cursor);

  switch (info & _C_MASK)
    {
      case _C_ID:
	{
	  unsigned	xref;
	  id		obj;

	  typeCheck(*type, _C_ID);
	  xref = (*xRefImp)(src, xRefSel, &cursor);
	  /*
	   *	Special case - a zero crossref value is a nil pointer.
	   */
	  if (xref == 0)
	    {
	      obj = nil;
	    }
	  else
	    {
	      if (info & _C_XREF)
		{
		  if (xref >= FastArrayCount(objMap))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"object crossref missing - %d",
					xref];
		    }
		  obj = FastArrayItemAtIndex(objMap, xref).o;
		  /*
		   *	If it's a cross-reference, we need to retain it in
		   *	order to give the appearance that it's actually a
		   *	new object.
		   */
		  [obj retain];
		}
	      else
		{
		  Class	c;
		  id	rep;

		  if (xref != FastArrayCount(objMap))
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"extra object crossref - %d",
					xref];
		    }
		  (*dValImp)(self, dValSel, @encode(Class), &c);

		  obj = [c allocWithZone: zone];
		  FastArrayAddItem(objMap, (FastArrayItem)obj);

		  rep = [obj initWithCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      FastArraySetItemAtIndex(objMap, (FastArrayItem)obj, xref);
		    }

		  rep = [obj awakeAfterUsingCoder: self];
		  if (rep != obj)
		    {
		      obj = rep;
		      FastArraySetItemAtIndex(objMap, (FastArrayItem)obj, xref);
		    }
		}
	    }
	  *(id*)address = obj;
	  return;
	}
      case _C_CLASS:
	{
	  unsigned	xref;
	  Class		c;
	  NSUnarchiverObjectInfo	*classInfo;
	  Class		dummy;

	  typeCheck(*type, _C_CLASS);
	  xref = (*xRefImp)(src, xRefSel, &cursor);
	  if (xref == 0)
	    {
	      /*
	       *	Special case - an xref of zero is a nul pointer.
	       */
	      *(SEL*)address = 0;
	      return;
	    }
	  if (info & _C_XREF)
	    {
	      if (xref >= FastArrayCount(clsMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"class crossref missing - %d", xref];
		}
	      classInfo = (NSUnarchiverObjectInfo*)FastArrayItemAtIndex(clsMap, xref).o;
	      *(Class*)address = mapClassObject(classInfo);
	      return;
	    }
	  while (info == _C_CLASS)
	    {
	      unsigned	cver;
	      NSString	*className;

	      if (xref != FastArrayCount(clsMap))
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
		  [classInfo release];
		}
	      classInfo->version = cver;
	      FastArrayAddItem(clsMap, (FastArrayItem)classInfo);
	      *(Class*)address = mapClassObject(classInfo);
	      /*
	       *	Point the address to a dummy location and read the
	       *	next tag - if it is another class, loop to get it.
	       */
	      address = &dummy;
	      info = (*tagImp)(src, tagSel, &cursor);
	      if (info == _C_CLASS)
		{
		  xref = (*xRefImp)(src, xRefSel, &cursor);
		}
	    }
	  if (info != _C_NONE)
	    {
	      [NSException raise: NSInternalInconsistencyException
			  format: @"class list improperly terminated"];
	    }
	  return;
	}
      case _C_SEL:
	{
	  unsigned	xref;
	  SEL		sel;

	  typeCheck(*type, _C_SEL);
	  xref = (*xRefImp)(src, xRefSel, &cursor);
	  if (xref == 0)
	    {
	      /*
	       *	Special case - an xref of zero is a nul pointer.
	       */
	      *(SEL*)address = 0;
	      return;
	    }
	  if (info & _C_XREF)
	    {
	      if (xref >= FastArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"sel crossref missing - %d", xref];
		}
	      sel = FastArrayItemAtIndex(ptrMap, xref).C;
	    }
	  else
	    {
	      if (xref != FastArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra sel crossref - %d", xref];
		}
	      (*desImp)(src, desSel, &sel, @encode(SEL), &cursor, nil);
	      FastArrayAddItem(ptrMap, (FastArrayItem)sel);
	    }
	  *(SEL*)address = sel;
	  return;
	}
      case _C_ARY_B:
	{
	  int	count;

	  typeCheck(*type, _C_ARY_B);
	  count = atoi(++type);
	  while (isdigit(*type))
	    {
	      type++;
	    }
	  [self decodeArrayOfObjCType: type count: count at: address];
	  return;
	}
      case _C_STRUCT_B:
	{
	  int offset = 0;

	  typeCheck(*type, _C_STRUCT_B);
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
      case _C_PTR:
	{
	  unsigned	xref;

	  typeCheck(*type, _C_PTR);
	  xref = (*xRefImp)(src, xRefSel, &cursor);
	  if (xref == 0)
	    {
	      /*
	       *	Special case - an xref of zero is a nul pointer.
	       */
	      *(void**)address = 0;
	      return;
	    }
	  if (info & _C_XREF)
	    {
	      if (xref >= FastArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"ptr crossref missing - %d", xref];
		}
	      *(void**)address = FastArrayItemAtIndex(ptrMap, xref).p;
	    }
	  else
	    {
	      unsigned	size;
	      NSData	*dat;

	      if (FastArrayCount(ptrMap) != xref)
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
	      FastArrayAddItem(ptrMap, (FastArrayItem)*(void**)address);

	      /*
	       *	Decode value and add memory to map for crossrefs.
	       */
	      (*dValImp)(self, dValSel, type, *(void**)address);
	    }
	  return;
	}
      case _C_CHARPTR:
	{
	  unsigned	xref;
	  char		*str;

	  typeCheck(*type, _C_CHARPTR);
	  xref = (*xRefImp)(src, xRefSel, &cursor);
	  if (xref == 0)
	    {
	      /*
	       *	Special case - an xref of zero is a nul pointer.
	       */
	      *(char**)address = 0;
	      return;
	    }
	  if (info & _C_XREF)
	    {
	      if (xref >= FastArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"string crossref missing - %d", xref];
		}
	      *(char**)address = FastArrayItemAtIndex(ptrMap, xref).s;
	    }
	  else
	    {
	      int	length;

	      if (xref != FastArrayCount(ptrMap))
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"extra string crossref - %d", xref];
		}
	      (*desImp)(src, desSel, address, @encode(char*), &cursor, nil);
	      FastArrayAddItem(ptrMap, (FastArrayItem)*(void**)address);
	    }
	  return;
	}
      case _C_CHR:
	typeCheck(*type, _C_CHR);
	(*desImp)(src, desSel, address, type, &cursor, nil);
	break;
      case _C_UCHR:
	  typeCheck(*type, _C_UCHR);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_SHT:
	  typeCheck(*type, _C_SHT);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_USHT:
	  typeCheck(*type, _C_USHT);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_INT:
	  typeCheck(*type, _C_INT);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_UINT:
	  typeCheck(*type, _C_UINT);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_LNG:
	  typeCheck(*type, _C_LNG);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_ULNG:
	  typeCheck(*type, _C_ULNG);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
#ifdef	_C_LNG_LNG
      case _C_LNG_LNG:
	  typeCheck(*type, _C_LNG_LNG);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_ULNG_LNG:
	  typeCheck(*type, _C_ULNG_LNG);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
#endif
      case _C_FLT:
	  typeCheck(*type, _C_FLT);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      case _C_DBL:
	  typeCheck(*type, _C_DBL);
	  (*desImp)(src, desSel, address, type, &cursor, nil);
	  break;
      default:
	  [NSException raise: NSInternalInconsistencyException
		      format: @"read unknown type info - %d", info];
    }
}

/*
 *	The [-decodeObject] method is implemented purely for performance -
 *	It duplicates the code for handling objects in the
 *	[-decodeValueOfObjCType:at:] method above, but differs in that the
 *	resulting object is autoreleased when it comes from this method.
 */
- (id) decodeObject
{
  uchar		info;
  unsigned	xref;
  id		obj;

  info = (*tagImp)(src, tagSel, &cursor);
  if ((info & _C_MASK) != _C_ID)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"expected object and got %s", typeToName(info)];
    }

  xref = (*xRefImp)(src, xRefSel, &cursor);
  /*
   *	Special case - a zero crossref value is a nil pointer.
   */
  if (xref == 0)
    {
      return nil;
    }

  if (info & _C_XREF)
    {
      if (xref >= FastArrayCount(objMap))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"object crossref missing - %d",
			    xref];
	}
      obj = FastArrayItemAtIndex(objMap, xref).o;
      /*
       *	If it's a cross-reference, we don't need to autorelease it
       *	since we don't own it.
       */
      return obj;
    }
  else
    {
      Class	c;
      id	rep;

      if (xref != FastArrayCount(objMap))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"extra object crossref - %d",
			    xref];
	}
      (*dValImp)(self, dValSel, @encode(Class), &c);

      obj = [c allocWithZone: zone];
      FastArrayAddItem(objMap, (FastArrayItem)obj);

      rep = [obj initWithCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  FastArraySetItemAtIndex(objMap, (FastArrayItem)obj, xref);
	}

      rep = [obj awakeAfterUsingCoder: self];
      if (rep != obj)
	{
	  obj = rep;
	  FastArraySetItemAtIndex(objMap, (FastArrayItem)obj, xref);
	}
      /*
       *	A newly allocated object needs to be autoreleased.
       */
      return [obj autorelease];
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
	  [info release];
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
	  [info release];
	}
      [info mapToClass: c withName: trueName];
    }
}

- (void) replaceObject: (id)anObject withObject: (id)replacement
{
  unsigned i;

  for (i = FastArrayCount(objMap) - 1; i > 0; i--)
    {
      if (FastArrayItemAtIndex(objMap, i).o == anObject)
	{
	  FastArraySetItemAtIndex(objMap, (FastArrayItem)replacement, i);
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

      [data release];
      data = [anObject retain];
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
	      tagImp = (unsigned char (*)(id, SEL, unsigned*))
		  [src methodForSelector: tagSel];
	      xRefImp = (unsigned (*)(id, SEL, unsigned*))
		  [src methodForSelector: xRefSel];
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
      clsMap = NSZoneMalloc(zone, sizeof(FastArray_t)*3);
      FastArrayInitWithZoneAndCapacity(clsMap, zone, sizeC);
      FastArrayAddItem(clsMap, (FastArrayItem)0);

      objMap = &clsMap[1];
      FastArrayInitWithZoneAndCapacity(objMap, zone, sizeO);
      FastArrayAddItem(objMap, (FastArrayItem)0);

      ptrMap = &clsMap[2];
      FastArrayInitWithZoneAndCapacity(ptrMap, zone, sizeP);
      FastArrayAddItem(ptrMap, (FastArrayItem)0);
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

/* libObjects compatibility */

- (void) decodeArrayOfObjCType: (const char*) type
		         count: (unsigned)count
			    at: (void*)buf
		      withName: (id*)name
{
  if (name)
    {
      (*dValImp)(self, dValSel, @encode(id), (void*)name);
    }
  else
    {
      id	obj;
      (*dValImp)(self, dValSel, @encode(id), (void*)&obj);
      if (obj)
	{
	  [obj release];
	}
    }
  [self decodeArrayOfObjCType: type count: count at: buf];
}

- (void) decodeIndent
{
}

- (void) decodeValueOfCType: (const char*) type
			 at: (void*)buf
		   withName: (id*)name
{
  if (name)
    {
      (*dValImp)(self, dValSel, @encode(id), (void*)name);
    }
  else
    {
      id	obj;
      (*dValImp)(self, dValSel, @encode(id), (void*)&obj);
      if (obj)
	{
	  [obj release];
	}
    }
  (*dValImp)(self, dValSel, type, buf);
}

- (void) decodeValueOfObjCType: (const char*) type
			    at: (void*)buf
		      withName: (id*)name
{
  if (name)
    {
      (*dValImp)(self, dValSel, @encode(id), (void*)name);
    }
  else
    {
      id	obj;
      (*dValImp)(self, dValSel, @encode(id), (void*)&obj);
      if (obj)
	{
	  [obj release];
	}
    }
  (*dValImp)(self, dValSel, type, buf);
}

- (void) decodeObjectAt: (id*)anObject
	       withName: (id*)name
{
  if (name)
    {
      (*dValImp)(self, dValSel, @encode(id), (void*)name);
    }
  else
    {
      id	obj;
      (*dValImp)(self, dValSel, @encode(id), (void*)&obj);
      if (obj)
	{
	  [obj release];
	}
    }
  (*dValImp)(self, dValSel, @encode(id), (void*)anObject);
}
@end

