/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/

#ifndef	GNUSTEP

#include "config.h"
#include "Foundation/Foundation.h"
#include "GNUstepBase/NSURL+GNUstepBase.h"

@implementation NSURL (GNUstepBase)
- (NSString*) fullPath
{
  NSRange	r;
  NSString	*s;

  s = [self absoluteString];
  if ((r = [s rangeOfString: @";"]).length > 0)
    {
      s = [s substringToIndex: r.location];
    }
  else if ((r = [s rangeOfString: @"?"]).length > 0)
    {
      s = [s substringToIndex: r.location];
    }
  r = [s rangeOfString: @"//"];
  s = [s substringFromIndex: NSMaxRange(r)];
  r = [s rangeOfString: @"/"];
  s = [s substringFromIndex: r.location];
  return s;
}
@end

#endif

