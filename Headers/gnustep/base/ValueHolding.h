/* Protocol for Objective-C objects that hold numerical and/or string values.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

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

#ifndef __ValueHolding_h_INCLUDE_GNU
#define __ValueHolding_h_INCLUDE_GNU

#include <gnustep/base/preface.h>

/* protocol String; */

@protocol ValueGetting
- (int) intValue;
- (float) floatValue;
- (double) doubleValue;
- (const char *) cStringValue;
- /* (id <String>) */ stringValue;
@end

@protocol ValueSetting
- (void) setIntValue: (int)anInt;
- (void) setFloatValue: (float)aFloat;
- (void) setDoubleValue: (double)aDouble;
- (void) setCStringValue: (const char *)aCString;
- (void) setStringValue: /* (id <String>) */ aString;
@end

@protocol ValueHolding <ValueGetting, ValueSetting>
@end

#endif /* __ValueHolding_h_INCLUDE_GNU */
