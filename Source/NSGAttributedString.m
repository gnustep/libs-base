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
#include <Foundation/NSGAttributedString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSZone.h>

#define		SANITY_CHECKS	0

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
  info->attrs = [a copyWithZone: z];
  return info;
}

- (void) dealloc
{
  RELEASE(attrs);
  NSDeallocateObject(self);
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Attributes at %u are - %@",
    loc, attrs];
}

@end



@implementation NSGAttributedString

static Class	infCls = 0;

static SEL	infSel;
static SEL	addSel;
static SEL	cntSel;
static SEL	insSel;
static SEL	oatSel;
static SEL	remSel;

static IMP	infImp;
static void	(*addImp)();
static unsigned (*cntImp)();
static void	(*insImp)();
static IMP	oatImp;
static void	(*remImp)();

#define	NEWINFO(Z,O,L)	((*infImp)(infCls, infSel, (Z), (O), (L)))
#define	ADDOBJECT(O)	((*addImp)(_infoArray, addSel, (O)))
#define	INSOBJECT(O,I)	((*insImp)(_infoArray, insSel, (O), (I)))
#define	OBJECTAT(I)	((*oatImp)(_infoArray, oatSel, (I)))
#define	REMOVEAT(I)	((*remImp)(_infoArray, remSel, (I)))

static void _setup()
{
  if (infCls == 0)
    {
      NSMutableArray	*a;

      infSel = @selector(newWithZone:value:at:);
      addSel = @selector(addObject:);
      cntSel = @selector(count);
      insSel = @selector(insertObject:atIndex:);
      oatSel = @selector(objectAtIndex:);
      remSel = @selector(removeObjectAtIndex:);

      infCls = [GSAttrInfo class];
      infImp = [infCls methodForSelector: infSel];

      a = [NSMutableArray allocWithZone: NSDefaultMallocZone()];
      a = [a initWithCapacity: 1];
      addImp = (void (*)())[a methodForSelector: addSel];
      cntImp = (unsigned (*)())[a methodForSelector: cntSel];
      insImp = (void (*)())[a methodForSelector: insSel];
      oatImp = [a methodForSelector: oatSel];
      remImp = (void (*)())[a methodForSelector: remSel];
      RELEASE(a);
    }
}

static void
_setAttributesFrom(
  NSAttributedString *attributedString,
  NSRange aRange,
  NSMutableArray *_infoArray)
{
  NSZone	*z = GSObjCZone(_infoArray);
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

  used = (*cntImp)(_infoArray, cntSel);
  NSCAssert(used > 0, NSInternalInconsistencyException);
  high = used - 1;

  if (index >= tmpLength)
    {
      if (index == tmpLength)
	{
	  found = OBJECTAT(high);
	  if (foundIndex != 0)
	    {
	      *foundIndex = high;
	    }
	  if (aRange != 0)
	    {
	      aRange->location = found->loc;
	      aRange->length = tmpLength - found->loc;
	    }
	  return found->attrs;
	}
      [NSException raise: NSRangeException
		  format: @"index is out of range in function "
			  @"_attributesAtIndexEffectiveRange()"];
    }
  
  /*
   * Binary search for efficiency in huge attributed strings
   */
  low = 0;
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
	      if (aRange != 0)
		{
		  aRange->location = found->loc;
		  aRange->length = nextLoc - found->loc;
		}
	      if (foundIndex != 0)
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

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = GSObjCZone(self);

  _infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
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
  return AUTORELEASE([_textChars copyWithZone: NSDefaultMallocZone()]);
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

#if	SANITY_CHECKS

#define	SANITY()	[self sanity]
	
- (void) sanity
{
  GSAttrInfo	*info;
  unsigned	i;
  unsigned	l = 0;
  unsigned	len = [_textChars length];
  unsigned	c = (*cntImp)(_infoArray, cntSel);

  NSAssert(c > 0, NSInternalInconsistencyException);
  info = OBJECTAT(0);
  NSAssert(info->loc == 0, NSInternalInconsistencyException);
  for (i = 1; i < c; i++)
    {
      info = OBJECTAT(i);
      NSAssert(info->loc > l, NSInternalInconsistencyException);
      NSAssert(info->loc <= len, NSInternalInconsistencyException);
      l = info->loc;
    }
}
#else
#define	SANITY()	
#endif

+ (void) initialize
{
  _setup();
}

- (id) initWithString: (NSString*)aString
	   attributes: (NSDictionary*)attributes
{
  NSZone	*z = GSObjCZone(self);

  _infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
  if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
      NSAttributedString	*as = (NSAttributedString*)aString;

      aString = [as string];
      _setAttributesFrom(as, NSMakeRange(0, [aString length]), _infoArray);
SANITY();
    }
  else
    {
      GSAttrInfo	*info;

      info = NEWINFO(z, attributes, 0);
      ADDOBJECT(info);
      RELEASE(info);
    }
  if (aString == nil)
    _textChars = [[NSMutableString allocWithZone: z] init];
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
  unsigned	tmpLength, arrayIndex, arraySize;
  NSRange	effectiveRange;
  unsigned	afterRangeLoc, beginRangeLoc;
  NSDictionary	*attrs;
  NSZone	*z = GSObjCZone(self);
  GSAttrInfo	*info;

  if (range.length == 0)
    {
      NSWarnMLog(@"Attempt to set attribute for zero-length range", 0);
      return;
    }
  if (attributes == nil)
    {
      attributes = [NSDictionary dictionary];
    }
SANITY();
  tmpLength = [_textChars length];
  GS_RANGE_CHECK(range, tmpLength);
  arraySize = (*cntImp)(_infoArray, cntSel);
  beginRangeLoc = range.location;
  afterRangeLoc = NSMaxRange(range);
  if (afterRangeLoc < tmpLength)
    {
      /*
       * Locate the first range that extends beyond our range.
       */
      attrs = _attributesAtIndexEffectiveRange(
	afterRangeLoc, &effectiveRange, tmpLength, _infoArray, &arrayIndex);
      if (effectiveRange.location > beginRangeLoc)
	{
	  /*
	   * The located range also starts at or after our range.
	   */
	  info = OBJECTAT(arrayIndex);
	  info->loc = afterRangeLoc;
	  arrayIndex--;
	}
      else
	{
	  /*
	   * The located range starts before our range.
	   * Create a subrange to go from our end to the end of the old range.
	   */
	  info = NEWINFO(z, attrs, afterRangeLoc);
	  arrayIndex++;
	  INSOBJECT(info, arrayIndex);
	  RELEASE(info);
	  arrayIndex--;
	}
    }
  else
    {
      arrayIndex = arraySize - 1;
    }
  
  /*
   * Remove any ranges completely within ours
   */
  while (arrayIndex > 0)
    {
      info = OBJECTAT(arrayIndex-1);
      if (info->loc < beginRangeLoc)
	break;
      REMOVEAT(arrayIndex);
      arrayIndex--;
    }

  info = OBJECTAT(arrayIndex);
  if (info->loc >= beginRangeLoc)
    {
      info->loc = beginRangeLoc;
      ASSIGNCOPY(info->attrs, attributes);
    }
  else
    {
      arrayIndex++;
      info = NEWINFO(z, attributes, beginRangeLoc);
      INSOBJECT(info, arrayIndex);
      RELEASE(info);
    }
  
SANITY();
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
  unsigned	tmpLength, arrayIndex, arraySize;
  NSRange	effectiveRange;
  NSDictionary	*attrs;
  GSAttrInfo	*info;
  int		moveLocations;
  NSZone	*z = GSObjCZone(self);
  unsigned	start;

SANITY();
  if (aString == nil)
    {
      aString = @"";
    }
  tmpLength = [_textChars length];
  GS_RANGE_CHECK(range, tmpLength);
  if (range.location == tmpLength)
    {
      /*
       * Special case - replacing a zero length string at the end
       * simply appends the new string and attributes are inherited.
       */
      [_textChars appendString: aString];
SANITY();
      return;
    }

  arraySize = (*cntImp)(_infoArray, cntSel);
  if (arraySize == 1)
    {
      /*
       * Special case - if the string has only one set of attributes
       * then the replacement characters will get them too.
       */
      [_textChars replaceCharactersInRange: range withString: aString];
SANITY();
      return;
    }

  /*
   * Get the attributes to associate with our replacement string.
   * Should be those of the first character replaced.
   * If the range replaced is empty, we use the attributes of the
   * previous character (if possible).
   */
  if (range.length == 0 && range.location > 0)
    start = range.location - 1;
  else
    start = range.location;
  attrs = _attributesAtIndexEffectiveRange(start, &effectiveRange,
    tmpLength, _infoArray, &arrayIndex);

  arrayIndex++;
  if (NSMaxRange(effectiveRange) > NSMaxRange(range))
    {
      info = NEWINFO(z, attrs, NSMaxRange(range));
      INSOBJECT(info, arrayIndex);
      arraySize++;
SANITY();
    }
  else if (NSMaxRange(effectiveRange) < NSMaxRange(range))
    {
      /*
       * Remove all range info for ranges enclosed within the one
       * we are replacing.  Adjust the start point of a range that
       * extends beyond ours.
       */
      info = OBJECTAT(arrayIndex);
      if (info->loc < NSMaxRange(range))
	{
	  int	next = arrayIndex + 1;

	  while (next < arraySize)
	    {
	      GSAttrInfo	*n = OBJECTAT(next);
	      if (n->loc <= NSMaxRange(range))
		{
		  REMOVEAT(arrayIndex);
		  arraySize--;
		  info = n;
		}
	      else
		{
		  break;
		}
	    }
	}
      info->loc = NSMaxRange(range);
    }

  moveLocations = [aString length] - range.length;
  if (effectiveRange.location == range.location
    && (moveLocations + range.length) == 0)
    {
      /*
       * If we are replacing a range with a zero length string and the
       * range we are using matches the range replaced, then we must
       * remove it from the array to avoid getting a zero length range.
       */
      arrayIndex--;
      REMOVEAT(arrayIndex);
      arraySize--;
    }

SANITY();
  /*
   * Now adjust the positions of the ranges following the one we are using.
   */
  while (arrayIndex < arraySize)
    {
      info = OBJECTAT(arrayIndex);
      info->loc += moveLocations;
      arrayIndex++;
    }
SANITY();
  [_textChars replaceCharactersInRange: range withString: aString];
SANITY();
}

- (void) dealloc
{
  RELEASE(_textChars);
  RELEASE(_infoArray);
  [super dealloc];
}

@end
