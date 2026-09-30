/**Implementation for GSBoxWeak for GNUStep
   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

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

#import "common.h"
#import "Foundation/Foundation.h"
#import "GNUstepBase/GSBoxWeak.h"
#import <objc/runtime.h>

@implementation GSBoxWeak
+ (instancetype) boxWeak: (id)v
{
  return AUTORELEASE([[self alloc] initWithValue: v]);
}
- (void) dealloc
{
  objc_destroyWeak(&value);
  DEALLOC
}
- (id) init
{
  return [self initWithValue: nil];
}
- (instancetype) initWithValue: (id)v
{
  if ((self = [super init]) != nil)
    {
      objc_initWeak(&value, v);
    }
  return self;
}
- (void) setValue: (id)v
{
  objc_storeWeak(&value, v);
}
- (id) value
{
  return objc_loadWeak(&value);
}
@end

