/* 
   NSGAttributedString.m

   Implementation of concrete subclass of a string class with attributes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: June 1997
   
   This file is part of ...

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

#include <Foundation/NSAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>

@implementation NSGAttributedString

void _setAttributesFrom(
  NSAttributedString *attributedString,
  NSRange aRange,
  NSMutableArray *attributeArray,
  NSMutableArray *locateArray)
{
  //always called immediately after -initWithString:attributes:
  NSRange effectiveRange;
  NSDictionary *attributeDict;

  if(aRange.length <= 0)
    return;//No attributes

  attributeDict = [attributedString attributesAtIndex:aRange.location
    effectiveRange:&effectiveRange];
  [attributeArray replaceObjectAtIndex:0 withObject:attributeDict];

  while (NSMaxRange(effectiveRange) < NSMaxRange(aRange))
  {
    attributeDict =
      [attributedString attributesAtIndex:NSMaxRange(effectiveRange)
        effectiveRange:&effectiveRange];
    [attributeArray addObject:attributeDict];
    [locateArray addObject:
      [NSNumber numberWithUnsignedInt:effectiveRange.location-aRange.location]];
  }
  return;
}

void _initWithString(
  NSString *aString,
  NSDictionary *attributes,
  NSString *textChars,
  NSMutableArray **attributeArray,
  NSMutableArray **locateArray)
{
  if (aString)
    [textChars initWithString:aString];
  else
    [textChars init];
  *attributeArray = [[NSMutableArray alloc] init];
  *locateArray = [[NSMutableArray alloc] init];
  if(!attributes)
    attributes = [[[NSDictionary alloc] init] autorelease];
  [(*attributeArray) addObject:attributes];
  [(*locateArray) addObject:[NSNumber numberWithUnsignedInt:0]];
}

NSDictionary *_attributesAtIndexEffectiveRange(
  unsigned int index,
  NSRange *aRange,
  unsigned int tmpLength,
  NSMutableArray *attributeArray,
  NSMutableArray *locateArray,
  unsigned int *foundIndex)
{
  unsigned int low,high,used,cnt,foundLoc,nextLoc;
  NSDictionary *foundDict;

  if(index<0 || index >= tmpLength)
  {
    [NSException raise:NSRangeException format:
      @"index is out of range in function _attributesAtIndexEffectiveRange()"];
  }
  
  //Binary search for efficiency in huge attributed strings
  used = [attributeArray count];
  low=0;
  high = used - 1;
  while(low<=high)
  {
    cnt=(low+high)/2;
    foundDict = [attributeArray objectAtIndex:cnt];
    foundLoc = [[locateArray objectAtIndex:cnt] unsignedIntValue];
    if(foundLoc > index)
    {
      high = cnt-1;
    }
    else
    {
      if(cnt >= used -1)
        nextLoc = tmpLength;
      else
        nextLoc = [[locateArray objectAtIndex:cnt+1] unsignedIntValue];
      if(foundLoc == index ||
        index < nextLoc)
      {
        //Found
        if(aRange)
        {
          aRange->location = foundLoc;
          aRange->length = nextLoc - foundLoc;
        }
        if(foundIndex)
          *foundIndex = cnt;
        return foundDict;
      }
      else
        low = cnt+1;
    }
  }
  NSCAssert(NO,@"Error in binary search algorithm");
  return nil;
}

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeObject:textChars];
  [aCoder encodeObject:attributeArray];
  [aCoder encodeObject:locateArray];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  textChars = [[aCoder decodeObject] retain];
  attributeArray = [[aCoder decodeObject] retain];
  locateArray = [[aCoder decodeObject] retain];
  return self;
}

- _setAttributesFrom:(NSAttributedString *)attributedString range:(NSRange)aRange
{
  //always called immediately after -initWithString:attributes:
  _setAttributesFrom(attributedString,aRange,attributeArray,locateArray);
  return self;
}

- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
  textChars = [NSString alloc];
  _initWithString(aString,attributes,textChars,&attributeArray,&locateArray);
  return self;
}

- (NSString *)string
{
  return textChars;
}

- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange
{
  return _attributesAtIndexEffectiveRange(
    index,aRange,[self length],attributeArray,locateArray,NULL);
}

- (void)dealloc
{
  [textChars release];
  [attributeArray release];
  [locateArray release];
  [super dealloc];
}

@end


@implementation NSGMutableAttributedString

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeObject:textChars];
  [aCoder encodeObject:attributeArray];
  [aCoder encodeObject:locateArray];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  textChars = [[aCoder decodeObject] retain];
  attributeArray = [[aCoder decodeObject] retain];
  locateArray = [[aCoder decodeObject] retain];
  return self;
}

- _setAttributesFrom:(NSAttributedString *)attributedString range:(NSRange)aRange
{
  //always called immediately after -initWithString:attributes:
  _setAttributesFrom(attributedString,aRange,attributeArray,locateArray);
  return self;
}

- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
  textChars = [NSMutableString alloc];
  _initWithString(aString,attributes,textChars,&attributeArray,&locateArray);
  return self;
}

- (NSString *)string
{
  return textChars;
}

- (NSMutableString *)mutableString
{
  return textChars;
}

- (NSDictionary *)attributesAtIndex:(unsigned int)index effectiveRange:(NSRange *)aRange
{
  return _attributesAtIndexEffectiveRange(
    index,aRange,[self length],attributeArray,locateArray,NULL);
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range
{
  unsigned int tmpLength,arrayIndex,arraySize,location;
  NSRange effectiveRange;
  NSNumber *afterRangeLocation,*beginRangeLocation;
  NSDictionary *attrs;
  
  if(!attributes)
    attributes = [NSDictionary dictionary];
  tmpLength = [self length];
  if(range.location < 0 || NSMaxRange(range) > tmpLength)
  {
    [NSException raise:NSRangeException
      format:@"RangeError in method -replaceCharactersInRange:withString: in class NSMutableAttributedString"];
  }
  arraySize = [locateArray count];
  if(NSMaxRange(range) < tmpLength)
  {
    attrs = _attributesAtIndexEffectiveRange(
      NSMaxRange(range),&effectiveRange,tmpLength,attributeArray,locateArray,&arrayIndex);

    afterRangeLocation =
      [NSNumber numberWithUnsignedInt:NSMaxRange(range)];
    if(effectiveRange.location > range.location)
    {
      [locateArray replaceObjectAtIndex:arrayIndex
        withObject:afterRangeLocation];
    }
    else
    {
      arrayIndex++;
        //There shouldn't be anything wrong in putting an object (attrs) in
        //an array more than once should there? The object will not change.
      [attributeArray insertObject:attrs atIndex:arrayIndex];
      [locateArray insertObject:afterRangeLocation atIndex:arrayIndex];
    }
    arrayIndex--;
  }
  else
    arrayIndex = arraySize - 1;
  
  while(arrayIndex > 0 &&
    [[locateArray objectAtIndex:arrayIndex-1] unsignedIntValue] >= range.location)
  {
    [locateArray removeObjectAtIndex:arrayIndex];
    [attributeArray removeObjectAtIndex:arrayIndex];
    arrayIndex--;
  }
  beginRangeLocation = [NSNumber numberWithUnsignedInt:range.location];
  location = [[locateArray objectAtIndex:arrayIndex] unsignedIntValue];
  if(location >= range.location)
  {
    if(location > range.location)
    {
      [locateArray replaceObjectAtIndex:arrayIndex
        withObject:beginRangeLocation];
    }
    [attributeArray replaceObjectAtIndex:arrayIndex
      withObject:attributes];
  }
  else
  {
    arrayIndex++;
    [attributeArray insertObject:attributes atIndex:arrayIndex];
    [locateArray insertObject:beginRangeLocation atIndex:arrayIndex];
  }
  
  /* Primitive method! Sets attributes and values for a given range of characters, replacing any previous attributes
  and values for that range.*/

  /*Sets the attributes for the characters in aRange to attributes. These new attributes replace any attributes
  previously associated with the characters in aRange. Raises an NSRangeException if any part of aRange lies beyond
  the end of the receiver's characters.
  See also: - addAtributes:range:, - removeAttributes:range:*/
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString
{
  unsigned int tmpLength,arrayIndex,arraySize,cnt,location,moveLocations;
  NSRange effectiveRange;
  NSDictionary *attrs;
  NSNumber *afterRangeLocation;

  if(!aString)
    aString = @"";
  tmpLength = [self length];
  if(range.location < 0 || NSMaxRange(range) > tmpLength)
  {
    [NSException raise:NSRangeException
      format:@"RangeError in method -replaceCharactersInRange:withString: in class NSMutableAttributedString"];
  }
  arraySize = [locateArray count];
  if(NSMaxRange(range) < tmpLength)
  {
    attrs = _attributesAtIndexEffectiveRange(
      NSMaxRange(range),&effectiveRange,tmpLength,attributeArray,locateArray,&arrayIndex);
    
    moveLocations = [aString length] - range.length;
    afterRangeLocation =
      [NSNumber numberWithUnsignedInt:NSMaxRange(range)+moveLocations];
    
    if(effectiveRange.location > range.location)
    {
      [locateArray replaceObjectAtIndex:arrayIndex
        withObject:afterRangeLocation];
    }
    else
    {
      arrayIndex++;
        //There shouldn't be anything wrong in putting an object (attrs) in
        //an array more than once should there? The object will not change.
      [attributeArray insertObject:attrs atIndex:arrayIndex];
      [locateArray insertObject:afterRangeLocation atIndex:arrayIndex];
    }
    
    for(cnt=arrayIndex+1;cnt<arraySize;cnt++)
    {
      location = [[locateArray objectAtIndex:cnt] unsignedIntValue] + moveLocations;
      [locateArray replaceObjectAtIndex:cnt
        withObject:[NSNumber numberWithUnsignedInt:location]];
    }
    arrayIndex--;
  }
  else
    arrayIndex = arraySize - 1;
  while(arrayIndex > 0 &&
    [[locateArray objectAtIndex:arrayIndex] unsignedIntValue] > range.location)
  {
    [locateArray removeObjectAtIndex:arrayIndex];
    [attributeArray removeObjectAtIndex:arrayIndex];
    arrayIndex--;
  }
  [textChars replaceCharactersInRange:range withString:aString];
}

- (void)dealloc
{
  [textChars release];
  [attributeArray release];
  [locateArray release];
  [super dealloc];
}

@end
