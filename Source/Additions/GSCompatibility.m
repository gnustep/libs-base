/* GSCompatibility - Extra definitions for compiling on MacOSX

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Written by:  Stephane Corthesy on Sat Nov 16 2002.

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
#import "common.h"
#include <objc/objc-class.h>
#import "GNUstepBase/GCObject.h"

/* Avoid compiler warnings about internal method
*/
@interface	NSError (GNUstep)
+ (NSError*) _last;
@end

NSThread *GSCurrentThread()
{
  return [NSThread currentThread];
}

NSMutableDictionary *GSCurrentThreadDictionary()
{
  return [[NSThread currentThread] threadDictionary];
}

NSArray *NSStandardLibraryPaths()
{
  return NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
					       NSAllDomainsMask, YES);
}

// Defined in NSDecimal.m
void NSDecimalFromComponents(NSDecimal *result,
			     unsigned long long mantissa,
			     short exponent, BOOL negative)
{
  *result = [[NSDecimalNumber decimalNumberWithMantissa:mantissa
			      exponent:exponent
			      isNegative:negative] decimalValue];
}

// Defined in NSDebug.m
NSString*
GSDebugMethodMsg(id obj, SEL sel, const char *file, int line, NSString *fmt)
{
  NSString	*message;
  Class		cls = [obj class];
  char		c = '-';

  cls = [obj class];
  if (class_isMetaClass(cls))
    {
      c = '+';
      cls = (Class)obj;
    }
  message = [NSString stringWithFormat: @"File %s: %d. In [%@ %c%@] %@",
    file, line, NSStringFromClass(cls), c, NSStringFromSelector(sel), fmt];
  return message;
}

NSString*
GSDebugFunctionMsg(const char *func, const char *file, int line, NSString *fmt)
{
  NSString *message;

  message = [NSString stringWithFormat: @"File %s: %d. In %s %@",
    file, line, func, fmt];
  return message;
}

