/* Runtime MacOSX compatibility functionality
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
static BOOL setupDone = NO;

static BOOL	MacOSXCompatible = NO;
static BOOL	MacOSXCompatibleGeometry = NO;
static BOOL	MacOSXCompatiblePropertyLists = NO;

/*
 * A trivial class to monitor user defaults to see how we should be
 * producing strings describing geometry structures.
 */
@interface GSBaseDefaultObserver : NSObject
+ (void) defaultsChanged: (NSNotification*)aNotification;
@end
@implementation GSBaseDefaultObserver
+ (void) defaultsChanged: (NSNotification*)aNotification
{
  NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
  id			def;
  Class			sClass = [NSString class];

  MacOSXCompatible = [defaults boolForKey: @"GSMacOSXCompatible"];

  def = [defaults objectForKey: @"GSMacOSXCompatibleGeometry"];
  if (def != nil && [def isKindOfClass: sClass] == YES)
    {
      MacOSXCompatibleGeometry = [def boolValue];
    }
  else
    {
      MacOSXCompatibleGeometry = MacOSXCompatible;
    }
  def = [defaults objectForKey: @"GSMacOSXCompatiblePropertyLists"];
  if (def != nil && [def isKindOfClass: sClass] == YES)
    {
      MacOSXCompatiblePropertyLists = [def boolValue];
    }
  else
    {
      MacOSXCompatiblePropertyLists = MacOSXCompatible;
    }
}
@end

static void
compatibilitySetup()
{
  if (setupDone == NO)
    {
      setupDone = YES;
      [[NSNotificationCenter defaultCenter]
	addObserver: [GSBaseDefaultObserver class]
	   selector: @selector(defaultsChanged:)
	       name: NSUserDefaultsDidChangeNotification
	     object: nil];
      [[GSBaseDefaultObserver class] defaultsChanged: nil];
    }
}

BOOL GSMacOSXCompatible()
{
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatible;
}

BOOL GSMacOSXCompatibleGeometry()
{
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatibleGeometry;
}

BOOL GSMacOSXCompatiblePropertyLists()
{
/* HACK until xml propertylists fully working */
return NO;
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatiblePropertyLists;
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
  unsigned char *sBuf = (unsigned char*)[source bytes];
  unsigned char *dBuf = NSZoneMalloc(NSDefaultMallocZone(), destlen);
  int		sIndex = 0;
  int		dIndex = 0;

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

static NSString*
XMLString(NSString* obj)
{
  /* Should substitute in entities */
  return obj;
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
GSXMLPlMake(id obj, NSDictionary *loc, unsigned lev)
{
  NSMutableString	*dest;

  dest = [NSMutableString stringWithCString:
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
    "SYSTEM \"file://localhost/System/Library/DTDs/PropertyList.dtd\">\n"
    "<plist version=\"0.9\">\n"];

  XMLPlObject(dest, obj, loc, 0);
  [dest appendString: @"</plist>"];
  return dest;
}

