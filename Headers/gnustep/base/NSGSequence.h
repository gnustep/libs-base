/* Interface to implementation of composite character sequence
   class for GNUSTEP
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by:  Stevo Crvenkovski
   Date: Marth 1997
   
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

#ifndef __NSGSequence_h_GNUSTEP_BASE_INCLUDE
#define __NSGSequence_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRange.h>



@class NSArray;
@class NSCharacterSet;
@class NSData;
@class NSDictionary;
@class NSString;
@class NSGSequence;

@protocol NSGSequence  <NSCopying>

// Creating Temporary Sequences
+ (NSGSequence*) sequenceWithString: (NSString*) aString 
    range: (NSRange)aRange;
+ (NSGSequence*) sequenceWithSequence:  (NSGSequence*) aSequence ;
+ (NSGSequence*) sequenceWithCharacters: (unichar *) characters
    length: (int) len;

// Initializing Newly Allocated Sequences
- (id) init;
- (id) initWithString: (NSString*)string
    range: (NSRange)aRange;
- (id) initWithSequence:  (NSGSequence*) aSequence;
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag;
- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length;

// Getting a Length of Sequence
- (unsigned int) length;

// Accessing Characters
- (unichar) characterAtIndex: (unsigned int)index;
- (unichar) baseCharacter;
- (unichar) precomposedCharacter;
- (void) getCharacters: (unichar*)buffer;
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange;
- (NSString*) description;
- (NSGSequence*) decompose;
- (NSGSequence*) order;
- (NSGSequence*) normalize;
- (BOOL) isEqual: (NSGSequence*) aSequence;
- (BOOL) isNormalized;
- (BOOL) isComposite;
- (NSGSequence*) maxComposed;
- (NSGSequence*) lowercase;
- (NSGSequence*) uppercase;
- (NSGSequence*) titlecase;
- (NSComparisonResult) compare:  (NSGSequence*) aSequence;

@end

@interface NSGSequence : NSObject <NSGSequence>
{
  unichar * _contents_chars;
  int _count;
  BOOL _normalized;
  BOOL _free_contents;
}
@end

#endif /* __NSGSequence_h_GNUSTEP_BASE_INCLUDE */
