/* Implementation for GNUStep of NSStrings with Unicode-string backing
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997
   
   Based on NSGCString and NSString
   Written by:  Andrew Kachites McCallum
   <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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
  if (_free_contents)
    {
      OBJC_FREE(_contents_chars);
      _free_contents = NO;
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

/* This is the designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  /* assert(!flag);	xxx need to make a subclass to handle this. */
  [super init];
  _count = length;
  _contents_chars = chars;
  _free_contents = flag;
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  unichar *s;
  OBJC_MALLOC(s, unichar, length);
  if (chars)
    memcpy(s, chars,2*length);
  return [self initWithCharactersNoCopy:s length:length freeWhenDone:YES];
}

- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  id a = [[NSGCString alloc] initWithCStringNoCopy: byteString
   length: length
   freeWhenDone: flag];
  [self release];
  return a;
}

- (id) init
{
  return [self initWithCharactersNoCopy:0 length:0 freeWhenDone: NO];
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

// #ifndef NO_GNUSTEP

// xxx This is Not NoCopy
// copy of cString just for compatibility
// Is this realy needed ???
- (const char *) cStringNoCopy
{
  char *r;

  OBJC_MALLOC(r, char, _count+1);
  ustrtostr(r,_contents_chars, _count);
  r[_count] = '\0';
  [NSData dataWithBytesNoCopy: r length: _count+1];
  return r;
}
// #endif /* NO_GNUSTEP */

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
  OBJC_MALLOC(_contents_chars, unichar, _count+1);
  [aCoder decodeArrayOfObjCType:@encode(unichar)
          count:_count
 	  at:_contents_chars
 	  withName:NULL];
  _free_contents = YES;
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
  if (_free_contents)
      OBJC_FREE(_contents_chars);
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
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

// This is the designated initializer for this class
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  [super init];
  _count = length;
  _capacity = length;
  _contents_chars = chars;
  _free_contents = flag;
  return self;
}

// NB capacity does not include the '\0' terminator.
- initWithCapacity: (unsigned)capacity
{
  unichar *tmp;
  if (capacity < 2)
    capacity = 2;
  OBJC_MALLOC(tmp, unichar, capacity);
  [self initWithCharactersNoCopy: tmp length: 0 freeWhenDone: YES];
  _capacity = capacity;
  return self;
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
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
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
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
    }
  [aString getCharacters: _contents_chars];
  _count = len;
  _hash = 0;
}

// ************ Stuff from NSGCString *********

/* Override NSString's designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  id a = [[NSGMutableCString alloc] initWithCStringNoCopy: byteString
   length: length
   freeWhenDone: flag];
  [self release];
  return a;
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
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
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
