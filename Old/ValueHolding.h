/* Protocol for Objective-C objects that hold numerical and/or string values.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __ValueHolding_h_GNUSTEP_BASE_INCLUDE
#define __ValueHolding_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

/* protocol String; */

@protocol ValueGetting
- (int) intValue;
- (float) floatValue;
- (double) doubleValue;
- (const char *) cStringValue;
- /* (NSString*) */ stringValue;
@end

@protocol ValueSetting
- (void) setIntValue: (int)anInt;
- (void) setFloatValue: (float)aFloat;
- (void) setDoubleValue: (double)aDouble;
- (void) setCStringValue: (const char *)aCString;
- (void) setStringValue: /* (NSString*) */ aString;
@end

@protocol ValueHolding <ValueGetting, ValueSetting>
@end

#endif /* __ValueHolding_h_GNUSTEP_BASE_INCLUDE */
