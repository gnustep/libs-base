  /* Support functions for Unicode implementation
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski < stevo@btinternet.com >
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include <config.h>
#include <Foundation/NSString.h>

struct _ucc_ {unichar from; char to;};

#include "unicode/cyrillic.h"
#include "unicode/latin2.h"
#include "unicode/nextstep.h"
#include "unicode/caseconv.h"
#include "unicode/cop.h"
#include "unicode/decomp.h"

typedef	unsigned char	unc;
static NSStringEncoding	defEnc = GSUndefinedEncoding;

unichar
encode_chartouni(char c, NSStringEncoding enc)
{
  /* All that I could find in Next documentation
    on NSNonLossyASCIIStringEncoding was << forthcoming >>. */
  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case NSISOLatin1StringEncoding:
	return (unichar)((unc)c);

      case NSNEXTSTEPStringEncoding:
	if ((unc)c < Next_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Next_char_to_uni_table[(unc)c - Next_conv_base]);

      case NSCyrillicStringEncoding:
	if ((unc)c < Cyrillic_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Cyrillic_char_to_uni_table[(unc)c - Cyrillic_conv_base]);

      case NSISOLatin2StringEncoding:
	if ((unc)c < Latin2_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Latin2_char_to_uni_table[(unc)c - Latin2_conv_base]);

#if 0
      case NSSymbolStringEncoding:
	if ((unc)c < Symbol_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Symbol_char_to_uni_table[(unc)c - Symbol_conv_base]);
#endif

      default:
	return 0;
    }
}

char
encode_unitochar(unichar u, NSStringEncoding enc)
{
  int	res;
  int	i = 0;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
	if (u < 128)
	  return (char)u;
	else
	  return 0;

      case NSISOLatin1StringEncoding:
	if (u < 256)
	  return (char)u;
	else
	  return 0;

      case NSNEXTSTEPStringEncoding:
	if (u < (unichar)Next_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Next_uni_to_char_table[i++].from) > 0)
	      && (i < Next_uni_to_char_table_size));
	    return res ? 0 : Next_uni_to_char_table[--i].to;
	  }

      case NSCyrillicStringEncoding:
	if (u < (unichar)Cyrillic_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Cyrillic_uni_to_char_table[i++].from) > 0)
	      && (i < Cyrillic_uni_to_char_table_size));
	    return res ? 0 : Cyrillic_uni_to_char_table[--i].to;
	  }

      case NSISOLatin2StringEncoding:
	if (u < (unichar)Latin2_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
	      && (i < Latin2_uni_to_char_table_size));
	    return res ? 0 : Latin2_uni_to_char_table[--i].to;
	  }

#if 0
      case NSSymbolStringEncoding:
	if (u < (unichar)Symbol_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
	      && (i < Symbol_uni_to_char_table_size));
	    return res ? '*' : Symbol_uni_to_char_table[--i].to;
	  }
#endif

      default:
	return 0;
    }
}

unichar
chartouni(char c)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }
  return encode_chartouni(c, defEnc);
}

char
unitochar(unichar u)
{
  unc				res;

  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }
  if ((res = encode_unitochar(u, defEnc)))
    {
      return res;
    }
  else
    {
      return '*';
    }
}

int
strtoustr(unichar *u1, const char *s1, int size)
{
  int count;

  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }
  for (count = 0; (count < size) && (s1[count] != 0); count++)
    {
      u1[count] = encode_chartouni(s1[count], defEnc);
    }
  return count;
}
 
int
ustrtostr(char *s2, unichar *u1, int size)
{
  int count;

  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }
  for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
    {
      s2[count] = encode_unitochar(u1[count], defEnc);
    }
  return count;
}
 
int
encode_strtoustr(unichar *u1, const char *s1, int size, NSStringEncoding enc)
{
  int count;

  for (count = 0; (count < size) && (s1[count] != 0); count++)
    {
      u1[count] = encode_chartouni(s1[count], enc);
    }
  return count;
}

int
encode_ustrtostr(char *s2, unichar *u1, int size, NSStringEncoding enc)
{
  int count;

  for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
    {
      s2[count] = encode_unitochar(u1[count], enc);
    }
  return count;
}

unichar
uni_tolower(unichar ch)
{
  int res;
  int count = 0;

  while (((res = ch - t_tolower[count++][0]) > 0) && (count < t_len_tolower));
  return res ? ch : t_tolower[--count][1];
}
 
unichar
uni_toupper(unichar ch)
{
  int res;
  int count = 0;

  while (((res = ch - t_toupper[count++][0]) > 0) && (count < t_len_toupper));
  return res ? ch : t_toupper[--count][1];
}

unsigned char
uni_cop(unichar u)
{
  unichar	count, first, last, comp;
  BOOL		notfound;

  first = 0;
  last = uni_cop_table_size;
  notfound = YES;
  count = 0;

  if (u > (unichar)0x0080)  // no nonspacing in ascii
    {
      while (notfound && (first <= last))
	{
	  if (first != last)
	    {
	      count = (first + last) / 2;
	      comp = uni_cop_table[count].code;
	      if (comp < u)
		{
		  first = count+1;
		}
	      else
		{
		  if (comp > u)
		    last = count-1;
		  else
		    notfound = NO;
		}
	    }
	  else  /* first == last */
	    {
	      if (u == uni_cop_table[first].code)
		return uni_cop_table[first].cop;
	      return 0;
	    } /* else */
	} /* while notfound ...*/
      return notfound ? 0 : uni_cop_table[count].cop;
    }
  else /* u is ascii */
    return 0;
}

BOOL
uni_isnonsp(unichar u)
{
// check is uni_cop good for this
  if (uni_cop(u))
    return YES;
  else
    return NO;
}

unichar*
uni_is_decomp(unichar u)
{
  unichar	count, first, last, comp;
  BOOL		notfound;

  first = 0;
  last = uni_dec_table_size;
  notfound = YES;
  count = 0;

  if (u > (unichar)0x0080)  // no composites in ascii
    {
      while (notfound && (first <= last))
	{
	  if (!(first == last))
	    {
	      count = (first + last) / 2;
	      comp = uni_dec_table[count].code;
	      if (comp < u)
		first = count+1;
	      else
		{
		  if (comp > u)
		    last = count-1;
		  else
		    notfound = NO;
		}
	    }
	  else  /* first == last */
	    {
	      if (u == uni_dec_table[first].code)
		return uni_dec_table[first].decomp;
	      return 0;
	    } /* else */
	} /* while notfound ...*/
      return notfound ? 0 : uni_dec_table[count].decomp;
    }
  else /* u is ascii */
    return 0;
}

