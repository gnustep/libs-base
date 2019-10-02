
/* Implementation of class NSUnit
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Mon Sep 30 15:58:21 EDT 2019

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

#include <Foundation/NSUnit.h>
#include <Foundation/NSArchiver.h>

@implementation NSUnitConverter
- (double)baseUnitValueFromValue:(double)value
{
  return 0.0;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
  return 0.0;
}
@end

@implementation NSUnit
  
+ (instancetype)new
{
  return [[self alloc] init];
}
           
- (instancetype)init
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_symbol, @"");
    }
  return self;
}
          
- (instancetype)initWithSymbol:(NSString *)symbol
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_symbol, symbol);
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      _symbol = [coder decodeObjectForKey: @"symbol"];
    }
  else
    {
      _symbol = [coder decodeObject];
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeObject: _symbol forKey: @"coder"];
    }
  else
    {
      [coder encodeObject: _symbol];
    }
}

- (instancetype) copyWithZone: (NSZone *)zone
{
  NSUnit *u = [[NSUnit allocWithZone: zone] initWithSymbol: [self symbol]];
  return u;
}

- (NSString *)symbol
{
  return _symbol;
}

@end

