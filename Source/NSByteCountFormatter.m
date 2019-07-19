/* Definition of class NSByteCountFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Written by: 	Gregory Casamento <greg.casamento@gmail.com>
   Date: 	July 2019
   
   This file is part of the GNUstep Library.
   
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
#define	GS_NSByteCountFormatter_IVARS \
 NSFormattingContext _formattingContext; \
 NSByteCountFormatterCountStyle _countStyle; \
 BOOL _allowsNonnumericFormatting; \
 BOOL _includesActualByteCount; \
 BOOL _adaptive; \
 NSByteCountFormatterUnits _allowedUnits; \
 BOOL _includesCount; \
 BOOL _includesUnit; \
 BOOL _zeroPadsFractionDigits; 

#define	EXPOSE_NSByteCountFormatter_IVARS	1

#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSValue.h>

#define	GSInternal		NSByteCountFormatterInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSByteCountFormatter)


@implementation NSByteCountFormatter
  
+ (NSString *)stringFromByteCount: (long long)byteCount
                       countStyle: (NSByteCountFormatterCountStyle)countStyle
{
  NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
  [formatter setCountStyle: countStyle];
  return [formatter stringFromByteCount: byteCount];
}

- (NSString *)stringFromByteCount: (long long)byteCount
{
  
  return nil;
}

- (id) init
{
  self = [super init];
  if(self == nil)
    {
      return nil;
    }

  GS_CREATE_INTERNAL(NSByteCountFormatter);

  internal->_countStyle = NSByteCountFormatterCountStyleFile;
  internal->_allowedUnits |= NSByteCountFormatterUseMB;

  return self;
}

- (NSFormattingContext) formattingContext
{
  return _formattingContext;
}

- (void) setFormattingContext: (NSFormattingContext)ctx
{
  _formattingContext = ctx;
}

- (NSByteCountFormatterCountStyle) countStyle
{
  return _countStyle;
}

- (void) setCountStyle: (NSByteCountFormatterCountStyle)style
{
  _countStyle = style;
}

- (BOOL) allowsNonnumericFormatting
{
  return _allowsNonnumericFormatting;
}

- (void) setAllowsNonnumericFormatting: (BOOL)flag
{
  _allowsNonnumericFormatting = flag;
}

- (BOOL) includesActualByteCount
{
  return _includesActualByteCount;
}

- (void) setIncludesActualByteCount: (BOOL)flag
{
  _includesActualByteCount = flag;
}

- (BOOL) adaptive
{
  return _adaptive;
}

- (void) setAdaptive: (BOOL)flag
{
  _adaptive = flag;
}

- (NSByteCountFormatterUnits) allowedUnits
{
  return _allowedUnits;
}

- (void) setAllowedUnits: (NSByteCountFormatterUnits)units
{
  _allowedUnits = units;
}

- (BOOL) includesCount
{
  return _includesCount;
}

- (void) setIncludesCount: (BOOL)flag
{
  _includesCount = flag;
}

- (BOOL) includesUnit
{
  return _includesUnit;
}

- (void) setIncludesUnit: (BOOL)flag
{
  _includesUnit = flag;
}
  
- (BOOL) zeroPadsFractionDigits
{
  return _zeroPadsFractionDigits;
}

- (void) setZeroPadsFractionDigits: (BOOL)flag
{
  _zeroPadsFractionDigits = flag;
}

@end

