/* Implementation for GNUStep of NSStrings with Unicode-string backing
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by Stevo Crvenkovski <stevoc@lotus.mpt.com.mk>
   Date: February 1997
   
   Based on NSGCSting and NSString
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

#include <gnustep/base/preface.h>
#include <Foundation/NSString.h>
#include <gnustep/base/NSString.h>
#include <Foundation/NSGString.h>
#include <gnustep/base/NSGString.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/NSGSequence.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

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

// Initializing Newly Allocated Strings

/* This is the designated initializer for this class. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  /* assert(!flag);	xxx need to make a subclass to handle this. */
  _count = length;
  _contents_chars = chars;
  _free_contents = flag;
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  unichar *s;
  OBJC_MALLOC(s, unichar, length+1);
  if (chars)
    memcpy(s, chars,2*length);
  s[length] = (unichar)0;
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

// Getting a String's Length

- (unsigned int) length
{
  return  _count;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  /* xxx This should raise an NSException. */
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_chars[index];
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
  ustrtostr(r,_contents_chars, _count);
  r[_count] = '\0';
  [[[MallocAddress alloc] initWithAddress:r] autorelease];
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
  [[[MallocAddress alloc] initWithAddress:r] autorelease];
  return r;
}
// #endif /* NO_GNUSTEP */

/* NSCoding Protocol */

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder:aCoder];  // *** added this
  [aCoder encodeValueOfObjCType:@encode(int) at:&_count
 	  withName:@"Concrete String count"];
  [aCoder encodeArrayOfObjCType:@encode(unichar)
 	  count:_count
 	  at:_contents_chars
  	  withName:@"Concrete String content_chars"];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  [aCoder decodeValueOfObjCType:@encode(int) at:&_count
  	  withName:NULL];
  OBJC_MALLOC(_contents_chars, unichar, _count+1);
  [aCoder decodeArrayOfObjCType:@encode(unichar)
          count:_count
 	  at:_contents_chars
 	  withName:NULL];
  _contents_chars[_count] = 0;
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
}

// Initializing Newly Allocated Strings

// This is the designated initializer for this class
// xxx Should capacity include the '\0' terminator?
- initWithCapacity: (unsigned)capacity
{
  _count = 0;
  _capacity = MAX(capacity, 2);
  OBJC_MALLOC(_contents_chars, unichar, _capacity);
  _contents_chars[0] = 0;
  _free_contents = YES;
  return self;
}

// Modify A String

- (void) deleteCharactersInRange: (NSRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, 
				    range.location, range.length);
}

//  xxx Check this
- (void) insertString: (NSString*)aString atIndex:(unsigned)index
{
  unsigned c = [aString length];
  unichar * u;
  OBJC_MALLOC(u, unichar, c+1);
  if (_count + c >= _capacity)
    {
      _capacity = MAX(_capacity*2, _count+2*c);
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableStringStruct*)self, index, c);
    [aString getCharacters:u];
  memcpy(_contents_chars + index,u, 2*c);
  OBJC_FREE(u);
  _contents_chars[_count] = 0;
}


- (void) setString: (NSString*)aString
{
  int len = [aString length];
  if (_capacity < len+1)
    {
      _capacity = len+1;
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
    }
  [aString getCharacters: _contents_chars];
  _contents_chars[len] = 0;
  _count = len;
}

// ************ Stuff from NSGCString *********

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  if (_capacity < length+1)
    {
      _capacity = length+1;
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
    }
  strtoustr(_contents_chars, byteString, length);
  _contents_chars[length] = 0;
  _count = length;
}

// xxx This should not be in this class
/* Override NSString's designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self initWithCapacity:length];
  [self setCString:byteString length:length];
  return self;
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
  _contents_chars[_count] = 0;
  _capacity = cap;
  _free_contents = YES;
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
  if (_count+1 >= _capacity)
    {
      _capacity *= 2;
      OBJC_REALLOC(_contents_chars, unichar, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableStringStruct*)self, index, 1);
  _contents_chars[index] = [newObject charValue];
  _contents_chars[_count] = 0;
}


- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableStringStruct*)self, index, 1);
  _contents_chars[_count] = 0;
}

@end
