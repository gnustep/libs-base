/* Implementation for GNUStep of NSStrings with C-string backing
   Copyright (C) 1993,1994, 1996, 1997, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   Optimised by:  Richard frith-Macdoanld <richard@brainstorm.co.uk>
   Date: October 1998

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
#include <base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSException.h>
#include <base/NSGString.h>
#include <base/NSGCString.h>
#include <Foundation/NSValue.h>
#include <base/behavior.h>

#include <base/Unicode.h>
#include <base/fast.x>

/*
 *	Include sequence handling code with instructions to generate search
 *	and compare functions for NSString objects.
 */
#define	GSEQ_STRCOMP	strCompCsNs
#define	GSEQ_STRRANGE	strRangeCsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompCsUs
#define	GSEQ_STRRANGE	strRangeCsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompCsCs
#define	GSEQ_STRRANGE	strRangeCsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

/*
 *	Include property-list parsing code configured for ascii characters.
 */
#define	GSPLUNI	0
#include "propList.h"

static	SEL	csInitSel = @selector(initWithCStringNoCopy: length: fromZone:);
static	SEL	msInitSel = @selector(initWithCapacity:);
static	IMP	csInitImp;	/* designated initialiser for cString	*/
static	IMP	msInitImp;	/* designated initialiser for mutable	*/

@interface NSGMutableCString (GNUDescription)
- (unsigned char*) _extendBy: (unsigned)len;
@end

@implementation NSGCString

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      csInitImp = [NSGCString instanceMethodForSelector: csInitSel];
      msInitImp = [NSGMutableCString instanceMethodForSelector: msInitSel];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject(self, 0, z);
}

+ (id) alloc
{
  return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

- (void) dealloc
{
  if (_zone)
    {
      NSZoneFree(_zone, (void*)_contents_chars);
      _zone = 0;
    }
  [super dealloc];
}

- (unsigned) hash
{
  if (_hash == 0)
    _hash = _fastImp._NSString_hash(self, @selector(hash));
  return _hash;
}

/*
 *	This is the GNUstep designated initializer for this class.
 *	NB. this does NOT change the '_hash' instance variable, so the copy
 *	methods can safely allocate a new object, copy the _hash into place,
 *	and then invoke this method to complete the copy operation.
 */
- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  _count = length;
  _contents_chars = (unsigned char*)byteString;
#if	GS_WITH_GC
  _zone = byteString ? GSAtomicMallocZone() : 0;
#else
  _zone = byteString ? zone : 0;
#endif
  return self;
}

/* This is the OpenStep designated initializer for this class. */
- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		freeWhenDone: (BOOL)flag
{
  NSZone	*z;

  if (flag && byteString)
    {
      z = NSZoneFromPointer(byteString);
    }
  else
    {
      z = 0;
    }
  return (*csInitImp)(self, csInitSel, byteString, length, z);
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone
{
  NSZone	*z = zone ? zone : fastZone(self);
  id a = [[NSGString allocWithZone: z] initWithCharactersNoCopy: chars
							 length: length
						       fromZone: z];
  RELEASE(self);
  return a;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  NSZone	*z = fastZone(self);
  id a = [[NSGString allocWithZone: z] initWithCharactersNoCopy: chars
							 length: length
						   freeWhenDone: flag];
  RELEASE(self);
  return a;
}

- (id) init
{
  return [self initWithCStringNoCopy: 0 length: 0 fromZone: 0];
}

- (void) _collectionReleaseContents
{
  return;
}

- (void) _collectionDealloc
{
  if (_zone)
    {
      NSZoneFree(_zone, (void*)_contents_chars);
      _zone = 0;
    }
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count > 0)
    {
      [aCoder encodeArrayOfObjCType: @encode(unsigned char)
			      count: _count
				 at: _contents_chars];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [aCoder decodeValueOfObjCType: @encode(unsigned)
			     at: &_count];
  if (_count > 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = fastZone(self);
#endif
      _contents_chars = NSZoneMalloc(_zone, _count);
      [aCoder decodeArrayOfObjCType: @encode(unsigned char)
			      count: _count
				 at: _contents_chars];
    }
  return self;
}

- (id) copy
{
  NSZone	*z = NSDefaultMallocZone();

  if (NSShouldRetainWithZone(self, z) == NO)
    {
      NSGCString	*obj;
      unsigned char	*tmp;

      obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
      if (_count)
	{
	  tmp = NSZoneMalloc(z, _count);
	  memcpy(tmp, _contents_chars, _count);
	}
      else
	{
	  tmp = 0;
	  z = 0;
	}
      obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
      if (_hash && obj)
        {
	  obj->_hash = _hash;
	}
      return obj;
    }
  else 
    {
      return RETAIN(self);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) == NO)
    {
      NSGCString	*obj;
      unsigned char	*tmp;

      obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
      if (_count)
	{
	  tmp = NSZoneMalloc(z, _count);
	  memcpy(tmp, _contents_chars, _count);
	}
      else
	{
	  tmp = 0;
	  z = 0;
	}
      obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
      if (_hash && obj)
        {
	  obj->_hash = _hash;
	}
      return obj;
    }
  else 
    {
      return RETAIN(self);
    }
}

- (id) mutableCopy
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString,
		0, NSDefaultMallocZone());
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  NSGCString	*tmp = (NSGCString*)obj;	// Same ivar layout!

	  memcpy(tmp->_contents_chars, _contents_chars, _count);
	  tmp->_count = _count;
	  tmp->_hash = _hash;
	}
    }
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString, 0, z);
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  NSGCString	*tmp = (NSGCString*)obj;	// Same ivar layout!

	  memcpy(tmp->_contents_chars, _contents_chars, _count);
	  tmp->_count = _count;
	  tmp->_hash = _hash;
	}
    }
  return obj;
}

- (const char *) cString
{
  unsigned char	*r = (unsigned char*)_fastMallocBuffer(_count+1);

  memcpy(r, _contents_chars, _count);
  r[_count] = '\0';
  return (const char*)r;
}

- (const char *) lossyCString
{
  unsigned char	*r = (unsigned char*)_fastMallocBuffer(_count+1);

  memcpy(r, _contents_chars, _count);
  r[_count] = '\0';
  return (const char*)r;
}

- (void) getCString: (char*)buffer
{
  memcpy(buffer, _contents_chars, _count);
  buffer[_count] = '\0';
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  if (maxLength > _count)
    maxLength = _count;
  memcpy(buffer, _contents_chars, maxLength);
  buffer[maxLength] = '\0';
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  int len;

  GS_RANGE_CHECK(aRange, _count);
  if (maxLength < aRange.length)
    {
      len = maxLength;
      if (leftoverRange)
	{
	  leftoverRange->location = 0;
	  leftoverRange->length = 0;
	}
    }
  else
    {
      len = aRange.length;
      if (leftoverRange)
	{
	  leftoverRange->location = aRange.location + maxLength;
	  leftoverRange->length = aRange.length - maxLength;
	}
    }

  memcpy(buffer, &_contents_chars[aRange.location], len);
  buffer[len] = '\0';
}

- (unsigned) count
{
  return _count;
}

- (unsigned int) cStringLength
{
  return _count;
}

- (unsigned int) length
{
  return _count;
}

- (unichar) characterAtIndex: (unsigned int)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return chartouni(_contents_chars[index]);
}

- (void) getCharacters: (unichar*)buffer
{
  unsigned	i;

  for (i = 0; i < _count; i++)
    buffer[i] = chartouni(((unsigned char *)_contents_chars)[i]);
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  unsigned	e, i;

  GS_RANGE_CHECK(aRange, _count);
  e = aRange.location + aRange.length;
  for (i = aRange.location; i < e; i++)
    *buffer++ = chartouni(((unsigned char *)_contents_chars)[i]);
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return [[self class] stringWithCString: _contents_chars + aRange.location
		       length: aRange.length];
}

- (NSStringEncoding) fastestEncoding
{
  if (([NSString defaultCStringEncoding] == NSASCIIStringEncoding)
    || ([NSString defaultCStringEncoding] == NSISOLatin1StringEncoding))
    return [NSString defaultCStringEncoding];
  else
    return NSUnicodeStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return [NSString defaultCStringEncoding];
}

- (BOOL) isEqual: (id)anObject
{
  Class	c;
  if (anObject == self)
    return YES;
  if (anObject == nil)
    return NO;
  c = fastClassOfInstance(anObject);

  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString)
    {
      NSGCString	*other = (NSGCString*)anObject;

      if (_count != other->_count)
	return NO;
      if (_hash == 0)
         _hash = _fastImp._NSString_hash(self, @selector(hash));
      if (other->_hash == 0)
         other->_hash = _fastImp._NSString_hash(other, @selector(hash));
      if (_hash != other->_hash)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NXConstantString)
    {
      NSGCString	*other = (NSGCString*)anObject;

      if (_count != other->_count)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    {
      if (strCompCsUs(self, anObject, 0, (NSRange){0,_count}) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (c == nil)
    return NO;
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    return _fastImp._NSString_isEqualToString_(self,
		@selector(isEqualToString:), anObject);
  else
    return NO;
}

- (BOOL) isEqualToString: (NSString*)aString
{
  Class	c;

  if (aString == self)
    return YES;
  if (aString == nil)
    return NO;
  c = fastClassOfInstance(aString);
  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString)
    {
      NSGCString	*other = (NSGCString*)aString;

      if (_count != other->_count)
	return NO;
      if (_hash == 0)
        _hash = _fastImp._NSString_hash(self, @selector(hash));
      if (other->_hash == 0)
         other->_hash = _fastImp._NSString_hash(other, @selector(hash));
      if (_hash != other->_hash)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NXConstantString)
    {
      NSGCString	*other = (NSGCString*)aString;

      if (_count != other->_count)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    {
      if (strCompCsUs(self, aString, 0, (NSRange){0,_count}) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (c == nil)
    return NO;
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    return _fastImp._NSString_isEqualToString_(self,
		@selector(isEqualToString:), aString);
  else
    return NO;
}

- (id) objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return [NSNumber numberWithChar: _contents_chars[index]];
}

- (int) _baseLength
{
  return _count;
} 

- (id) initWithString: (NSString*)string
{
  unsigned	length = [string cStringLength];
  NSZone	*z;
  unsigned char	*buf;

  if (length > 0)
    {
      z = fastZone(self);
      buf = NSZoneMalloc(z, length+1);  // getCString appends a nul.
      [string getCString: buf];
    }
  else
    {
      z = 0;
      buf = 0;
    }
  return [self initWithCStringNoCopy: buf length: length fromZone: z];
}

- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned) level
			    to: (id<GNUDescriptionDestination>)output
{
  if (output == nil)
    return;

  if (_count == 0)
    {
      [output appendString: @"\"\""];
    }
  else
    {
      unsigned	i;
      unsigned	length = _count;
      BOOL	needQuote = NO;

      for (i = 0; i < _count; i++)
	{
	  unsigned char	val = _contents_chars[i];

	  if (isalnum(val))
	    {
	      continue;
	    }
	  switch (val)
	    {
	      case '\a': 
	      case '\b': 
	      case '\t': 
	      case '\r': 
	      case '\n': 
	      case '\v': 
	      case '\f': 
	      case '\\': 
	      case '"' : 
		length += 1;
		break;

	      default: 
		if (val == ' ' || isprint(val))
		  {
		    needQuote = YES;
		  }
		else
		  {
		    length += 4;
		  }
		break;
	    }
	}

      if (needQuote || length != _count)
	{
	  Class		c = fastClass(output);
	  NSZone	*z = NSDefaultMallocZone();
	  unsigned char	*buf;
	  unsigned char	*ptr;

	  length += 2;
	  if (c == _fastCls._NSGMutableCString)
	    {
	      buf = [(NSGMutableCString*)output _extendBy: length];
	    }
	  else
	    {
	      buf = NSZoneMalloc(z, length+1);
	    }
	  ptr = buf;
	  *ptr++ = '"';
	  for (i = 0; i < _count; i++)
	    {
	      unsigned char	val = _contents_chars[i];

	      switch (val)
		{
		  case '\a': 	*ptr++ = '\\'; *ptr++ = 'a';  break;
		  case '\b': 	*ptr++ = '\\'; *ptr++ = 'b';  break;
		  case '\t': 	*ptr++ = '\\'; *ptr++ = 't';  break;
		  case '\r': 	*ptr++ = '\\'; *ptr++ = 'r';  break;
		  case '\n': 	*ptr++ = '\\'; *ptr++ = 'n';  break;
		  case '\v': 	*ptr++ = '\\'; *ptr++ = 'v';  break;
		  case '\f': 	*ptr++ = '\\'; *ptr++ = 'f';  break;
		  case '\\': 	*ptr++ = '\\'; *ptr++ = '\\'; break;
		  case '"' : 	*ptr++ = '\\'; *ptr++ = '"';  break;

		  default: 
		    if (isprint(val) || val == ' ')
		      {
			*ptr++ = val;
		      }
		    else
		      {
			*ptr++ = '\\';
			*ptr++ = '0';
			*ptr++ = ((val&0700)>>6)+'0';
			*ptr++ = ((val&070)>>3)+'0';
			*ptr++ = (val&07)+'0';
		      }
		    break;
		}
	    }
	  *ptr++ = '"';
	  *ptr = '\0';
	  if (c != _fastCls._NSGMutableCString)
	    {
	      NSString	*result;

	      result = [[_fastCls._NSGCString allocWithZone: z]
		initWithCStringNoCopy: buf length: length fromZone: z];
	      [output appendString: result];
	      RELEASE(result);
	    }
	}
      else
	{
	  [output appendString: self];
	}
    }
}

- (id) propertyList
{
  id		result;
  pldata	data;

  data.ptr = _contents_chars;
  data.pos = 0;
  data.end = _count;
  data.lin = 1;
  data.err = nil;

  if (plInit == 0)
    setupPl([NSGCString class]);

  result = parsePlItem(&data);

  if (result == nil && data.err != nil)
    {
      [NSException raise: NSGenericException
		  format: @"%@ at line %u", data.err, data.lin];
    }
  return AUTORELEASE(result);
}

- (NSDictionary*) propertyListFromStringsFileFormat
{
  id		result;
  pldata	data;

  data.ptr = _contents_chars;
  data.pos = 0;
  data.end = _count;
  data.lin = 1;
  data.err = nil;

  if (plInit == 0)
    setupPl([NSGCString class]);

  result = parseSfItem(&data);
  if (result == nil && data.err != nil)
    {
      [NSException raise: NSGenericException
		  format: @"%@ at line %u", data.err, data.lin];
    }
  return AUTORELEASE(result);
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  if (anIndex >= _count)
    [NSException raise: NSRangeException format: @"Invalid location."];
  return NSMakeRange(anIndex, 1);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"compare with nil"];
  c = fastClass(aString);
  if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    return strCompCsUs(self, aString, mask, aRange);
  else if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    return strCompCsCs(self, aString, mask, aRange);
  else
    return strCompCsNs(self, aString, mask, aRange);
}

- (NSRange) rangeOfString: (NSString *) aString
		  options: (unsigned int) mask
		    range: (NSRange) aRange
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  c = fastClass(aString);
  if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    return strRangeCsUs(self, aString, mask, aRange);
  else if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    return strRangeCsCs(self, aString, mask, aRange);
  else
    return strRangeCsNs(self, aString, mask, aRange);
}

@end


@implementation NSGMutableCString

+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject(self, 0, z);
}

+ (id) alloc
{
  return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior(self, [NSGCString class]);
    }
}

typedef struct {
  @defs(NSGMutableCString)
} NSGMutableCStringStruct;

static inline void
stringGrowBy(NSGMutableCStringStruct *self, unsigned want)
{
  want += self->_count + 1;
  if (want > self->_capacity)
    self->_capacity += self->_capacity/2;
  if (want > self->_capacity)
    self->_capacity = want;
  self->_contents_chars
    = NSZoneRealloc(self->_zone, self->_contents_chars, self->_capacity);
}

static inline void
stringIncrementCountAndMakeHoleAt(NSGMutableCStringStruct *self, 
				  int index, int size)
{
  if (size > 0)
    {
      if (self->_count > 0)
	{
#ifndef STABLE_MEMCPY
	  unsigned i = self->_count;

	  while (i-- > index)
	    {
	      self->_contents_chars[i+size] = self->_contents_chars[i];
	    }
#else
	  memcpy(self->_contents_chars + index, 
		 self->_contents_chars + index + size,
		 self->_count - index);
#endif /* STABLE_MEMCPY */
	}
      self->_count += size;
      self->_hash = 0;
    }
}

static inline void
stringDecrementCountAndFillHoleAt(NSGMutableCStringStruct *self, 
				  int index, int size)
{
  if (size > 0)
    {
      self->_count -= size;
#ifndef STABLE_MEMCPY
      {
	int i;

	for (i = index; i <= self->_count; i++)
	  {
	    self->_contents_chars[i] = self->_contents_chars[i+size];
	  }
      }
#else
      memcpy(self->_contents_chars + index + size,
	     self->_contents_chars + index, 
	     self->_count - index);
#endif /* STABLE_MEMCPY */
      self->_hash = 0;
    }
}

/* This is the designated initializer for this class */
- (id) initWithCapacity: (unsigned)capacity
{
  _count = 0;
  _capacity = capacity;
  if (capacity)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = fastZone(self);
#endif
      _contents_chars = NSZoneMalloc(_zone, _capacity);
    }
  return self;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  self = (*msInitImp)(self, msInitSel, 0);
  if (self)
    {
      _count = length;
      _capacity = length;
      _contents_chars = (unsigned char*)byteString;
#if	GS_WITH_GC
      _zone = byteString ? GSAtomicMallocZone() : 0;
#else
      _zone = byteString ? zone : 0;
#endif
    }
  return self;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone
{
  NSZone	*z = zone ? zone : fastZone(self);
  id a = [[NSGMutableString allocWithZone: z] initWithCharactersNoCopy: chars
							 length: length
						       fromZone: z];
  RELEASE(self);
  return a;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  NSZone	*z = fastZone(self);
  id a = [[NSGMutableString allocWithZone: z] initWithCharactersNoCopy: chars
							   length: length
						     freeWhenDone: flag];
  RELEASE(self);
  return a;
}

- (id) copy
{
  unsigned char	*tmp;
  NSGCString	*obj;
  NSZone	*z = NSDefaultMallocZone();

  obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
  if (_count)
    {
      tmp = NSZoneMalloc(z, _count);
      memcpy(tmp, _contents_chars, _count);
    }
  else
    {
      tmp = 0;
      z = 0;
    }
  obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
  if (_hash && obj)
    {
      NSGMutableCString	*tmp = (NSGMutableCString*)obj;	// Same ivar layout

      tmp->_hash = _hash;
    }
  return obj;
}

- (id) copyWithZone: (NSZone*)z
{
  unsigned char	*tmp;
  NSGCString	*obj;

  obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
  if (_count)
    {
      tmp = NSZoneMalloc(z, _count);
      memcpy(tmp, _contents_chars, _count);
    }
  else
    {
      tmp = 0;
      z = 0;
    }
  obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
  if (_hash && obj)
    {
      NSGMutableCString	*tmp = (NSGMutableCString*)obj;	// Same ivar layout

      tmp->_hash = _hash;
    }
  return obj;
}

- (id) mutableCopy
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString,
		0, NSDefaultMallocZone());
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  memcpy(obj->_contents_chars, _contents_chars, _count);
	  obj->_count = _count;
	  obj->_hash = _hash;
	}
    }
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString, 0, z);
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  memcpy(obj->_contents_chars, _contents_chars, _count);
	  obj->_count = _count;
	  obj->_hash = _hash;
	}
    }
  return obj;
}

- (void) deleteCharactersInRange: (NSRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, 
				    range.location, range.length);
}

// xxx This should be primitive method
- (void) replaceCharactersInRange: (NSRange)range
		       withString: (NSString*)aString
{
  [self deleteCharactersInRange: range];
  [self insertString: aString atIndex: range.location];
}

- (void) insertString: (NSString*)aString atIndex: (unsigned)index
{
  unsigned c = [aString cStringLength];
  unsigned char	save;

  if (_count + c >= _capacity)
    stringGrowBy((NSGMutableCStringStruct *)self, c);
  stringIncrementCountAndMakeHoleAt((NSGMutableCStringStruct*)self, index, c);
  save = _contents_chars[index+c];	// getCString will put a nul here.
  [aString getCString: _contents_chars + index];
  _contents_chars[index+c] = save;
}

- (void) appendString: (NSString*)aString
{
  Class	c;

  if (aString == nil || (c = fastClassOfInstance(aString)) == nil)
    return;
  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString)
    {
      NSGMutableCString	*other = (NSGMutableCString*)aString;
      unsigned		l = other->_count;

      if (_count + l > _capacity)
	stringGrowBy((NSGMutableCStringStruct *)self, l);
      memcpy(_contents_chars + _count, other->_contents_chars, l);
      _count += l;
      _hash = 0;
    }
  else
    {
      unsigned l = [aString cStringLength];
      if (_count + l >= _capacity)
	stringGrowBy((NSGMutableCStringStruct *)self, l);
      [aString getCString: _contents_chars + _count];
      _count += l;
      _hash = 0;
    }
}

- (void) setString: (NSString*)aString
{
  unsigned length = [aString cStringLength];
  if (_capacity <= length)
    {
      _capacity = length+1;
      _contents_chars =
		NSZoneRealloc(_zone, _contents_chars, _capacity);
    }
  [aString getCString: _contents_chars];
  _count = length;
  _hash = 0;
}

- (id) init
{
  return [self initWithCStringNoCopy: 0 length: 0 fromZone: 0];
}

- (void) removeRange: (NSRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, 
				    range.location, range.length);
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &cap];
  [self initWithCapacity: cap];
  _count = cap;
  if (_count > 0)
    {
      [aCoder decodeArrayOfObjCType: @encode(unsigned char)
			      count: _count
			         at: _contents_chars];
    }
  return self;
}

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_chars[index];
}


- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  // one for the next char, one for the '\0';
  if (_count >= _capacity)
    {
      _capacity *= 2;
      _contents_chars =
		NSZoneRealloc(_zone, _contents_chars, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableCStringStruct*)self, index, 1);
  _contents_chars[index] = [newObject charValue];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, index, 1);
}

- (unsigned char*) _extendBy: (unsigned)len
{
  unsigned char	*ptr;

  if (len > 0)
    stringGrowBy((NSGMutableCStringStruct *)self, len);
  ptr = &_contents_chars[_count];
  _count += len;
  _hash = 0;
  return ptr;
}
@end

@implementation NXConstantString

+ (id) allocWithZone: (NSZone*)z
{
  [NSException raise: NSGenericException
	      format: @"Attempt to allocate an NXConstantString"];
  return nil;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  [NSException raise: NSGenericException
	      format: @"Attempt to init an NXConstantString"];
  return nil;
}

/*
 *	NXConstantString overrides [-dealloc] so that it is never deallocated.
 *	If we pass an NXConstantString to another process or record it in an
 *	archive and readi it back, the new copy will never be deallocated -
 *	causing a memory leak.  So we tell the system to use the super class.
 */
- (Class) classForArchiver
{
  return [self superclass];
}

- (Class) classForCoder
{
  return [self superclass];
}

- (Class) classForPortCoder
{
  return [self superclass];
}

- (void) dealloc
{
}

- (const char*) cString
{
  return (const char*) _contents_chars;
}

- (id) retain
{
  return self;
}

- (oneway void) release
{
  return;
}

- (id) autorelease
{
  return self;
}

- (id) copy
{
  return self;
}

- (id) copyWithZone: (NSZone*)z
{
  return self;
}

- (NSZone*) zone
{
  return NSDefaultMallocZone();
}

- (NSStringEncoding) fastestEncoding
{
  return NSASCIIStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return NSASCIIStringEncoding;
}

- (unichar) characterAtIndex: (unsigned int)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return (unichar)_contents_chars[index];
}

- (unsigned) hash
{
  unsigned ret = 0;

  int len = _count;

  if (len > NSHashStringLength)
    len = NSHashStringLength;
  if (len)
    {
      const unsigned char	*p;
      unsigned	char_count = 0;

      p = _contents_chars;
      while (*p && char_count++ < NSHashStringLength)
	{
	  ret = (ret << 5) + ret + *p++;
	}

      /*
       * The hash caching in our concrete string classes uses zero to denote
       * an empty cache value, so we MUST NOT return a hash of zero.
       */
      if (ret == 0)
	ret = 0xffffffff;
    }
  else
    {
      ret = 0xfffffffe;	/* Hash for an empty string.	*/
    }
  return ret;
}

- (BOOL) isEqual: (id)anObject
{
  Class	c;
  if (anObject == self)
    {
      return YES;
    }
  if (anObject == nil)
    {
      return NO;
    }
  c = fastClassOfInstance(anObject);

  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    {
      NXConstantString	*other = (NXConstantString*)anObject;

      if (_count != other->_count)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    {
      if (strCompCsUs(self, anObject, 0, (NSRange){0,_count}) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (c == nil)
    {
      return NO;
    }
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    {
      return _fastImp._NSString_isEqualToString_(self,
	@selector(isEqualToString:), anObject);
    }
  else
    {
      return NO;
    }
}

- (BOOL) isEqualToString: (NSString*)aString
{
  Class	c;

  if (aString == self)
    {
      return YES;
    }
  if (aString == nil)
    {
      return NO;
    }
  c = fastClassOfInstance(aString);
  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    {
      NXConstantString	*other = (NXConstantString*)aString;

      if (_count != other->_count)
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
    {
      if (strCompCsUs(self, aString, 0, (NSRange){0,_count}) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (c == nil)
    {
      return NO;
    }
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    {
      return _fastImp._NSString_isEqualToString_(self,
	@selector(isEqualToString:), aString);
    }
  else
    {
      return NO;
    }
}

- (id) mutableCopy
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString,
		0, NSDefaultMallocZone());
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  NXConstantString	*tmp = (NXConstantString*)obj;

	  memcpy(tmp->_contents_chars, _contents_chars, _count);
	  tmp->_count = _count;
	  tmp->_hash = 0;
	}
    }
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  NSGMutableCString	*obj;

  obj = (NSGMutableCString*)NSAllocateObject(_fastCls._NSGMutableCString, 0, z);
  if (obj)
    {
      obj = (*msInitImp)(obj, msInitSel, _count);
      if (obj)
	{
	  NXConstantString	*tmp = (NXConstantString*)obj;

	  memcpy(tmp->_contents_chars, _contents_chars, _count);
	  tmp->_count = _count;
	  tmp->_hash = 0;		// No hash available yet.
	}
    }
  return obj;
}
@end
