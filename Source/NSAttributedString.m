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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/* Warning -	[-initWithString:attributes:] is the designated initialiser,
 *		but it doesn't provide any way to perform the function of the
 *		[-initWithAttributedString:] initialiser.
 *		In order to work youd this, the string argument of the
 *		designated initialiser has been overloaded such that it
 *		is expected to accept an NSAttributedString here instead of
 *		a string.  If you create an NSAttributedString subclass, you
 *		must make sure that your implementation of the initialiser
 *		copes with either an NSString or an NSAttributedString.
 *		If it receives an NSAttributedString, it should ignore the
 *		attributes argument and use the values from the string.
 */

#include <base/preface.h>
#include <base/fast.x>
#include <base/Unicode.h>

#include <Foundation/NSAttributedString.h>
#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPortCoder.h>


@interface GSMutableAttributedStringTracker : NSMutableString
{
  NSMutableAttributedString	*_owner;
}
+ (NSMutableString*) stringWithOwner: (NSMutableAttributedString*)as;
@end


@implementation NSAttributedString

static Class NSAttributedString_concrete_class;
static Class NSMutableAttributedString_concrete_class;

//Internal methods
+ (void) _setConcreteClass: (Class)c
{
  NSAttributedString_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableAttributedString_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSAttributedString_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableAttributedString_concrete_class;
}

+ (void) initialize
{
  if (self == [NSAttributedString class])
    {
      NSAttributedString_concrete_class
	= [NSGAttributedString class];
      NSMutableAttributedString_concrete_class
	= [NSGMutableAttributedString class];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

//NSCoding protocol
- (void) encodeWithCoder: (NSCoder*)anEncoder
{
  [super encodeWithCoder: anEncoder];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  return [super initWithCoder: aDecoder];
}

- (Class) classForPortCoder
{
  return [self class];
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
  if ([self isKindOfClass: [NSMutableAttributedString class]] ||
        NSShouldRetainWithZone(self, zone) == NO)
    return [[[[self class] _concreteClass] allocWithZone: zone]
        initWithAttributedString: self];
  else
    return [self retain];
}

//NSMutableCopying protocol
- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[[[self class] _mutableConcreteClass] allocWithZone: zone]
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

//Retrieving character information
- (unsigned int) length
{
  return [[self string] length];
}

- (NSString *) string
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

  if (rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
    {
      [NSException raise: NSRangeException format: 
	@"RangeError in method -attributesAtIndex: longestEffectiveRange: inRange: in class NSAttributedString"];
    }
  attrDictionary = [self attributesAtIndex: index effectiveRange: aRange];
  if (!aRange)
    return attrDictionary;
  
  while(aRange->location > rangeLimit.location)
  {
    //Check extend range backwards
    tmpDictionary =
      [self attributesAtIndex: aRange->location-1
        effectiveRange: &tmpRange];
    if ([tmpDictionary isEqualToDictionary: attrDictionary])
      aRange->location = tmpRange.location;
  }
  while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
  {
    //Check extend range forwards
    tmpDictionary =
      [self attributesAtIndex: NSMaxRange(*aRange)
        effectiveRange: &tmpRange];
    if ([tmpDictionary isEqualToDictionary: attrDictionary])
      aRange->length = NSMaxRange(tmpRange) - aRange->location;
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
  //Raises exception if index is out of range, so that I don't have to test this...

  if (!attributeName)
  {
    if (aRange)
      *aRange = NSMakeRange(0,[self length]);
      //If attributeName is nil, then the attribute will not exist in the
      //entire text - therefore aRange of the entire text must be correct
    
    return nil;
  }
  attrValue = [tmpDictionary objectForKey: attributeName];  
  return attrValue;
}

- (id) attribute: (NSString*)attributeName atIndex: (unsigned int)index longestEffectiveRange: (NSRange *)aRange inRange: (NSRange)rangeLimit
{
  NSDictionary *tmpDictionary;
  id attrValue,tmpAttrValue;
  NSRange tmpRange;

  if (rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
  {
    [NSException raise: NSRangeException format: 
      @"RangeError in method -attribute: atIndex: longestEffectiveRange: inRange: in class NSAttributedString"];
  }
  
  attrValue = [self attribute: attributeName atIndex: index effectiveRange: aRange];
  //Raises exception if index is out of range, so that I don't have to test this...

  if (!attributeName)
    return nil;//attribute: atIndex: effectiveRange: handles this case...
  if (!aRange)
    return attrValue;
  
  while(aRange->location > rangeLimit.location)
  {
    //Check extend range backwards
    tmpDictionary =
      [self attributesAtIndex: aRange->location-1
        effectiveRange: &tmpRange];
    tmpAttrValue = [tmpDictionary objectForKey: attributeName];
    if (tmpAttrValue == attrValue)
      aRange->location = tmpRange.location;
  }
  while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
  {
    //Check extend range forwards
    tmpDictionary =
      [self attributesAtIndex: NSMaxRange(*aRange)
        effectiveRange: &tmpRange];
    tmpAttrValue = [tmpDictionary objectForKey: attributeName];
    if (tmpAttrValue == attrValue)
      aRange->length = NSMaxRange(tmpRange) - aRange->location;
  }
  *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
  return attrValue;
}

//Comparing attributed strings
- (BOOL) isEqualToAttributedString: (NSAttributedString *)otherString
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
    
  while(YES)
  {
    if (NSIntersectionRange(ownEffectiveRange,otherEffectiveRange).length > 0 &&
      ![ownDictionary isEqualToDictionary: otherDictionary])
    {
      result = NO;
      break;
    }
    if (NSMaxRange(ownEffectiveRange) < NSMaxRange(otherEffectiveRange))
    {
      ownDictionary = [self
        attributesAtIndex: NSMaxRange(ownEffectiveRange)
        effectiveRange: &ownEffectiveRange];
    }
    else
    {
      if (NSMaxRange(otherEffectiveRange) >= length)
        break;//End of strings
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
  if ([anObject isKindOf: [NSAttributedString class]])
    return [self isEqualToAttributedString: anObject];
  return NO;
}


//Extracting a substring
- (NSAttributedString *) attributedSubstringFromRange: (NSRange)aRange
{
  NSAttributedString	*newAttrString;
  NSString		*newSubstring;
  NSDictionary		*attrs;
  NSRange		range;

  if (aRange.location<0 || aRange.length<0 || NSMaxRange(aRange)>[self length])
    [NSException raise: NSRangeException
		format: @"RangeError in method -attributedSubstringFromRange: "
			@"in class NSAttributedString"];
  
  newSubstring = [[self string] substringFromRange: aRange];

  attrs = [self attributesAtIndex: aRange.location effectiveRange: &range];
  range = NSIntersectionRange(range, aRange);
  if (NSEqualRanges(range, aRange) == YES)
    {
      newAttrString = [[NSAttributedString alloc] initWithString: newSubstring
						      attributes: attrs];
    }
  else
    {
      NSMutableAttributedString	*m;
      NSRange			rangeToSet = range;

      m = [[NSMutableAttributedString alloc] initWithString: newSubstring
						 attributes: nil];
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
      [m release];
    }

  [newAttrString autorelease];
  return newAttrString;
}

@end //NSAttributedString

@implementation NSMutableAttributedString

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

//Retrieving character information
- (NSMutableString *) mutableString
{
  return [GSMutableAttributedStringTracker stringWithOwner: self];
}

//Changing characters
- (void) deleteCharactersInRange: (NSRange)aRange
{
  [self replaceCharactersInRange: aRange withString: nil];
}

//Changing attributes
- (void) setAttributes: (NSDictionary *)attributes range: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];// Primitive method!
}

- (void) addAttribute: (NSString *)name value: (id)value range: (NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;

  tmpLength = [self length];
  if (aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise: NSRangeException
      format: @"RangeError in method -addAttribute: value: range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex: aRange.location
    effectiveRange: &effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary: attrDict];
    [newDict autorelease];
    [newDict setObject: value forKey: name];
    [self setAttributes: newDict range: effectiveRange];
    
    if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if (NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex: NSMaxRange(effectiveRange)
        effectiveRange: &effectiveRange];
    }
  }
}

- (void) addAttributes: (NSDictionary *)attributes range: (NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;
  
  if (!attributes)
  {
    //I cannot use NSParameterAssert here, if is has to be an NSInvalidArgumentException
    [NSException raise: NSInvalidArgumentException
      format: @"attributes is nil in method -addAttributes: range: in class NSMutableAtrributedString"];
  }
  tmpLength = [self length];
  if (aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise: NSRangeException
      format: @"RangeError in method -addAttribute: value: range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex: aRange.location
    effectiveRange: &effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary: attrDict];
    [newDict autorelease];
    [newDict addEntriesFromDictionary: attributes];
    [self setAttributes: newDict range: effectiveRange];
    
    if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if (NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex: NSMaxRange(effectiveRange)
        effectiveRange: &effectiveRange];
    }
  }
}

- (void) removeAttribute: (NSString *)name range: (NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;
  
  tmpLength = [self length];
  if (aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise: NSRangeException
      format: @"RangeError in method -addAttribute: value: range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex: aRange.location
    effectiveRange: &effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary: attrDict];
    [newDict autorelease];
    [newDict removeObjectForKey: name];
    [self setAttributes: newDict range: effectiveRange];
    
    if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if (NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex: NSMaxRange(effectiveRange)
        effectiveRange: &effectiveRange];
    }
  }
}

//Changing characters and attributes
- (void) appendAttributedString: (NSAttributedString *)attributedString
{
  [self replaceCharactersInRange: NSMakeRange([self length],0)
    withAttributedString: attributedString];
}

- (void) insertAttributedString: (NSAttributedString *)attributedString atIndex: (unsigned int)index
{
  [self replaceCharactersInRange: NSMakeRange(index,0)
    withAttributedString: attributedString];
}

- (void) replaceCharactersInRange: (NSRange)aRange withAttributedString: (NSAttributedString *)attributedString
{
  NSRange effectiveRange,clipRange,ownRange;
  NSDictionary *attrDict;
  NSString *tmpStr;
  
  tmpStr = [attributedString string];
  [self replaceCharactersInRange: aRange
    withString: tmpStr];
  
  effectiveRange = NSMakeRange(0,0);
  clipRange = NSMakeRange(0,[tmpStr length]);
  while(NSMaxRange(effectiveRange) < NSMaxRange(clipRange))
  {
    attrDict = [attributedString attributesAtIndex: effectiveRange.location
      effectiveRange: &effectiveRange];
    ownRange = NSIntersectionRange(clipRange,effectiveRange);
    ownRange.location += aRange.location;
    [self setAttributes: attrDict range: ownRange];
  }
}

- (void) replaceCharactersInRange: (NSRange)aRange withString: (NSString *)aString
{
  [self subclassResponsibility: _cmd];// Primitive method!
}

- (void) setAttributedString: (NSAttributedString *)attributedString
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
  return [str autorelease];
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

- (const char *) cString
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

