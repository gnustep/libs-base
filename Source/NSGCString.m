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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <gnustep/base/NSGString.h>
#include <gnustep/base/NSGCString.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/behavior.h>

#include <gnustep/base/Unicode.h>
#include <gnustep/base/fast.x>

static	SEL	csInitSel = @selector(initWithCStringNoCopy:length:fromZone:);
static	SEL	msInitSel = @selector(initWithCapacity:);
static	IMP	csInitImp;	/* designated initialiser for cString	*/
static	IMP	msInitImp;	/* designated initialiser for mutable	*/

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
      NSZoneFree(_zone, (void*)_contents_chars);
      _zone = 0;
    }
  [super dealloc];
}

- (unsigned) hash
{
  if (_hash == 0)
    {
      _hash = _fastImp._NSString_hash(self, @selector(hash));
    }
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
  _contents_chars = byteString;
  _zone = byteString ? zone : 0;
  return self;
}

/* This is the OpenStep designated initializer for this class. */
- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		freeWhenDone: (BOOL)flag
{
  NSZone	*z;

  if (flag)
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
  [self release];
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
  [self release];
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

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType:@encode(unsigned) at:&_count];
  if (_count > 0)
    {
      [aCoder encodeArrayOfObjCType:@encode(unsigned char)
			      count:_count
				 at:_contents_chars];
    }
}

- initWithCoder: aCoder
{
  [aCoder decodeValueOfObjCType:@encode(unsigned)
			     at:&_count];
  if (_count > 0)
    {
      _zone = fastZone(self);
      _contents_chars = NSZoneMalloc(_zone, _count);
      [aCoder decodeArrayOfObjCType:@encode(unsigned char)
			      count:_count
				 at:_contents_chars];
    }
  return self;
}

- copy
{
  NSZone	*z = NSDefaultMallocZone();

  if (NSShouldRetainWithZone(self, z) == NO)
    {
      NSGCString	*obj;
      char		*tmp;

      obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
      tmp = NSZoneMalloc(z, _count);
      memcpy(tmp, _contents_chars, _count);
      obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
      if (_hash && obj)
        {
	  obj->_hash = _hash;
	}
      return obj;
    }
  else 
    {
      return [self retain];
    }
}

- copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) == NO)
    {
      NSGCString	*obj;
      char		*tmp;

      obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
      tmp = NSZoneMalloc(z, _count);
      memcpy(tmp, _contents_chars, _count);
      obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
      if (_hash && obj)
        {
	  obj->_hash = _hash;
	}
      return obj;
    }
  else 
    {
      return [self retain];
    }
}

- mutableCopy
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

- mutableCopyWithZone: (NSZone*)z
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
  char *r = (char*)_fastMallocBuffer(_count+1);

  memcpy(r, _contents_chars, _count);
  r[_count] = '\0';
  return r;
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

- (BOOL) isEqual: (id)anObject
{
  Class	c;
  if (anObject == self)
    return YES;
  if (anObject == nil)
    return NO;
  c = fastClassOfInstance(anObject);

  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString || c == _fastCls._NXConstantString)
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
  if (c == _fastCls._NSGCString || c == _fastCls._NSGMutableCString || c == _fastCls._NXConstantString)
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
  else if (c == nil)
    return NO;
  else if (fastClassIsKindOfClass(c, _fastCls._NSString))
    return _fastImp._NSString_isEqualToString_(self,
		@selector(isEqualToString:), aString);
  else
    return NO;
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
    NSZone	*z = fastZone(self);
    unsigned	length = [string cStringLength];
    char	*buf = NSZoneMalloc(z, length+1);  // getCString appends a nul.

    [string getCString: buf];
    return [self initWithCStringNoCopy: buf length: length fromZone: z];
}

- (void) descriptionTo: (id<GNUDescriptionDestination>)output
{
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
	  char	val = _contents_chars[i];

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
		    length += 3;
		  }
		break;
	    }
	}

      if (needQuote || length != _count)
	{
	  NSZone	*z = fastZone(self);
	  char		*buf = NSZoneMalloc(z, length+3);
	  char		*ptr = buf;
	  NSString	*result;

	  *ptr++ = '"';
	  for (i = 0; i < _count; i++)
	    {
	      char	val = _contents_chars[i];

	      switch (val)
		{
		  case '\a':	*ptr++ = '\\'; *ptr++ = 'a';  break;
		  case '\b':	*ptr++ = '\\'; *ptr++ = 'b';  break;
		  case '\t':	*ptr++ = '\\'; *ptr++ = 't';  break;
		  case '\r':	*ptr++ = '\\'; *ptr++ = 'r';  break;
		  case '\n':	*ptr++ = '\\'; *ptr++ = 'n';  break;
		  case '\v':	*ptr++ = '\\'; *ptr++ = 'v';  break;
		  case '\f':	*ptr++ = '\\'; *ptr++ = 'f';  break;
		  case '\\':	*ptr++ = '\\'; *ptr++ = '\\'; break;
		  case '"' :	*ptr++ = '\\'; *ptr++ = '"';  break;

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
	  result = [[_fastCls._NSGCString alloc] initWithCStringNoCopy: buf
			length: length+2 fromZone: z];
	  [output appendString: result];
	  [result release];
	}
      else
	{
	  [output appendString: self];
	}
    }
}
@end


@implementation NSGMutableCString

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject (self, 0, z);
}

+ alloc
{
  return NSAllocateObject (self, 0, NSDefaultMallocZone());
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
- initWithCapacity: (unsigned)capacity
{
  _count = 0;
  _capacity = capacity;
  if (capacity)
    {
      _zone = fastZone(self);
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
      _contents_chars = byteString;
      _zone = byteString ? zone : 0;
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
  [self release];
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
  [self release];
  return a;
}

- copy
{
  char		*tmp;
  NSGCString	*obj;
  NSZone	*z = NSDefaultMallocZone();

  obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
  tmp = NSZoneMalloc(z, _count);
  memcpy(tmp, _contents_chars, _count);
  obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
  if (_hash && obj)
    {
      NSGMutableCString	*tmp = (NSGMutableCString*)obj;	// Same ivar layout

      tmp->_hash = _hash;
    }
  return obj;
}

- copyWithZone: (NSZone*)z
{
  char		*tmp;
  NSGCString	*obj;

  obj = (NSGCString*)NSAllocateObject(_fastCls._NSGCString, 0, z);
  tmp = NSZoneMalloc(z, _count);
  memcpy(tmp, _contents_chars, _count);
  obj = (*csInitImp)(obj, csInitSel, tmp, _count, z);
  if (_hash && obj)
    {
      NSGMutableCString	*tmp = (NSGMutableCString*)obj;	// Same ivar layout

      tmp->_hash = _hash;
    }
  return obj;
}

- mutableCopy
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

- mutableCopyWithZone: (NSZone*)z
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
  char	save;
  if (_count + c >= _capacity)
    {
      _capacity = MAX(_capacity*2, _count+c+1);
      _contents_chars = NSZoneRealloc(_zone, _contents_chars, _capacity);
    }
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
        {
          _capacity = MAX(_capacity*2, _count+l);
          _contents_chars =
		    NSZoneRealloc(fastZone(self), _contents_chars, _capacity);
        }
      memcpy(_contents_chars + _count, other->_contents_chars, l);
      _count += l;
      _hash = 0;
    }
  else
    {
      unsigned l = [aString cStringLength];
      if (_count + l >= _capacity)
        {
          _capacity = MAX(_capacity*2, _count+l+1);
          _contents_chars =
		    NSZoneRealloc(fastZone(self), _contents_chars, _capacity);
        }
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
		NSZoneRealloc(fastZone(self), _contents_chars, _capacity);
    }
  [aString getCString: _contents_chars];
  _count = length;
  _hash = 0;
}

- (id) init
{
  return [self initWithCStringNoCopy: 0 length: 0 fromZone: 0];
}

/* For IndexedCollecting Protocol and other GNU libobjects conformity. */

/* xxx This should be made to return void, but we need to change
   IndexedCollecting and its conformers */
- (void) removeRange: (IndexRange)range
{
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, 
				    range.location, range.length);
}

- initWithCoder: aCoder
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType:@encode(unsigned) at:&cap];
  [self initWithCapacity:cap];
  _count = cap;
  if (_count > 0)
    {
      [aCoder decodeArrayOfObjCType: @encode(unsigned char)
			      count: _count
			         at: _contents_chars];
    }
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
      _contents_chars =
		NSZoneRealloc(fastZone(self), _contents_chars, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSGMutableCStringStruct*)self, index, 1);
  _contents_chars[index] = [newObject charValue];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  stringDecrementCountAndFillHoleAt((NSGMutableCStringStruct*)self, index, 1);
}

@end

@implementation NXConstantString

/*
 *	NXConstantString overrides [-dealloc] so that it is never deallocated.
 *	If we pass an NXConstantString to another process or record it in an
 *	archive and readi it back, the new copy will never be deallocated -
 *	causing a memory leak.  So we tell the system to use the super class.
 */
- (Class)classForArchiver
{
  return [self superclass];
}

- (Class)classForCoder
{
  return [self superclass];
}

- (Class)classForPortCoder
{
  return [self superclass];
}

- (void)dealloc
{
}

- (const char*) cString
{
  return _contents_chars;
}

- retain
{
  return self;
}

- (oneway void) release
{
  return;
}

- autorelease
{
  return self;
}

- copyWithZone: (NSZone*)z
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

@end
