/* Implementation of composite character sequence class for GNUSTEP
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by:  Stevo Crvenkovski
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


#include <gnustep/base/preface.h>
#include <gnustep/base/Coding.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <limits.h>
#include <string.h>		// for strstr()
#include <sys/stat.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>

#include <gnustep/base/NSGSequence.h>
#include <gnustep/base//Unicode.h>


#define FALSE 0
#define TRUE 1

@implementation NSGSequence

// Creating Temporary Sequences

+ (NSGSequence*) sequenceWithString: (NSString*) aString 
    range: (NSRange)aRange
{
  return [[[self alloc] initWithString: aString range: aRange]
	  autorelease];
}

+ (NSGSequence*) sequenceWithSequence:  (NSGSequence*) aSequence 

{
  return [[[self alloc]
	   initWithSequence: aSequence]
	  autorelease];
}

+ (NSGSequence*) sequenceWithCharacters:  (unichar *) characters
  length: (int) len
{
  return [[[self alloc]
	   initWithCharacters: characters length: len]
	  autorelease];
}

+ (NSGSequence*) sequenceWithCharactersNoCopy:  (unichar *) characters
  length: (int) len freeWhenDone: (BOOL) flag
{
  return [[[self alloc]
	   initWithCharactersNoCopy: characters length: len freeWhenDone:flag]
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
  return [self initWithString:@"" range: NSMakeRange(0,0)];
}

- (id) initWithString: (NSString*)string
    range: (NSRange)aRange
{
  unichar *s;
  if (aRange.location > [string length])
    [NSException raise: NSRangeException format:@"Invalid location."];

  if (aRange.length > ([string length] - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  OBJC_MALLOC(s, unichar, aRange.length+1);
  [string getCharacters:s range: aRange];
  s[aRange.length] = (unichar)0;
  return [self initWithCharactersNoCopy:s length: aRange.length freeWhenDone:YES];
}

- (id) initWithSequence:  (NSGSequence*) aSequence 
{
  unichar *s;
  int len=[aSequence length];
  OBJC_MALLOC(s, unichar, len+1);
  [aSequence getCharacters:s];
  s[len] = (unichar)0;
  return [self initWithCharactersNoCopy:s length:len freeWhenDone:YES];
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
    memcpy(s, chars,2*length);
  s[length] = (unichar)0;
  return [self initWithCharactersNoCopy:s length:length freeWhenDone:YES];
}

// Getting a Length of Sequence

- (unsigned int) length
{
  return _count;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  /* xxx raise NSException instead of assert. */
  assert(index < [self length]);
  return _contents_chars[index];
}

- (unichar) baseCharacter
{
  if(![self isNormalized])
    [self normalize];
  return _contents_chars[0];
}

- (unichar) precomposedCharacter
{
  [self notImplemented:_cmd];
  return _contents_chars[0];
}

/* Inefficient. */
- (void) getCharacters: (unichar*)buffer
{
  [self getCharacters:buffer range:((NSRange){0,[self length]})];
  return;
}

/* Inefficient. */
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange
{
  int i;
  for (i = 0; i < aRange.length; i++)
    {
      buffer[i] = [self characterAtIndex: aRange.location+i];
    }
}

//for debuging
- (NSString*) description
{
  unichar * point;
  point=_contents_chars;
  while(*point)
    printf("%X ",*point++);
  printf("\n");
  return @"";
}

- (NSGSequence*) decompose
{
  #define MAXDEC 18

  unichar *source;
  unichar *target;
  unichar *spoint;
  unichar *tpoint;
  unichar *dpoint;
  BOOL notdone;
  int len;

  if (_count)
    {
    OBJC_MALLOC(source, unichar, _count*MAXDEC+1);
    OBJC_MALLOC(target, unichar, _count*MAXDEC+1);
    spoint = source;
    tpoint = target;
    memcpy(source, _contents_chars, 2*_count);
    source[_count]=(unichar)(0);
    do
    {
      notdone=FALSE;
      do
      {
        if(!(dpoint=uni_is_decomp(*spoint)))
          *tpoint++ = *spoint;
        else
        {
          while(*dpoint)
            *tpoint++=*dpoint++;
          notdone=TRUE;
        }
      } while(*spoint++);

      *tpoint=(unichar)0;  // *** maybe not needed

      memcpy(source, target,2*(_count*MAXDEC+1));

      tpoint = target;
      spoint = source;

    } while(notdone);
    len = uslen(source);
    OBJC_REALLOC(_contents_chars, unichar, len+1);
    memcpy(_contents_chars,source,2*(len+1));
    _contents_chars[len] = (unichar)0;
    _count = len;
    OBJC_FREE(target);
    OBJC_FREE(source);
    return self;
  }
 else
 {
   return self;
 }
 return self;
}

- (NSGSequence*) order
{
  unichar  *first,*second,tmp;
  int  count,len;
  BOOL notdone;

  do
  {
    notdone=NO;
    first=_contents_chars;
    second=first+1;
    len=[self length];
    for(count=1;count<len;count++)
    {
      if(uni_cop(*second))
      {
         if(uni_cop(*first)>uni_cop(*second))
         {
            tmp= *first;
            *first= *second;
            *second=tmp;
            notdone=YES;
         }
         if(uni_cop(*first)==uni_cop(*second))
           if(*first>*second)
           {
              tmp= *first;
              *first= *second;
              *second=tmp;
              notdone=YES;
           }
      }
      first++;
      second++;
    }
  } while(notdone);
  return self;
}

- (NSGSequence*) normalize
{
  if(![self isNormalized])
  {
    [[self decompose] order];
    _normalized=YES;
  }
  return self;
}

- (BOOL) isEqual: (NSGSequence*) aSequence
{
  return [self compare:aSequence]==NSOrderedSame;
}

- (BOOL) isNormalized
{
  return _normalized;
}

- (BOOL) isComposite
{
  if(uni_is_decomp(_contents_chars[0]))
    return YES;
  else
    if([self length]<2)
      return NO;
    else
      return YES;
}

- (NSGSequence*) maxComposed
{
  [self notImplemented:_cmd];
  return self;
}

- (NSGSequence*) lowercase
{
  unichar *s;
  int count;
  int len=[self length];
  OBJC_MALLOC(s, unichar,len +1);
  for(count=0;count<len;count++)
    s[count]=uni_tolower(_contents_chars[count]);
  s[len] = (unichar)0;
  return [NSGSequence sequenceWithCharactersNoCopy:s length:len freeWhenDone:YES];
}

- (NSGSequence*) uppercase
{
  unichar *s;
  int count;
  int len=[self length];
  OBJC_MALLOC(s, unichar,len +1);
  for(count=0;count<len;count++)
    s[count]=uni_toupper(_contents_chars[count]);
  s[len] = (unichar)0;
  return [NSGSequence sequenceWithCharactersNoCopy:s length:len freeWhenDone:YES];
}

- (NSGSequence*) titlecase
{
  [self notImplemented:_cmd];
  return self;
}

/* Inefficient */
- (NSComparisonResult) compare:  (NSGSequence*) aSequence
{
  int i,end;
  unsigned int myLength;
  unsigned int seqLength;
 
  if(![self isNormalized])
    [self normalize];
  if(![aSequence isNormalized])
    [aSequence normalize];
  myLength = [self length];
  seqLength = [aSequence length];
  if(myLength < seqLength)
    end=myLength;
  else
    end=seqLength;
  for (i = 0; i < end; i ++)
  {
    if ([self characterAtIndex:i] < [aSequence characterAtIndex:i]) return NSOrderedAscending;
    if ([self characterAtIndex:i] > [aSequence characterAtIndex:i]) return NSOrderedDescending;
  }
  if(myLength<seqLength)
    return NSOrderedAscending;
  if(myLength>seqLength)
    return NSOrderedDescending;
  return NSOrderedSame;
}


/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone] initWithSequence:self];
}


// **************** do I need this?
- copy
{
  return [self copyWithZone: NSDefaultMallocZone ()];
}

// **************** do I need this?
- mutableCopyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone]
	  initWithSequence: self];
}

@end
