/* 
   NSAttributedString.m

   Implementation of string class with attributes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: November 1997
   
   This file is part of GNUStep-base

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

//FIXME: 1) The NSMutableString object returned from the -mutableString method
//       in NSMutableAttributedString is NOT tracked for changes to update
//       NSMutableAttributedString's attributes as it should.

//FIXME: 2) If out-of-memory exceptions are raised in some methods,
//       inconsistencies may develop, because the two internal arrays in
//       NSGAttributedString and NSGMutableAttributedString called
//       attributeArray and locateArray must always be syncronized.

//FIXME: 3) The method _setAttributesFrom: must be overridden by
//          concrete subclasses of NSAttributedString which is WRONG and
//          VERY bad! I haven't found any other way to make
//          - initWithString:attributes: the designated initializer 
//          in NSAttributedString and still implement
//          - initWithAttributedString: without having to override it
//          in the concrete subclass.

#include <Foundation/NSAttributedString.h>
#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPortCoder.h>

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

- _setAttributesFrom:(NSAttributedString *)attributedString range:(NSRange)aRange
{
  //Private method for implementing -initWithAttributedString: and
  //-attributedSubstringFromRange:
  [self subclassResponsibility:_cmd];
  return self;
}

+ (void) initialize
{
  if (self == [NSAttributedString class])
  {
    NSAttributedString_concrete_class = [NSGAttributedString class];
    NSMutableAttributedString_concrete_class = [NSGMutableAttributedString class];
  }
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

//NSCoding protocol
- (void) encodeWithCoder: anEncoder
{
  [super encodeWithCoder:anEncoder];
}

- initWithCoder: aDecoder
{
  return [super initWithCoder:aDecoder];
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
- copyWithZone: (NSZone*)zone
{
  if ([self isKindOfClass: [NSMutableAttributedString class]] ||
        NSShouldRetainWithZone(self, zone) == NO)
    return [[[[self class] _concreteClass] allocWithZone:zone]
        initWithAttributedString:self];
  else
    return [self retain];
}

//NSMutableCopying protocol
- mutableCopyWithZone: (NSZone*)zone
{
  return [[[[self class] _mutableConcreteClass] allocWithZone:zone]
	  initWithAttributedString:self];
}

//Creating an NSAttributedString
- (id)init
{
  return [self initWithString:nil attributes:nil];//Designated initializer
}

- (id)initWithString:(NSString *)aString
{
  return [self initWithString:aString attributes:nil];//Designated initializer
}

- (id)initWithAttributedString:(NSAttributedString *)attributedString
{
  NSString *tmpStr;

  if(!attributedString)
    [self initWithString:nil attributes:nil];//Designated initializer
  else
  {
    tmpStr = [attributedString string];
    [self initWithString:tmpStr attributes:nil];//Designated initializer
    [self _setAttributesFrom:attributedString range:NSMakeRange(0,[tmpStr length])];
  }
  return self;
}

- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
  //This is the designated initializer
  return [super init];
}

//Retrieving character information
- (unsigned int)length
{
  return [[self string] length];
}

- (NSString *)string
{
  [self subclassResponsibility:_cmd];/* Primitive method! */
  return nil;
}

//Retrieving attribute information
- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange
{
  [self subclassResponsibility:_cmd];/* Primitive method! */
  return nil;
}

- (NSDictionary *)attributesAtIndex:(unsigned int)index longestEffectiveRange:(NSRange *)aRange inRange:(NSRange)rangeLimit
{
  NSDictionary *attrDictionary,*tmpDictionary;
  NSRange tmpRange;

  if(rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
  {
    [NSException raise:NSRangeException format:
      @"RangeError in method -attributesAtIndex:longestEffectiveRange:inRange: in class NSAttributedString"];
  }
  attrDictionary = [self attributesAtIndex:index effectiveRange:aRange];
  if(!aRange)
    return attrDictionary;
  
  while(aRange->location > rangeLimit.location)
  {
    //Check extend range backwards
    tmpDictionary =
      [self attributesAtIndex:aRange->location-1
        effectiveRange:&tmpRange];
    if([tmpDictionary isEqualToDictionary:attrDictionary])
      aRange->location = tmpRange.location;
  }
  while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
  {
    //Check extend range forwards
    tmpDictionary =
      [self attributesAtIndex:NSMaxRange(*aRange)
        effectiveRange:&tmpRange];
    if([tmpDictionary isEqualToDictionary:attrDictionary])
      aRange->length = NSMaxRange(tmpRange) - aRange->location;
  }
  *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
  return attrDictionary;
}

- (id)attribute:(NSString *)attributeName atIndex:(unsigned int)index effectiveRange:(NSRange *)aRange
{
  NSDictionary *tmpDictionary;
  id attrValue;

  tmpDictionary = [self attributesAtIndex:index effectiveRange:aRange];
  //Raises exception if index is out of range, so that I don't have to test this...

  if(!attributeName)
  {
    if(aRange)
      *aRange = NSMakeRange(0,[self length]);
      //If attributeName is nil, then the attribute will not exist in the
      //entire text - therefore aRange of the entire text must be correct
    
    return nil;
  }
  attrValue = [tmpDictionary objectForKey:attributeName];  
  return attrValue;
}

- (id)attribute:(NSString *)attributeName atIndex:(unsigned int)index longestEffectiveRange:(NSRange *)aRange inRange:(NSRange)rangeLimit
{
  NSDictionary *tmpDictionary;
  id attrValue,tmpAttrValue;
  NSRange tmpRange;

  if(rangeLimit.location < 0 || NSMaxRange(rangeLimit) > [self length])
  {
    [NSException raise:NSRangeException format:
      @"RangeError in method -attribute:atIndex:longestEffectiveRange:inRange: in class NSAttributedString"];
  }
  
  attrValue = [self attribute:attributeName atIndex:index effectiveRange:aRange];
  //Raises exception if index is out of range, so that I don't have to test this...

  if(!attributeName)
    return nil;//attribute:atIndex:effectiveRange: handles this case...
  if(!aRange)
    return attrValue;
  
  while(aRange->location > rangeLimit.location)
  {
    //Check extend range backwards
    tmpDictionary =
      [self attributesAtIndex:aRange->location-1
        effectiveRange:&tmpRange];
    tmpAttrValue = [tmpDictionary objectForKey:attributeName];
    if(tmpAttrValue == attrValue)
      aRange->location = tmpRange.location;
  }
  while(NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
  {
    //Check extend range forwards
    tmpDictionary =
      [self attributesAtIndex:NSMaxRange(*aRange)
        effectiveRange:&tmpRange];
    tmpAttrValue = [tmpDictionary objectForKey:attributeName];
    if(tmpAttrValue == attrValue)
      aRange->length = NSMaxRange(tmpRange) - aRange->location;
  }
  *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
  return attrValue;
}

//Comparing attributed strings
- (BOOL)isEqualToAttributedString:(NSAttributedString *)otherString
{
  NSRange ownEffectiveRange,otherEffectiveRange;
  unsigned int length;
  NSDictionary *ownDictionary,*otherDictionary;
  BOOL result;

  if(!otherString)
    return NO;
  if(![[otherString string] isEqual:[self string]])
    return NO;
  
  length = [otherString length];
  if(length<=0)
    return YES;

  ownDictionary = [self attributesAtIndex:0
    effectiveRange:&ownEffectiveRange];
  otherDictionary = [otherString attributesAtIndex:0
    effectiveRange:&otherEffectiveRange];
  result = YES;
    
  while(YES)
  {
    if(NSIntersectionRange(ownEffectiveRange,otherEffectiveRange).length > 0 &&
      ![ownDictionary isEqualToDictionary:otherDictionary])
    {
      result = NO;
      break;
    }
    if(NSMaxRange(ownEffectiveRange) < NSMaxRange(otherEffectiveRange))
    {
      ownDictionary = [self
        attributesAtIndex:NSMaxRange(ownEffectiveRange)
        effectiveRange:&ownEffectiveRange];
    }
    else
    {
      if(NSMaxRange(otherEffectiveRange) >= length)
        break;//End of strings
      otherDictionary = [otherString
        attributesAtIndex:NSMaxRange(otherEffectiveRange)
        effectiveRange:&otherEffectiveRange];
    }
  }
  return result;
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOf:[NSAttributedString class]])
    return [self isEqualToAttributedString:anObject];
  return NO;
}


//Extracting a substring
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)aRange
{
  NSAttributedString *newAttrString;
  NSString *newSubstring;

  if(aRange.location<0 || aRange.length<0 || NSMaxRange(aRange)>[self length])
    [NSException raise:NSRangeException
      format:@"RangeError in method -attributedSubstringFromRange: in class NSAttributedString"];
  
  newSubstring = [[self string] substringFromRange:aRange];//Should already be autoreleased

  newAttrString = [[NSAttributedString alloc] initWithString:newSubstring attributes:nil];
  [newAttrString autorelease];
  [newAttrString _setAttributesFrom:self range:aRange];

  return newAttrString;
}

@end //NSAttributedString

@implementation NSMutableAttributedString

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

//Retrieving character information
- (NSMutableString *)mutableString
{
  [self subclassResponsibility:_cmd];
  return nil;
}

//Changing characters
- (void)deleteCharactersInRange:(NSRange)aRange
{
  [self replaceCharactersInRange:aRange withString:nil];
}

//Changing attributes
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
  [self subclassResponsibility:_cmd];// Primitive method!
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;

  tmpLength = [self length];
  if(aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise:NSRangeException
      format:@"RangeError in method -addAttribute:value:range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex:aRange.location
    effectiveRange:&effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
    [newDict autorelease];
    [newDict setObject:value forKey:name];
    [self setAttributes:newDict range:effectiveRange];
    
    if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if(NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
        effectiveRange:&effectiveRange];
    }
  }
}

- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;
  
  if(!attributes)
  {
    //I cannot use NSParameterAssert here, if is has to be an NSInvalidArgumentException
    [NSException raise:NSInvalidArgumentException
      format:@"attributes is nil in method -addAttributes:range: in class NSMutableAtrributedString"];
  }
  tmpLength = [self length];
  if(aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise:NSRangeException
      format:@"RangeError in method -addAttribute:value:range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex:aRange.location
    effectiveRange:&effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
    [newDict autorelease];
    [newDict addEntriesFromDictionary:attributes];
    [self setAttributes:newDict range:effectiveRange];
    
    if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if(NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
        effectiveRange:&effectiveRange];
    }
  }
}

- (void)removeAttribute:(NSString *)name range:(NSRange)aRange
{
  NSRange effectiveRange;
  NSDictionary *attrDict;
  NSMutableDictionary *newDict;
  unsigned int tmpLength;
  
  tmpLength = [self length];
  if(aRange.location <= 0 || NSMaxRange(aRange) > tmpLength)
  {
    [NSException raise:NSRangeException
      format:@"RangeError in method -addAttribute:value:range: in class NSMutableAttributedString"];
  }
  
  attrDict = [self attributesAtIndex:aRange.location
    effectiveRange:&effectiveRange];

  while(effectiveRange.location < NSMaxRange(aRange))
  {
    effectiveRange = NSIntersectionRange(aRange,effectiveRange);
    
    newDict = [[NSMutableDictionary alloc] initWithDictionary:attrDict];
    [newDict autorelease];
    [newDict removeObjectForKey:name];
    [self setAttributes:newDict range:effectiveRange];
    
    if(NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
      effectiveRange.location = NSMaxRange(aRange);//This stops the loop...
    else if(NSMaxRange(effectiveRange) < tmpLength)
    {
      attrDict = [self attributesAtIndex:NSMaxRange(effectiveRange)
        effectiveRange:&effectiveRange];
    }
  }
}

//Changing characters and attributes
- (void)appendAttributedString:(NSAttributedString *)attributedString
{
  [self replaceCharactersInRange:NSMakeRange([self length],0)
    withAttributedString:attributedString];
}

- (void)insertAttributedString:(NSAttributedString *)attributedString atIndex:(unsigned int)index
{
  [self replaceCharactersInRange:NSMakeRange(index,0)
    withAttributedString:attributedString];
}

- (void)replaceCharactersInRange:(NSRange)aRange withAttributedString:(NSAttributedString *)attributedString
{
  NSRange effectiveRange,clipRange,ownRange;
  NSDictionary *attrDict;
  NSString *tmpStr;
  
  tmpStr = [attributedString string];
  [self replaceCharactersInRange:aRange
    withString:tmpStr];
  
  effectiveRange = NSMakeRange(0,0);
  clipRange = NSMakeRange(0,[tmpStr length]);
  while(NSMaxRange(effectiveRange) < NSMaxRange(clipRange))
  {
    attrDict = [attributedString attributesAtIndex:effectiveRange.location
      effectiveRange:&effectiveRange];
    ownRange = NSIntersectionRange(clipRange,effectiveRange);
    ownRange.location += aRange.location;
    [self setAttributes:attrDict range:ownRange];
  }
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
  [self subclassResponsibility:_cmd];// Primitive method!
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
  [self replaceCharactersInRange:NSMakeRange(0,[self length])
    withAttributedString:attributedString];
}

//Grouping changes
- (void)beginEditing
{
  //Overridden by subclasses
}

- (void)endEditing
{
  //Overridden by subclasses
}

@end //NSMutableAttributedString
