/* Support functions for Unicode implementation
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski <stevoc@lotus.mpt.com.mk>
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

#include <Foundation/NSString.h>

struct _ucc_ {unichar from; char to;};

#include "unicode/cyrillic.h"
#include "unicode/nextstep.h"
#include "unicode/caseconv.h"
#include "unicode/cop.h"
#include "unicode/decomp.h"

#define FALSE 0
#define TRUE 1

unichar encode_chartouni(char c, NSStringEncoding enc)
{
    /* All that I could find in Next documentation
      on NSNonLossyASCIIStringEncoding was <<forthcoming>>. */
    if((enc==NSNonLossyASCIIStringEncoding)
      || (enc==NSASCIIStringEncoding)
      || (enc==NSISOLatin1StringEncoding))
        return (unichar)c;

    if((enc==NSNEXTSTEPStringEncoding))
      if((unsigned char)c<Next_conv_base)
        return (unichar)c;
      else
        return(Next_char_to_uni_table[(unsigned char)c - Next_conv_base]);

    if((enc==NSCyrillicStringEncoding))
      if((unsigned char)c<Cyrillic_conv_base)
        return (unichar)c;
      else
        return(Cyrillic_char_to_uni_table[(unsigned char)c - Cyrillic_conv_base]);

#if 0
    if((enc==NSSymbolStringEncoding))
      if((unsigned char)c<Symbol_conv_base)
        return (unichar)c;
      else
        return(Symbol_char_to_uni_table[(unsigned char)c - Symbol_conv_base]);
#endif

  return 0;
}

char encode_unitochar(unichar u, NSStringEncoding enc)
{
  int res;
  int i=0;

    if((enc==NSNonLossyASCIIStringEncoding)
      || (enc==NSASCIIStringEncoding))
          if(u<128)
            return (char)u;
          else
            return 0;


    if((enc==NSISOLatin1StringEncoding))
          if(u<256)
            return (char)u;
          else
            return 0;

    if((enc== NSNEXTSTEPStringEncoding))
          if(u<(unichar)Next_conv_base)
            return (char)u;
          else
          {
             while(((res=u-Next_uni_to_char_table[i++].from)>0) & (i<Next_uni_to_char_table_size));
             return res?0:Next_uni_to_char_table[--i].to;
          }

    if((enc==NSCyrillicStringEncoding))
          if(u<(unichar)Cyrillic_conv_base)
            return (char)u;
          else
          {
             while(((res=u-Cyrillic_uni_to_char_table[i++].from)>0) & (i<Cyrillic_uni_to_char_table_size));
             return res?0:Cyrillic_uni_to_char_table[--i].to;
          }

#if 0
    if((enc==NSSymbolStringEncoding))
          if(u<(unichar)Symbol_conv_base)
            return (char)u;
          else
          {
             while(((res=u-Symbol_uni_to_char_table[i++].from)>0) & (i<Symbol_uni_to_char_table_size));
             return res?'*':Symbol_uni_to_char_table[--i].to;
          }
#endif

    return 0;
}

unichar chartouni(char c)
{
  NSStringEncoding enc = [NSString defaultCStringEncoding];
  return encode_chartouni(c, enc);
}

char unitochar(unichar u)
{
  unsigned char res;
  NSStringEncoding enc = [NSString defaultCStringEncoding];
  if((res=encode_unitochar(u, enc)))
    return res;
  else
    return '*';
}

int strtoustr(unichar * u1,const char *s1,int size)
 {
   int count;
  for(count=0;(s1[count]!=0)&(count<size);count++)
    u1[count]=chartouni(s1[count]);
  return count;
 }
 
int ustrtostr(char *s2,unichar *u1,int size)
  {
   int count;
   for(count=0;count<size;count++)
    s2[count]=unitochar(u1[count]);
   return(count);
  }

/* Be carefull if you use this. Unicode arrays returned by
   -getCharacters methods are not zero terminated */
int
uslen (unichar *u)
{
  int len = 0;
  while (u[len] != 0)
    {
      if (u[++len] == 0)
	return len;
      ++len;
    }
  return len;
}

unichar uni_tolower(unichar ch)
{
  int res;
  int count=0;
  while(((res=ch - t_tolower[count++][0])>0)&(count<t_len_tolower));
  return res?ch:t_tolower[--count][1];
 }
 
 unichar uni_toupper(unichar ch)
{
  int res;
  int count=0;
  while(((res=ch - t_toupper[count++][0])>0)&(count<t_len_toupper));
  return res?ch:t_toupper[--count][1];
 }

unsigned char uni_cop(unichar u)
{
  unichar count,first,last,comp;
  BOOL notfound;

  first = 0;
  last = uni_cop_table_size;
  notfound = TRUE;
  count=0;

  if(u > (unichar)0x0080)  // no nonspacing in ascii
  {
    while(notfound & (first <= last))
    {
        if(!(first==last))
        {
           count = (first + last) / 2;
           comp=uni_cop_table[count].code;
           if(comp < u)
             first = count+1;
           else
             if(comp > u)
               last = count-1;
             else
               notfound = FALSE;
        }
        else  /* first==last */
        {
           if(u == uni_cop_table[first].code)
             return uni_cop_table[first].cop;
           return 0;
        } /* else */
    } /* while notfound ...*/
    return notfound?0:uni_cop_table[count].cop;
  }
  else /* u is ascii */
    return 0;
}

BOOL uni_isnonsp(unichar u)
{
#define TRUE 1
#define FALSE 0
// check is uni_cop good for this
  if(uni_cop(u))
    return TRUE;
  else
    return FALSE;
}

unichar *uni_is_decomp(unichar u)
{
  unichar count,first,last,comp;
  BOOL notfound;

  first = 0;
  last = uni_dec_table_size;
  notfound = TRUE;
  count=0;

  if(u > (unichar)0x0080)  // no composites in ascii
  {
    while(notfound & (first <= last))
    {
        if(!(first==last))
        {
           count = (first + last) / 2;
           comp=uni_dec_table[count].code;
           if(comp < u)
             first = count+1;
           else
             if(comp > u)
               last = count-1;
             else
               notfound = FALSE;
        }
        else  /* first==last */
        {
           if(u == uni_dec_table[first].code)
             return uni_dec_table[first].decomp;
           return 0;
        } /* else */
    } /* while notfound ...*/
    return notfound?0:uni_dec_table[count].decomp;
  }
  else /* u is ascii */
    return 0;
}

