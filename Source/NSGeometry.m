/* NSGeometry.m - geometry functions
 * Copyright (C) 1993, 1994, 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: Mar 1995
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

/**** Included Headers *******************************************************/

/*
 *	Define IN_NSGEOMETRY_M so that the Foundation/NSGeometry.h header can
 *	provide non-inline versions of the function implementations for us.
 */
#define	IN_NSGEOMETRY_M

#include <config.h>
#include <math.h>
#include <base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>

extern BOOL	GSMacOSXCompatibleGeometry();	// Compatibility mode

static Class	NSStringClass = 0;
static Class	NSScannerClass = 0;
static SEL	scanFloatSel = @selector(scanFloat:);
static SEL	scanStringSel = @selector(scanString:intoString:);
static SEL	scannerSel = @selector(scannerWithString:);
static BOOL	(*scanFloatImp)(NSScanner*, SEL, float*);
static BOOL	(*scanStringImp)(NSScanner*, SEL, NSString*, NSString**);
static id 	(*scannerImp)(Class, SEL, NSString*);

static inline void
setupCache()
{
  if (NSStringClass == 0)
    {
      NSStringClass = [NSString class];
      NSScannerClass = [NSScanner class];
      scanFloatImp = (BOOL (*)(NSScanner*, SEL, float*))
	[NSScannerClass instanceMethodForSelector: scanFloatSel];
      scanStringImp = (BOOL (*)(NSScanner*, SEL, NSString*, NSString**))
	[NSScannerClass instanceMethodForSelector: scanStringSel];
      scannerImp = (id (*)(Class, SEL, NSString*))
	[NSScannerClass methodForSelector: scannerSel];
    }
}

/**** Function Implementations ***********************************************/
/* Most of these are implemented in the header file as inline functkions */

NSRect
NSIntegralRect(NSRect aRect)
{
  NSRect	rect;

  if (NSIsEmptyRect(aRect))
    return NSMakeRect(0, 0, 0, 0);

  rect.origin.x = floor(aRect.origin.x);
  rect.origin.y = floor(aRect.origin.y);
  rect.size.width = ceil(aRect.size.width);
  rect.size.height = ceil(aRect.size.height);
  return rect;
}

void 	
NSDivideRect(NSRect aRect,
             NSRect *slice,
             NSRect *remainder,
             float amount,
             NSRectEdge edge)
{
  static NSRect sRect;
  static NSRect	rRect;
    
  if (!slice)
    slice = &sRect;
  if (!remainder)
    remainder = &rRect;
    
  if (NSIsEmptyRect(aRect))
    {
      *slice = NSMakeRect(0,0,0,0);
      *remainder = NSMakeRect(0,0,0,0);
      return;
    }

  switch (edge)
    {
      case NSMinXEdge:
	if (amount > aRect.size.width)
	  {
	    *slice = aRect;
	    *remainder = NSMakeRect(NSMaxX(aRect),
				    aRect.origin.y, 
				    0,
				    aRect.size.height);
	  }
	else
	  {
	    *slice = NSMakeRect(aRect.origin.x,
				aRect.origin.y,
				amount, 
				aRect.size.height);
	    *remainder = NSMakeRect(NSMaxX(*slice),
				    aRect.origin.y, 
				    NSMaxX(aRect) - NSMaxX(*slice),
				    aRect.size.height);
	  }
	break;
      case NSMinYEdge:
	if (amount > aRect.size.height)
	  {
	    *slice = aRect;
	    *remainder = NSMakeRect(aRect.origin.x,
				    NSMaxY(aRect), 
				    aRect.size.width, 0);
	  }
	else
	  {
	    *slice = NSMakeRect(aRect.origin.x,
				aRect.origin.y, 
				aRect.size.width,
				amount);
	    *remainder = NSMakeRect(aRect.origin.x,
				    NSMaxY(*slice), 
				    aRect.size.width,
				    NSMaxY(aRect) - NSMaxY(*slice));
	  }
	break;
      case (NSMaxXEdge):
	if (amount > aRect.size.width)
	  {
	    *slice = aRect;
	    *remainder = NSMakeRect(aRect.origin.x,
				    aRect.origin.y, 
				    0,
				    aRect.size.height);
	  }
	else
	  {
	    *slice = NSMakeRect(NSMaxX(aRect) - amount,
				aRect.origin.y,
				amount,
				aRect.size.height);
	    *remainder = NSMakeRect(aRect.origin.x,
				    aRect.origin.y, 
				    NSMinX(*slice) - aRect.origin.x,
				    aRect.size.height);
	  }
	break;
      case NSMaxYEdge:
	if (amount > aRect.size.height)
	  {
	    *slice = aRect;
	    *remainder = NSMakeRect(aRect.origin.x,
				    aRect.origin.y, 
				    aRect.size.width,
				    0);
	  }
	else
	  {
	    *slice = NSMakeRect(aRect.origin.x,
				NSMaxY(aRect) - amount, 
				aRect.size.width,
				amount);
	    *remainder = NSMakeRect(aRect.origin.x,
				    aRect.origin.y, 
				    aRect.size.width,
				    NSMinY(*slice) - aRect.origin.y);
	  }
	break;
      default:
	break;
    }

  return;
}

/** Get a String Representation... **/

NSString*
NSStringFromPoint(NSPoint aPoint)
{
  setupCache();
  if (GSMacOSXCompatibleGeometry() == YES)
    return [NSStringClass stringWithFormat:
      @"{%g, %g}", aPoint.x, aPoint.y];
  else
    return [NSStringClass stringWithFormat:
      @"{x=%g; y=%g}", aPoint.x, aPoint.y];
}

NSString*
NSStringFromRect(NSRect aRect)
{
  setupCache();
  if (GSMacOSXCompatibleGeometry() == YES)
    return [NSStringClass stringWithFormat:
      @"{{%g, %g}, {%g, %g}}",
      aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height];
  else
    return [NSStringClass stringWithFormat:
      @"{x=%g; y=%g; width=%g; height=%g}",
      aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height];
}

NSString*
NSStringFromSize(NSSize aSize)
{
  setupCache();
  if (GSMacOSXCompatibleGeometry() == YES)
    return [NSStringClass stringWithFormat:
      @"{%g, %g}", aSize.width, aSize.height];
  else
    return [NSStringClass stringWithFormat:
      @"{width=%g; height=%g}", aSize.width, aSize.height];
}

NSPoint
NSPointFromString(NSString* string)
{
  NSScanner	*scanner;
  NSPoint	point;

  setupCache();
  scanner = (*scannerImp)(NSScannerClass, scannerSel, string);
  if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"x", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &point.x)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"y", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &point.y)
    && (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
    {
      return point;
    }
  else
    {
      [scanner setScanLocation: 0];
      if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &point.x)
	&& (*scanStringImp)(scanner, scanStringSel, @",", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &point.y)
	&& (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
	{
	  return point;
	}
      else
	{
	  return NSMakePoint(0, 0);
	}
    }
}

NSSize
NSSizeFromString(NSString* string)
{
  NSScanner	*scanner;
  NSSize	size;
  
  setupCache();
  scanner = (*scannerImp)(NSScannerClass, scannerSel, string);
  if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"width", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &size.width)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"height", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &size.height)
    && (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
    {
      return size;
    }
  else
    {
      [scanner setScanLocation: 0];
      if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &size.width)
	&& (*scanStringImp)(scanner, scanStringSel, @",", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &size.height)
	&& (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
	{
	  return size;
	}
      else
	{
	  return NSMakeSize(0, 0);
	}
    }
}

NSRect
NSRectFromString(NSString* string)
{
  NSScanner	*scanner;
  NSRect	rect;
  
  setupCache();
  scanner = (*scannerImp)(NSScannerClass, scannerSel, string);
  if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"x", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &rect.origin.x)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)

    && (*scanStringImp)(scanner, scanStringSel, @"y", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &rect.origin.y)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)
      
    && (*scanStringImp)(scanner, scanStringSel, @"width", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &rect.size.width)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)
      
    && (*scanStringImp)(scanner, scanStringSel, @"height", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanFloatImp)(scanner, scanFloatSel, &rect.size.height)
    && (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
    {
      return rect;
    }
  else
    {
      [scanner setScanLocation: 0];
      if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
	&& (*scanStringImp)(scanner, scanStringSel, @"{", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &rect.origin.x)
	&& (*scanStringImp)(scanner, scanStringSel, @",", NULL)

	&& (*scanFloatImp)(scanner, scanFloatSel, &rect.origin.y)
	&& (*scanStringImp)(scanner, scanStringSel, @"}", NULL)
	&& (*scanStringImp)(scanner, scanStringSel, @",", NULL)
	  
	&& (*scanStringImp)(scanner, scanStringSel, @"{", NULL)
	&& (*scanFloatImp)(scanner, scanFloatSel, &rect.size.width)
	&& (*scanStringImp)(scanner, scanStringSel, @",", NULL)
	  
	&& (*scanFloatImp)(scanner, scanFloatSel, &rect.size.height)
	&& (*scanStringImp)(scanner, scanStringSel, @"}", NULL)
	&& (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
	{
	  return rect;
	}
      else
	{
	  return NSMakeRect(0, 0, 0, 0);
	}
    }
}

