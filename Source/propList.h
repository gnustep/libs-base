/* Text Property-List parsing code for NSString.m and NSGCString.m
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: October 1998

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
 *	Cache some commonly used character sets along with methods to
 *	check membership.
 */

static SEL		cMemberSel = @selector(characterIsMember:);

static NSCharacterSet	*hexdigits = nil;
static BOOL		(*hexdigitsImp)(id, SEL, unichar) = 0;
static void setupHexdigits()
{
  if (hexdigits == nil)
    {
      hexdigits = [NSCharacterSet characterSetWithCharactersInString:
	@"0123456789abcdef"];
      [hexdigits retain];
      hexdigitsImp =
	(BOOL(*)(id,SEL,unichar)) [hexdigits methodForSelector: cMemberSel];
    }
}

static NSCharacterSet	*quotables = nil;
static BOOL		(*quotablesImp)(id, SEL, unichar) = 0;
static void setupQuotables()
{
  if (quotables == nil)
    {
      NSMutableCharacterSet	*s;

      s = (NSMutableCharacterSet*)[NSMutableCharacterSet
	characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz$./_"];
      [s invert];
      quotables = [s copy];
      quotablesImp =
	(BOOL(*)(id,SEL,unichar)) [quotables methodForSelector: cMemberSel];
    }
}

static NSCharacterSet	*whitespce = nil;
static BOOL		(*whitespceImp)(id, SEL, unichar) = 0;
static void setupWhitespce()
{
  if (whitespce == nil)
    {
#if 0
      whitespce = [NSCharacterSet whitespaceAndNewlineCharacterSet];
#else
      whitespce = [NSMutableCharacterSet characterSetWithCharactersInString:
	@" \t\r\n\f\b"];
#endif
      [whitespce retain];
      whitespceImp =
	(BOOL(*)(id,SEL,unichar)) [whitespce methodForSelector: cMemberSel];
    }
}

@class	NSGMutableArray;
@class	NSGMutableDictionary;

static Class	plCls;
static Class	plArray;
static id	(*plAdd)(id, SEL, id);
static Class	plDictionary;
static id	(*plSet)(id, SEL, id, id);
static id	(*plInit)(id, SEL, void*, unsigned) = 0;
static id	(*plAlloc)(Class, SEL, NSZone*);
static id	(*plAutorelease)(id, SEL);
#if	GSPLUNI
static SEL	plSel = @selector(initWithCharacters:length:);
#else
static SEL	plSel = @selector(initWithCString:length:);
#endif

static void setupPl(Class c)
{
  if (plInit == 0)
    {
      plCls = c;
      plAlloc = (id (*)(id, SEL, NSZone*))
	[c methodForSelector: @selector(allocWithZone:)];
      plInit = (id (*)(id, SEL, void*, unsigned))
	[c instanceMethodForSelector: plSel];
      plAutorelease = (id (*)(id, SEL))
	[c instanceMethodForSelector: @selector(autorelease)];
      plArray = [NSGMutableArray class];
      plAdd = (id (*)(id, SEL, id))
	[plArray instanceMethodForSelector: @selector(addObject:)];
      plDictionary = [NSGMutableDictionary class];
      plSet = (id (*)(id, SEL, id, id))
	[plDictionary instanceMethodForSelector: @selector(setObject:forKey:)];
    }
  setupHexdigits();
  setupQuotables();
  setupWhitespce();
}


#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
#define char2num(ch) \
inrange(ch,'0','9') \
? ((ch)-0x30) \
: (inrange(ch,'a','f') \
? ((ch)-0x57) : ((ch)-0x37))

typedef	struct	{
#if	GSPLUNI
  const unichar	*ptr;
#else
  const char	*ptr;
#endif
  unsigned	end;
  unsigned	pos;
  unsigned	lin;
  NSString	*err;
} pldata;

/*
 *	Property list parsing - skip whitespace keeping count of lines and
 *	regarding objective-c style comments as whitespace.
 *	Returns YES if there is any non-whitespace text remaining.
 */
static BOOL skipSpace(pldata *pld)
{
  unichar	c;

  while (pld->pos < pld->end)
    {
      c = (unichar)pld->ptr[pld->pos];

      if ((*whitespceImp)(whitespce, cMemberSel, c) == NO)
	{
	  if (c == '/' && pld->pos < pld->end - 1)
	    {
	      /*
	       * Check for comments beginning '/' followed by '/' or '*'
	       */
	      if (pld->ptr[pld->pos + 1] == '/')
		{
		  pld->pos += 2;
		  while (pld->pos < pld->end)
		    {
		      c = pld->ptr[pld->pos];
		      if (c == '\n')
			break;
		      pld->pos++;
		    }
		  if (pld->pos >= pld->end)
		    {
		      pld->err = @"reached end of string in comment";
		      return NO;
		    }
		}
	      else if (pld->ptr[pld->pos + 1] == '*')
		{
		  pld->pos += 2;
		  while (pld->pos < pld->end)
		    {
		      c = pld->ptr[pld->pos];
		      if (c == '\n')
			pld->lin++;
		      else if (c == '*' && pld->pos < pld->end - 1
			&& pld->ptr[pld->pos+1] == '/')
			{
			  pld->pos++; /* Skip past '*'	*/
			  break;
			}
		      pld->pos++;
		    }
		  if (pld->pos >= pld->end)
		    {
		      pld->err = @"reached end of string in comment";
		      return NO;
		    }
		}
	      else
		return YES;
	    }
	  else
	    return YES;
	}
      if (c == '\n')
	pld->lin++;
      pld->pos++;
    }
  pld->err = @"reached end of string";
  return NO;
}

static inline id parseQuotedString(pldata* pld)
{
  unsigned	start = ++pld->pos;
  unsigned	escaped = 0;
  unsigned	shrink = 0;
  BOOL		hex = NO;
  NSString	*obj;

  while (pld->pos < pld->end)
    {
      unichar	c = (unichar)pld->ptr[pld->pos];

      if (escaped)
	{
	  if (escaped == 1 && c == '0')
	    {
	      escaped = 2;
	      hex = NO;
	    }
	  else if (escaped > 1)
	    {
	      if (escaped == 2 && c == 'x')
		{
		  hex = YES;
		  shrink++;
		  escaped++;
		}
	      else if (hex && (*hexdigitsImp)(hexdigits, cMemberSel, c))
		{
		  shrink++;
		  escaped++;
		}
	      else if (c >= '0' && c <= '7')
		{
		  shrink++;
		  escaped++;
		}
	      else
		{
		  escaped = 0;
		}
	    }
	  else
	    {
	      escaped = 0;
	    }
	}
      else
	{
	  if (c == '\\')
	    {
	      escaped = 1;
	      shrink++;
	    }
	  else if (c == '"')
	    break;
	}
      pld->pos++;
    }
  if (pld->pos >= pld->end)
    {
      pld->err = @"reached end of string while parsing quoted string";
      return nil;
    }
  if (pld->pos - start - shrink == 0)
    {
      obj = @"";
    }
  else
    {
#if	GSPLUNI
      unichar	chars[pld->pos - start - shrink];
#else
      char	chars[pld->pos - start - shrink];
#endif
      unsigned	j;
      unsigned	k;

      escaped = 0;
      hex = NO;
      for (j = start, k = 0; j < pld->pos; j++)
	{
	  unichar	c = (unichar)pld->ptr[j];

	  if (escaped)
	    {
	      if (escaped == 1 && c == '0')
		{
		  chars[k] = 0;
		  hex = NO;
		  escaped++;
		}
	      else if (escaped > 1)
		{
		  if (escaped == 2 && c == 'x')
		    {
		      hex = YES;
		      escaped++;
		    }
		  else if (hex && (*hexdigitsImp)(hexdigits, cMemberSel, c))
		    {
		      chars[k] <<= 4;
		      chars[k] |= char2num(c);
		      escaped++;
		    }
		  else if (c >= '0' && c <= '7')
		    {
		      chars[k] <<= 3;
		      chars[k] |= (c - '0');
		      escaped++;
		    }
		  else
		    {
		      escaped = 0;
		      chars[++k] = c;
		      k++;
		    }
		}
	      else
		{
		  escaped = 0;
		  switch (c)
		    {
		      case 'a' : chars[k] = '\a'; break;
		      case 'b' : chars[k] = '\b'; break;
		      case 't' : chars[k] = '\t'; break;
		      case 'r' : chars[k] = '\r'; break;
		      case 'n' : chars[k] = '\n'; break;
		      case 'v' : chars[k] = '\v'; break;
		      case 'f' : chars[k] = '\f'; break;
		      default  : chars[k] = c; break;
		    }
		  k++;
		}
	    }
	  else
	    {
	      chars[k] = c;
	      if (c == '\\')
		escaped = 1;
	      else
		k++;
	    }
	}
      obj = (*plAlloc)(plCls, @selector(allocWithZone:), NSDefaultMallocZone());
      obj = (*plInit)(obj, plSel, (void*)chars, pld->pos - start - shrink);
      (*plAutorelease)(obj, @selector(autorelease));
    }
  pld->pos++;
  return obj;
}

static inline id parseUnquotedString(pldata *pld)
{
  unsigned	start = pld->pos;
  id		obj;

  while (pld->pos < pld->end)
    {
      if ((*quotablesImp)(quotables, cMemberSel,
        (unichar)pld->ptr[pld->pos]) == YES)
	break;
      pld->pos++;
    }
  obj = (*plAlloc)(plCls, @selector(allocWithZone:), NSDefaultMallocZone());
  obj = (*plInit)(obj, plSel, (void*)&pld->ptr[start], pld->pos-start);
  (*plAutorelease)(obj, @selector(autorelease));
  return obj;
}

static id parsePlItem(pldata* pld)
{
  if (skipSpace(pld) == NO)
    return nil;

  switch (pld->ptr[pld->pos])
    {
      case '{':
	{
	  NSMutableDictionary	*dict;

	  dict = [[[plDictionary allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0] autorelease];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != '}')
	    {
	      id	key;
	      id	val;

	      key = parsePlItem(pld);
	      if (key == nil)
		return nil;
	      if (skipSpace(pld) == NO)
		return nil;
	      if (pld->ptr[pld->pos] != '=')
		{
		  pld->err = @"unexpected character (wanted '=')";
		  return nil;
		}
	      pld->pos++;
	      val = parsePlItem(pld);
	      if (val == nil)
		return nil;
	      if (skipSpace(pld) == NO)
		return nil;
	      if (pld->ptr[pld->pos] == ';')
		pld->pos++;
	      else if (pld->ptr[pld->pos] != '}')
		{
		  pld->err = @"unexpected character (wanted ';' or '}')";
		  return nil;
		}
	      (*plSet)(dict, @selector(setObject:forKey:), val, key);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing dictionary";
	      return nil;
	    }
	  pld->pos++;
	  return dict;
	}

      case '(':
	{
	  NSMutableArray	*array;

	  array = [[[plArray allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0] autorelease];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != ')')
	    {
	      id	val;

	      val = parsePlItem(pld);
	      if (val == nil)
		return nil;
	      if (skipSpace(pld) == NO)
		return nil;
	      if (pld->ptr[pld->pos] == ',')
		pld->pos++;
	      else if (pld->ptr[pld->pos] != ')')
		{
		  pld->err = @"unexpected character (wanted ',' or ')')";
		  return nil;
		}
	      (*plAdd)(array, @selector(addObject:), val);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing array";
	      return nil;
	    }
	  pld->pos++;
	  return array;
	}

      case '<':
	{
	  NSMutableData	*data;
	  unsigned	max = pld->end - 1;
	  unsigned char	buf[BUFSIZ];
	  unsigned	len = 0;

	  data = [NSMutableData dataWithCapacity: 0];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != '>')
	    {
	      while (pld->pos < max
		&& (*hexdigitsImp)(hexdigits, cMemberSel,
		(unichar)pld->ptr[pld->pos])
		&& (*hexdigitsImp)(hexdigits, cMemberSel,
		(unichar)pld->ptr[pld->pos+1]))
		{
		  unsigned char	byte;

		  byte = (char2num(pld->ptr[pld->pos])) << 4; 
		  pld->pos++;
		  byte |= char2num(pld->ptr[pld->pos]);
		  pld->pos++;
		  buf[len++] = byte;
		  if (len > sizeof(buf))
		    {
		      [data appendBytes: buf length: len];
		      len = 0;
		    }
		}
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing data";
	      return nil;
	    }
	  if (pld->ptr[pld->pos] != '>')
	    {
	      pld->err = @"unexpected character in string";
	      return nil;
	    }
	  if (len > 0)
	    {
	      [data appendBytes: buf length: len];
	    }
	  pld->pos++;
	  return data;
	}

      case '"':
	return parseQuotedString(pld);

      default:
	return parseUnquotedString(pld);
    }
}

static id parseSfItem(pldata* pld)
{
  NSMutableDictionary	*dict;

  dict = [[[plDictionary allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: 0] autorelease];
  while (skipSpace(pld) == YES)
    {
      id	key;
      id	val;

      if (pld->ptr[pld->pos] == '"')
	key = parseQuotedString(pld);
      else
	key = parseUnquotedString(pld);
      if (key == nil)
	return nil;
      if (skipSpace(pld) == NO)
	{
	  pld->err = @"incomplete final entry (no semicolon?)";
	  return nil;
	}
      if (pld->ptr[pld->pos] == ';')
	{
	  pld->pos++;
	  (*plSet)(dict, @selector(setObject:forKey:), @"", key);
	}
      else if (pld->ptr[pld->pos] == '=')
	{
	  pld->pos++;
	  if (skipSpace(pld) == NO)
	    return nil;
	  if (pld->ptr[pld->pos] == '"')
	    val = parseQuotedString(pld);
	  else
	    val = parseUnquotedString(pld);
	  if (val == nil)
	    return nil;
	  if (skipSpace(pld) == NO)
	    {
	      pld->err = @"missing final semicolon";
	      return nil;
	    }
	  (*plSet)(dict, @selector(setObject:forKey:), val, key);
	  if (pld->ptr[pld->pos] == ';')
	    pld->pos++;
	  else
	    {
	      pld->err = @"unexpected character (wanted ';')";
	      return nil;
	    }
	}
      else
	{
	  pld->err = @"unexpected character (wanted '=' or ';')";
	  return nil;
	}
    }
  return dict;
}
