/**
   NSKVOLegacy.m

   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: greg.casamento@gmail.com
   Date: December 2024

   This method implements the older methods that are still supported by
   Apple, but are considered legacy.

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "common.h"
#import "NSKVOInternal.h"
#import <objc/objc-arc.h>
#import <stdatomic.h>

#import "Foundation/NSArray.h"
#import "Foundation/NSString.h"

@interface NSObject (NSKVOLegacyMethods)
+ (void) setKeys: (NSArray *)keysArray triggerChangeNotificationsForDependentKey: (NSString *)key;
@end

@implementation NSObject (NSKVOLegacyMethods)

+ (void) setKeys: (NSArray *)keysArray triggerChangeNotificationsForDependentKey: (NSString *)key
{
  NSLog(@"setKeys: called...%@, %@", keysArray, key);
}

@end
