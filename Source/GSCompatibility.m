/** Runtime MacOSX compatibility functionality
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <rfm@gnu.org>
   Date: August 2000
   
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
#include <Foundation/Foundation.h>
#include <Foundation/NSDebug.h>

#include "GSPrivate.h"

@class	GSMutableString;

#ifndef HAVE_RINT
#include <math.h>
static double rint(double a)
{
  return (floor(a+0.5));
}
#endif

/*
 * Runtime MacOS-X compatibility flags.
 */

BOOL GSMacOSXCompatibleGeometry(void)
{
  if (GSUserDefaultsFlag(GSOldStyleGeometry) == YES)
    return NO;
  return GSUserDefaultsFlag(GSMacOSXCompatible);
}

BOOL GSMacOSXCompatiblePropertyLists(void)
{
  if (GSUserDefaultsFlag(NSWriteOldStylePropertyLists) == YES)
    return NO;
  return GSUserDefaultsFlag(GSMacOSXCompatible);
}

#include <math.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>

static char base64[]
  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString*
encodeBase64(NSData *source)
{
  int		length = [source length];
  int		enclen = length / 3;
  int		remlen = length - 3 * enclen;
  int		destlen = 4 * ((length - 1) / 3) + 5;
  unsigned char *sBuf;
  unsigned char *dBuf;
  int		sIndex = 0;
  int		dIndex = 0;

  if (length == 0)
    {
      return @"";
    }
  sBuf = (unsigned char*)[source bytes];
  dBuf = NSZoneMalloc(NSDefaultMallocZone(), destlen);
  dBuf[destlen - 1] = '\0';

  for (sIndex = 0; sIndex < length - 2; sIndex += 3, dIndex += 4)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1]
	= base64[((sBuf[sIndex] << 4) | (sBuf[sIndex + 1] >> 4)) & 0x3f];
      dBuf[dIndex + 2]
	= base64[((sBuf[sIndex + 1] << 2) | (sBuf[sIndex + 2] >> 6)) & 0x3f];
      dBuf[dIndex + 3] = base64[sBuf[sIndex + 2] & 0x3f];
    }

  if (remlen == 1)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
      dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
      dBuf[dIndex + 2] = '=';
      dBuf[dIndex + 3] = '=';
    }
  else if (remlen == 2)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
      dBuf[dIndex + 1] |= sBuf[sIndex + 1] >> 4;
      dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
      dBuf[dIndex + 2] = (sBuf[sIndex + 1] << 2) & 0x3c;
      dBuf[dIndex + 2] = base64[dBuf[dIndex + 2]];
      dBuf[dIndex + 3] = '=';
    }

  return [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithCStringNoCopy: dBuf length: destlen-1 freeWhenDone: YES];
}

static NSCharacterSet *xmlQuotables = nil;
static NSCharacterSet *plQuotables = nil;
static NSCharacterSet *oldPlQuotables = nil;
static unsigned const char *plQuotablesBitmapRep = NULL;
#define GS_IS_QUOTABLE(X) IS_BIT_SET(plQuotablesBitmapRep[(X)/8], (X) % 8)

static inline void Append(NSString *src, GSMutableString *dst)
{
  [(NSMutableString*)dst appendString: src];
}

static void
PString(NSString *obj, GSMutableString *output)
{
  unsigned	length;

  if ((length = [obj length]) == 0)
    {
      Append(@"\"\"", output);
      return;
    }

  if ([obj rangeOfCharacterFromSet: oldPlQuotables].length > 0
    || [obj characterAtIndex: 0] == '/')
    {
      unichar	tmp[length <= 1024 ? length : 0];
      unichar	*ustring;
      unichar	*from;
      unichar	*end;
      int	len = 0;

      if (length <= 1024)
	{
	  ustring = tmp;
	}
      else
	{
	  ustring = NSZoneMalloc(NSDefaultMallocZone(), length*sizeof(unichar));
	}
      end = &ustring[length];
      [obj getCharacters: ustring];
      for (from = ustring; from < end; from++)
	{
	  switch (*from)
	    {
	      case '\a':
	      case '\b':
	      case '\t':
	      case '\r':
	      case '\n':
	      case '\v':
	      case '\f':
	      case '\\':
	      case '\'' :
	      case '"' :
		len += 2;
		break;

	      default:
		if (*from < 128)
		  {
		    if (isprint(*from) || *from == ' ')
		      {
			len++;
		      }
		    else
		      {
			len += 4;
		      }
		  }
		else
		  {
		    len += 6;
		  }
		break;
	    }
	}

	{
	  char	buf[len+3];
	  char	*ptr = buf;

	  *ptr++ = '"';
	  for (from = ustring; from < end; from++)
	    {
	      switch (*from)
		{
		  case '\a': 	*ptr++ = '\\'; *ptr++ = 'a';  break;
		  case '\b': 	*ptr++ = '\\'; *ptr++ = 'b';  break;
		  case '\t': 	*ptr++ = '\\'; *ptr++ = 't';  break;
		  case '\r': 	*ptr++ = '\\'; *ptr++ = 'r';  break;
		  case '\n': 	*ptr++ = '\\'; *ptr++ = 'n';  break;
		  case '\v': 	*ptr++ = '\\'; *ptr++ = 'v';  break;
		  case '\f': 	*ptr++ = '\\'; *ptr++ = 'f';  break;
		  case '\\': 	*ptr++ = '\\'; *ptr++ = '\\'; break;
		  case '\'': 	*ptr++ = '\\'; *ptr++ = '\''; break;
		  case '"' : 	*ptr++ = '\\'; *ptr++ = '"';  break;

		  default:
		    if (*from < 128)
		      {
			if (isprint(*from) || *from == ' ')
			  {
			    *ptr++ = *from;
			  }
			else
			  {
			    sprintf(ptr, "\\%03o", *(unsigned char*)from);
			    ptr = &ptr[4];
			  }
		      }
		    else
		      {
			sprintf(ptr, "\\u%04x", *from);
			ptr = &ptr[6];
		      }
		    break;
		}
	    }
	  *ptr++ = '"';
	  *ptr = '\0';
	  obj = [[NSString alloc] initWithCString: buf];
	  Append(obj, output);
	  RELEASE(obj);
	}
      if (length > 1024)
	{
	  NSZoneFree(NSDefaultMallocZone(), ustring);
	}
    }
  else
    {
      Append(obj, output);
    }
}

static void
XString(NSString* obj, GSMutableString *output)
{
  static char	*hexdigits = "0123456789ABCDEF";
  unsigned	end;

  end = [obj length];
  if (end == 0)
    {
      return;
    }

  if ([obj rangeOfCharacterFromSet: xmlQuotables].length > 0)
    {
      unichar	*base;
      unichar	*map;
      unichar	c;
      unsigned	len;
      unsigned	rpos;
      unsigned	wpos;

      base = NSZoneMalloc(NSDefaultMallocZone(), end * sizeof(unichar));
      [obj getCharacters: base];
      for (len = rpos = 0; rpos < end; rpos++)
	{
	  c = base[rpos];
	  switch (c)
	    {
	      case '&': 
		len += 5;
		break;
	      case '<': 
	      case '>': 
		len += 4;
		break;
	      case '\'': 
	      case '"': 
		len += 6;
		break;
	      case '\\': 
		len += 1;
		break;

	      default: 
		if (c < 0x20)
		  {
		    if (c == 0x09 || c == 0x0A || c == 0x0D)
		      {
			len++;
		      }
		    else
		      {
			len += 4;
		      }
		  }
		else if (c > 0xD7FF && c < 0xE000)
		  {
		    len += 6;
		  }
		else if (c > 0xFFFD)
		  {
		    len += 6;
		  }
		else
		  {
		    len++;
		  }
		break;
	    }
	}
      map = NSZoneMalloc(NSDefaultMallocZone(), len * sizeof(unichar));
      for (wpos = rpos = 0; rpos < end; rpos++)
	{
	  c = base[rpos];
	  switch (c)
	    {
	      case '&': 
		map[wpos++] = '&';
		map[wpos++] = 'a';
		map[wpos++] = 'm';
		map[wpos++] = 'p';
		map[wpos++] = ';';
		break;
	      case '<': 
		map[wpos++] = '&';
		map[wpos++] = 'l';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;
	      case '>': 
		map[wpos++] = '&';
		map[wpos++] = 'g';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;
	      case '\'': 
		map[wpos++] = '&';
		map[wpos++] = 'a';
		map[wpos++] = 'p';
		map[wpos++] = 'o';
		map[wpos++] = 's';
		map[wpos++] = ';';
		break;
	      case '"': 
		map[wpos++] = '&';
		map[wpos++] = 'q';
		map[wpos++] = 'u';
		map[wpos++] = 'o';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;
	      case '\\': 
		map[wpos++] = '\\';
		map[wpos++] = '\\';
		break;

	      default: 
		if (c < 0x20)
		  {
		    if (c == 0x09 || c == 0x0A || c == 0x0D)
		      {
			map[wpos++] = c;
		      }
		    else
		      {
			map[wpos++] = '\\';
			map[wpos++] = '0' + ((c / 64) & 7);
			map[wpos++] = '0' + ((c / 8) & 7);
			map[wpos++] = '0' + (c & 7);
		      }
		  }
		else if (c > 0xD7FF && c < 0xE000)
		  {
		    map[wpos++] = '\\';
		    map[wpos++] = 'U';
		    map[wpos++] = hexdigits[(c>>12) & 0xf];
		    map[wpos++] = hexdigits[(c>>8) & 0xf];
		    map[wpos++] = hexdigits[(c>>4) & 0xf];
		    map[wpos++] = hexdigits[c & 0xf];
		  }
		else if (c > 0xFFFD)
		  {
		    map[wpos++] = '\\';
		    map[wpos++] = hexdigits[(c>>12) & 0xf];
		    map[wpos++] = hexdigits[(c>>8) & 0xf];
		    map[wpos++] = hexdigits[(c>>4) & 0xf];
		    map[wpos++] = hexdigits[c & 0xf];
		    map[wpos++] = '\\';
		  }
		else
		  {
		    map[wpos++] = c;
		  }
		break;
	    }
	}
      NSZoneFree(NSDefaultMallocZone(), base);
      obj = [[NSString alloc] initWithCharacters: map length: len];
      Append(obj, output);
      RELEASE(obj);
    }
  else
    {
      Append(obj, output);
    }
}

static NSString	*indentStrings[] = {
  @"",
  @"  ",
  @"    ",
  @"      ",
  @"\t",
  @"\t  ",
  @"\t    ",
  @"\t      ",
  @"\t\t",
  @"\t\t  ",
  @"\t\t    ",
  @"\t\t      ",
  @"\t\t\t",
  @"\t\t\t  ",
  @"\t\t\t    ",
  @"\t\t\t      ",
  @"\t\t\t\t",
  @"\t\t\t\t  ",
  @"\t\t\t\t    ",
  @"\t\t\t\t      ",
  @"\t\t\t\t\t",
  @"\t\t\t\t\t  ",
  @"\t\t\t\t\t    ",
  @"\t\t\t\t\t      ",
  @"\t\t\t\t\t\t"
};

/**
 * obj is the object to be written out<br />
 * loc is the locale for formatting (or nil to indicate no formatting)<br />
 * lev is the level of indentation to use<br />
 * step is the indentation step (0 == 0, 1 = 2, 2 = 4, 3 = 8)<br />
 * x is a flag to indicate xml property list format<br />
 * dest is the output buffer.
 */
static void
OAppend(id obj, NSDictionary *loc, unsigned lev, unsigned step,
  BOOL x, GSMutableString *dest)
{
  if ([obj isKindOfClass: [NSString class]])
    {
      if (x == YES)
	{
	  Append(@"<string>", dest);
	  XString(obj, dest);
	  Append(@"</string>\n", dest);
	}
      else
	{
	  PString(obj, dest);
	}
    }
  else if ([obj isKindOfClass: [NSNumber class]])
    {
      double	val = [obj doubleValue];

      if (val == 1.0)
	{
	  if (x)
	    {
	      Append(@"<true/>\n", dest);
	    }
	  else
	    {
	      Append(@"<*BY>", dest);
	    }
	}
      else if (val == 0.0)
	{
	  if (x)
	    {
	      Append(@"<false/>\n", dest);
	    }
	  else
	    {
	      Append(@"<*BN>", dest);
	    }
	}
      else if (rint(val) == val)
	{
	  if (x == YES)
	    {
	      Append(@"<integer>", dest);
	      XString([obj stringValue], dest);
	      Append(@"</integer>\n", dest);
	    }
	  else
	    {
	      Append(@"<*I", dest);
	      PString([obj stringValue], dest);
	      Append(@">", dest);
	    }
	}
      else
	{
	  if (x == YES)
	    {
	      Append(@"<real>", dest);
	      XString([obj stringValue], dest);
	      Append(@"</real>\n", dest);
	    }
	  else
	    {
	      Append(@"<*R", dest);
	      PString([obj stringValue], dest);
	      Append(@">", dest);
	    }
	}
    }
  else if ([obj isKindOfClass: [NSData class]])
    {
      if (x == YES)
	{
	  Append(@"<data>", dest);
	  Append(encodeBase64(obj), dest);
	  Append(@"</data>\n", dest);
	}
      else
	{
	  NSString	*str;
	  const char	*src;
	  char		*dst;
	  int		length;
	  int		i;
	  int		j;
	  NSZone	*z = NSDefaultMallocZone();

	  src = [obj bytes];
	  length = [obj length];
	  #define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

	  dst = (char*) NSZoneMalloc(z, 2*length+length/4+3);
	  dst[0] = '<';
	  for (i = 0, j = 1; i < length; i++, j++)
	    {
	      dst[j++] = num2char((src[i]>>4) & 0x0f);
	      dst[j] = num2char(src[i] & 0x0f);
	      if ((i&0x3) == 3 && i != length-1)
		{
		  /* if we've just finished a 32-bit int, print a space */
		  dst[++j] = ' ';
		}
	    }
	  dst[j++] = '>';
	  dst[j] = '\0';
	  str = [[NSString allocWithZone: z] initWithCStringNoCopy: dst
							    length: j
						      freeWhenDone: YES];
	  Append(str, dest);
	  RELEASE(str);
	}
    }
  else if ([obj isKindOfClass: [NSDate class]])
    {
      if (x == YES)
	{
	  Append(@"<date>", dest);
	  Append([obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
	    timeZone: nil locale: nil], dest);
	  Append(@"</date>\n", dest);
	}
      else
	{
	  Append(@"<*D", dest);
	  Append([obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
	    timeZone: nil locale: nil], dest);
	  Append(@">", dest);
	}
    }
  else if ([obj isKindOfClass: [NSArray class]])
    {
      NSString	*iBaseString;
      NSString	*iSizeString;
      unsigned	level = lev;

      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iBaseString = indentStrings[level*step];
	}
      else
	{
	  iBaseString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}
      level++;
      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iSizeString = indentStrings[level*step];
	}
      else
	{
	  iSizeString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}

      if (x == YES)
	{
	  NSEnumerator	*e;

	  Append(@"<array>", dest);
	  e = [obj objectEnumerator];
	  while ((obj = [e nextObject]))
	    {
	      Append(iSizeString, dest);
	      OAppend(obj, loc, level, step, YES, dest);
	    }
	  Append(iBaseString, dest);
	  Append(@"</array>\n", dest);
	}
      else
	{
	  unsigned		count = [obj count];
	  unsigned		last = count - 1;
	  NSString		*plists[count];
	  unsigned		i;

	  [obj getObjects: plists];

	  if (loc == nil)
	    {
	      Append(@"(", dest);
	      for (i = 0; i < count; i++)
		{
		  id	item = plists[i];

		  OAppend(item, nil, 0, step, NO, dest);
		  if (i != last)
		    {
		      Append(@", ", dest);
		    }
		}
	      Append(@")", dest);
	    }
	  else
	    {
	      Append(@"(\n", dest);
	      for (i = 0; i < count; i++)
		{
		  id	item = plists[i];

		  Append(iSizeString, dest);
		  OAppend(item, loc, level, step, NO, dest);
		  if (i == last)
		    {
		      Append(@"\n", dest);
		    }
		  else
		    {
		      Append(@",\n", dest);
		    }
		}
	      Append(iBaseString, dest);
	      Append(@")", dest);
	    }
	}
    }
  else if ([obj isKindOfClass: [NSDictionary class]])
    {
      NSString	*iBaseString;
      NSString	*iSizeString;
      unsigned	level = lev;

      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iBaseString = indentStrings[level*step];
	}
      else
	{
	  iBaseString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}
      level++;
      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iSizeString = indentStrings[level*step];
	}
      else
	{
	  iSizeString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}

      if (x == YES)
	{
	  NSEnumerator	*e;
	  id		key;

	  Append(@"<dict>\n", dest);
	  e = [obj keyEnumerator];
	  while ((key = [e nextObject]))
	    {
	      id	val;

	      val = [obj objectForKey: key];
	      Append(iSizeString, dest);
	      Append(@"<key>", dest);
	      XString(key, dest);
	      Append(@"</key>\n", dest);
	      OAppend(val, loc, level, step, YES, dest);
	    }
	  Append(iBaseString, dest);
	  Append(@"</dict>\n", dest);
	}
      else
	{
	  SEL		objSel = @selector(objectForKey:);
	  IMP		myObj = [obj methodForSelector: objSel];
	  unsigned	i;
	  NSArray	*keyArray = [obj allKeys];
	  unsigned	numKeys = [keyArray count];
	  NSString	*plists[numKeys];
	  NSString	*keys[numKeys];

	  [keyArray getObjects: keys];

	  if (loc == nil)
	    {
	      for (i = 0; i < numKeys; i++)
		{
		  plists[i] = (*myObj)(obj, objSel, keys[i]);
		}

	      Append(@"{", dest);
	      for (i = 0; i < numKeys; i++)
		{
		  OAppend(keys[i], nil, 0, step, NO, dest);
		  Append(@" = ", dest);
		  OAppend(plists[i], nil, 0, step, NO, dest);
		  Append(@"; ", dest);
		}
	      Append(@"}", dest);
	    }
	  else
	    {
	      BOOL	canCompare = YES;
	      Class	lastClass = 0;

	      for (i = 0; i < numKeys; i++)
		{
		  if (GSObjCClass(keys[i]) == lastClass)
		    continue;
		  if ([keys[i] respondsToSelector: @selector(compare:)] == NO)
		    {
		      canCompare = NO;
		      break;
		    }
		  lastClass = GSObjCClass(keys[i]);
		}

	      if (canCompare == YES)
		{
		  #define STRIDE_FACTOR 3
		  unsigned	c,d, stride;
		  BOOL		found;
		  NSComparisonResult	(*comp)(id, SEL, id) = 0;
		  int		count = numKeys;
		  #ifdef	GSWARN
		  BOOL		badComparison = NO;
		  #endif

		  stride = 1;
		  while (stride <= count)
		    {
		      stride = stride * STRIDE_FACTOR + 1;
		    }
		  lastClass = 0;
		  while (stride > (STRIDE_FACTOR - 1))
		    {
		      // loop to sort for each value of stride
		      stride = stride / STRIDE_FACTOR;
		      for (c = stride; c < count; c++)
			{
			  found = NO;
			  if (stride > c)
			    {
			      break;
			    }
			  d = c - stride;
			  while (!found)
			    {
			      id			a = keys[d + stride];
			      id			b = keys[d];
			      Class			x;
			      NSComparisonResult	r;

			      x = GSObjCClass(a);
			      if (x != lastClass)
				{
				  lastClass = x;
				  comp = (NSComparisonResult (*)(id, SEL, id))
				    [a methodForSelector: @selector(compare:)];
				}
			      r = (*comp)(a, @selector(compare:), b);
			      if (r < 0)
				{
				  #ifdef	GSWARN
				  if (r != NSOrderedAscending)
				    {
				      badComparison = YES;
				    }
				  #endif
				  keys[d + stride] = b;
				  keys[d] = a;
				  if (stride > d)
				    {
				      break;
				    }
				  d -= stride;
				}
			      else
				{
				  #ifdef	GSWARN
				  if (r != NSOrderedDescending
				    && r != NSOrderedSame)
				    {
				      badComparison = YES;
				    }
				  #endif
				  found = YES;
				}
			    }
			}
		    }
		  #ifdef	GSWARN
		  if (badComparison == YES)
		    {
		      NSWarnFLog(@"Detected bad return value from comparison");
		    }
		  #endif
		}

	      for (i = 0; i < numKeys; i++)
		{
		  plists[i] = (*myObj)(obj, objSel, keys[i]);
		}

	      Append(@"{\n", dest);
	      for (i = 0; i < numKeys; i++)
		{
		  Append(iSizeString, dest);
		  OAppend(keys[i], loc, level, step, NO, dest);
		  Append(@" = ", dest);
		  OAppend(plists[i], loc, level, step, NO, dest);
		  Append(@";\n", dest);
		}
	      Append(iBaseString, dest);
	      Append(@"}", dest);
	    }
	}
    }
  else
    {
      NSDebugLog(@"Non-property-list class (%@) encoded as string",
	NSStringFromClass([obj class]));
      if (x == YES)
	{
	  Append(@"<string>", dest);
	  XString([obj description], dest);
	  Append(@"</string>\n", dest);
	}
      else
	{
	  Append([obj description], dest);
	}
    }
}

void
GSPropertyListMake(id obj, NSDictionary *loc, BOOL xml, unsigned step, id *str)
{
  GSMutableString	*dest;

  if (plQuotablesBitmapRep == NULL)
    {
      NSMutableCharacterSet	*s;
      NSData			*bitmap;

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	@"abcdefghijklmnopqrstuvwxyz!#$%&*+-./:?@|~_^"]
	mutableCopy];
      [s invert];
      plQuotables = [s copy];
      RELEASE(s);
      bitmap = RETAIN([plQuotables bitmapRepresentation]);
      plQuotablesBitmapRep = [bitmap bytes];
      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	@"abcdefghijklmnopqrstuvwxyz$./_"]
	mutableCopy];
      [s invert];
      oldPlQuotables = [s copy];
      RELEASE(s);

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"&<>'\\\""] mutableCopy];
      [s addCharactersInRange: NSMakeRange(0x0001, 0x001f)];
      [s removeCharactersInRange: NSMakeRange(0x0009, 0x0002)];
      [s removeCharactersInRange: NSMakeRange(0x000D, 0x0001)];
      [s addCharactersInRange: NSMakeRange(0xD800, 0x07FF)];
      [s addCharactersInRange: NSMakeRange(0xFFFE, 0x0002)];
      xmlQuotables = [s copy];
      RELEASE(s);
    }

  if (*str == nil)
    {
      *str = AUTORELEASE([GSMutableString new]);
    }
  else if (GSObjCClass(*str) != [GSMutableString class])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Illegal object (%@) at argument 0", *str];
    }
  dest = *str;
  
  if (xml == YES)
    {
      Append([NSMutableString stringWithCString:
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
	"PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" "
	"\"http://www.gnustep.org/plist-0_9.xml\">\n"
	"<plist version=\"0.9\">\n"], dest);
    }

  OAppend(obj, loc, 0, step > 3 ? 3 : step, xml, dest);
  if (xml == YES)
    {
      Append(@"</plist>", dest);
    }
}

