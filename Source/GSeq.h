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

#define MAXDEC 18

typedef	struct {
  unichar	*chars;
  unsigned	count;
  unsigned	capacity;
  BOOL		normalized;
} GSeqStruct;

typedef	GSeqStruct	*GSeq;

#define	GSEQ_MAKE(BUF, SEQ, LEN) \
    unichar	BUF[LEN * MAXDEC + 1]; \
    GSeqStruct	SEQ = { BUF, LEN, LEN * MAXDEC, 0 }

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

