/* Implementation of composite character sequence functions for GNUSTEP
   Copyright (C) 1999 Free Software Foundation, Inc.
  
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: May 1999
   Based on code by:  Stevo Crvenkovski <stevo@btinternet.com>
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

/*
 *	Warning - this contains hairy code - handle with care.
 *	The first part of this file contains variable and constant definitions
 *	plus inline function definitions for handling sequences of unicode
 *	characters.  It is bracketed in preprocessor conditionals so that it
 *	is only ever included once.
 *	The second part of the file contains inline function definitions that
 *	are designed to be modified depending on the defined macros at the
 *	point where they are included.  This is meant to be included multiple
 *	times so the same code can be used for NSString, NSGString, and
 *	NSGCString objects.
 */

#ifndef __GSeq_h_GNUSTEP_BASE_INCLUDE
#define __GSeq_h_GNUSTEP_BASE_INCLUDE

/*
 *	Some standard selectors for frequently used methods.
 */
static SEL	caiSel = @selector(characterAtIndex:);
static SEL	gcrSel = @selector(getCharacters:range:);
static SEL	ranSel = @selector(rangeOfComposedCharacterSequenceAtIndex:);

/*
 *	The maximum decompostion level for composite unicode characters.
 */
#define MAXDEC 18

/*
 *	The structure definition for handling a unicode character sequence
 *	for a single character.
 */
typedef	struct {
  unichar	*chars;
  unsigned	count;
  unsigned	capacity;
  BOOL		normalized;
} GSeqStruct;
typedef	GSeqStruct	*GSeq;

/*
 *	A macro to define a GSeqStruct variable capable of holding a
 *	unicode character sequence of the specified length.
 */
#define	GSEQ_MAKE(BUF, SEQ, LEN) \
    unichar	BUF[LEN * MAXDEC + 1]; \
    GSeqStruct	SEQ = { BUF, LEN, LEN * MAXDEC, 0 }

/*
 *	A function to normalize a unicode character sequence.
 */
static inline void GSeq_normalize(GSeq seq)
{
  unsigned	count = seq->count;
  unichar	*source = seq->chars;

  if (count)
    {
      unichar	target[count*MAXDEC+1];
      BOOL	notdone = YES;

      while (notdone)
	{
	  unichar	*spoint = source;
	  unichar	*tpoint = target;

	  source[count] = (unichar)(0);
	  notdone = NO;
	  do
	    {
	      unichar	*dpoint = uni_is_decomp(*spoint);

	      if (!dpoint)
		{
		  *tpoint++ = *spoint;
		}
	      else
		{
		  while (*dpoint)
		    {
		      *tpoint++ = *dpoint++;
		    }
		  notdone = YES;
		}
	    }
	  while (*spoint++);

	  count = tpoint - target;
	  memcpy(source, target, 2*count);
	}

      seq->count = count;
      if (count > 1)
	{
	  notdone = YES;

	  while (notdone)
	    {
	      unichar	*first = seq->chars;
	      unichar	*second = first + 1;
	      unsigned	i;

	      notdone = NO;
	      for (i = 1; i < count; i++)
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
      seq->normalized = YES;
    }
}
 
/*
 *	A function to compare two unicode character sequences normalizing if
 *	required.
 */
static inline NSComparisonResult GSeq_compare(GSeq s0, GSeq s1)
{
  unsigned	i;
  unsigned	end;
  unsigned	len0;
  unsigned	len1;
  unichar	*c0 = s0->chars;
  unichar	*c1 = s1->chars;

  if (s0->normalized == NO)
    GSeq_normalize(s0);
  if (s1->normalized == NO)
    GSeq_normalize(s1);
  len0 = s0->count;
  len1 = s1->count;
  if (len0 < len1)
    end = len0;
  else
    end = len1;
  for (i = 0; i < end; i++)
    {
      if (c0[i] < c1[i])
	return NSOrderedAscending;
      if (c0[i] > c1[i])
	return NSOrderedDescending;
    }
  if (len0 < len1)
    return NSOrderedAscending;
  if (len0 > len1)
    return NSOrderedDescending;
  return NSOrderedSame;
}

static inline void GSeq_lowercase(GSeq seq)
{
  unichar	*s = seq->chars;
  unsigned	len = seq->count;
  unsigned	i;

  for (i = 0; i < len; i++)
    s[i] = uni_tolower(s[i]);
}

static inline void GSeq_uppercase(GSeq seq)
{
  unichar	*s = seq->chars;
  unsigned	len = seq->count;
  unsigned	i;

  for (i = 0; i < len; i++)
    s[i] = uni_toupper(s[i]);
}

/*
 * Specify NSString, NSGString or NSGCString
 */
#define	GSEQ_NS	0
#define	GSEQ_US	1
#define	GSEQ_CS	2

/*
 *	Structures to access NSGString and NSGCString ivars.
 */
typedef struct {
  @defs(NSGString)
} NSGStringStruct;

typedef struct {
  @defs(NSGCString)
} NSGCStringStruct;

/*
 * Definitions for bitmask of search options.  These MUST match the
 * enumeration in NSString.h
 */
#define FCLS  3
#define BCLS  7
#define FLS  2
#define BLS 6
#define FCS  1
#define BCS  5
#define FS  0
#define BS  4
#define FCLAS  11
#define BCLAS  15
#define FLAS  10
#define BLAS 14
#define FCAS  9
#define BCAS  13
#define FAS  8
#define BAS  12

#endif /* __GSeq_h_GNUSTEP_BASE_INCLUDE */

/*
 * Set up macros for dealing with 'self' on the basis of GSQ_S
 */
#if	GSEQ_S == GSEQ_US
#define	GSEQ_ST	NSGStringStruct*
#define	GSEQ_SLEN	s->_count
#define	GSEQ_SGETC(I)	s->_contents_chars[I]
#define	GSEQ_SGETR(B,R)	memcpy(B, &s->_contents_chars[R.location], 2*(R).length)
#define	GSEQ_SRANGE(I)	(*srImp)((id)s, ranSel, I)
#else
#if	GSEQ_S == GSEQ_CS
#define	GSEQ_ST	NSGCStringStruct*
#define	GSEQ_SLEN	s->_count
#define	GSEQ_SGETC(I)	(unichar)s->_contents_chars[I]
#define	GSEQ_SGETR(B,R)	( { \
  unsigned _lcount = 0; \
  while (_lcount < (R).length) \
    { \
      (B)[_lcount] = (unichar)s->_contents_chars[(R).location + _lcount]; \
      _lcount++; \
    } \
} )
#define	GSEQ_SRANGE(I)	(NSRange){I,1}
#else
#define	GSEQ_ST	NSString*
#define	GSEQ_SLEN	[s length]
#define	GSEQ_SGETC(I)	(*scImp)(s, caiSel, I)
#define	GSEQ_SGETR(B,R)	(*sgImp)(s, gcrSel, B, R)
#define	GSEQ_SRANGE(I)	(*srImp)(s, ranSel, I)
#endif
#endif

/*
 * Set up macros for dealing with 'other' string on the basis of GSQ_O
 */
#if	GSEQ_O == GSEQ_US
#define	GSEQ_OT	NSGStringStruct*
#define	GSEQ_OLEN	o->_count
#define	GSEQ_OGETC(I)	o->_contents_chars[I]
#define	GSEQ_OGETR(B,R)	memcpy(B, &o->_contents_chars[R.location], 2*(R).length)
#define	GSEQ_ORANGE(I)	(*orImp)((id)o, ranSel, I)
#else
#if	GSEQ_O == GSEQ_CS
#define	GSEQ_OT	NSGCStringStruct*
#define	GSEQ_OLEN	o->_count
#define	GSEQ_OGETC(I)	(unichar)o->_contents_chars[I]
#define	GSEQ_OGETR(B,R)	( { \
  unsigned _lcount = 0; \
  while (_lcount < (R).length) \
    { \
      (B)[_lcount] = (unichar)o->_contents_chars[(R).location + _lcount]; \
      _lcount++; \
    } \
} )
#define	GSEQ_ORANGE(I)	(NSRange){I,1}
#else
#define	GSEQ_OT	NSString*
#define	GSEQ_OLEN	[o length]
#define	GSEQ_OGETC(I)	(*ocImp)(o, caiSel, I)
#define	GSEQ_OGETR(B,R)	(*ogImp)(o, gcrSel, B, R)
#define	GSEQ_ORANGE(I)	(*orImp)(o, ranSel, I)
#endif
#endif

/*
 * If a string comparison function is required, implement it.
 */
#ifdef	GSEQ_STRCOMP
static inline NSComparisonResult
GSEQ_STRCOMP(NSString *ss, NSString *os, unsigned mask, NSRange aRange)
{
  GSEQ_ST	s = (GSEQ_ST)ss;
  GSEQ_OT	o = (GSEQ_OT)os;
  unsigned	oLength;			/* Length of other.	*/
  unsigned	sLength = GSEQ_SLEN;

  if (aRange.location > sLength)
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > (sLength - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];

  oLength = GSEQ_OLEN;
  if (sLength - aRange.location == 0)
    {
      if (oLength == 0)
	{
	  return NSOrderedSame;
	}
      return NSOrderedAscending;
    }
  else if (oLength == 0)
    {
      return NSOrderedDescending;
    }

  if (mask & NSLiteralSearch)
    {
      unsigned	i;
      unsigned	sLen = aRange.length;
      unsigned	oLen = oLength;
      unsigned	end;
#if	GSEQ_S == GSEQ_NS
      void	(*sgImp)(NSString*, SEL, unichar*, NSRange);
      unichar	sBuf[sLen];
#else
#if	GSEQ_S == GSEQ_US
      unichar	*sBuf;
#else
      char	*sBuf;
#endif
#endif
#if	GSEQ_O == GSEQ_NS
      void	(*ogImp)(NSString*, SEL, unichar*, NSRange);
      unichar	oBuf[oLen];
#else
#if	GSEQ_O == GSEQ_US
      unichar	*oBuf;
#else
      char	*oBuf;
#endif
#endif

#if	GSEQ_S == GSEQ_NS
      sgImp = (void (*)())[(id)s methodForSelector: gcrSel];
      GSEQ_SGETR(sBuf, aRange);
#else
      sBuf = &s->_contents_chars[aRange.location];
#endif
#if	GSEQ_O == GSEQ_NS
      ogImp = (void (*)())[(id)o methodForSelector: gcrSel];
      GSEQ_OGETR(oBuf, NSMakeRange(0, oLen));
#else
      oBuf = o->_contents_chars;
#endif

      if (oLen < sLen)
	end = oLen;
      else
	end = sLen;

      if (mask & NSCaseInsensitiveSearch)
	{
	  for (i = 0; i < end; i++)
	    {
	      unichar	c1 = uni_tolower((unichar)sBuf[i]);
	      unichar	c2 = uni_tolower((unichar)oBuf[i]);

	      if (c1 < c2)
		return NSOrderedAscending;
	      if (c1 > c2)
		return NSOrderedDescending;
	    }
	}
      else
	{
	  for (i = 0; i < end; i++)
	    {
	      if ((unichar)sBuf[i] < (unichar)oBuf[i])
		return NSOrderedAscending;
	      if ((unichar)sBuf[i] > (unichar)oBuf[i])
		return NSOrderedDescending;
	    }
	}
      if (sLen > oLen)
	return NSOrderedDescending;
      else if (sLen < oLen)
	return NSOrderedAscending;
      else
	return NSOrderedSame;
    }
  else
    {
      unsigned		start = aRange.location;
      unsigned		end = start + aRange.length;
      unsigned		sCount = start;
      unsigned		oCount = 0;
      NSComparisonResult result;
#if	GSEQ_S == GSEQ_NS || GSEQ_S == GSEQ_US
      NSRange		(*srImp)(NSString*, SEL, unsigned);
#endif
#if	GSEQ_O == GSEQ_NS || GSEQ_O == GSEQ_US
      NSRange		(*orImp)(NSString*, SEL, unsigned);
#endif
#if	GSEQ_S == GSEQ_NS
      void		(*sgImp)(NSString*, SEL, unichar*, NSRange);
#endif
#if	GSEQ_O == GSEQ_NS
      void		(*ogImp)(NSString*, SEL, unichar*, NSRange);
#endif

#if	GSEQ_S == GSEQ_NS || GSEQ_S == GSEQ_US
      srImp = (NSRange (*)())[(id)s methodForSelector: ranSel];
#endif
#if	GSEQ_O == GSEQ_NS || GSEQ_O == GSEQ_US
      orImp = (NSRange (*)())[(id)o methodForSelector: ranSel];
#endif
#if	GSEQ_S == GSEQ_NS
      sgImp = (void (*)())[(id)s methodForSelector: gcrSel];
#endif
#if	GSEQ_O == GSEQ_NS
      ogImp = (void (*)())[(id)o methodForSelector: gcrSel];
#endif


      while (sCount < end)
	{
	  if (oCount >= oLength)
	    {
	      return NSOrderedDescending;
	    }
	  else if (sCount >= sLength)
	    {
	      return NSOrderedAscending;
	    }
	  else
	    {
	      NSRange	sRange = GSEQ_SRANGE(sCount);
	      NSRange	oRange = GSEQ_ORANGE(oCount);
	      GSEQ_MAKE(sBuf, sSeq, sRange.length);
	      GSEQ_MAKE(oBuf, oSeq, oRange.length);

	      GSEQ_SGETR(sBuf, sRange);
	      GSEQ_OGETR(oBuf, oRange);

	      result = GSeq_compare(&sSeq, &oSeq);

	      if (result != NSOrderedSame)
		{
		  if (mask & NSCaseInsensitiveSearch)
		    {
		      GSeq_lowercase(&oSeq);
		      GSeq_lowercase(&sSeq);
		      result = GSeq_compare(&sSeq, &oSeq);
		      if (result != NSOrderedSame)
			{
			  return result;
			}
		    }
		  else
		    {
		      return result;
		    }
		}

	      sCount += sRange.length;
	      oCount += oRange.length;
	    }
	}
      if (oCount < oLength)
	return NSOrderedAscending;
      return NSOrderedSame;
   }
}
#undef	GSEQ_STRCOMP
#endif

/*
 * If a string search function is required, implement it.
 */
#ifdef	GSEQ_STRRANGE
static inline NSRange
GSEQ_STRRANGE(NSString *ss, NSString *os, unsigned mask, NSRange aRange)
{
  GSEQ_ST	s = (GSEQ_ST)ss;
  GSEQ_OT	o = (GSEQ_OT)os;
  unsigned	myLength;
  unsigned	myIndex;
  unsigned	myEndIndex;
  unsigned	strLength;
#if	GSEQ_S == GSEQ_NS
  unichar	(*scImp)(NSString*, SEL, unsigned);
  void		(*sgImp)(NSString*, SEL, unichar*, NSRange);
#endif
#if	GSEQ_O == GSEQ_NS
  unichar	(*ocImp)(NSString*, SEL, unsigned);
  void		(*ogImp)(NSString*, SEL, unichar*, NSRange);
#endif
#if	GSEQ_S == GSEQ_NS || GSEQ_S == GSEQ_US
  NSRange	(*srImp)(NSString*, SEL, unsigned);
#endif
#if	GSEQ_O == GSEQ_NS || GSEQ_O == GSEQ_US
  NSRange	(*orImp)(NSString*, SEL, unsigned);
#endif
  
  /* Check that the search range is reasonable */
  myLength = GSEQ_SLEN;
  if (aRange.location > myLength)
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > (myLength - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];


  /* Ensure the string can be found */
  strLength = GSEQ_OLEN;
  if (strLength > aRange.length || strLength == 0)
    return (NSRange){0, 0};

  /*
   * Cache method implementations for getting characters and ranges
   */
#if	GSEQ_S == GSEQ_NS
  scImp = (unichar (*)())[(id)s methodForSelector: caiSel];
  sgImp = (void (*)())[(id)s methodForSelector: gcrSel];
#endif
#if	GSEQ_O == GSEQ_NS
  ocImp = (unichar (*)())[(id)o methodForSelector: caiSel];
  ogImp = (void (*)())[(id)o methodForSelector: gcrSel];
#endif
#if	GSEQ_S == GSEQ_NS || GSEQ_S == GSEQ_US
  srImp = (NSRange (*)())[(id)s methodForSelector: ranSel];
#endif
#if	GSEQ_O == GSEQ_NS || GSEQ_O == GSEQ_US
  orImp = (NSRange (*)())[(id)o methodForSelector: ranSel];
#endif

  switch (mask)
    {
      case FCLS : 
      case FCLAS : 
	{
	  unichar	strFirstCharacter = GSEQ_OGETC(0);

	  myIndex = aRange.location;
	  myEndIndex = aRange.location + aRange.length - strLength;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  for (;;)
	    {
	      unsigned	i = 1;
	      unichar	myCharacter = GSEQ_SGETC(myIndex);
	      unichar	strCharacter = strFirstCharacter;

	      for (;;)
		{
		  if ((myCharacter != strCharacter) &&
		      ((uni_tolower(myCharacter) != uni_tolower(strCharacter))))
		    break;
		  if (i == strLength)
		    return (NSRange){myIndex, strLength};
		  myCharacter = GSEQ_SGETC(myIndex + i);
		  strCharacter = GSEQ_OGETC(i);
		  i++;
		}
	      if (myIndex == myEndIndex)
		break;
	      myIndex++;
	    }
	  return (NSRange){0, 0};
	}

      case BCLS : 
      case BCLAS : 
	{
	  unichar	strFirstCharacter = GSEQ_OGETC(0);

	  myIndex = aRange.location + aRange.length - strLength;
	  myEndIndex = aRange.location;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  for (;;)
	    {
	      unsigned	i = 1;
	      unichar	myCharacter = GSEQ_SGETC(myIndex);
	      unichar	strCharacter = strFirstCharacter;

	      for (;;)
		{
		  if ((myCharacter != strCharacter) &&
		      ((uni_tolower(myCharacter) != uni_tolower(strCharacter))))
		    break;
		  if (i == strLength)
		    return (NSRange){myIndex, strLength};
		  myCharacter = GSEQ_SGETC(myIndex + i);
		  strCharacter = GSEQ_OGETC(i);
		  i++;
		}
	      if (myIndex == myEndIndex)
		break;
	      myIndex--;
	    }
	  return (NSRange){0, 0};
	}

      case FLS : 
      case FLAS : 
	{
	  unichar	strFirstCharacter = GSEQ_OGETC(0);

	  myIndex = aRange.location;
	  myEndIndex = aRange.location + aRange.length - strLength;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  for (;;)
	    {
	      unsigned	i = 1;
	      unichar	myCharacter = GSEQ_SGETC(myIndex);
	      unichar	strCharacter = strFirstCharacter;

	      for (;;)
		{
		  if (myCharacter != strCharacter)
		    break;
		  if (i == strLength)
		    return (NSRange){myIndex, strLength};
		  myCharacter = GSEQ_SGETC(myIndex + i);
		  strCharacter = GSEQ_OGETC(i);
		  i++;
		}
	      if (myIndex == myEndIndex)
		break;
	      myIndex++;
	    }
	  return (NSRange){0, 0};
	}

      case BLS : 
      case BLAS : 
	{
	  unichar	strFirstCharacter = GSEQ_OGETC(0);

	  myIndex = aRange.location + aRange.length - strLength;
	  myEndIndex = aRange.location;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  for (;;)
	    {
	      unsigned	i = 1;
	      unichar	myCharacter = GSEQ_SGETC(myIndex);
	      unichar	strCharacter = strFirstCharacter;

	      for (;;)
		{
		  if (myCharacter != strCharacter)
		    break;
		  if (i == strLength)
		    return (NSRange){myIndex, strLength};
		  myCharacter = GSEQ_SGETC(myIndex + i);
		  strCharacter = GSEQ_OGETC(i);
		  i++;
		}
	      if (myIndex == myEndIndex)
		break;
	      myIndex--;
	    }
	  return (NSRange){0, 0};
	}

      case FCS : 
      case FCAS : 
	{
	  unsigned	strBaseLength;
	  NSRange	iRange;

	  strBaseLength = [(NSString*)o _baseLength];

	  myIndex = aRange.location;
	  myEndIndex = aRange.location + aRange.length - strBaseLength;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  iRange = GSEQ_ORANGE(0);
	  if (iRange.length)
	    {
	      GSEQ_MAKE(iBuf, iSeq, iRange.length);

	      GSEQ_OGETR(iBuf, iRange);
	      GSeq_lowercase(&iSeq);

	      for (;;)
		{
		  NSRange	sRange = GSEQ_SRANGE(myIndex);
		  GSEQ_MAKE(sBuf, sSeq, sRange.length);

		  GSEQ_SGETR(sBuf, sRange);
		  GSeq_lowercase(&sSeq);

		  if (GSeq_compare(&iSeq, &sSeq) == NSOrderedSame)
		    {
		      unsigned	myCount = sRange.length;
		      unsigned	strCount = iRange.length;

		      if (strCount >= strLength)
			{
			  return (NSRange){myIndex, myCount};
			}
		      for (;;)
			{
			  NSRange	r0 = GSEQ_SRANGE(myIndex + myCount);
			  GSEQ_MAKE(b0, s0, r0.length);
			  NSRange	r1 = GSEQ_ORANGE(strCount);
			  GSEQ_MAKE(b1, s1, r1.length);

			  GSEQ_SGETR(b0, r0);
			  GSEQ_OGETR(b1, r1);

			  if (GSeq_compare(&s0, &s1) != NSOrderedSame)
			    {
			      GSeq_lowercase(&s0);
			      GSeq_lowercase(&s1);
			      if (GSeq_compare(&s0, &s1) != NSOrderedSame)
				{
				  break;
				}
			    }
			  myCount += r0.length;
			  strCount += r1.length;
			  if (strCount >= strLength)
			    {
			      return (NSRange){myIndex, myCount};
			    }
			}
		    }
		  myIndex += sRange.length;
		  if (myIndex > myEndIndex)
		    break;
		}
	    }
	  return (NSRange){0, 0};
	}

      case BCS : 
      case BCAS : 
	{
	  unsigned	strBaseLength;
	  NSRange	iRange;

	  strBaseLength = [(NSString*)o _baseLength];

	  myIndex = aRange.location + aRange.length - strBaseLength;
	  myEndIndex = aRange.location;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  iRange = GSEQ_ORANGE(0);
	  if (iRange.length)
	    {
	      GSEQ_MAKE(iBuf, iSeq, iRange.length);

	      GSEQ_OGETR(iBuf, iRange);
	      GSeq_lowercase(&iSeq);

	      for (;;)
		{
		  NSRange	sRange = GSEQ_SRANGE(myIndex);
		  GSEQ_MAKE(sBuf, sSeq, sRange.length);

		  GSEQ_SGETR(sBuf, sRange);
		  GSeq_lowercase(&sSeq);

		  if (GSeq_compare(&iSeq, &sSeq) == NSOrderedSame)
		    {
		      unsigned	myCount = sRange.length;
		      unsigned	strCount = iRange.length;

		      if (strCount >= strLength)
			{
			  return (NSRange){myIndex, myCount};
			}
		      for (;;)
			{
			  NSRange	r0 = GSEQ_SRANGE(myIndex + myCount);
			  GSEQ_MAKE(b0, s0, r0.length);
			  NSRange	r1 = GSEQ_ORANGE(strCount);
			  GSEQ_MAKE(b1, s1, r1.length);

			  GSEQ_SGETR(b0, r0);
			  GSEQ_OGETR(b1, r1);

			  if (GSeq_compare(&s0, &s1) != NSOrderedSame)
			    {
			      GSeq_lowercase(&s0);
			      GSeq_lowercase(&s1);
			      if (GSeq_compare(&s0, &s1) != NSOrderedSame)
				{
				  break;
				}
			    }
			  myCount += r0.length;
			  strCount += r1.length;
			  if (strCount >= strLength)
			    {
			      return (NSRange){myIndex, myCount};
			    }
			}
		    }
		  if (myIndex < myEndIndex)
		    break;
		  myIndex--;
		  while (uni_isnonsp(GSEQ_SGETC(myIndex))
		    && (myIndex > 0))
		    myIndex--;
		}
	    }
	  return (NSRange){0, 0};
	}

      case BS : 
      case BAS : 
	{
	  unsigned	strBaseLength;
	  NSRange	iRange;

	  strBaseLength = [(NSString*)o _baseLength];

	  myIndex = aRange.location + aRange.length - strBaseLength;
	  myEndIndex = aRange.location;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  iRange = GSEQ_ORANGE(0);
	  if (iRange.length)
	    {
	      GSEQ_MAKE(iBuf, iSeq, iRange.length);

	      GSEQ_OGETR(iBuf, iRange);

	      for (;;)
		{
		  NSRange	sRange = GSEQ_SRANGE(myIndex);
		  GSEQ_MAKE(sBuf, sSeq, sRange.length);

		  GSEQ_SGETR(sBuf, sRange);

		  if (GSeq_compare(&iSeq, &sSeq) == NSOrderedSame)
		    {
		      unsigned	myCount = sRange.length;
		      unsigned	strCount = iRange.length;

		      if (strCount >= strLength)
			{
			  return (NSRange){myIndex, myCount};
			}
		      for (;;)
			{
			  NSRange	r0 = GSEQ_SRANGE(myIndex + myCount);
			  GSEQ_MAKE(b0, s0, r0.length);
			  NSRange	r1 = GSEQ_ORANGE(strCount);
			  GSEQ_MAKE(b1, s1, r1.length);

			  GSEQ_SGETR(b0, r0);
			  GSEQ_OGETR(b1, r1);

			  if (GSeq_compare(&s0, &s1) != NSOrderedSame)
			    {
			      break;
			    }
			  myCount += r0.length;
			  strCount += r1.length;
			  if (strCount >= strLength)
			    {
			      return (NSRange){myIndex, myCount};
			    }
			}
		    }
		  if (myIndex < myEndIndex)
		    break;
		  myIndex--;
		  while (uni_isnonsp(GSEQ_SGETC(myIndex))
		    && (myIndex > 0))
		    myIndex--;
		}
	    }
	  return (NSRange){0, 0};
	}

      case FS : 
      case FAS : 
      default : 
	{
	  unsigned	strBaseLength;
	  NSRange	iRange;

	  strBaseLength = [(NSString*)o _baseLength];

	  myIndex = aRange.location;
	  myEndIndex = aRange.location + aRange.length - strBaseLength;

	  if (mask & NSAnchoredSearch)
	    myEndIndex = myIndex;

	  iRange = GSEQ_ORANGE(0);
	  if (iRange.length)
	    {
	      GSEQ_MAKE(iBuf, iSeq, iRange.length);

	      GSEQ_OGETR(iBuf, iRange);

	      for (;;)
		{
		  NSRange	sRange = GSEQ_SRANGE(myIndex);
		  GSEQ_MAKE(sBuf, sSeq, sRange.length);

		  GSEQ_SGETR(sBuf, sRange);

		  if (GSeq_compare(&iSeq, &sSeq) == NSOrderedSame)
		    {
		      unsigned	myCount = sRange.length;
		      unsigned	strCount = iRange.length;

		      if (strCount >= strLength)
			{
			  return (NSRange){myIndex, myCount};
			}
		      for (;;)
			{
			  NSRange	r0 = GSEQ_SRANGE(myIndex + myCount);
			  GSEQ_MAKE(b0, s0, r0.length);
			  NSRange	r1 = GSEQ_ORANGE(strCount);
			  GSEQ_MAKE(b1, s1, r1.length);

			  GSEQ_SGETR(b0, r0);
			  GSEQ_OGETR(b1, r1);

			  if (GSeq_compare(&s0, &s1) != NSOrderedSame)
			    {
			      break;
			    }
			  myCount += r0.length;
			  strCount += r1.length;
			  if (strCount >= strLength)
			    {
			      return (NSRange){myIndex, myCount};
			    }
			}
		    }
		  myIndex += sRange.length;
		  if (myIndex > myEndIndex)
		    break;
		}
	    }
	  return (NSRange){0, 0};
	}
    }
  return (NSRange){0, 0};
}
#undef	GSEQ_STRRANGE
#endif

/*
 * Clean up macro namespace
 */
#ifdef	GSEQ_S
#undef	GSEQ_SLEN
#undef	GSEQ_SGETC
#undef	GSEQ_SGETR
#undef	GSEQ_SRANGE
#undef	GSEQ_ST
#undef	GSEQ_S
#endif

#ifdef	GSEQ_O
#undef	GSEQ_OLEN
#undef	GSEQ_OGETC
#undef	GSEQ_OGETR
#undef	GSEQ_ORANGE
#undef	GSEQ_OT
#undef	GSEQ_O
#endif

