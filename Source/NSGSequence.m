/* Implementation of composite character sequence class for GNUSTEP
   Copyright (C) 1997 Free Software Foundation, Inc.
  
   Written by:  Stevo Crvenkovski <stevo@btinternet.com>
   Date: March 1997
  
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
#include <base/preface.h>
#include <base/Coding.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <base/IndexedCollection.h>
#include <base/IndexedCollectionPrivate.h>
#include <limits.h>
#include <string.h>		// for strstr()
#include <sys/stat.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>

#include <base/NSGSequence.h>
#include <base//Unicode.h>

#define MAXDEC 18

static inline void gs_seq_decompose(unichar **buffer, unsigned *length)
{
  unichar	*spoint;
  unichar	*tpoint;
  unichar	*dpoint;
  unsigned	count = *length;

  if (count)
    {
      unichar	source[count*MAXDEC+1];
      unichar	target[count*MAXDEC+1];
      unichar	*chars = *buffer;
      BOOL	notdone = YES;

      spoint = source;
      tpoint = target;
      memcpy(source, chars, 2*count);
      source[count] = (unichar)(0);

      while (notdone)
	{
	  notdone = NO;
	  do
	    {
	      if (!(dpoint = uni_is_decomp(*spoint)))
		*tpoint++ = *spoint;
	      else
		{
		  while (*dpoint)
		    *tpoint++ = *dpoint++;
		  notdone = YES;
		}
	    }
	  while (*spoint++);

	  *tpoint = (unichar)0;  // *** maybe not needed

	  memcpy(source, target, 2*(count*MAXDEC+1));

	  tpoint = target;
	  spoint = source;
	}

      count = uslen(source);
      OBJC_REALLOC(chars, unichar, count+1);
      memcpy(chars, source, 2*(count+1));
      chars[count] = (unichar)0;
      *buffer = chars;
      *length = count;
    }
}
 
static inline void gs_seq_order(unichar *chars, unsigned len)
{
  if (len > 1)
    {
      BOOL	notdone = YES;

      while (notdone)
	{
	  unichar	*first = chars;
	  unichar	*second = first + 1;
	  unsigned	count;

	  notdone = NO;
	  for (count = 1; count < len; count++)
	    {
	      if (uni_cop(*second))
		{
		  if (uni_cop(*first) > uni_cop(*second))
		    {
		      unichar	tmp = *first;

		      *first = *second;
		      *second = tmp;
		      notdone = YES;
		    }
		  else if (uni_cop(*first) == uni_cop(*second))
		    {
		      if (*first > *second)
			{
			   unichar	tmp = *first;

			   *first = *second;
			   *second = tmp;
			   notdone = YES;
			}
		    }
		}
	      first++;
	      second++;
	    }
	}
    }
}


@implementation NSGSequence

static	Class	seqClass;

+ (void) initialize
{
  if (self == [NSGSequence class])
    {
      seqClass = self;
    }
}

// Creating Temporary Sequences

+ (NSGSequence*) sequenceWithString: (NSString*) aString
    range: (NSRange)aRange
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithString: aString range: aRange] autorelease];
}

+ (NSGSequence*) sequenceWithSequence:  (NSGSequence*) aSequence

{
  return [[[self allocWithZone: NSDefaultMallocZone()]
   initWithSequence: aSequence] autorelease];
}

+ (NSGSequence*) sequenceWithCharacters:  (unichar *) characters
  length: (int) len
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithCharacters: characters length: len] autorelease];
}

+ (NSGSequence*) sequenceWithCharactersNoCopy:  (unichar *) characters
  length: (int) len freeWhenDone: (BOOL) flag
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithCharactersNoCopy: characters length: len freeWhenDone: flag]
	  autorelease];
}

- (void)dealloc
{
  if (_free_contents)
    {
      OBJC_FREE(_contents_chars);
      _free_contents = NO;
    }
  [super dealloc];
}

// Initializing Newly Allocated Sequences

// xxx take care of _normalize in all init* methods
- (id) init
{
  return [self initWithString: @"" range: NSMakeRange(0, 0)];
}

- (id) initWithString: (NSString*)string
    range: (NSRange)aRange
{
  unichar *s;
  if (aRange.location > [string length])
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > ([string length] - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];

  OBJC_MALLOC(s, unichar, aRange.length+1);
  [string getCharacters: s range: aRange];
  s[aRange.length] = (unichar)0;
  return [self initWithCharactersNoCopy: s
				 length: aRange.length
			   freeWhenDone: YES];
}

- (id) initWithSequence:  (NSGSequence*) aSequence
{
  unichar	*s;
  unsigned	len = aSequence->_count;

  OBJC_MALLOC(s, unichar, len+1);
  memcpy(s, aSequence->_contents_chars, len);
  s[len] = (unichar)0;
  return [self initWithCharactersNoCopy: s length: len freeWhenDone: YES];
}

- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  if (_free_contents && _contents_chars)
    {
      OBJC_FREE(_contents_chars);
    }

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
    memcpy(s, chars, 2*length);
  s[length] = (unichar)0;
  return [self initWithCharactersNoCopy: s length: length freeWhenDone: YES];
}

// Getting a Length of Sequence

- (unsigned int) length
{
  return _count;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  if (index >= _count)
    [NSException raise: NSRangeException
		format: @"index greater than sequence length"];
  return _contents_chars[index];
}

- (unichar) baseCharacter
{
  if (!_normalized)
    [self normalize];
  return _contents_chars[0];
}

- (unichar) precomposedCharacter
{
  [self notImplemented: _cmd];
  return _contents_chars[0];
}

- (void) getCharacters: (unichar*)buffer
{
  memcpy(buffer, _contents_chars, _count*2);
}

/* Inefficient. */
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange
{
  memcpy(buffer, &_contents_chars[aRange.location], aRange.length*2);
}

//for debuging
- (NSString*) description
{
  unichar * point;
  point = _contents_chars;
  while(*point)
    printf("%X ", *point++);
  printf("\n");
  return @"";
}

- (NSGSequence*) decompose
{
  gs_seq_decompose(&_contents_chars, &_count);
  return self;
}

- (NSGSequence*) order
{
  gs_seq_order(_contents_chars, _count);
  return self;
}

- (NSGSequence*) normalize
{
  if (!_normalized)
    {
      gs_seq_decompose(&_contents_chars, &_count);
      gs_seq_order(_contents_chars, _count);
      _normalized = YES;
    }
  return self;
}

- (BOOL) isEqual: (NSGSequence*) aSequence
{
  return [self compare: aSequence] == NSOrderedSame;
}

- (BOOL) isNormalized
{
  return _normalized;
}

- (BOOL) isComposite
{
  if (uni_is_decomp(_contents_chars[0]))
    return YES;
  else
    if (_count < 2)
      return NO;
    else
      return YES;
}

- (NSGSequence*) maxComposed
{
  [self notImplemented: _cmd];
  return self;
}

- (NSGSequence*) lowercase
{
  unichar	*s;
  unsigned	count;
  unsigned	len = _count;

  OBJC_MALLOC(s, unichar, len + 1);
  for (count =0; count < len; count++)
    s[count] = uni_tolower(_contents_chars[count]);
  s[len] = (unichar)0;
  return [seqClass sequenceWithCharactersNoCopy: s
					 length: len
				   freeWhenDone: YES];
}

- (NSGSequence*) uppercase
{
  unichar	*s;
  unsigned	count;
  unsigned	len = _count;

  OBJC_MALLOC(s, unichar, len + 1);
  for (count = 0; count < len; count++)
    s[count] = uni_toupper(_contents_chars[count]);
  s[len] = (unichar)0;
  return [seqClass sequenceWithCharactersNoCopy: s
					 length: len
				   freeWhenDone: YES];
}

- (NSGSequence*) titlecase
{
  [self notImplemented: _cmd];
  return self;
}

- (NSComparisonResult) compare:  (NSGSequence*) aSequence
{
  unsigned	i;
  unsigned	end;
  unsigned	myLength;
  unsigned	seqLength;

  if (!_normalized)
    {
      gs_seq_decompose(&_contents_chars, &_count);
      gs_seq_order(_contents_chars, _count);
      _normalized = YES;
    }
  if (!aSequence->_normalized)
    {
      gs_seq_decompose(&aSequence->_contents_chars, &aSequence->_count);
      gs_seq_order(aSequence->_contents_chars, aSequence->_count);
      _normalized = YES;
    }
  myLength = _count;
  seqLength = aSequence->_count;
  if (myLength < seqLength)
    end = myLength;
  else
    end = seqLength;
  for (i = 0; i < end; i ++)
    {
      if (_contents_chars[i] < aSequence->_contents_chars[i])
	return NSOrderedAscending;
      if (_contents_chars[i] > aSequence->_contents_chars[i])
	return NSOrderedDescending;
    }
  if (myLength < seqLength)
    return NSOrderedAscending;
  if (myLength > seqLength)
    return NSOrderedDescending;
  return NSOrderedSame;
}


/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone: zone] initWithSequence: self];
}


// **************** do I need this?
- mutableCopyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone: zone]
	  initWithSequence: self];
}

@end
