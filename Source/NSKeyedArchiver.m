/** Implementation for NSKeyedArchiver for GNUStep
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
#include <Foundation/NSObject.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>

/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_RETAIN_KEY(M, X)	
#define	GSI_MAP_RELEASE_KEY(M, X)	
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_HASH(M, X)	((X).uint)
#define	GSI_MAP_EQUAL(M, X,Y)	((X).uint == (Y).uint)
#define	GSI_MAP_NOCLEAN	1

#include <GNUstepBase/GSIMap.h>


#define	_IN_NSKEYEDARCHIVER_M	1
#include <Foundation/NSKeyedArchiver.h>
#undef	_IN_NSKEYEDARCHIVER_M

/* Exceptions */
NSString * const NSInvalidArchiveOperationException
= @"NSInvalidArchiveOperationException";

static NSMapTable	*globalClassMap = 0;

#define	CHECKKEY \
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
  if ([_enc objectForKey: aKey] != nil) \
    { \
      [NSException raise: NSInvalidArgumentException \
		  format: @"%@, duplicate key '%@' in %@", \
	NSStringFromClass([self class]), aKey, NSStringFromSelector(_cmd)]; \
    }

@interface	NSKeyedArchiver (Private)
- (NSDictionary*) _buildObjectReference: (id)anObject;
- (void) _encodeObject: (id)anObject
		forKey: (NSString*)aKey
	   conditional: (BOOL)conditional;
@end

@implementation	NSKeyedArchiver (Private)
/*
 * Add an object to the table off all encoded objects, and return a reference.
 */
- (NSDictionary*) _buildObjectReference: (id)anObject
{
  unsigned	ref = 0;

  if (anObject != nil)
    {
      ref = [_obj count];
      [_obj addObject: anObject];
    }
  return [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: ref]
				     forKey: @"CF$UID"];
}

/*
 * The real workhorse of the archiving process ... this deals with all
 * archiving of objects.
 */
- (void) _encodeObject: (id)anObject
		forKey: (NSString*)aKey
	   conditional: (BOOL)conditional
{
  id			original = anObject;
  GSIMapNode		node;
  id			objectInfo = nil;	// Encoded object
  NSMutableDictionary	*m = nil;
  NSNumber		*refNum;
  NSDictionary		*keyDict;
  unsigned		ref = 0;

  if (anObject != nil)
    {
      /*
       * Obtain replacement object for the value being encoded.
       * Notify delegate of progress and set up new mapping if necessary.
       */
      node = GSIMapNodeForKey(_repMap, (GSIMapKey)anObject);
      if (node == 0)
	{
	  anObject = [original replacementObjectForKeyedArchiver: self];
	  if (_delegate != nil)
	    {
	      if (anObject != nil)
		{
		  anObject = [_delegate archiver: self
				willEncodeObject: anObject];
		}
	      if (original != anObject)
		{
		  [_delegate archiver: self
		    willReplaceObject: original
			   withObject: anObject];
		}
	    }
	  GSIMapAddPair(_repMap, (GSIMapKey)original, (GSIMapVal)anObject);
	}
    }

  if (anObject != nil)
    {
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)anObject);
      if (node == 0)
	{
	  if (conditional == YES)
	    {
	      node = GSIMapNodeForKey(_cIdMap, (GSIMapKey)anObject);
	      if (node == 0)
		{
		  ref = [_obj count];
		  GSIMapAddPair(_cIdMap, (GSIMapKey)anObject, (GSIMapVal)ref);
		  /*
		   * Use the null object as a placeholder for a conditionally
		   * encoded object.
		   */
		  [_obj addObject: [_obj objectAtIndex: 0]];
		}
	      else
		{
		  /*
		   * This object has already been conditionally encoded.
		   */
		  ref = node->value.uint;
		}
	    }
	  else
	    {
// FIXME ... exactly what classes are stored directly???
	      if ([anObject isKindOfClass: [NSString class]] == YES)
		{
		  // We will store the string object directly.
		  objectInfo = anObject;
		}
	      else
		{
		  // We store a dictionary describing the object.
		  m = [NSMutableDictionary new];
		  objectInfo = m;
		}

	      node = GSIMapNodeForKey(_cIdMap, (GSIMapKey)anObject);
	      if (node == 0)
		{
		  /*
		   * Not encoded ... create dictionary for it.
		   */
		  ref = [_obj count];
		  GSIMapAddPair(_uIdMap, (GSIMapKey)anObject, (GSIMapVal)ref);
		  [_obj addObject: objectInfo];
		}
	      else
		{
		  /*
		   * Conditionally encoded ... replace with actual value.
		   */
		  ref = node->value.uint;
		  GSIMapAddPair(_uIdMap, (GSIMapKey)anObject, (GSIMapVal)ref);
		  GSIMapRemoveKey(_cIdMap, (GSIMapKey)anObject);
		  [_obj replaceObjectAtIndex: ref withObject: objectInfo];
		}
	      RELEASE(m);
	    }
	}
      else
	{
	  ref = node->value.uint;
	}
    }

  /*
   * Store the mapping from aKey to the appropriate entry in _obj
   */
  refNum = [[NSNumber alloc] initWithInt: ref];
  keyDict = [NSDictionary dictionaryWithObject: refNum forKey: @"CF$UID"];
  [_enc setObject: keyDict forKey: aKey];
  RELEASE(refNum);

  /*
   * objectInfo is a dictionary describing the object.
   */
  if (objectInfo != nil && m == objectInfo)
    {
      NSMutableDictionary	*savedEnc = _enc;
      unsigned			savedKeyNum = _keyNum;
      Class			c = [anObject class];
      NSString			*classname;
      Class			mapped;

      /*
       * Map the class of the object to the actual class it is encoded as.
       * First ask the object, then apply any name mappings to that value.
       */
      mapped = [anObject classForKeyedArchiver];
      if (mapped != nil)
	{
	  c = mapped;
	}

      classname = [self classNameForClass: c];
      if (classname == nil)
	{
	  classname = [[self class] classNameForClass: c];
	}
      if (classname == nil)
	{
	  classname = NSStringFromClass(c);
	}
      else
	{
	  c = NSClassFromString(classname);
	}

      /*
       * At last, get the object to encode itsself.  Save and restore the
       * current object scope of course.
       */
      _enc = m;
      _keyNum = 0;
      [anObject encodeWithCoder: self];
      _keyNum = savedKeyNum;
      _enc = savedEnc;

      /*
       * This is ugly, but it seems to be the way MacOS-X does it ...
       * We create class information by storing it directly into the
       * table of all objects, and making a reference so we can look
       * up the table entry by class pointer.
       * A much cleaner way to do it would be by encoding the class
       * normally, but we are trying to be compatible.
       *
       * Also ... we encode the class *after* encoding the instance,
       * simply because that seems to be the way MacOS-X does it and
       * we want to maximise compatibility (perhaps they had good reason?)
       */
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)c);
      if (node == 0)
	{
	  NSMutableDictionary	*cDict;
	  NSMutableArray	*hierarchy;

	  ref = [_obj count];
	  GSIMapAddPair(_uIdMap, (GSIMapKey)c, (GSIMapVal)ref);
	  cDict = [[NSMutableDictionary alloc] initWithCapacity: 2];

	  /*
	   * record class name
	   */
	  [cDict setObject: classname forKey: @"$classname"];

	  /*
	   * Record the class hierarchy for this object.
	   */
	  hierarchy = [NSMutableArray new];
	  while (c != 0)
	    {
	      Class	next = [c superClass];

	      [hierarchy addObject: NSStringFromClass(c)];
	      if (next == c)
		{
		  break;
		}
	      c = next;
	    }
	  [cDict setObject: hierarchy forKey: @"$classes"];
	  RELEASE(hierarchy);
	  [_obj addObject: cDict];
	  RELEASE(cDict);
	}
      else
	{
	  ref = node->value.uint;
	}

      /*
       * Now create a reference to the class information and store it
       * in the object description dictionary for the object we just encoded.
       */
      refNum = [[NSNumber alloc] initWithInt: ref];
      keyDict = [NSDictionary dictionaryWithObject: refNum forKey: @"CF$UID"]; 
      [m setObject: keyDict forKey: @"$class"];
      RELEASE(refNum);
    }

  /*
   * If we have encoded the object information, tell the delegaate.
   */
  if (objectInfo != nil && _delegate != nil)
    {
      [_delegate archiver: self didEncodeObject: anObject];
    }
}
@end

@implementation	NSKeyedArchiver

/*
 * When I tried this on MacOS 10.3 it encoded the object with the key 'root',
 * so this implementation does the same.
 */
+ (NSData*) archivedDataWithRootObject: (id)anObject
{
  NSMutableData		*m = nil;
  NSKeyedArchiver	*a = nil;
  NSData		*d = nil;

  NS_DURING
    {
      m = [[NSMutableData alloc] initWithCapacity: 10240];
      a = [[NSKeyedArchiver alloc] initForWritingWithMutableData: m];
      [a encodeObject: anObject forKey: @"root"];
      [a finishEncoding];
      d = [m copy];
      DESTROY(m);
      DESTROY(a);
    }
  NS_HANDLER
    {
      DESTROY(m);
      DESTROY(a);
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(d);
}

+ (BOOL) archiveRootObject: (id)anObject toFile: (NSString*)aPath
{
  CREATE_AUTORELEASE_POOL(pool);
  NSData	*d;
  BOOL		result;

  d = [self archivedDataWithRootObject: anObject];
  result = [d writeToFile: aPath atomically: YES];
  RELEASE(pool);
  return result;
}

+ (NSString*) classNameForClass: (Class)aClass
{
  return (NSString*)NSMapGet(globalClassMap, (void*)aClass);
}

+ (void) initialize
{
  if (globalClassMap == 0)
    {
      globalClassMap = 
	NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
    }
}

+ (void) setClassName: (NSString*)aString forClass: (Class)aClass
{
  if (aString == nil)
    {
      NSMapRemove(globalClassMap, (void*)aClass);
    }
  else
    {
      NSMapInsert(globalClassMap, (void*)aClass, aString);
    }
}

- (BOOL) allowsKeyedCoding
{
  return YES;
}

- (NSString*) classNameForClass: (Class)aClass
{
  return (NSString*)NSMapGet(_clsMap, (void*)aClass);
}

- (void) dealloc
{
  RELEASE(_enc);
  RELEASE(_obj);
  RELEASE(_data);
  if (_clsMap != 0)
    {
      NSFreeMapTable(_clsMap);
      _clsMap = 0;
    }
  if (_cIdMap)
    {
      GSIMapEmptyMap(_cIdMap);
      if (_uIdMap)
	{
	  GSIMapEmptyMap(_uIdMap);
	}
      if (_repMap)
	{
	  GSIMapEmptyMap(_repMap);
	}
      NSZoneFree(_cIdMap->zone, (void*)_cIdMap);
    }
  [super dealloc];
}

- (id) delegate
{
  return _delegate;
}

- (void) encodeBool: (BOOL)aBool forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithBool: aBool] forKey: aKey];
}

- (void) encodeBytes: (const uint8_t*)aPointer length: (unsigned)length forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSData dataWithBytes: aPointer length: length]
	   forKey: aKey];
}

- (void) encodeConditionalObject: (id)anObject
{
  [self _encodeObject: anObject
	       forKey: [NSString stringWithFormat: @"$%u", _keyNum++]
	  conditional: YES];
}

- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey
{
  CHECKKEY

  [self _encodeObject: anObject forKey: aKey conditional: YES];
}

- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithDouble: aDouble] forKey: aKey];
}

- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithFloat: aFloat] forKey: aKey];
}

- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithInt: anInteger] forKey: aKey];
}

- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithLong: anInteger] forKey: aKey];
}

- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_enc setObject: [NSNumber  numberWithLongLong: anInteger] forKey: aKey];
}

- (void) encodeObject: (id)anObject
{
  [self _encodeObject: anObject
	       forKey: [NSString stringWithFormat: @"$%u", _keyNum++]
	  conditional: NO];
}

- (void) encodeObject: (id)anObject forKey: (NSString*)aKey
{
  CHECKKEY

  [self _encodeObject: anObject forKey: aKey conditional: NO];
}

- (void) encodePoint: (NSPoint)p
{
  [self encodeValueOfObjCType: @encode(float) at: &p.x];
  [self encodeValueOfObjCType: @encode(float) at: &p.y];
}

- (void) encodeRect: (NSRect)r
{
  [self encodeValueOfObjCType: @encode(float) at: &r.origin.x];
  [self encodeValueOfObjCType: @encode(float) at: &r.origin.y];
  [self encodeValueOfObjCType: @encode(float) at: &r.size.width];
  [self encodeValueOfObjCType: @encode(float) at: &r.size.height];
}

- (void) encodeSize: (NSSize)s
{
  [self encodeValueOfObjCType: @encode(float) at: &s.width];
  [self encodeValueOfObjCType: @encode(float) at: &s.height];
}

- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)address
{
  NSString	*aKey;
  id		o;

  if (*type == _C_ID || *type == _C_CLASS)
    {
      [self encodeObject: *(id*)address];
      return;
    }

  aKey = [NSString stringWithFormat: @"$%u", _keyNum++];
  switch (*type)
    {
      case _C_SEL:
	{
	  // Selectors are encoded by name as strings.
	  o = NSStringFromSelector(*(SEL*)address);
	  [self encodeObject: o];
	}
	return;

      case _C_CHARPTR:
	{
	  /*
	   * Bizzarely MacOS-X seems to encode char* values by creating
	   * string objects and encoding those objects!
	   */
	  o = [NSString stringWithCString: (char*)address];
	  [self encodeObject: o];
	}
	return;

      case _C_CHR:
	o = [NSNumber numberWithInt: (int)*(char*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_UCHR:
	o = [NSNumber numberWithInt: (int)*(unsigned char*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_SHT:
	o = [NSNumber numberWithInt: (int)*(short*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_USHT:
	o = [NSNumber numberWithLong: (long)*(unsigned short*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_INT:
	o = [NSNumber numberWithInt: *(int*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_UINT:
	o = [NSNumber numberWithUnsignedInt: *(unsigned int*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_LNG:
	o = [NSNumber numberWithLong: *(long*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_ULNG:
	o = [NSNumber numberWithUnsignedLong: *(unsigned long*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_LNG_LNG:
	o = [NSNumber numberWithLongLong: *(long long*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_ULNG_LNG:
	o = [NSNumber numberWithUnsignedLongLong:
	  *(unsigned long long*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_FLT:
	o = [NSNumber numberWithFloat: *(float*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_DBL:
	o = [NSNumber numberWithDouble: *(double*)address];
	[_enc setObject: o forKey: aKey];
	return;

      case _C_STRUCT_B:
	[NSException raise: NSInvalidArgumentException
		    format: @"-[%@ %@]: this archiver cannote encode structs",
	  NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	return;

      default:	/* Types that can be ignored in first pass.	*/
	[NSException raise: NSInvalidArgumentException
		    format: @"-[%@ %@]: unknown type encoding ('%c')",
	  NSStringFromClass([self class]), NSStringFromSelector(_cmd), *type];
	break;
    }
}

- (void) finishEncoding
{
  NSMutableDictionary	*final;
  NSData		*data;
  NSString		*error;

  [_delegate archiverWillFinish: self];

  final = [NSMutableDictionary new];
  [final setObject: NSStringFromClass([self class]) forKey: @"$archiver"];
  [final setObject: @"100000" forKey: @"$version"];
  [final setObject: _enc forKey: @"$top"];
  [final setObject: _obj forKey: @"$objects"];
  data = [NSPropertyListSerialization dataFromPropertyList: final
						    format: _format
					  errorDescription: &error];
  RELEASE(final);
  [_data setData: data];
  [_delegate archiverDidFinish: self];
}

- (id) initForWritingWithMutableData: (NSMutableData*)data
{
  self = [super init];
  if (self)
    {
      NSZone	*zone = [self zone];

      _keyNum = 0;
      _data = RETAIN(data);

      _clsMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
      /*
       *	Set up map tables.
       */
      _cIdMap = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t)*5);
      _uIdMap = &_cIdMap[1];
      _repMap = &_cIdMap[2];
      GSIMapInitWithZoneAndCapacity(_cIdMap, zone, 10);
      GSIMapInitWithZoneAndCapacity(_uIdMap, zone, 200);
      GSIMapInitWithZoneAndCapacity(_repMap, zone, 1);

      _enc = [NSMutableDictionary new];		// Top level mapping dict
      _obj = [NSMutableArray new];		// Array of objects.
      [_obj addObject: @"$null"];		// Placeholder.

      _format = NSPropertyListXMLFormat_v1_0;	// FIXME ... should be binary.
    }
  return self;
}

- (NSPropertyListFormat) outputFormat
{
  return _format;
}

- (void) setClassName: (NSString*)aString forClass: (Class)aClass
{
  if (aString == nil)
    {
      NSMapRemove(_clsMap, (void*)aClass);
    }
  else
    {
      NSMapInsert(_clsMap, (void*)aClass, aString);
    }
}

- (void) setDelegate: (id)anObject
{
  _delegate = anObject;		// Not retained.
}

- (void) setOutputFormat: (NSPropertyListFormat)format
{
  _format = format;
}

@end

@implementation NSObject (NSKeyedArchiverDelegate)
- (void) archiver: (NSKeyedArchiver*)anArchiver didEncodeObject: (id)anObject
{
}
- (id) archiver: (NSKeyedArchiver*)anArchiver willEncodeObject: (id)anObject
{
  return anObject;
}
- (void) archiverDidFinish: (NSKeyedArchiver*)anArchiver
{
}
- (void) archiverWillFinish: (NSKeyedArchiver*)anArchiver
{
}
- (void) archiver: (NSKeyedArchiver*)anArchiver
willReplaceObject: (id)anObject
       withObject: (id)newObject
{
}
@end

@implementation NSObject (NSKeyedArchiverObjectSubstitution) 
- (Class) classForKeyedArchiver
{
  return [self classForArchiver];
}
- (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver*)archiver
{
  return [self replacementObjectForArchiver: nil];
}
@end



@implementation NSCoder (NSGeometryKeyedCoding)
- (void) encodePoint: (NSPoint)aPoint forKey: (NSString*)aKey
{
  NSString	*val;
  val = [NSString stringWithFormat: @"{%g, %g}", aPoint.x, aPoint.y];
  [self encodeObject: val forKey: aKey];
}
- (void) encodeRect: (NSRect)aRect forKey: (NSString*)aKey
{
  NSString	*val;
  val = [NSString stringWithFormat: @"{{%g, %g}, {%g, %g}}",
    aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height];
  [self encodeObject: val forKey: aKey];
}
- (void) encodeSize: (NSSize)aSize forKey: (NSString*)aKey
{
  NSString	*val;
  val = [NSString stringWithFormat: @"{%g, %g}", aSize.width, aSize.height];
  [self encodeObject: val forKey: aKey];
}
- (NSPoint) decodePointForKey: (NSString*)aKey
{
  const char	*val = [[self decodeObjectForKey: aKey] UTF8String];
  NSPoint	aPoint;
  if (val == 0)
    aPoint = NSMakePoint(0, 0);
  else if (sscanf(val, "{%f, %f}", &aPoint.x, &aPoint.y) != 2)
    [NSException raise: NSInvalidArgumentException
		format: @"[%@ -%@]: bad value - '%s'",
      NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
  return aPoint;
}
- (NSRect) decodeRectForKey: (NSString*)aKey
{
  const char	*val = [[self decodeObjectForKey: aKey] UTF8String];
  NSRect	aRect;
  if (val == 0)
    aRect = NSMakeRect(0, 0, 0, 0);
  else if (sscanf(val, "{{%f, %f}, {%f, %f}}",
    &aRect.origin.x, &aRect.origin.y, &aRect.size.height, &aRect.size.height)
  != 4)
    [NSException raise: NSInvalidArgumentException
		format: @"[%@ -%@]: bad value - '%s'",
      NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
  return aRect;
}
- (NSSize) decodeSizeForKey: (NSString*)aKey
{
  const char	*val = [[self decodeObjectForKey: aKey] UTF8String];
  NSSize	aSize;
  if (val == 0)
    aSize = NSMakeSize(0, 0);
  else if (sscanf(val, "{%f, %f}", &aSize.height, &aSize.height) != 2)
    [NSException raise: NSInvalidArgumentException
		format: @"[%@ -%@]: bad value - '%s'",
      NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
  return aSize;
}
@end

