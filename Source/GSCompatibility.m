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

#include "GSUserDefaults.h"

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

BOOL GSMacOSXCompatibleGeometry()
{
  if (GSUserDefaultsFlag(GSOldStyleGeometry) == YES)
    return NO;
  return GSUserDefaultsFlag(GSMacOSXCompatible);
}

BOOL GSMacOSXCompatiblePropertyLists()
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

static NSCharacterSet *quotables = nil;

static void setupQuotables()
{
  if (quotables == nil)
    {
      NSMutableCharacterSet	*s;

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"&<>'\\\""] mutableCopy];
      [s addCharactersInRange: NSMakeRange(0x0001, 0x001f)];
      [s removeCharactersInRange: NSMakeRange(0x0009, 0x0002)];
      [s removeCharactersInRange: NSMakeRange(0x000D, 0x0001)];
      [s addCharactersInRange: NSMakeRange(0xD800, 0x07FF)];
      [s addCharactersInRange: NSMakeRange(0xFFFE, 0x0002)];
      quotables = [s copy];
      RELEASE(s);
    }
}

static NSString*
XMLString(NSString* obj)
{
  static char	*hexdigits = "0123456789ABCDEF";
  unsigned	end;

  end = [obj length];
  if (end == 0)
    {
      return obj;
    }

  if (quotables == nil)
    {
      setupQuotables();
    }

  if ([obj rangeOfCharacterFromSet: quotables].length > 0)
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
      return [NSString stringWithCharacters: map length: len];
    }
  else
    {
      return obj;
    }
}

static NSString	*indentStrings[] = {
  @"",
  @"    ",
  @"\t",
  @"\t    ",
  @"\t\t",
  @"\t\t    ",
  @"\t\t\t",
  @"\t\t\t    ",
  @"\t\t\t\t",
  @"\t\t\t\t    ",
  @"\t\t\t\t\t",
  @"\t\t\t\t\t    ",
  @"\t\t\t\t\t\t"
};

static void
XMLPlObject(NSMutableString *dest, id obj, NSDictionary *loc, unsigned lev)
{
  if (lev >= sizeof(indentStrings) / sizeof(*indentStrings))
    lev = sizeof(indentStrings) / sizeof(*indentStrings) - 1;

  [dest appendString: indentStrings[lev]];

  if ([obj isKindOfClass: [NSString class]])
    {
      [dest appendString: @"<string>"];
      [dest appendString: XMLString(obj)];
      [dest appendString: @"</string>\n"];
    }
  else if ([obj isKindOfClass: [NSNumber class]])
    {
      double	val = [obj doubleValue];

      if (val == 1.0)
	{
	  [dest appendString: @"<true/>\n"];
	}
      else if (val == 0.0)
	{
	  [dest appendString: @"<false/>\n"];
	}
      else if (rint(val) == val)
	{
	  [dest appendString: @"<integer>"];
	  [dest appendString: [obj stringValue]];
	  [dest appendString: @"</integer>\n"];
	}
      else
	{
	  [dest appendString: @"<real>"];
	  [dest appendString: [obj stringValue]];
	  [dest appendString: @"</real>\n"];
	}
    }
  else if ([obj isKindOfClass: [NSData class]])
    {
      [dest appendString: @"<data>"];
      [dest appendString: encodeBase64(obj)];
      [dest appendString: @"</data>\n"];
    }
  else if ([obj isKindOfClass: [NSDate class]])
    {
      [dest appendString: @"<date>"];
      [dest appendString:
	[obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"]];
      [dest appendString: @"</date>\n"];
    }
  else if ([obj isKindOfClass: [NSArray class]])
    {
      NSEnumerator	*e;

      [dest appendString: @"<array>\n"];
      e = [obj objectEnumerator];
      while ((obj = [e nextObject]))
        {
          XMLPlObject(dest, obj, loc, lev + 1);
        }
      [dest appendString: indentStrings[lev]];
      [dest appendString: @"</array>\n"];
    }
  else if ([obj isKindOfClass: [NSDictionary class]])
    {
      NSEnumerator	*e;
      id		key;
      unsigned		nxt = lev + 1;

      if (lev >= sizeof(indentStrings) / sizeof(*indentStrings))
	lev = sizeof(indentStrings) / sizeof(*indentStrings) - 1;

      [dest appendString: @"<dict>\n"];
      e = [obj keyEnumerator];
      while ((key = [e nextObject]))
        {
	  id	val;

          val = [obj objectForKey: key];
	  [dest appendString: indentStrings[nxt]];
	  [dest appendString: @"<key>"];
	  [dest appendString: XMLString(key)];
	  [dest appendString: @"</key>\n"];
          XMLPlObject(dest, val, loc, nxt);
        }
      [dest appendString: indentStrings[lev]];
      [dest appendString: @"</dict>\n"];
    }
  else
    {
      NSLog(@"Non-property-list class encoded as string");
      [dest appendString: @"<string>"];
      [dest appendString: [obj description]];
      [dest appendString: @"</string>\n"];
    }
}

NSString*
GSXMLPlMake(id obj, NSDictionary *loc)
{
  NSMutableString	*dest;

  dest = [NSMutableString stringWithCString:
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
    "PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" "
    "\"http://www.gnustep.org/plist-0_9.xml\">\n"
    "<plist version=\"0.9\">\n"];

  XMLPlObject(dest, obj, loc, 0);
  [dest appendString: @"</plist>"];
  return dest;
}

