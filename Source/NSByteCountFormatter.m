/** Definition of class NSByteCountFormatter
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
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
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

#import "Foundation/NSArchiver.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSByteCountFormatter.h"
#import "Foundation/NSString.h"
#import "Foundation/NSAttributedString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSValue.h"

#define	GSInternal		NSByteCountFormatterInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSByteCountFormatter)

// Unit definitions...
#define KB (double)1024.0
#define MB (double)(1024.0 * 1024.0)
#define GB (double)(1024.0 * 1024.0 * 1024.0)
#define TB (double)(1024.0 * 1024.0 * 1024.0 * 1024.0)
#define PB (double)(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0)
#define EB (double)(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0)
#define ZB (double)(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0)
#define YB (double)(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0)

@implementation NSByteCountFormatter
  
+ (NSString*) stringFromByteCount: (long long)byteCount
                       countStyle: (NSByteCountFormatterCountStyle)countStyle
{
  NSByteCountFormatter *formatter = AUTORELEASE([NSByteCountFormatter new]);

  [formatter setCountStyle: countStyle];
  return [formatter stringFromByteCount: byteCount];
}

- (NSString*) stringForObjectValue: (id)obj
{
  long long byteCount = 0;
  
  if ([obj respondsToSelector: @selector(longLongValue)])
    {
      byteCount = [obj longLongValue];
    }

  return [self stringFromByteCount: byteCount];
}

- (NSByteCountFormatterUnits) _adaptiveSettings: (double)byteCount
{
  NSByteCountFormatterUnits units = NSByteCountFormatterUseDefault;
  
  if (byteCount >= KB || byteCount == 0.0) 
    {
      units = NSByteCountFormatterUseKB;
    }
  if (byteCount >= MB) 
    {
      units = NSByteCountFormatterUseMB;
    }
  if (byteCount >= GB) 
    {
      units = NSByteCountFormatterUseGB;
    }
  if (byteCount >= TB) 
    {
      units = NSByteCountFormatterUseTB;
    }
  if (byteCount >= PB) 
    {
      units = NSByteCountFormatterUsePB;
    }
  if (byteCount >= EB) 
    {
      units = NSByteCountFormatterUseEB;
    }
  if (byteCount >= YB) 
    {
      units = NSByteCountFormatterUseYBOrHigher;
    }
  
  return units;
}

- (NSString*) stringFromByteCount: (long long)byteCount
{
  NSString                      *result = nil;
  double                        bc = (double)byteCount;
  double                        count = 0;
  NSString                      *outputFormat = @"";
  NSString                      *unitName = @"";
  NSByteCountFormatterUnits     allowed = internal->_allowedUnits;

  if (internal->_adaptive)
    {
      allowed = [self _adaptiveSettings: bc];
    }
  else if (allowed == NSByteCountFormatterUseDefault)
    {
      allowed = NSByteCountFormatterUseMB;
    }

  if (allowed & NSByteCountFormatterUseYBOrHigher)
    {
      count = bc / YB;
      unitName = @"YB";
    }
  if (allowed & NSByteCountFormatterUseEB)
    {
      count = bc / EB;
      unitName = @"EB";
    }
  if (allowed & NSByteCountFormatterUsePB)
    {
      count = bc / PB;
      unitName = @"PB";
    }
  if (allowed & NSByteCountFormatterUseTB)
    {
      count = bc / TB;
      unitName = @"TB";
    }
  if (allowed & NSByteCountFormatterUseGB)
    {
      count = bc / GB;
      unitName = @"GB";
    }
  if (allowed & NSByteCountFormatterUseMB)
    {
      count = bc / MB;	    
      unitName = @"MB";
    }
  if (allowed & NSByteCountFormatterUseKB)
    {
      count = bc / KB;
      unitName = @"KB";      
    }
  if (allowed & NSByteCountFormatterUseBytes)
    {
      count = bc;
      unitName = @"bytes";
    }

  if (internal->_allowsNonnumericFormatting && count == 0.0)
    {
      outputFormat = [outputFormat stringByAppendingString: @"Zero"];
    }
  else
    {
      if (internal->_zeroPadsFractionDigits)
	{
	  outputFormat = [outputFormat stringByAppendingString: @"%01.08f"];
	}
      else
	{
	  NSInteger whole = (NSInteger)(count / 1);
	  double frac = (double)count - (double)whole;
	  if (frac > 0.0)
	    {
	      whole += 1;
	    }
	  count = (double)whole;
	  outputFormat = [outputFormat stringByAppendingString: @"%01.0f"];
	}
    }
  
  if (internal->_includesUnit)
    {
      NSString *paddedUnit = [NSString stringWithFormat: @" %@",unitName];
      outputFormat = [outputFormat stringByAppendingString: paddedUnit];
    }

  // Do the formatting...
  result = [NSString stringWithFormat: outputFormat, count];
  
  return result;
}

- (id) init
{
  if (nil == (self = [super init]))
    {
      return nil;
    }

  GS_CREATE_INTERNAL(NSByteCountFormatter);

  internal->_countStyle = NSByteCountFormatterCountStyleFile;
  internal->_allowedUnits = NSByteCountFormatterUseDefault;
  internal->_adaptive = YES;
  internal->_formattingContext = NSFormattingContextUnknown;
  internal->_allowsNonnumericFormatting = YES;
  internal->_includesUnit = YES;

  return self;
}

- (NSFormattingContext) formattingContext
{
  return internal->_formattingContext;
}

- (void) setFormattingContext: (NSFormattingContext)ctx
{
  internal->_formattingContext = ctx;
}

- (NSByteCountFormatterCountStyle) countStyle
{
  return internal->_countStyle;
}

- (void) setCountStyle: (NSByteCountFormatterCountStyle)style
{
  internal->_countStyle = style;
}

- (BOOL) allowsNonnumericFormatting
{
  return internal->_allowsNonnumericFormatting;
}

- (void) setAllowsNonnumericFormatting: (BOOL)flag
{
  internal->_allowsNonnumericFormatting = flag;
}

- (BOOL) includesActualByteCount
{
  return internal->_includesActualByteCount;
}

- (void) setIncludesActualByteCount: (BOOL)flag
{
  internal->_includesActualByteCount = flag;
}

- (BOOL) isAdaptive
{
  return internal->_adaptive;
}

- (void) setAdaptive: (BOOL)flag
{
  internal->_adaptive = flag;
}

- (NSByteCountFormatterUnits) allowedUnits
{
  return internal->_allowedUnits;
}

- (void) setAllowedUnits: (NSByteCountFormatterUnits)units
{
  internal->_allowedUnits = units;
}

- (BOOL) includesCount
{
  return internal->_includesCount;
}

- (void) setIncludesCount: (BOOL)flag
{
  internal->_includesCount = flag;
}

- (BOOL) includesUnit
{
  return internal->_includesUnit;
}

- (void) setIncludesUnit: (BOOL)flag
{
  internal->_includesUnit = flag;
}
  
- (BOOL) zeroPadsFractionDigits
{
  return internal->_zeroPadsFractionDigits;
}

- (void) setZeroPadsFractionDigits: (BOOL)flag
{
  internal->_zeroPadsFractionDigits = flag;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if (nil == (self = [super init]))
    {
      return nil;
    }

  GS_CREATE_INTERNAL(NSByteCountFormatter);

  if ([coder allowsKeyedCoding])
    {
      internal->_formattingContext = [coder decodeIntegerForKey: @"NSFormattingContext"];
      internal->_countStyle = [coder decodeIntegerForKey: @"NSCountStyle"];
      internal->_allowsNonnumericFormatting = !([coder decodeBoolForKey: @"NSNoNonnumeric"]);
      internal->_includesActualByteCount = [coder decodeBoolForKey: @"NSIncludesActualByteCount"];
      internal->_adaptive = !([coder decodeBoolForKey: @"NSNoAdaptive"]);
      internal->_allowedUnits = [coder decodeIntegerForKey: @"NSAllowedUnits"];
      internal->_includesCount = !([coder decodeBoolForKey: @"NSNoCount"]);
      internal->_includesUnit = !([coder decodeBoolForKey: @"NSNoUnit"]);
      internal->_zeroPadsFractionDigits = [coder decodeBoolForKey: @"NSZeroPad"];
    }
  else
    {
      [coder decodeValueOfObjCType: @encode(NSFormattingContext) at: &internal->_formattingContext];
      [coder decodeValueOfObjCType: @encode(NSByteCountFormatterCountStyle) at: &internal->_countStyle];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_allowsNonnumericFormatting];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_includesActualByteCount];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_adaptive];
      [coder decodeValueOfObjCType: @encode(NSByteCountFormatterUnits) at: &internal->_allowedUnits];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_includesCount];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_includesUnit];
      [coder decodeValueOfObjCType: @encode(BOOL) at: &internal->_zeroPadsFractionDigits];
    }

  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: internal->_formattingContext forKey: @"NSFormattingContext"];
      [coder encodeInteger: internal->_countStyle forKey: @"NSCountStyle"];
      [coder encodeBool: !(internal->_allowsNonnumericFormatting) forKey: @"NSNoNonnumeric"];
      [coder encodeBool: internal->_includesActualByteCount forKey: @"NSIncludesActualByteCount"];
      [coder encodeBool: !(internal->_adaptive) forKey: @"NSNoAdaptive"];
      [coder encodeInteger: internal->_allowedUnits forKey: @"NSAllowedUnits"];
      [coder encodeBool: !(internal->_includesCount) forKey: @"NSNoCount"];
      [coder encodeBool: !(internal->_includesUnit) forKey: @"NSNoUnit"];
      [coder encodeBool: internal->_zeroPadsFractionDigits forKey: @"NSZeroPad"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSFormattingContext) at: &internal->_formattingContext];
      [coder encodeValueOfObjCType: @encode(NSByteCountFormatterCountStyle) at: &internal->_countStyle];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_allowsNonnumericFormatting];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_includesActualByteCount];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_adaptive];
      [coder encodeValueOfObjCType: @encode(NSByteCountFormatterUnits) at: &internal->_allowedUnits];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_includesCount];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_includesUnit];
      [coder encodeValueOfObjCType: @encode(BOOL) at: &internal->_zeroPadsFractionDigits];
    }
}

@end
