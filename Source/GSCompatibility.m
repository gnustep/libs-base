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

#include "config.h"
#include "Foundation/Foundation.h"
#include "Foundation/NSDebug.h"

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

