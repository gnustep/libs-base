/* Text Property-List parsing code for NSString.m and NSGCString.m
   Copyright (C) 1998,2000 Free Software Foundation, Inc.
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#if	HAVE_LIBXML
#include	<Foundation/GSXML.h>

static void
decodeBase64Unit(const char* ptr, unsigned char *out)
{
  out[0] =  (ptr[0]         << 2) | ((ptr[1] & 0x30) >> 4);
  out[1] = ((ptr[1] & 0x0F) << 4) | ((ptr[2] & 0x3C) >> 2);
  out[2] = ((ptr[2] & 0x03) << 6) |  (ptr[3] & 0x3F);
  out[3] = 0;
}

static NSData*
decodeBase64(const char *source)
{
  int		length = strlen(source);
  char		*sourceBuffer = objc_malloc(length+1);
  NSMutableData	*data = [NSMutableData dataWithCapacity:0];
  int i, j;
  unsigned char	tmp[4];

  strcpy(sourceBuffer, source);
  j = 0;

  for (i = 0; i < length; i++)
    {
      if (!isspace(source[i]))
        {
          sourceBuffer[j++] = source[i];
        }
    }

  sourceBuffer[j] = '\0';
  length = strlen(sourceBuffer);
  while (length > 0 && sourceBuffer[length-1] == '=')
    {
      sourceBuffer[--length] = '\0';
    }
  for (i = 0; i < length; i += 4)
    {
       decodeBase64Unit(&sourceBuffer[i], tmp);
       [data appendBytes: tmp length: strlen(tmp)];
    }

  objc_free(sourceBuffer);

  return data;
}

#endif

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
	@"0123456789abcdefABCDEF"];
      IF_NO_GC(RETAIN(hexdigits));
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

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz$./_"]
	mutableCopy];
      [s invert];
      quotables = [s copy];
      RELEASE(s);
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
      whitespce = [NSCharacterSet characterSetWithCharactersInString:
	@" \t\r\n\f\b"];
      IF_NO_GC(RETAIN(whitespce));
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
		  pld->pos--;
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
	    {
	      break;
	    }
	}
      if (c == '\n')
	pld->lin++;
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
		      j--;
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
		{
		  escaped = 1;
		}
	      else
		{
		  k++;
		}
	    }
	}
      obj = (*plAlloc)(plCls, @selector(allocWithZone:), NSDefaultMallocZone());
      obj = (*plInit)(obj, plSel, (void*)chars, pld->pos - start - shrink);
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

	  dict = [[plDictionary allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != '}')
	    {
	      id	key;
	      id	val;

	      key = parsePlItem(pld);
	      if (key == nil)
		return nil;
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(key);
		  return nil;
		}
	      if (pld->ptr[pld->pos] != '=')
		{
		  pld->err = @"unexpected character (wanted '=')";
		  RELEASE(key);
		  return nil;
		}
	      pld->pos++;
	      val = parsePlItem(pld);
	      if (val == nil)
		{
		  RELEASE(key);
		  return nil;
		}
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(key);
		  RELEASE(val);
		  return nil;
		}
	      if (pld->ptr[pld->pos] == ';')
		{
		  pld->pos++;
		}
	      else if (pld->ptr[pld->pos] != '}')
		{
		  pld->err = @"unexpected character (wanted ';' or '}')";
		  RELEASE(key);
		  RELEASE(val);
		  return nil;
		}
	      (*plSet)(dict, @selector(setObject:forKey:), val, key);
	      RELEASE(key);
	      RELEASE(val);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing dictionary";
	      RELEASE(dict);
	      return nil;
	    }
	  pld->pos++;
	  return dict;
	}

      case '(':
	{
	  NSMutableArray	*array;

	  array = [[plArray allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != ')')
	    {
	      id	val;

	      val = parsePlItem(pld);
	      if (val == nil)
		{
		  return nil;
		}
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(val);
		  return nil;
		}
	      if (pld->ptr[pld->pos] == ',')
		{
		  pld->pos++;
		}
	      else if (pld->ptr[pld->pos] != ')')
		{
		  pld->err = @"unexpected character (wanted ',' or ')')";
		  RELEASE(val);
		  return nil;
		}
	      (*plAdd)(array, @selector(addObject:), val);
	      RELEASE(val);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing array";
	      RELEASE(array);
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

	  data = [[NSMutableData alloc] initWithCapacity: 0];
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
		  if (len == sizeof(buf))
		    {
		      [data appendBytes: buf length: len];
		      len = 0;
		    }
		}
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing data";
	      RELEASE(data);
	      return nil;
	    }
	  if (pld->ptr[pld->pos] != '>')
	    {
	      pld->err = @"unexpected character in string";
	      RELEASE(data);
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

#if	HAVE_LIBXML
static GSXMLNode*
elementNode(GSXMLNode* node)
{
  while (node != nil)
    {
      if ([node type] == XML_ELEMENT_NODE)
        {
          break;
        }
      node = [node next];
    }
  return node;
}

static id
nodeToObject(GSXMLNode* node)
{
  NSString	*name;
  NSString	*content;
  GSXMLNode	*children;

  node = elementNode(node);
  if (node == nil)
    {
      return nil;
    }
  name = [node name];
  children = [node children];
  content = [children content];
  children = elementNode(children);

  if ([name isEqualToString: @"string"])
    {
      return content;
    }
  else if ([name isEqualToString: @"key"])
    {
      return content;
    }
  else if ([name isEqualToString: @"true"])
    {
      return [NSNumber numberWithBool: YES];
    }
  else if ([name isEqualToString: @"false"])
    {
      return [NSNumber numberWithBool: NO];
    }
  else if ([name isEqualToString: @"integer"])
    {
      return [NSNumber numberWithInt: [content intValue]];
    }
  else if ([name isEqualToString: @"real"])
    {
      return [NSNumber numberWithDouble: [content doubleValue]];
    }
  else if ([name isEqualToString: @"date"])
    {
      return [NSCalendarDate dateWithString: content
                             calendarFormat: @"%Y-%m-%d %H:%M:%S %z"];
    }
  else if ([name isEqualToString: @"data"])
    {
      return decodeBase64([content cString]);
    }
  // container class
  else if ([name isEqualToString: @"array"])
    {
      NSMutableArray	*container = [NSMutableArray array];

      while (children != nil)
        {
	  id	val;

	  val = nodeToObject(children);
          [container addObject: val];
          children = elementNode([children next]);
        }
      return container;
    }
  else if ([name isEqualToString: @"dict"])
    {
      NSMutableDictionary	*container = [NSMutableDictionary dictionary];

      while (children != nil)
        {
	  NSString	*key;
	  id		val;

	  key = nodeToObject(children);
          children = elementNode([children next]);
	  val = nodeToObject(children);
          children = elementNode([children next]);
          [container setObject: val forKey: key];
        }
      return container;
    }
  else
    {
      return nil;
    }
}
#endif

static id parsePl(pldata* pld)
{
#if	HAVE_LIBXML
  while (pld->pos < pld->end && isspace(pld->ptr[pld->pos]))
    {
      pld->pos++;
    }
  /*
   * A string beginning with a '<?' must be an XML file
   */
  if (pld->pos + 1 < pld->end && pld->ptr[pld->pos] == '<'
    && pld->ptr[pld->pos+1] == '?')
    {
      NSData		*data;
      GSXMLParser	*parser;
      char		*buf = NSZoneMalloc(NSDefaultMallocZone(), pld->end);

      memcpy(buf, pld->ptr, pld->end);
      data = [NSData dataWithBytesNoCopy: buf length: pld->end]; 
      parser = [GSXMLParser parserWithData: data];
      [parser substituteEntities: NO];
      if ([parser parse] == YES)
	{
	  if (![[[[parser doc] root] name] isEqualToString: @"plist"])
	    {
	      NSLog(@"not a property list - because name node is %@",
		[[[parser doc] root] name]);
	      return nil;
	    }
	  return RETAIN(nodeToObject([[[parser doc] root] children]));
	}
      else
	{
	  NSLog(@"not a property list - failed to parse as XML");
	  return nil;
	}
    }
#endif
  return parsePlItem(pld);
}

static id parseSfItem(pldata* pld)
{
  NSMutableDictionary	*dict;

  dict = [[plDictionary allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: 0];
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
	  RELEASE(key);
	  return nil;
	}
      if (pld->ptr[pld->pos] == ';')
	{
	  pld->pos++;
	  (*plSet)(dict, @selector(setObject:forKey:), @"", key);
	  RELEASE(key);
	}
      else if (pld->ptr[pld->pos] == '=')
	{
	  pld->pos++;
	  if (skipSpace(pld) == NO)
	    {
	      RELEASE(key);
	      return nil;
	    }
	  if (pld->ptr[pld->pos] == '"')
	    val = parseQuotedString(pld);
	  else
	    val = parseUnquotedString(pld);
	  if (val == nil)
	    {
	      RELEASE(key);
	      return nil;
	    }
	  if (skipSpace(pld) == NO)
	    {
	      pld->err = @"missing final semicolon";
	      RELEASE(key);
	      RELEASE(val);
	      return nil;
	    }
	  (*plSet)(dict, @selector(setObject:forKey:), val, key);
	  RELEASE(key);
	  RELEASE(val);
	  if (pld->ptr[pld->pos] == ';')
	    pld->pos++;
	  else
	    {
	      pld->err = @"unexpected character (wanted ';')";
	      RELEASE(dict);
	      return nil;
	    }
	}
      else
	{
	  RELEASE(key);
	  RELEASE(dict);
	  pld->err = @"unexpected character (wanted '=' or ';')";
	  return nil;
	}
    }
  return dict;
}
