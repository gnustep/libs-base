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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGString.h>
#include <Foundation/NSData.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/NSGSequence.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

#include <gnustep/base/fast.x>
#include <gnustep/base/Unicode.h>


@implementation NSGString

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
    return YES;
  if (anObject == nil)
    return NO;
  c = fastClassOfInstance(anObject);
  if (c == _fastCls._NSGString || c == _fastCls._NSGMutableString ||
      c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString ||
      c == _fastCls._NXConstantString)
    {
      NSGString	*other = (NSGString*)anObject;

      if (_hash == 0)
        _hash = _fastImp._NSString_hash(self, @selector(hash));
      if (other->_hash == 0)
        other->_hash = _fastImp._NSString_hash(other, @selector(hash));
      if (_hash != other->_hash)
	return NO;
      return _fastImp._NSString_isEqualToString_(self,
		@selector(isEqualToString:), other);
    }
  else if (c == nil)
    return NO;
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    return _fastImp._NSString_isEqualToString_(self,
		@selector(isEqualToString:), anObject);
  else
    return NO;
}

// Initializing Newly Allocated Strings

/* This is the GNUstep designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone
{
    self = [super init];
    if (self) {
	_count = length;
	_contents_chars = chars;
	_zone = chars ? zone : 0;
    }
    return self;
}

/* This is the OpenStep designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
    self = [super init];
    if (self) {
	_count = length;
	_contents_chars = chars;
	if (flag) {
	    _zone = NSZoneFromPointer(chars);
	}
	else {
	    _zone = 0;
	}
    }
    return self;
}

- (id) initWithCharacters: (const unichar*)chars
		   length: (unsigned int)length
{
    NSZone	*z = fastZone(self);
    unichar	*s = NSZoneMalloc(z, length*sizeof(unichar));

    if (chars)
	memcpy(s, chars, sizeof(unichar)*length);
    return [self initWithCharactersNoCopy:s length:length fromZone:z];
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  id a = [[NSGCString allocWithZone: zone]
	initWithCStringNoCopy: byteString length: length fromZone: zone];
  [self release];
  return a;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  id a = [[NSGCString allocWithZone: fastZone(self)]
	initWithCStringNoCopy: byteString length: length freeWhenDone: flag];
  [self release];
  return a;
}

- (id) init
{
  return [self initWithCharactersNoCopy:0 length:0 fromZone: fastZone(self)];
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
  if (aRange.location >= _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  memcpy(buffer, _contents_chars + aRange.location, aRange.length*2);
}

// Dividing Strings into Substrings

- (NSString*) substringFromRange: (NSRange)aRange
{
  if (aRange.location > _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  return [[self class] stringWithCharacters: _contents_chars + aRange.location
		       length: aRange.length];
}

// Getting C Strings

- (const char *) cString
{
  char *r;

  OBJC_MALLOC(r, char, _count+1);
  if (_count > 0)
    ustrtostr(r,_contents_chars, _count);
  r[_count] = '\0';
  [NSData dataWithBytesNoCopy: r length: _count+1];
  return r;
}

// xxx fix me
- (unsigned int) cStringLength
{
  return _count;
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
  int count=0;
  int blen=0;
  while(count < [self length])
    if(!uni_isnonsp([self characterAtIndex: count++]))
      blen++;
  return blen;
} 

/* NSCoding Protocol */

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType:@encode(int) at:&_count
 	  withName:@"Concrete String count"];
  [aCoder encodeArrayOfObjCType:@encode(unichar)
 	  count:_count
 	  at:_contents_chars
  	  withName:@"Concrete String content_chars"];
}

- initWithCoder: aCoder
{
    [aCoder decodeValueOfObjCType:@encode(int) at:&_count
					 withName:NULL];
    _zone = fastZone(self);
    _contents_chars = NSZoneMalloc(_zone, sizeof(unichar)*_count);
    [aCoder decodeArrayOfObjCType:@encode(unichar)
          count:_count
 	  at:_contents_chars
 	  withName:NULL];
    return self;
}


// ******* Stuff from NSGCString *********
//    Do we need this ???

- (void) _collectionReleaseContents
{
  return;
}

- (void) _collectionDealloc
{
  if (_zone)
    {
      NSZoneFree(_zone, _contents_chars);
      _zone = 0;
    }
}

- (Class) classForPortCoder
{
  return [self class];
}

- replacementObjectForPortCoder:(NSPortCoder*)aCoder
{
    return self;
}


// FOR IndexedCollection SUPPORT;

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return [NSNumber numberWithChar: unitochar(_contents_chars[index])];
}

@end



@implementation NSGMutableString

// @class NSMutableString;

// @protocol NSMutableString <NSString>

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
 #ifndef STABLE_MEMCPY
  {
    int i;
    for (i = self->_count; i >= index; i--)
      self->_contents_chars[i+size] = self->_contents_chars[i];
  }
 #else
  memcpy(self->_contents_chars + index, 
	 self->_contents_chars + index + size,
	 2*(self->_count - index));
 #endif /* STABLE_MEMCPY */
  (self->_count) += size;
  (self->_hash) = 0;
}

static inline void
stringDecrementCountAndFillHoleAt(NSGMutableStringStruct *self, 
				  int index, int size)
{
  (self->_count) -= size;
 #ifndef STABLE_MEMCPY
  {
    int i;
    for (i = index; i <= self->_count; i++)
      self->_contents_chars[i] = self->_contents_chars[i+size];
  }
 #else
  memcpy(self->_contents_chars + index + size,
	 self->_contents_chars + index, 
	 2*(self->_count - index));
 #endif // STABLE_MEMCPY
  (self->_hash) = 0;
}

// Initializing Newly Allocated Strings

- (id) init
{
  return [self initWithCapacity: 0];
}

/* This is the GNUstep designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone
{
    self = [super init];
    if (self) {
	_count = length;
	_capacity = length;
	_contents_chars = chars;
	_zone = zone;
    }
    return self;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
    self = [super init];
    if (self) {
	_count = length;
	_capacity = length;
	_contents_chars = chars;
	if (flag) {
	    _zone = NSZoneFromPointer(chars);
	}
	else {
	    _zone = 0;
	}
    }
    return self;
}

- initWithCapacity: (unsigned)capacity
{
    self = [super init];
    if (self) {
	if (capacity < 2)
	    capacity = 2;
	_count = 0;
	_capacity = capacity;
	_zone = fastZone(self);
	_contents_chars = NSZoneMalloc(_zone, sizeof(unichar)*capacity);
    }
    return self;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  id a = [[NSGMutableCString allocWithZone: zone]
	initWithCStringNoCopy: byteString length: length fromZone: zone];
  [self release];
  return a;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  id a = [[NSGMutableCString allocWithZone: fastZone(self)]
	initWithCStringNoCopy: byteString length: length freeWhenDone: flag];
  [self release];
  return a;
}

// Modify A String

- (void) deleteCharactersInRange: (NSRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, 
				    range.location, range.length);
}

- (void) replaceCharactersInRange: (NSRange)aRange
   withString: (NSString*)aString
{
  int offset;
  unsigned stringLength;

  if (aRange.location > _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];

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

/* For IndexedCollecting Protocol and other GNU libobjects conformity. */

/* xxx This should be made to return void, but we need to change
   IndexedCollecting and its conformers */
- (void) removeRange: (IndexRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, 
				    range.location, range.length);
}

- (void) encodeWithCoder: aCoder    //  *** changed to unichar
{
  [aCoder encodeValueOfObjCType:@encode(unsigned) at:&_capacity
	  withName:@"String capacity"];
  [aCoder encodeValueOfObjCType:@encode(int) at:&_count
	  withName:@"Concrete String count"];
  [aCoder encodeArrayOfObjCType:@encode(unichar)
	  count:_count
	  at:_contents_chars
	  withName:@"Concrete String content_chars"];
}

- initWithCoder: aCoder    //  *** changed to unichar
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType:@encode(unsigned) at:&cap withName:NULL];
  [self initWithCapacity:cap];
  [aCoder decodeValueOfObjCType:@encode(int) at:&_count
	  withName:NULL];
  [aCoder decodeArrayOfObjCType:@encode(unichar)
          count:_count
	  at:_contents_chars
	  withName:NULL];
  return self;
}

/* For IndexedCollecting protocol */

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return unitochar(_contents_chars[index]);
}



// FOR IndexedCollection and OrderedCollection SUPPORT;

- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  // one for the next char, one for the '\0';
  if (_count >= _capacity)
    {
      _capacity = _count;
      if (_capacity < 2)
	_capacity = 2;
      _contents_chars =
	NSZoneRealloc(_zone, _contents_chars, sizeof(unichar)*_capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableStringStruct*)self, index, 1);
  _contents_chars[index] = [newObject charValue];
}


- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, index, 1);
}

@end
