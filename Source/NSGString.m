/* Implementation for GNUStep of NSStrings with Unicode-string backing
   Copyright (C) 1997,1998 Free Software Foundation, Inc.
   
   Written by Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997
   
   Based on NSGCString and NSString
   Written by:  Andrew Kachites McCallum
   <mccallum@gnu.ai.mit.edu>
   Date: March 1995

   Optimised by  Richard Frith-Macdonald <richard@brainstorm.co.uk>
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
#include <Foundation/NSGString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <base/behavior.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

#include <base/fast.x>
#include <base/Unicode.h>

/*
 *	Include sequence handling code with instructions to generate search
 *	and compare functions for NSString objects.
 */
#define	GSEQ_STRCOMP	strCompUsNs
#define	GSEQ_STRRANGE	strRangeUsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompUsUs
#define	GSEQ_STRRANGE	strRangeUsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompUsCs
#define	GSEQ_STRRANGE	strRangeUsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

/*
 *	Include property-list parsing code configured for unicode characters.
 */
#define	GSPLUNI	1
#include "propList.h"


@implementation NSGString

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject (self, 0, z);
}

+ alloc
{
  return NSAllocateObject (self, 0, NSDefaultMallocZone());
}

- (void)dealloc
{
  if (_zone)
    {
      NSZoneFree(_zone, _contents_chars);
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
  if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString
    || c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString)
    {
      NSGString	*other = (NSGString*)anObject;
      NSRange	r = {0, _count};

      /*
       * First see if the has is the same - if not, we can't be equal.
       */
      if (_hash == 0)
        _hash = _fastImp._NSString_hash(self, @selector(hash));
      if (other->_hash == 0)
        other->_hash = _fastImp._NSString_hash(other, @selector(hash));
      if (_hash != other->_hash)
	return NO;

      /*
       * Do a compare depending on the type of the other string.
       */
      if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString)
	{
	  if (strCompUsUs(self, other, 0, r) == NSOrderedSame)
	    return YES;
	}
      else
	{
	  if (strCompUsCs(self, other, 0, r) == NSOrderedSame)
	    return YES;
	}
      return NO;
    }
  else if (c == _fastCls._NXConstantString)
    {
      NSGString	*other = (NSGString*)anObject;
      NSRange	r = {0, _count};

      if (strCompUsCs(self, other, 0, r) == NSOrderedSame)
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

// Initializing Newly Allocated Strings

/* This is the OpenStep designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  _count = length;
  _contents_chars = chars;
  if (flag == YES && chars != 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = NSZoneFromPointer(chars);
#endif
    }
  else
    {
      _zone = 0;
    }
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
		   length: (unsigned int)length
{
  if (length > 0)
    {
      unichar	*s = NSZoneMalloc(fastZone(self), length*sizeof(unichar));

      if (chars != 0)
	memcpy(s, chars, sizeof(unichar)*length);
      self = [self initWithCharactersNoCopy: s
				     length: length
			       freeWhenDone: YES];
    }
  else
    {
      self = [self initWithCharactersNoCopy: 0 length: 0 freeWhenDone: NO];
    }
  return self;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  id a = [[NSGCString allocWithZone: fastZone(self)]
	initWithCStringNoCopy: byteString length: length freeWhenDone: flag];
  RELEASE(self);
  return a;
}

- (id) init
{
  return [self initWithCharactersNoCopy:0 length:0 freeWhenDone: 0];
}

// Getting a String's Length

- (unsigned int) length
{
  return  _count;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  if (index >= _count)
    [NSException raise: NSRangeException format:@"Invalid index."];
  return _contents_chars[index];
}

- (void)getCharacters: (unichar*)buffer
{
  memcpy(buffer, _contents_chars, _count*2);
}

- (void)getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  memcpy(buffer, _contents_chars + aRange.location, aRange.length*2);
}

// Dividing Strings into Substrings

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return [[self class] stringWithCharacters: _contents_chars + aRange.location
		       length: aRange.length];
}

// Getting C Strings

- (const char *) cString
{
  char *r = (char*)_fastMallocBuffer(_count+1);

  if (_count > 0)
    ustrtostr(r, _contents_chars, _count);
  r[_count] = '\0';
  return r;
}

// xxx fix me
- (unsigned int) cStringLength
{
  return _count;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  unsigned int	len = [self length];

  if (len == 0)
    {
      return [NSData data];
    }

  if (encoding == NSUnicodeStringEncoding)
    {
      unichar *buff;

      buff = (unichar*)NSZoneMalloc(NSDefaultMallocZone(), 2*len+2);
      buff[0] = 0xFEFF;
      memcpy(buff+1, _contents_chars, 2*len);
      return [NSData dataWithBytesNoCopy: buff length: 2*len+2];
    }
  else
    {
      int t;
      unsigned char *buff;

      buff = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), len+1);
      // FIXME: Here should the lossy flag be used
      if (flag)
	t = encode_ustrtostr(buff, _contents_chars, len, encoding);
      else 
	t = encode_ustrtostr_strict(buff, _contents_chars, len, encoding);
      buff[t] = '\0';
      if (!t)
        {
	  NSZoneFree(NSDefaultMallocZone(), buff);
	  return nil;
	}
      return [NSData dataWithBytesNoCopy: buff length: t];
    }
  return nil;
}

- (NSStringEncoding) fastestEncoding
{
  return NSUnicodeStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return NSUnicodeStringEncoding;
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  int count = 0;
  int blen = 0;

  while (count < _count)
    if (!uni_isnonsp(_contents_chars[count++]))
      blen++;
  return blen;
} 

/* NSCoding Protocol */

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count > 0)
    {
      [aCoder encodeArrayOfObjCType: @encode(unichar)
			      count: _count
				 at: _contents_chars];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = fastZone(self);
#endif
      _contents_chars = NSZoneMalloc(_zone, sizeof(unichar)*_count);
      [aCoder decodeArrayOfObjCType: @encode(unichar)
			      count: _count
				 at: _contents_chars];
    }
  return self;
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
    setupPl([NSGString class]);

  result = parsePl(&data);

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
    setupPl([NSGString class]);

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
  unsigned	start;
  unsigned	end;

  if (anIndex >= _count)
    [NSException raise: NSRangeException format:@"Invalid location."];

  start = anIndex;
  while (uni_isnonsp(_contents_chars[start]) && start > 0)
    start--;
  end = start + 1;
  if (end < _count)
    while ((end < _count) && (uni_isnonsp(_contents_chars[end])) )
      end++;
  return NSMakeRange(start, end-start);
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
    return strCompUsUs(self, aString, mask, aRange);
  else if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    return strCompUsCs(self, aString, mask, aRange);
  else
    return strCompUsNs(self, aString, mask, aRange);
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
    return strRangeUsUs(self, aString, mask, aRange);
  else if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString
    || c == _fastCls._NXConstantString)
    return strRangeUsCs(self, aString, mask, aRange);
  else
    return strRangeUsNs(self, aString, mask, aRange);
}


- (BOOL) boolValue
{
  if (_count == 0)
    {
      return 0;
    }
  else
    {
      char	buf[_count+1];

      ustrtostr(buf, _contents_chars, _count);
      buf[_count] = '\0';
      if (_count == 3
	&& (_contents_chars[0] == 'Y' || _contents_chars[0] == 'y')
	&& (_contents_chars[1] == 'E' || _contents_chars[1] == 'e')
	&& (_contents_chars[2] == 'S' || _contents_chars[2] == 's'))
	{
	  return YES;
	}
      else
	{
	  return atoi(buf);
	}
    }
}

- (double) doubleValue
{
  if (_count == 0)
    {
      return 0;
    }
  else
    {
      char	buf[_count+1];

      ustrtostr(buf, _contents_chars, _count);
      buf[_count] = '\0';
      return atof(buf);
    }
}

- (float) floatValue
{
  if (_count == 0)
    {
      return 0;
    }
  else
    {
      char	buf[_count+1];

      ustrtostr(buf, _contents_chars, _count);
      buf[_count] = '\0';
      return (float) atof(buf);
    }
}

- (int) intValue
{
  if (_count == 0)
    {
      return 0;
    }
  else
    {
      char	buf[_count+1];

      ustrtostr(buf, _contents_chars, _count);
      buf[_count] = '\0';
      return atoi(buf);
    }
}

@end



@implementation NSGMutableString

// @class NSMutableString;

// @protocol NSMutableString <NSString>

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
      class_add_behavior(self, [NSGString class]);
    }
}
typedef struct {
  @defs(NSGMutableString)
} NSGMutableStringStruct;

static inline void
stringIncrementCountAndMakeHoleAt(NSGMutableStringStruct *self, 
				  int index, int size)
{
  if (size > 0)
    {
      if (self->_count > 0)
	{
	  NSCAssert(index+size<=self->_count,@"index+size>length");
	  NSCAssert(self->_count+size<=self->_capacity,@"length+size>capacity");
#ifndef STABLE_MEMCPY
	  {
	    int i;

	    for (i = self->_count; i >= index; i--)
	      {
		self->_contents_chars[i+size] = self->_contents_chars[i];
	      }
	  }
#else
	  memcpy(self->_contents_chars + index,
	    self->_contents_chars + index + size, 2*(self->_count - index));
#endif /* STABLE_MEMCPY */
	  self->_count += size;
	}
      self->_hash = 0;
    }
}

static inline void
stringDecrementCountAndFillHoleAt(NSGMutableStringStruct *self, 
				  int index, int size)
{
  if (size > 0)
    {
      if (self->_count > 0)
	{
	  NSCAssert(index+size<=self->_count,@"index+size>length");
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
			 2*(self->_count - index));
#endif // STABLE_MEMCPY
	}
      self->_hash = 0;
    }
}

// Initializing Newly Allocated Strings

- (id) init
{
  return [self initWithCapacity: 0];
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  _count = length;
  _capacity = length;
  _contents_chars = chars;
  if (flag == YES && chars != 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = NSZoneFromPointer(chars);
#endif
    }
  else
    {
      _zone = 0;
    }
  return self;
}

- (id) initWithCapacity: (unsigned)capacity
{
  self = [super init];
  if (self)
    {
      if (capacity < 2)
	{
	  capacity = 2;
	}
      _count = 0;
      _capacity = capacity;
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = fastZone(self);
#endif
      _contents_chars = NSZoneMalloc(_zone, sizeof(unichar)*capacity);
    }
  return self;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  id a = [[NSGMutableCString allocWithZone: fastZone(self)]
	initWithCStringNoCopy: byteString length: length freeWhenDone: flag];
  RELEASE(self);
  return a;
}

// Modify A String

- (void) deleteCharactersInRange: (NSRange)range
{
  GS_RANGE_CHECK(range, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, 
				    range.location, range.length);
}

- (void) replaceCharactersInRange: (NSRange)aRange
		       withString: (NSString*)aString
{
  int offset;
  unsigned stringLength;

  GS_RANGE_CHECK(aRange, _count);

  stringLength = (aString == nil) ? 0 : [aString length];
  offset = stringLength - aRange.length;

  if (_count + stringLength > _capacity + aRange.length)
    {
      _capacity += stringLength - aRange.length;
      if (_capacity < 2)
	_capacity = 2;
      _contents_chars =
	NSZoneRealloc(_zone, _contents_chars, sizeof(unichar)*_capacity);
    }

#ifdef  HAVE_MEMMOVE
  if (offset != 0)
    {
      unichar *src = _contents_chars + aRange.location + aRange.length;
      memmove(src + offset, src, (_count - aRange.location - aRange.length)*2);
    }
#else
  if (offset > 0)
    {
      int first = aRange.location + aRange.length;
      int i;
      for (i = _count - 1; i >= first; i--)
        _contents_chars[i+offset] = _contents_chars[i];
    }
  else if (offset < 0)
    {
      int i;
      for (i = aRange.location + aRange.length; i < _count; i++)
        _contents_chars[i+offset] = _contents_chars[i];
    }
#endif
  [aString getCharacters: &_contents_chars[aRange.location]];
  _count += offset;
  _hash = 0;
}

- (void) setString: (NSString*)aString
{
  int len = [aString length];
  if (_capacity < len)
    {
      _capacity = len;
      if (_capacity < 2)
	_capacity = 2;
      _contents_chars =
	NSZoneRealloc(_zone, _contents_chars, sizeof(unichar)*_capacity);
    }
  [aString getCharacters: _contents_chars];
  _count = len;
  _hash = 0;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &cap];
  [self initWithCapacity:cap];
  _count = cap;
  if (_count)
    {
      [aCoder decodeArrayOfObjCType: @encode(unichar)
			      count: _count
				 at: _contents_chars];
    }
  return self;
}

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return unitochar(_contents_chars[index]);
}

@end
