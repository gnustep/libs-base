/* 
   NSAttributedString.m

   Implementation of string class with attributes

   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: November 1997
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: April 1999
   
   This file is part of GNUstep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

/* Warning -	[-initWithString:attributes:] is the designated initialiser,
 *		but it doesn't provide any way to perform the function of the
 *		[-initWithAttributedString:] initialiser.
 *		In order to work round this, the string argument of the
 *		designated initialiser has been overloaded such that it
 *		is expected to accept an NSAttributedString here instead of
 *		a string.  If you create an NSAttributedString subclass, you
 *		must make sure that your implementation of the initialiser
 *		copes with either an NSString or an NSAttributedString.
 *		If it receives an NSAttributedString, it should ignore the
 *		attributes argument and use the values from the string.
 */

#include "config.h"
#include <base/preface.h>
#include <base/fast.x>
#include <base/Unicode.h>

#include <Foundation/NSAttributedString.h>
#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSRange.h>

@class	NSGMutableDictionary;
static Class	dictionaryClass = 0;

static SEL	eqSel;
static SEL	setSel;
static SEL	getSel;
static SEL	allocDictSel;
static SEL	initDictSel;
static SEL	addDictSel;
static SEL	setDictSel;
static SEL	relDictSel;
static SEL	remDictSel;

static IMP	allocDictImp;
static IMP	initDictImp;
static IMP	addDictImp;
static IMP	setDictImp;
static IMP	relDictImp;
static IMP	remDictImp;

@interface GSMutableAttributedStringTracker : NSMutableString
{
  NSMutableAttributedString	*_owner;
}
+ (NSMutableString*) stringWithOwner: (NSMutableAttributedString*)as;
@end


@implementation NSAttributedString

static Class NSAttributedString_abstract_class;
static Class NSAttributedString_concrete_class;
static Class NSMutableAttributedString_abstract_class;
static Class NSMutableAttributedString_concrete_class;

+ (void) initialize
{
  if (self == [NSAttributedString class])
    {
      NSAttributedString_abstract_class = self;
      NSAttributedString_concrete_class = [NSGAttributedString class];
      NSMutableAttributedString_abstract_class
	= [NSMutableAttributedString class];
      NSMutableAttributedString_concrete_class
	= [NSGMutableAttributedString class];
      dictionaryClass = [NSGMutableDictionary class];

      eqSel = @selector(isEqual:);
      setSel = @selector(setAttributes:range:);
      getSel = @selector(attributesAtIndex:effectiveRange:);
      allocDictSel = @selector(allocWithZone:);
      initDictSel = @selector(initWithDictionary:);
      addDictSel = @selector(addEntriesFromDictionary:);
      setDictSel = @selector(setObject:forKey:);
      relDictSel = @selector(release);
      remDictSel = @selector(removeObjectForKey:);

      allocDictImp = [dictionaryClass methodForSelector: allocDictSel];
      initDictImp = [dictionaryClass instanceMethodForSelector: initDictSel];
      addDictImp = [dictionaryClass instanceMethodForSelector: addDictSel];
      setDictImp = [dictionaryClass instanceMethodForSelector: setDictSel];
      remDictImp = [dictionaryClass instanceMethodForSelector: remDictSel];
      relDictImp = [dictionaryClass instanceMethodForSelector: relDictSel];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSAttributedString_abstract_class)
    return NSAllocateObject(NSAttributedString_concrete_class, 0, z);
  else
    return NSAllocateObject(self, 0, z);
}

- (Class) classForCoder
{
  return NSAttributedString_abstract_class;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  NSRange		r = NSMakeRange(0, 0);
  unsigned		index = NSMaxRange(r);
  unsigned		length = [self length];
  NSString		*string = [self string];
  NSDictionary		*attrs;

  [aCoder encodeObject: string];
  while (index < length)
    {
      attrs = [self attributesAtIndex: index effectiveRange: &r];
      index = NSMaxRange(r);
      [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &index];
      [aCoder encodeObject: attrs];
    }
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  NSString	*string = [aDecoder decodeObject];
  unsigned	length = [string length];

  if (length == 0)
    {
      self = [self initWithString: string attributes: nil];
    }
  else
    {
      unsigned		index;
      NSDictionary	*attrs;

      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &index];
      attrs = [aDecoder decodeObject];
      if (index == length)
	{
	  self = [self initWithString: string attributes: attrs];
	}
      else
	{
	  NSRange	r = NSMakeRange(0, index);
	  unsigned	last = index;
	  NSMutableAttributedString	*m;

	  m = [NSMutableAttributedString alloc];
	  m = [m initWithString: string attributes: nil];
	  [m setAttributes: attrs range: r];
	  while (index < length);
	    {
	      [aDecoder decodeValueOfObjCType: @encode(unsigned int)
					   at: &index];
	      attrs = [aDecoder decodeObject];
	      r = NSMakeRange(last, index - last);
	      [m setAttributes: attrs range: r];
	      last = index;
	    }
	  RELEASE(self);
	  self = [m copy];
	  RELEASE(m);
	}
    }
  return self;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

//NSCopying protocol
- (id) copyWithZone: (NSZone*)zone
{
  if ([self isKindOfClass: [NSMutableAttributedString class]]
    || NSShouldRetainWithZone(self, zone) == NO)
    return [[NSAttributedString_concrete_class allocWithZone: zone]
      initWithAttributedString: self];
  else
    return RETAIN(self);
}

//NSMutableCopying protocol
- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[NSMutableAttributedString_concrete_class allocWithZone: zone]
    initWithAttributedString: self];
}

//Creating an NSAttributedString
- (id) init
{
  return [self initWithString: nil attributes: nil];
}

- (id) initWithString: (NSString*)aString
{
  return [self initWithString: aString attributes: nil];
}

- (id) initWithAttributedString: (NSAttributedString*)attributedString
{
  return [self initWithString: (NSString*)attributedString attributes: nil];
}

- (id) initWithString: (NSString*)aString attributes: (NSDictionary*)attributes
{
  //This is the designated initializer
  [self subclassResponsibility: _cmd];/* Primitive method! */
  return nil;
}

- (NSString*) description
{
  NSRange		r = NSMakeRange(0, 0);
  unsigned		index = NSMaxRange(r);
  unsigned		length = [self length];
  NSString		*string = [self string];
  NSDictionary		*attrs;
  NSMutableString	*desc;

  desc = [[NSMutableString alloc] init];
  while (index < length &&
    (attrs = [self attributesAtIndex: index effectiveRange: &r]) != nil)
    {
      index = NSMaxRange(r);
      [desc appendFormat: @"%@%@", [string substringWithRange: r], attrs];
    }
  return desc;
}

//Retrieving character information
- (unsigned int) length
{
  return [[self string] length];
}

- (NSString*) string
{
  [self subclassResponsibility: _cmd];/* Primitive method! */
  return nil;
}

//Retrieving attribute information
- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange
{
  [self subclassResponsibility: _cmd];/* Primitive method! */
  return nil;
}

- (NSDictionary*) attributesAtIndex: (unsigned)index
	      longestEffectiveRange: (NSRange*)aRange
			    inRange: (NSRange)rangeLimit
{
  NSDictionary	*attrDictionary, *tmpDictionary;
  NSRange	tmpRange;
  IMP		getImp;

  if (rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
    {
      [NSException raise: NSRangeException
		  format: @"RangeError in method -attributesAtIndex:longestEffectiveRange:inRange: in class NSAttributedString"];
    }
  getImp = [self methodForSelector: getSel];
  attrDictionary = (*getImp)(self, getSel, index, aRange);
  if (aRange == 0)
    return attrDictionary;
  
  while (aRange->location > rangeLimit.location)
    {
      //Check extend range backwards
      tmpDictionary = (*getImp)(self, getSel, aRange->location-1, &tmpRange);
      if ([tmpDictionary isEqualToDictionary: attrDictionary])
	{
	  aRange->length = NSMaxRange(*aRange) - tmpRange.location;
	  aRange->location = tmpRange.location;
	}
      else
	{
	  break;
	}
    }
  while (NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
    {
      //Check extend range forwards
      tmpDictionary = (*getImp)(self, getSel, NSMaxRange(*aRange), &tmpRange);
      if ([tmpDictionary isEqualToDictionary: attrDictionary])
	{
	  aRange->length = NSMaxRange(tmpRange) - aRange->location;
	}
      else
	{
	  break;
	}
    }
  *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
  return attrDictionary;
}

- (id) attribute: (NSString*)attributeName
	 atIndex: (unsigned)index
  effectiveRange: (NSRange*)aRange
{
  NSDictionary *tmpDictionary;
  id attrValue;

  tmpDictionary = [self attributesAtIndex: index effectiveRange: aRange];

  if (attributeName == nil)
    {
      if (aRange != 0)
	{
	  *aRange = NSMakeRange(0,[self length]);
	  /*
	   * If attributeName is nil, then the attribute will not exist in the
	   * entire text - therefore aRange of the entire text must be correct
	   */
        }
      return nil;
    }
  attrValue = [tmpDictionary objectForKey: attributeName];  
  return attrValue;
}

- (id) attribute: (NSString*)attributeName
	 atIndex: (unsigned int)index
  longestEffectiveRange: (NSRange*)aRange
	 inRange: (NSRange)rangeLimit
{
  NSDictionary	*tmpDictionary;
  id		attrValue;
  id		tmpAttrValue;
  NSRange	tmpRange;
  BOOL		(*eImp)(id,SEL,id);
  IMP		getImp;

  if (rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
    {
      [NSException raise: NSRangeException
		  format: @"RangeError in method -attribute:atIndex:longestEffectiveRange:inRange: in class NSAttributedString"];
    }

  if (attributeName == nil)
    return nil;
  
  attrValue = [self attribute: attributeName
		      atIndex: index
	       effectiveRange: aRange];

  if (aRange == 0)
    return attrValue;

  /*
   * If attrValue == nil then eImp will be zero
   */
  eImp = (BOOL(*)(id,SEL,id))[attrValue methodForSelector: eqSel];
  getImp = [self methodForSelector: getSel];
  
  while (aRange->location > rangeLimit.location)
    {
      //Check extend range backwards
      tmpDictionary = (*getImp)(self, getSel,  aRange->location-1, &tmpRange);
      tmpAttrValue = [tmpDictionary objectForKey: attributeName];
      if (tmpAttrValue == attrValue
	|| (eImp != 0 && (*eImp)(attrValue, eqSel, tmpAttrValue)))
	{
	  aRange->length = NSMaxRange(*aRange) - tmpRange.location;
	  aRange->location = tmpRange.location;
	}
      else
	{
	  break;
	}
    }
  while (NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
    {
      //Check extend range forwards
      tmpDictionary = (*getImp)(self, getSel,  NSMaxRange(*aRange), &tmpRange);
      tmpAttrValue = [tmpDictionary objectForKey: attributeName];
      if (tmpAttrValue == attrValue
	|| (eImp != 0 && (*eImp)(attrValue, eqSel, tmpAttrValue)))
	{
	  aRange->length = NSMaxRange(tmpRange) - aRange->location;
	}
      else
	{
	  break;
	}
    }
  *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
  return attrValue;
}

//Comparing attributed strings
- (BOOL) isEqualToAttributedString: (NSAttributedString*)otherString
{
  NSRange ownEffectiveRange,otherEffectiveRange;
  unsigned int length;
  NSDictionary *ownDictionary,*otherDictionary;
  BOOL result;

  if (!otherString)
    return NO;
  if (![[otherString string] isEqual: [self string]])
    return NO;
  
  length = [otherString length];
  if (length<=0)
    return YES;

  ownDictionary = [self attributesAtIndex: 0
			   effectiveRange: &ownEffectiveRange];
  otherDictionary = [otherString attributesAtIndex: 0
				    effectiveRange: &otherEffectiveRange];
  result = YES;
    
  while (YES)
    {
      if (NSIntersectionRange(ownEffectiveRange, otherEffectiveRange).length > 0
	&& ![ownDictionary isEqualToDictionary: otherDictionary])
	{
	  result = NO;
	  break;
	}
      if (NSMaxRange(ownEffectiveRange) < NSMaxRange(otherEffectiveRange))
	{
	  ownDictionary = [self attributesAtIndex: NSMaxRange(ownEffectiveRange)
				   effectiveRange: &ownEffectiveRange];
	}
      else
	{
	  if (NSMaxRange(otherEffectiveRange) >= length)
	    {
	      break;//End of strings
	    }
	  otherDictionary = [otherString
	    attributesAtIndex: NSMaxRange(otherEffectiveRange)
	    effectiveRange: &otherEffectiveRange];
	}
    }
  return result;
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOfClass: NSAttributedString_abstract_class])
    return [self isEqualToAttributedString: anObject];
  return NO;
}


//Extracting a substring
- (NSAttributedString*) attributedSubstringFromRange: (NSRange)aRange
{
  NSAttributedString	*newAttrString;
  NSString		*newSubstring;
  NSDictionary		*attrs;
  NSRange		range;
  unsigned		len = [self length];

  GS_RANGE_CHECK(aRange, len);
  
  newSubstring = [[self string] substringWithRange: aRange];

  attrs = [self attributesAtIndex: aRange.location effectiveRange: &range];
  range = NSIntersectionRange(range, aRange);
  if (NSEqualRanges(range, aRange) == YES)
    {
      newAttrString = [NSAttributedString_concrete_class alloc];
      newAttrString = [newAttrString initWithString: newSubstring
					 attributes: attrs];
    }
  else
    {
      NSMutableAttributedString	*m;
      NSRange			rangeToSet = range;

      m = [NSMutableAttributedString_concrete_class alloc];
      m = [m initWithString: newSubstring attributes: nil];
      rangeToSet.location = 0;
      [m setAttributes: attrs range: rangeToSet];
      while (NSMaxRange(range) < NSMaxRange(aRange))
	{
	  attrs = [self attributesAtIndex: NSMaxRange(range)
			   effectiveRange: &range];
	  rangeToSet = NSIntersectionRange(range, aRange);
	  rangeToSet.location -= aRange.location;
	  [m setAttributes: attrs range: rangeToSet];
	}
      newAttrString = [m copy];
      RELEASE(m);
    }

  IF_NO_GC(AUTORELEASE(newAttrString));
  return newAttrString;
}

- (NSAttributedString*) attributedSubstringWithRange: (NSRange)aRange
{
  return [self attributedSubstringFromRange: aRange];
}

@end //NSAttributedString

@implementation NSMutableAttributedString

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableAttributedString_abstract_class)
    return NSAllocateObject(NSMutableAttributedString_concrete_class, 0, z);
  else
    return NSAllocateObject(self, 0, z);
}

- (Class) classForCoder
{
  return NSMutableAttributedString_abstract_class;
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  NSString	*string = [aDecoder decodeObject];
  unsigned	length = [string length];

  if (length == 0)
    {
      self = [self initWithString: string attributes: nil];
    }
  else
    {
      unsigned		index;
      NSDictionary	*attrs;

      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &index];
      attrs = [aDecoder decodeObject];
      if (index == length)
	{
	  self = [self initWithString: string attributes: attrs];
	}
      else
	{
	  NSRange	r = NSMakeRange(0, index);
	  unsigned	last = index;

	  self = [self initWithString: string attributes: nil];
	  [self setAttributes: attrs range: r];
	  while (index < length);
	    {
	      [aDecoder decodeValueOfObjCType: @encode(unsigned int)
					   at: &index];
	      attrs = [aDecoder decodeObject];
	      r = NSMakeRange(last, index - last);
	      [self setAttributes: attrs range: r];
	      last = index;
	    }
	}
    }
  return self;
}

//Retrieving character information
- (NSMutableString*) mutableString
{
  return [GSMutableAttributedStringTracker stringWithOwner: self];
}

//Changing characters
- (void) deleteCharactersInRange: (NSRange)aRange
{
  [self replaceCharactersInRange: aRange withString: nil];
}

//Changing attributes
- (void) setAttributes: (NSDictionary*)attributes range: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];// Primitive method!
}

- (void) addAttribute: (NSString*)name value: (id)value range: (NSRange)aRange
{
  NSRange		effectiveRange;
  NSDictionary		*attrDict;
  NSMutableDictionary	*newDict;
  unsigned int		tmpLength;
  IMP			getImp;

  tmpLength = [self length];
  GS_RANGE_CHECK(aRange, tmpLength);
  
  getImp = [self methodForSelector: getSel];
  attrDict = (*getImp)(self, getSel, aRange.location, &effectiveRange);

  if (effectiveRange.location < NSMaxRange(aRange))
    {
      IMP	setImp;

      setImp = [self methodForSelector: setSel];

      [self beginEditing];
      while (effectiveRange.location < NSMaxRange(aRange))
	{
	  effectiveRange = NSIntersectionRange(aRange, effectiveRange);
	  
	  newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
	    NSDefaultMallocZone());
	  newDict = (*initDictImp)(newDict, initDictSel, attrDict);
	  (*setDictImp)(newDict, setDictSel, value, name);
	  (*setImp)(self, setSel, newDict, effectiveRange);
	  IF_NO_GC((*relDictImp)(newDict, relDictSel));
	  
	  if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
	    {
	      effectiveRange.location = NSMaxRange(aRange);// stop the loop...
	    }
	  else if (NSMaxRange(effectiveRange) < tmpLength)
	    {
	      attrDict = (*getImp)(self, getSel, NSMaxRange(effectiveRange),
		&effectiveRange);
	    }
	}
      [self endEditing];
    }
}

- (void) addAttributes: (NSDictionary*)attributes range: (NSRange)aRange
{
  NSRange		effectiveRange;
  NSDictionary		*attrDict;
  NSMutableDictionary	*newDict;
  unsigned int		tmpLength;
  IMP			getImp;
  
  if (!attributes)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attributes is nil in method -addAttributes:range: "
			  @"in class NSMutableAtrributedString"];
    }
  tmpLength = [self length];
  if (aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
    {
      [NSException raise: NSRangeException
		  format: @"RangeError in method -addAttribute:value:range: "
			  @"in class NSMutableAttributedString"];
    }
  
  getImp = [self methodForSelector: getSel];
  attrDict = (*getImp)(self, getSel, aRange.location, &effectiveRange);

  if (effectiveRange.location < NSMaxRange(aRange))
    {
      IMP	setImp;

      setImp = [self methodForSelector: setSel];

      [self beginEditing];
      while (effectiveRange.location < NSMaxRange(aRange))
	{
	  effectiveRange = NSIntersectionRange(aRange,effectiveRange);
	  
	  newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
	    NSDefaultMallocZone());
	  newDict = (*initDictImp)(newDict, initDictSel, attrDict);
	  (*addDictImp)(newDict, addDictSel, attributes);
	  (*setImp)(self, setSel, newDict, effectiveRange);
	  IF_NO_GC((*relDictImp)(newDict, relDictSel));
	  
	  if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
	    {
	      effectiveRange.location = NSMaxRange(aRange);// stop the loop...
	    }
	  else if (NSMaxRange(effectiveRange) < tmpLength)
	    {
	      attrDict = (*getImp)(self, getSel, NSMaxRange(effectiveRange),
		&effectiveRange);
	    }
	}
      [self endEditing];
    }
}

- (void) removeAttribute: (NSString*)name range: (NSRange)aRange
{
  NSRange		effectiveRange;
  NSDictionary		*attrDict;
  NSMutableDictionary	*newDict;
  unsigned int		tmpLength;
  IMP			getImp;
  
  tmpLength = [self length];
  GS_RANGE_CHECK(aRange, tmpLength);
  
  getImp = [self methodForSelector: getSel];
  attrDict = (*getImp)(self, getSel, aRange.location, &effectiveRange);

  if (effectiveRange.location < NSMaxRange(aRange))
    {
      IMP	setImp;

      setImp = [self methodForSelector: setSel];

      [self beginEditing];
      while (effectiveRange.location < NSMaxRange(aRange))
	{
	  effectiveRange = NSIntersectionRange(aRange,effectiveRange);
	  
	  newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
	    NSDefaultMallocZone());
	  newDict = (*initDictImp)(newDict, initDictSel, attrDict);
	  (*remDictImp)(newDict, remDictSel, name);
	  (*setImp)(self, setSel, newDict, effectiveRange);
	  IF_NO_GC((*relDictImp)(newDict, relDictSel));
	  
	  if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
	    {
	      effectiveRange.location = NSMaxRange(aRange);// stop the loop...
	    }
	  else if (NSMaxRange(effectiveRange) < tmpLength)
	    {
	      attrDict = (*getImp)(self, getSel, NSMaxRange(effectiveRange),
		&effectiveRange);
	    }
	}
      [self endEditing];
    }
}

//Changing characters and attributes
- (void) appendAttributedString: (NSAttributedString*)attributedString
{
  [self replaceCharactersInRange: NSMakeRange([self length],0)
	    withAttributedString: attributedString];
}

- (void) insertAttributedString: (NSAttributedString*)attributedString
			atIndex: (unsigned int)index
{
  [self replaceCharactersInRange: NSMakeRange(index,0)
	    withAttributedString: attributedString];
}

- (void) replaceCharactersInRange: (NSRange)aRange
	     withAttributedString: (NSAttributedString*)attributedString
{
  NSDictionary	*attrDict;
  NSString	*tmpStr;
  unsigned	max;
  
  if (attributedString == nil)
    {
      [self replaceCharactersInRange: aRange withString: nil];
      return;
    }

  [self beginEditing];
  tmpStr = [attributedString string];
  [self replaceCharactersInRange: aRange withString: tmpStr];
  max = [tmpStr length];

  if (max > 0)
    {
      unsigned	loc = 0;
      NSRange	effectiveRange = NSMakeRange(0, loc);
      NSRange	clipRange = NSMakeRange(0, max);
      IMP	getImp;
      IMP	setImp;

      getImp = [attributedString methodForSelector: getSel];
      setImp = [self methodForSelector: setSel];
      while (loc < max)
	{
	  NSRange	ownRange;

	  attrDict = (*getImp)(attributedString, getSel, loc, &effectiveRange);
	  ownRange = NSIntersectionRange(clipRange, effectiveRange);
	  ownRange.location += aRange.location;
	  (*setImp)(self, setSel, attrDict, ownRange);
	  loc = NSMaxRange(effectiveRange);
	}
    }
  [self endEditing];
}

- (void) replaceCharactersInRange: (NSRange)aRange
		       withString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];// Primitive method!
}

- (void) setAttributedString: (NSAttributedString*)attributedString
{
  [self replaceCharactersInRange: NSMakeRange(0,[self length])
	    withAttributedString: attributedString];
}

//Grouping changes
- (void) beginEditing
{
  //Overridden by subclasses
}

- (void) endEditing
{
  //Overridden by subclasses
}

@end //NSMutableAttributedString




/*
 * The GSMutableAttributedStringTracker class is a concrete subclass of
 * NSMutableString which keeps it's owner informed of any changes made
 * to it.
 */
@implementation GSMutableAttributedStringTracker

+ (NSMutableString*) stringWithOwner: (NSMutableAttributedString*)as
{
  GSMutableAttributedStringTracker	*str;
  NSZone	*z = NSDefaultMallocZone();

  str = (GSMutableAttributedStringTracker*) NSAllocateObject(self, 0, z);

  str->_owner = RETAIN(as);
  return AUTORELEASE(str);
}

- (void) dealloc
{
  RELEASE(_owner);
  NSDeallocateObject(self);
}

- (unsigned int) length
{
  return [[_owner string] length];
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return [[_owner string] characterAtIndex: index];
}

- (void)getCharacters: (unichar*)buffer
{
  return [[_owner string] getCharacters: buffer];
}

- (void)getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  return [[_owner string] getCharacters: buffer range: aRange];
}

- (const char*) cString
{
  return [[_owner string] cString];
}

- (unsigned int) cStringLength
{
  return [[_owner string] cStringLength];
}

- (NSStringEncoding) fastestEncoding
{
  return [[_owner string] fastestEncoding];
}

- (NSStringEncoding) smallestEncoding
{
  return [[_owner string] smallestEncoding];
}

- (int) _baseLength
{
  return [[_owner string] _baseLength];
} 

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  return [[_owner string] encodeWithCoder: aCoder];
}

- (Class) classForCoder
{
  return [[_owner string] classForCoder];
}

- (void) replaceCharactersInRange: (NSRange)aRange
		       withString: (NSString*)aString
{
  [_owner replaceCharactersInRange: aRange withString: aString]; 
}

@end

