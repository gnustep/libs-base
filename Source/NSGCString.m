/* Implementation for GNUStep of NSStrings with C-string backing
   Copyright (C) 1993,1994, 1996, 1997 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
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
#include <gnustep/base/NSString.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/behavior.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

#include <gnustep/base//Unicode.h>

static Class	immutableClass;
static Class	mutableClass;

@implementation NSGCString

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      immutableClass = [NSGCString class];
      mutableClass = [NSGMutableCString class];
    }
}

- (void)dealloc
{
  if (_free_contents)
    OBJC_FREE(_contents_chars);
  [super dealloc];
}

- (unsigned) hash
{
  if (_hash == 0)
    if ((_hash = [super hash]) == 0)
      _hash = 0xffffffff;
  return _hash;
}

/* This is the designated initializer for this class. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  /* assert(!flag); xxx need to make a subclass to handle this. */
  [super init];
  _count = length;
  _contents_chars = byteString;
  _free_contents = flag;
  return self;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  id a = [[NSGString alloc] initWithCharactersNoCopy: chars
   length: length
   freeWhenDone: flag];
  [self release];
  return a;
}

- (id) init
{
  return [self initWithCString:""];
}

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

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType:@encode(char*) at:&_contents_chars 
	  withName:@"Concrete String content_chars"];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  [aCoder decodeValueOfObjCType:@encode(char*) at:&_contents_chars
	  withName:NULL];
  _count = strlen(_contents_chars);
  _free_contents = YES;
  return self;
}

- (const char *) cString
{
  char *r;

  OBJC_MALLOC(r, char, _count+1);
  memcpy(r, _contents_chars, _count);
  r[_count] = '\0';
  [[[MallocAddress alloc] initWithAddress:r] autorelease];
  return r;
}

- (const char *) cStringNoCopy
{
  return _contents_chars;
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

  if (aRange.location >= _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
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
  int i;

  for (i = 0; i < _count; i++)
    buffer[i] = chartouni(((unsigned char *)_contents_chars)[i]);
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  int e, i;

  if (aRange.location >= _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  e = aRange.location + aRange.length;
  for (i = aRange.location; i < e; i++)
    *buffer++ = chartouni(((unsigned char *)_contents_chars)[i]);
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  if (aRange.location > _count)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (_count - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  return [[self class] stringWithCString: _contents_chars + aRange.location
		       length: aRange.length];
}

- (NSStringEncoding) fastestEncoding
{
  if(([NSString defaultCStringEncoding]==NSASCIIStringEncoding)  || ([NSString defaultCStringEncoding]==NSISOLatin1StringEncoding))
    return [NSString defaultCStringEncoding];
  else
    return NSUnicodeStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return [NSString defaultCStringEncoding];
}

- (BOOL) isEqualToString: (NSString*)aString
{
  Class	c = [aString class];
  if (c == immutableClass || c == mutableClass)
    {
      NSGCString	*other = (NSGCString*)aString;

      if (_count != other->_count)
	return NO;
      if (_hash && other->_hash && (_hash != other->_hash))
	return NO;
      if (memcmp(_contents_chars, other->_contents_chars, _count) != 0)
	return NO;
      return YES;
    }
  else
    return [super isEqualToString: aString];
  return YES;
}


// FOR IndexedCollection SUPPORT;

- objectAtIndex: (unsigned)index
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
  return [self initWithCString:[string cStringNoCopy]];
}

@end


@implementation NSGMutableCString

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
stringIncrementCountAndMakeHoleAt(NSGMutableCStringStruct *self, 
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
	 self->_count - index);
#endif /* STABLE_MEMCPY */
  (self->_count) += size;
  (self->_hash) = 0;
}

static inline void
stringDecrementCountAndFillHoleAt(NSGMutableCStringStruct *self, 
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
	 self->_count - index);
#endif /* STABLE_MEMCPY */
  (self->_hash) = 0;
}

/* This is the designated initializer for this class */
/* NB. capacity does not include the '\0' terminator */
- initWithCapacity: (unsigned)capacity
{
  [super init];
  _count = 0;
  _capacity = MAX(capacity, 3);
  OBJC_MALLOC(_contents_chars, char, _capacity+1);
  _contents_chars[0] = '\0';
  _free_contents = YES;
  return self;
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
  [self deleteCharactersInRange:range];
  [self insertString:aString atIndex:range.location];
}

- (void) insertString: (NSString*)aString atIndex:(unsigned)index
{
  unsigned c = [aString cStringLength];
  if (_count + c > _capacity)
    {
      _capacity = MAX(_capacity*2, _count+c);
      OBJC_REALLOC(_contents_chars, char, _capacity+1);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableCStringStruct*)self, index, c);
  memcpy(_contents_chars + index, [aString cStringNoCopy], c);
  _contents_chars[_count] = '\0';
}

- (void) appendString: (NSString*)aString
{
  unsigned c = [aString cStringLength];
  if (_count + c > _capacity)
    {
      _capacity = MAX(_capacity*2, _count+c);
      OBJC_REALLOC(_contents_chars, char, _capacity+1);
    }
  memcpy(_contents_chars + _count, [aString cStringNoCopy], c);
  _count += c;
  _contents_chars[_count] = '\0';
  _hash = 0;
}

- (void) setString: (NSString*)aString
{
  const char *s = [aString cStringNoCopy];
  unsigned length = strlen(s);
  if (_capacity < length)
    {
      _capacity = length;
      OBJC_REALLOC(_contents_chars, char, _capacity+1);
    }
  memcpy(_contents_chars, s, length);
  _contents_chars[length] = '\0';
  _count = length;
  _hash = 0;
}

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  if (_capacity < length)
    {
      _capacity = length;
      OBJC_REALLOC(_contents_chars, char, _capacity+1);
    }
  memcpy(_contents_chars, byteString, length);
  _contents_chars[length] = '\0';
  _count = length;
  _hash = 0;
}

/* Override NSString's designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [super init];
  _count = length;
  _capacity = length;
  _contents_chars = byteString;
  _free_contents = flag;
  return self;
}

/* Override NSString's designated initializer for Unicode Strings. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  id a = [[NSGMutableString alloc] initWithCharactersNoCopy: chars
   length: length
   freeWhenDone: flag];
  [self release];
  return a;
}

- (id) init
{
  return [self initWithCString:""];
};

/* For IndexedCollecting Protocol and other GNU libobjects conformity. */

/* xxx This should be made to return void, but we need to change
   IndexedCollecting and its conformers */
- (void) removeRange: (IndexRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, 
				    range.location, range.length);
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType:@encode(unsigned) at:&_capacity
	  withName:@"String capacity"];
  [aCoder encodeValueOfObjCType:@encode(char*) at:&_contents_chars 
	  withName:@"String content_chars"];
}

- initWithCoder: aCoder
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType:@encode(unsigned) at:&cap withName:NULL];
  [self initWithCapacity:cap];
  [aCoder decodeValueOfObjCType:@encode(char*) at:&_contents_chars
	  withName:NULL];
  _count = strlen(_contents_chars);
  _capacity = cap;
  _free_contents = YES;
  return self;
}

/* For IndexedCollecting protocol */

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_chars[index];
}


// FOR IndexedCollection and OrderedCollection SUPPORT;

- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  // one for the next char, one for the '\0';
  if (_count >= _capacity)
    {
      _capacity *= 2;
      OBJC_REALLOC(_contents_chars, char, _capacity+1);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableCStringStruct*)self, index, 1);
  _contents_chars[index] = [newObject charValue];
  _contents_chars[_count] = '\0';
}

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, index, 1);
  _contents_chars[_count] = '\0';
}

@end
