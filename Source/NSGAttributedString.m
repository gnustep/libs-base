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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
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
#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRange.h>
#include <base/NSGArray.h>
#include <base/fast.x>

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

static Class	infCls = 0;

static SEL	infSel = @selector(newWithZone:value:at:);
static IMP	infImp = 0;

static SEL	addSel = @selector(addObject:);
static void	(*addImp)() = 0;

static SEL	cntSel = @selector(count);
static unsigned (*cntImp)() = 0;

static SEL	insSel = @selector(insertObject:atIndex:);
static void	(*insImp)() = 0;

static SEL	oatSel = @selector(objectAtIndex:);
static IMP	oatImp = 0;

static SEL	remSel = @selector(removeObjectAtIndex:);
static void	(*remImp)() = 0;

#define	NEWINFO(Z,O,L)	((*infImp)(infCls, infSel, (Z), (O), (L)))
#define	ADDOBJECT(O)	((*addImp)(_infoArray, addSel, (O)))
#define	INSOBJECT(O,I)	((*insImp)(_infoArray, insSel, (O), (I)))
#define	OBJECTAT(I)	((*oatImp)(_infoArray, oatSel, (I)))
#define	REMOVEAT(I)	((*remImp)(_infoArray, remSel, (I)))

static void _setup()
{
  if (infCls == 0)
    {
      Class	c = [NSGMutableArray class];

      infCls = [GSAttrInfo class];
      infImp = [infCls methodForSelector: infSel];
      addImp = (void (*)())[c instanceMethodForSelector: addSel];
      cntImp = (unsigned (*)())[c instanceMethodForSelector: cntSel];
      insImp = (void (*)())[c instanceMethodForSelector: insSel];
      oatImp = [c instanceMethodForSelector: oatSel];
      remImp = (void (*)())[c instanceMethodForSelector: remSel];
    }
}

static void
_setAttributesFrom(
  NSAttributedString *attributedString,
  NSRange aRange,
  NSMutableArray *_infoArray)
{
  NSZone	*z = fastZone(_infoArray);
  NSRange	range;
  NSDictionary	*attr;
  GSAttrInfo	*info;
  unsigned	loc;

  /*
   * remove any old attributes of the string.
   */
  [_infoArray removeAllObjects];

  if (aRange.length <= 0)
    return;

  attr = [attributedString attributesAtIndex: aRange.location
			      effectiveRange: &range];
  info = [GSAttrInfo newWithZone: z value: attr at: 0];
  ADDOBJECT(info);
  RELEASE(info);

  while ((loc = NSMaxRange(range)) < NSMaxRange(aRange))
    {
      attr = [attributedString attributesAtIndex: loc
				  effectiveRange: &range];
      info = [GSAttrInfo newWithZone: z value: attr at: loc - aRange.location];
      ADDOBJECT(info);
      RELEASE(info);
    }
}

inline static NSDictionary*
_attributesAtIndexEffectiveRange(
  unsigned int index,
  NSRange *aRange,
  unsigned int tmpLength,
  NSMutableArray *_infoArray,
  unsigned int *foundIndex)
{
  unsigned	low, high, used, cnt, nextLoc;
  GSAttrInfo	*found = nil;

  if (index >= tmpLength)
    {
      if (index == tmpLength)
	{
	  *foundIndex = index;
	  return nil;
	}
      [NSException raise: NSRangeException
		  format: @"index is out of range in function "
			  @"_attributesAtIndexEffectiveRange()"];
    }
  
  used = (*cntImp)(_infoArray, cntSel);

  /*
   * Binary search for efficiency in huge attributed strings
   */
  low = 0;
  high = used - 1;
  while (low <= high)
    {
      cnt = (low + high) / 2;
      found = OBJECTAT(cnt);
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
	      GSAttrInfo	*inf = OBJECTAT(cnt + 1);

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
  _setup();
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
  [aCoder encodeValueOfObjCType: @encode(id) at: &_textChars];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_infoArray];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  self = [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_textChars];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_infoArray];
  return self;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = fastZone(self);

  _infoArray = [[NSGMutableArray allocWithZone: z] initWithCapacity: 1];
  if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
      NSAttributedString	*as = (NSAttributedString*)aString;

      aString = [as string];
      _setAttributesFrom(as, NSMakeRange(0, [aString length]), _infoArray);
    }
  else
    {
      GSAttrInfo	*info;

      info = NEWINFO(z, attributes, 0);
      ADDOBJECT(info);
      RELEASE(info);
    }
  if (aString == nil)
    _textChars = @"";
  else
    _textChars = [aString copyWithZone: z];
  return self;
}

- (NSString*) string
{
  return _textChars;
}

- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange
{
  return _attributesAtIndexEffectiveRange(
    index, aRange, [_textChars length], _infoArray, NULL);
}

- (void) dealloc
{
  RELEASE(_textChars);
  RELEASE(_infoArray);
  [super dealloc];
}

@end


@implementation NSGMutableAttributedString

+ (void) initialize
{
  _setup();
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
  [aCoder encodeValueOfObjCType: @encode(id) at: &_textChars];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_infoArray];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  self = [super initWithCoder: aCoder];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_textChars];
  [aCoder decodeValueOfObjCType: @encode(id) at: &_infoArray];
  return self;
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = fastZone(self);

  _infoArray = [[NSGMutableArray allocWithZone: z] initWithCapacity: 1];
  if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
      NSAttributedString	*as = (NSAttributedString*)aString;

      aString = [as string];
      _setAttributesFrom(as, NSMakeRange(0, [aString length]), _infoArray);
    }
  else
    {
      GSAttrInfo	*info;

      info = NEWINFO(z, attributes, 0);
      ADDOBJECT(info);
      RELEASE(info);
    }
  if (aString == nil)
    _textChars = [[NSGMutableString allocWithZone: z] init];
  else
    _textChars = [aString mutableCopyWithZone: z];
  return self;
}

- (NSString*) string
{
  return _textChars;
}

- (NSDictionary*) attributesAtIndex: (unsigned)index
		     effectiveRange: (NSRange*)aRange
{
  unsigned	dummy;
  return _attributesAtIndexEffectiveRange(
    index, aRange, [_textChars length], _infoArray, &dummy);
}

- (void) setAttributes: (NSDictionary*)attributes
		 range: (NSRange)range
{
  unsigned	tmpLength, arrayIndex, arraySize, location;
  NSRange	effectiveRange;
  unsigned	afterRangeLoc, beginRangeLoc;
  NSDictionary	*attrs;
  NSZone	*z = fastZone(self);
  GSAttrInfo	*info;

  if (!attributes)
    attributes = [NSDictionary dictionary];
  tmpLength = [_textChars length];
  GS_RANGE_CHECK(range, tmpLength);
  arraySize = (*cntImp)(_infoArray, cntSel);
  if (NSMaxRange(range) < tmpLength)
    {
      attrs = _attributesAtIndexEffectiveRange(
	NSMaxRange(range), &effectiveRange, tmpLength, _infoArray, &arrayIndex);

      afterRangeLoc = NSMaxRange(range);
      if (effectiveRange.location > range.location)
	{
	  info = OBJECTAT(arrayIndex);
	  info->loc = afterRangeLoc;
	}
      else
	{
	  info = NEWINFO(z, attrs, afterRangeLoc);
	  arrayIndex++;
	  INSOBJECT(info, arrayIndex);
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
      info = OBJECTAT(arrayIndex-1);
      if (info->loc < range.location)
	break;
      REMOVEAT(arrayIndex);
      arrayIndex--;
    }

  beginRangeLoc = range.location;
  info = OBJECTAT(arrayIndex);
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
      info = NEWINFO(z, attributes, beginRangeLoc);
      INSOBJECT(info, arrayIndex);
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
  unsigned	tmpLength, arrayIndex, arraySize, cnt, moveLocations;
  NSRange	effectiveRange;
  NSDictionary	*attrs;
  unsigned	afterRangeLoc;
  GSAttrInfo	*info;
  NSZone	*z = fastZone(self);

  if (!aString)
    aString = @"";
  tmpLength = [_textChars length];
  GS_RANGE_CHECK(range, tmpLength);
  arraySize = (*cntImp)(_infoArray, cntSel);
  if (NSMaxRange(range) < tmpLength)
    {
      attrs = _attributesAtIndexEffectiveRange(
	NSMaxRange(range), &effectiveRange, tmpLength, _infoArray, &arrayIndex);
      
      moveLocations = [aString length] - range.length;
      afterRangeLoc = NSMaxRange(range) + moveLocations;
      
      if (effectiveRange.location > range.location)
	{
	  info = OBJECTAT(arrayIndex);
	  info->loc = afterRangeLoc;
	}
      else
	{
	  info = NEWINFO(z, attrs, afterRangeLoc);
	  arrayIndex++;
	  INSOBJECT(info, arrayIndex);
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
	 
	  [_infoArray getObjects: objs range: r];
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
      info = OBJECTAT(arrayIndex);
      if (info->loc <= range.location)
	break;
      REMOVEAT(arrayIndex);
      arrayIndex--;
    }
  [_textChars replaceCharactersInRange: range withString: aString];
}

- (void) dealloc
{
  RELEASE(_textChars);
  RELEASE(_infoArray);
  [super dealloc];
}

@end
