/* 
   NSGAttributedString.m

   Implementation of concrete subclass of a string class with attributes

   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: November 1997
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: April 1999
   
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

#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>

@interface	GSAttrInfo : NSObject
{
@public
  unsigned	loc;
  NSDictionary	*attrs;
}

+ (GSAttrInfo*) newWithZone: (NSZone*)z value: (NSDictionary*)a at: (unsigned)l;

@end

@implementation	GSAttrInfo

+ (GSAttrInfo*) newWithZone: (NSZone*)z value: (NSDictionary*)a at: (unsigned)l;
{
  GSAttrInfo	*info = (GSAttrInfo*)NSAllocateObject(self, 0, z);

  info->loc = l;
  info->attrs = [a copy];
  return info;
}

- (void) dealloc
{
  RELEASE(attrs);
  NSDeallocateObject(self);
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &loc];
  [aCoder encodeValueOfObjCType: @encode(id) at: &attrs];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  self = [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &loc];
  [aCoder decodeValueOfObjCType: @encode(id) at: &attrs];
  return self;
}

@end



@implementation NSGAttributedString

static SEL	infSel = @selector(newWithZone:value:at:);
static IMP	infImp = 0;
static Class	infCls = 0;

void _setAttributesFrom(
  NSAttributedString *attributedString,
  NSRange aRange,
  NSMutableArray *infoArray)
{
  NSZone	*z = [infoArray zone];
  NSRange	range;
  NSDictionary	*attr;
  GSAttrInfo	*info;
  unsigned	loc;

  /*
   * remove any old attributes of the string.
   */
  [infoArray removeAllObjects];

  if (aRange.length <= 0)
    return;

  attr = [attributedString attributesAtIndex: aRange.location
			      effectiveRange: &range];
  info = [GSAttrInfo newWithZone: z value: attr at: 0];
  [infoArray addObject: info];
  RELEASE(info);

  while ((loc = NSMaxRange(range)) < NSMaxRange(aRange))
    {
      attr = [attributedString attributesAtIndex: loc
				  effectiveRange: &range];
      info = [GSAttrInfo newWithZone: z value: attr at: loc - aRange.location];
      [infoArray addObject: info];
      RELEASE(info);
    }
}

NSDictionary *_attributesAtIndexEffectiveRange(
  unsigned int index,
  NSRange *aRange,
  unsigned int tmpLength,
  NSMutableArray *infoArray,
  unsigned int *foundIndex)
{
  unsigned	low, high, used, cnt, nextLoc;
  GSAttrInfo	*found = nil;

  if (index >= tmpLength)
    {
      [NSException raise: NSRangeException
		  format: @"index is out of range in function "
			  @"_attributesAtIndexEffectiveRange()"];
    }
  
  used = [infoArray count];

  /*
   * Binary search for efficiency in huge attributed strings
   */
  low = 0;
  high = used - 1;
  while (low <= high)
    {
      cnt = (low + high) / 2;
      found = [infoArray objectAtIndex: cnt];
      if (found->loc > index)
	{
	  high = cnt - 1;
	}
      else
	{
	  if (cnt >= used - 1)
	    {
	      nextLoc = tmpLength;
	    }
	  else
	    {
	      GSAttrInfo	*inf = [infoArray objectAtIndex: cnt + 1];

	      nextLoc = inf->loc;
	    }
	  if (found->loc == index || index < nextLoc)
	    {
	      //Found
	      if (aRange)
		{
		  aRange->location = found->loc;
		  aRange->length = nextLoc - found->loc;
		}
	      if (foundIndex)
		{
		  *foundIndex = cnt;
		}
	      return found->attrs;
	    }
	  else
	    {
	      low = cnt + 1;
	    }
	}
    }
  NSCAssert(NO,@"Error in binary search algorithm");
  return nil;
}

+ (void) initialize
{
  if (infCls == 0)
    {
      infCls = [GSAttrInfo class];
      infImp = [infCls methodForSelector: infSel];
    }
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfObjCType: @encode(id) at: &textChars];
  [aCoder encodeValueOfObjCType: @encode(id) at: &infoArray];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  self = [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(id) at: &textChars];
  [aCoder decodeValueOfObjCType: @encode(id) at: &infoArray];
  return self;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = [self zone];

  infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
  if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
      NSAttributedString	*as = (NSAttributedString*)aString;

      aString = [as string];
      _setAttributesFrom(as, NSMakeRange(0, [aString length]), infoArray);
    }
  else
    {
      GSAttrInfo	*info;

      info = (*infImp)(infCls, infSel, z, attributes, 0);
      [infoArray addObject: info];
      RELEASE(info);
    }
  if (aString == nil)
    textChars = @"";
  else
    textChars = [aString copyWithZone: z];
  return self;
}

- (NSString*) string
{
  return textChars;
}

- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange
{
  return _attributesAtIndexEffectiveRange(
    index, aRange, [self length], infoArray, NULL);
}

- (void) dealloc
{
  RELEASE(textChars);
  RELEASE(infoArray);
  [super dealloc];
}

@end


@implementation NSGMutableAttributedString

+ (void) initialize
{
  if (infCls == 0)
    {
      infCls = [GSAttrInfo class];
      infImp = [infCls methodForSelector: infSel];
    }
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfObjCType: @encode(id) at: &textChars];
  [aCoder encodeValueOfObjCType: @encode(id) at: &infoArray];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  self = [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(id) at: &textChars];
  [aCoder decodeValueOfObjCType: @encode(id) at: &infoArray];
  return self;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = [self zone];

  infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
  if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
      NSAttributedString	*as = (NSAttributedString*)aString;

      aString = [as string];
      _setAttributesFrom(as, NSMakeRange(0, [aString length]), infoArray);
    }
  else
    {
      GSAttrInfo	*info;

      info = (*infImp)(infCls, infSel, z, attributes, 0);
      [infoArray addObject: info];
      RELEASE(info);
    }
  if (aString == nil)
    textChars = [[NSMutableString alloc] init];
  else
    textChars = [aString mutableCopyWithZone: z];
  return self;
}

- (NSString*) string
{
  return textChars;
}

- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange
{
  return _attributesAtIndexEffectiveRange(
    index, aRange, [self length], infoArray, NULL);
}

- (void) setAttributes: (NSDictionary*)attributes
		 range: (NSRange)range
{
  unsigned	tmpLength, arrayIndex, arraySize, location;
  NSRange	effectiveRange;
  unsigned	afterRangeLoc, beginRangeLoc;
  NSDictionary	*attrs;
  NSZone	*z = [self zone];
  GSAttrInfo	*info;

  if (!attributes)
    attributes = [NSDictionary dictionary];
  tmpLength = [self length];
  if (NSMaxRange(range) > tmpLength)
    {
      [NSException raise: NSRangeException
		  format: @"RangeError in method -replaceCharactersInRange: "
			  @"withString: in class NSMutableAttributedString"];
    }
  arraySize = [infoArray count];
  if (NSMaxRange(range) < tmpLength)
    {
      attrs = _attributesAtIndexEffectiveRange(
	NSMaxRange(range), &effectiveRange, tmpLength, infoArray, &arrayIndex);

      afterRangeLoc = NSMaxRange(range);
      if (effectiveRange.location > range.location)
	{
	  info = [infoArray objectAtIndex: arrayIndex];
	  info->loc = afterRangeLoc;
	}
      else
	{
	  info = (*infImp)(infCls, infSel, z, attrs, afterRangeLoc);
	  [infoArray insertObject: info atIndex: ++arrayIndex];
	  RELEASE(info);
	}
      arrayIndex--;
    }
  else
    {
      arrayIndex = arraySize - 1;
    }
  
  while (arrayIndex > 0)
    {
      info = [infoArray objectAtIndex: arrayIndex-1];
      if (info->loc < range.location)
	break;
      [infoArray removeObjectAtIndex: arrayIndex];
      arrayIndex--;
    }

  beginRangeLoc = range.location;
  info = [infoArray objectAtIndex: arrayIndex];
  location = info->loc;
  if (location >= range.location)
    {
      if (location > range.location)
	{
	  info->loc = beginRangeLoc;
	}
      ASSIGN(info->attrs, attributes);
    }
  else
    {
      arrayIndex++;
      info = (*infImp)(infCls, infSel, z, attributes, beginRangeLoc);
      [infoArray insertObject: info atIndex: arrayIndex];
      RELEASE(info);
    }
  
  /*
   *	Primitive method! Sets attributes and values for a given range of
   *	characters, replacing any previous attributes and values for that
   *	range.
   */

  /*
   *	Sets the attributes for the characters in aRange to attributes.
   *	These new attributes replace any attributes previously associated
   *	with the characters in aRange. Raises an NSRangeException if any
   *	part of aRange lies beyond the end of the receiver's characters.
   *	See also: - addAtributes: range: , - removeAttributes: range:
   */
}

- (void) replaceCharactersInRange: (NSRange)range
		       withString: (NSString*)aString
{
  unsigned	tmpLength, arrayIndex, arraySize, cnt, location, moveLocations;
  NSRange	effectiveRange;
  NSDictionary	*attrs;
  unsigned	afterRangeLoc;
  GSAttrInfo	*info;
  NSZone	*z = [self zone];

  if (!aString)
    aString = @"";
  tmpLength = [self length];
  if (NSMaxRange(range) > tmpLength)
    {
      [NSException raise: NSRangeException
		  format: @"RangeError in method -replaceCharactersInRange: "
			  @"withString: in class NSMutableAttributedString"];
    }
  arraySize = [infoArray count];
  if (NSMaxRange(range) < tmpLength)
    {
      attrs = _attributesAtIndexEffectiveRange(
	NSMaxRange(range), &effectiveRange, tmpLength, infoArray, &arrayIndex);
      
      moveLocations = [aString length] - range.length;
      afterRangeLoc = NSMaxRange(range) + moveLocations;
      
      if (effectiveRange.location > range.location)
	{
	  info = [infoArray objectAtIndex: arrayIndex];
	  info->loc = afterRangeLoc;
	}
      else
	{
	  info = (*infImp)(infCls, infSel, z, attrs, afterRangeLoc);
	  [infoArray insertObject: info atIndex: ++arrayIndex];
	  arraySize++;
	  RELEASE(info);
	}

      /*
       * Everything after our modified range need to be shifted.
       */
      if (arrayIndex + 1 < arraySize)
	{
	  unsigned	l = arraySize - arrayIndex - 1;
	  NSRange	r = NSMakeRange(arrayIndex + 1, l);
	  GSAttrInfo	*objs[l];
	 
	  [infoArray getObjects: objs range: r];
	  for (cnt = 0; cnt < l; cnt++)
	    {
	      objs[cnt]->loc += moveLocations;
	    }
	}
      arrayIndex--;
    }
  else
    {
      arrayIndex = arraySize - 1;
    }

  while (arrayIndex > 0)
    {
      info = [infoArray objectAtIndex: arrayIndex];
      if (info->loc <= range.location)
	break;
      [infoArray removeObjectAtIndex: arrayIndex];
      arrayIndex--;
    }
  [textChars replaceCharactersInRange: range withString: aString];
}

- (void) dealloc
{
  RELEASE(textChars);
  RELEASE(infoArray);
  [super dealloc];
}

@end
